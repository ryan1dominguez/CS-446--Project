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

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.primary.endpoint
}

output "rds_address" {
  description = "RDS database address (hostname only)"
  value       = aws_db_instance.primary.address
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.primary.db_name
}

output "database_username" {
  description = "Database username"
  value       = aws_db_instance.primary.username
  sensitive   = true
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret containing DB password"
  value       = aws_secretsmanager_secret.db_password.name
}

output "rds_replica_endpoint" {
  description = "Endpoint of our Replica RDS DB"
  value       = aws_db_instance.replica.endpoint
}

output "rds_replica_address" {
  description = "RDS replica address (hostname)"
  value       = aws_db_instance.replica.address
}

output "rds_replica_arn" {
  description = "RDS replica ARN"
  value       = aws_db_instance.replica.arn
}