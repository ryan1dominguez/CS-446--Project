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
        yum update -y

        yum install -y docker

        systemctl start docker
        systemctl enable docker

        docker pull ${var.docker_image}
        docker run -d -p 3000:3000 -e AWS_REGION=${var.aws_region} --restart unless-stopped ${var.docker_image}

        sleep 10
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

resource "aws_autoscaling_group" "app" {
    name = "ha-dr-asg"
    desired_capacity = var.desired_capacity
    max_size = var.max_size
    min_size = var.min_size
    target_group_arns = [aws_lb_target_group.app.arn]
    vpc_zone_identifier = data.aws_subnets.default.ids

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