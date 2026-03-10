variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "data_subnet_ids" {
  type        = list(string)
  description = "Isolated subnet IDs for RDS (data tier)."
}

variable "security_group_id" {
  type        = string
  description = "RDS security group ID."
}

variable "engine_version" {
  type        = string
  description = "Postgres engine version."
  default     = "16.4"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class. Use db.t4g.micro for dev/staging, db.t4g.medium+ for prod."
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Initial allocated storage in GiB."
  default     = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Storage autoscaling ceiling in GiB. Set equal to allocated_storage to disable."
  default     = 100
}

variable "multi_az" {
  type        = bool
  description = "Enable Multi-AZ standby replica for automatic failover. Required in prod."
  default     = false
}

variable "deletion_protection" {
  type        = bool
  description = "Prevent Terraform (and the console) from deleting the instance. Always true in prod."
  default     = false
}

variable "backup_retention_days" {
  type        = number
  description = "Automated backup retention period in days. Minimum 1 for point-in-time recovery."
  default     = 7
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Enable Performance Insights for query-level visibility. Recommended in prod."
  default     = false
}

variable "db_name" {
  type        = string
  description = "Name of the initial database."
  default     = "chatty"
}

variable "db_username" {
  type        = string
  description = "Master DB username."
  default     = "chatty"
}
