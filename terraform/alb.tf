# Target Group for EC2 instances
resource "aws_lb_target_group" "app" {
  name     = "ha-dr-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "ha-dr-target-group"
  }
}

# Application Load Balancer
resource "aws_lb" "app" {
  name               = "ha-dr-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.available_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "ha-dr-alb"
  }
}

# Listener for HTTP traffic
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}


data "aws_vpc" "default_secondary" {
  provider = aws.secondary
  default  = true
}

data "aws_subnets" "default_secondary" {
  provider = aws.secondary

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_secondary.id]
  }
}


# Target Group (secondary)
resource "aws_lb_target_group" "app_secondary" {
  provider = aws.secondary

  name     = "ha-dr-tg-secondary"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_secondary.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "ha-dr-target-group-secondary"
  }
}

# ALB (secondary)
resource "aws_lb" "app_secondary" {
  provider           = aws.secondary
  name               = "ha-dr-alb-secondary"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_secondary.id]
  subnets            = data.aws_subnets.default_secondary.ids

  enable_deletion_protection = false

  tags = {
    Name = "ha-dr-alb-secondary"
  }
}

# Listener (secondary)
resource "aws_lb_listener" "app_secondary" {
  provider          = aws.secondary
  load_balancer_arn = aws_lb.app_secondary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_secondary.arn
  }
}
