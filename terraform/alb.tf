resource "aws_lb_target_group" "app" {
    name = "ha-dr-tg"
    port = 3000
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id 

    health_check {
        enabled = true 
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 5
        interval = 30
        path = "/health"
        matcher = "200"
    }

    deregistration_delay = 30

    tags = {
        Name = "ha-dr-target-group"
    }
}

resource "aws_lb" "app" {
    name = "ha-dr-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.alb.id]
    subnets = data.aws_subnets.default.ids

    enable_deletion_protection = false

    tags = {
        Name = "ha-dr-alb"
    }

}

resource "aws_lb_listener" "app" {
    load_balancer_arn = aws_lb.app.arn 
    port = "80"
    protocol = "HTTP"

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.app.arn
    }
}