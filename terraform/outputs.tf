output "load_balancer_url" {
    description = "The url of the app load balancer"
    value = "http://${aws_lb.app.dns_name}"
}

output "load_balancer_dns" {
    description = "The dns name of the app load balancer"
    value = aws_lb.app.dns_name
}

output "app_security_group_id" {
    description = "ID of the app security group"
    value = aws_security_group.app.id
}