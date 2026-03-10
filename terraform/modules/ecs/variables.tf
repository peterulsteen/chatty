variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS task networking."
}

variable "security_group_id" {
  type        = string
  description = "Security group ID applied to ECS tasks."
}

variable "target_group_arn" {
  type        = string
  description = "ALB target group ARN the ECS service registers into."
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix for ALB-based auto-scaling CloudWatch metrics."
}

variable "target_group_arn_suffix" {
  type        = string
  description = "Target group ARN suffix for ALB-based auto-scaling CloudWatch metrics."
}

variable "container_image" {
  type        = string
  description = "Full ECR image URI including git SHA tag (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/chatty-dev/chatty:abc1234)."
}

variable "container_port" {
  type    = number
  default = 8000
}

variable "cpu" {
  type        = number
  description = "Fargate task CPU units (256 | 512 | 1024 | 2048 | 4096)."
  default     = 256
}

variable "memory" {
  type        = number
  description = "Fargate task memory in MiB."
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "Initial desired task count. Managed by auto-scaling after first deploy."
  default     = 1
}

variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 4
}

variable "database_url_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for DATABASE_URL. Pass empty string to skip secret injection."
  default     = ""
}

variable "environment_variables" {
  type        = map(string)
  description = "Non-sensitive environment variables injected into the container."
  default     = {}
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log group retention in days."
  default     = 30
}
