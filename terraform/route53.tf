data "aws_route53_zone" "main" {
  zone_id = "Z05797891QSG0DWTK9LDY"
}

resource "aws_route53_health_check" "primary" {
  fqdn          = aws_lb.app.dns_name
  port          = 80
  type          = "HTTP"
  resource_path = "/health"
}

resource "aws_route53_health_check" "secondary" {
  fqdn          = aws_lb.app_secondary.dns_name
  port          = 80
  type          = "HTTP"
  resource_path = "/health"
}


resource "aws_route53_record" "app_primary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name = "api.cs446test.com"
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }

  set_identifier = "primary-alb"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary.id
}

resource "aws_route53_record" "app_secondary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name = "api.ha-project-demo.com"

  type    = "A"

  alias {
    name                   = aws_lb.app_secondary.dns_name
    zone_id                = aws_lb.app_secondary.zone_id
    evaluate_target_health = true
  }

  set_identifier = "secondary-alb"

  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = aws_route53_health_check.secondary.id
}