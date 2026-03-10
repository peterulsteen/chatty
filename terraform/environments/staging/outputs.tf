output "alb_dns_name" {
  description = "ALB DNS name — point your dev domain CNAME here."
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL — set as image registry in CI/CD."
  value       = module.ecs.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.ecs.ecs_service_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS task logs."
  value       = module.ecs.cloudwatch_log_group
}
