variable "project" {
  type    = string
  default = "chatty"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "data_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "single_nat_gateway" {
  type        = bool
  description = "Single NAT saves ~$30/mo in dev. Not HA — always false in prod."
  default     = true
}

# ── ALB ───────────────────────────────────────────────────────────────────────

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the HTTPS listener."
}

variable "cors_origins" {
  type    = list(string)
  default = ["http://localhost:3000"]
}

# ── RDS ───────────────────────────────────────────────────────────────────────

variable "create_rds" {
  type        = bool
  description = "Provision an RDS Postgres instance. Disabled in dev by default."
  default     = false
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "rds_multi_az" {
  type    = bool
  default = false
}

variable "rds_deletion_protection" {
  type    = bool
  default = false
}

# ── ECS ───────────────────────────────────────────────────────────────────────

variable "container_image" {
  type        = string
  description = "Full ECR image URI including git SHA tag."
}

variable "ecs_cpu" {
  type    = number
  default = 256
}

variable "ecs_memory" {
  type    = number
  default = 512
}

variable "ecs_desired_count" {
  type    = number
  default = 1
}

variable "ecs_min_capacity" {
  type    = number
  default = 1
}

variable "ecs_max_capacity" {
  type    = number
  default = 2
}
