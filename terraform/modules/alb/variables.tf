variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the ALB."
}

variable "security_group_id" {
  type        = string
  description = "ALB security group ID."
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the HTTPS listener."
}

variable "health_check_path" {
  type        = string
  description = "HTTP path the ALB uses for target health checks."
  default     = "/health/"
}

variable "container_port" {
  type        = number
  description = "Container port the ALB forwards traffic to."
  default     = 8000
}

variable "deregistration_delay" {
  type        = number
  description = "Seconds before deregistering draining targets. Lower = faster zero-downtime deploys."
  default     = 30
}
