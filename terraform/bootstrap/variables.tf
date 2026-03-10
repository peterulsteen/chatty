variable "project" {
  type        = string
  description = "Project name — namespaces all bootstrap resources."
}

variable "aws_region" {
  type        = string
  description = "AWS region for bootstrap resources."
  default     = "us-east-1"
}
