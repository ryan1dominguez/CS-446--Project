data "aws_ami" "amazon_linux" {
    most_recent = true
    owners = ["amazon"]

    filter {
        name = "name"
        values = ["al2023-ami-*-x86_64"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

}



data "aws_ami" "amazon_linux_secondary" {
  provider    = aws.secondary
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_iam_role" "ec2_role" {
    name = "ha-dr-ec2-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
    role = aws_iam_role.ec2_role.name
    policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "secrets_access" {
  name = "ha-dr-secrets-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
    name = "ha-dr-ec2-profile"
    role = aws_iam_role.ec2_role.name
}

resource "aws_launch_template" "app" {
    name_prefix = "ha-dr-app-"
    image_id = data.aws_ami.amazon_linux.id 
    instance_type = var.instance_type

    iam_instance_profile {
        name = aws_iam_instance_profile.ec2_profile.name
    }
    
    vpc_security_group_ids = [aws_security_group.app.id]

    user_data = base64encode(<<-EOF
              #!/bin/bash
              set -e
              
              exec > >(tee /var/log/user-data.log)
              exec 2>&1
              
              echo "=== Starting user data script ==="
              
              yum update -y
              
              yum install -y docker aws-cli
              
              systemctl start docker
              systemctl enable docker
              
              echo "Fetching database password..."
              DB_PASSWORD=$(aws secretsmanager get-secret-value \
                --secret-id ${aws_secretsmanager_secret.db_password.name} \
                --region ${var.aws_region} \
                --query SecretString \
                --output text)
              
              echo "Pulling Docker image..."
              docker pull ${var.docker_image}
              
              echo "Starting application container..."
              docker run -d \
                -p 3000:3000 \
                -e AWS_REGION=${var.aws_region} \
                -e DB_HOST=${aws_db_instance.primary.address} \
                -e DB_PORT=5432 \
                -e DB_NAME=orders_db \
                -e DB_USER=postgres \
                -e DB_PASSWORD="$DB_PASSWORD" \
                -e DB_SSL=true \
                --restart unless-stopped \
                --name ha-dr-app \
                ${var.docker_image}
              
              echo "=== User data script complete ==="
              EOF
  )

    monitoring {
        enabled = true
    }

    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "ha-dr-app-instance"
        }
    }

}



resource "aws_launch_template" "app_secondary" {
  provider    = aws.secondary
  name_prefix = "ha-dr-app-secondary-"
  image_id    = data.aws_ami.amazon_linux_secondary.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name  # IAM role is global
  }

  vpc_security_group_ids = [aws_security_group.app_secondary.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log)
    exec 2>&1

    yum update -y
    yum install -y docker aws-cli

    systemctl start docker
    systemctl enable docker

    echo "Fetching database password..."
    DB_PASSWORD=$(aws secretsmanager get-secret-value \
      --secret-id ${aws_secretsmanager_secret.db_password.name} \
      --region ${var.aws_region} \
      --query SecretString \
      --output text)

    echo "Pulling Docker image..."
    docker pull ${var.docker_image}

    echo "Starting application container..."
    docker run -d \
      -p 3000:3000 \
      -e AWS_REGION=${var.secondary_region} \
      -e DB_HOST=${aws_db_instance.primary.address} \
      -e DB_PORT=5432 \
      -e DB_NAME=orders_db \
      -e DB_USER=postgres \
      -e DB_PASSWORD="$DB_PASSWORD" \
      -e DB_SSL=true \
      --restart unless-stopped \
      --name ha-dr-app \
      ${var.docker_image}
  EOF
  )

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ha-dr-app-instance-secondary"
    }
  }
}



resource "aws_autoscaling_group" "app" {
    name = "ha-dr-asg"
    desired_capacity = var.desired_capacity
    max_size = var.max_size
    min_size = var.min_size
    target_group_arns = [aws_lb_target_group.app.arn]
    vpc_zone_identifier = local.available_subnet_ids

    launch_template {
        id = aws_launch_template.app.id
        version = "$Latest"
    }

    health_check_type = "ELB"
    health_check_grace_period = 300

    tag {
        key = "Name"
        value = "ha-dr-app-asg-instance"
        propagate_at_launch = true
    }

}


resource "aws_autoscaling_group" "app_secondary" {
  provider = aws.secondary

  name               = "ha-dr-asg-secondary"
  desired_capacity   = var.desired_capacity
  max_size           = var.max_size
  min_size           = var.min_size
  target_group_arns  = [aws_lb_target_group.app_secondary.arn]
  vpc_zone_identifier = data.aws_subnets.default_secondary.ids

  launch_template {
    id      = aws_launch_template.app_secondary.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "ha-dr-app-asg-instance-secondary"
    propagate_at_launch = true
  }
}
