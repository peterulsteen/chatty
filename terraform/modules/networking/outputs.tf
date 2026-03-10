output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB tier) — one per AZ."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (ECS tier) — one per AZ."
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "Isolated data subnet IDs (RDS tier) — one per AZ."
  value       = aws_subnet.data[*].id
}

output "alb_security_group_id" {
  description = "ALB security group ID."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "App (ECS task) security group ID."
  value       = aws_security_group.app.id
}

output "rds_security_group_id" {
  description = "RDS security group ID."
  value       = aws_security_group.rds.id
}
