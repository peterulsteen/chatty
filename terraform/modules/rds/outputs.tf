output "database_url_secret_arn" {
  description = "Secrets Manager ARN for DATABASE_URL — pass to the ECS module."
  value       = aws_secretsmanager_secret.database_url.arn
}

output "db_endpoint" {
  description = "RDS endpoint (host:port)."
  value       = aws_db_instance.main.endpoint
}

output "db_instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.main.identifier
}
