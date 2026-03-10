output "ecr_repository_url" {
  description = "ECR repository URL — use as the image registry base in CI/CD."
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role (runtime container permissions)."
  value       = aws_iam_role.task.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name for ECS task logs."
  value       = aws_cloudwatch_log_group.app.name
}
