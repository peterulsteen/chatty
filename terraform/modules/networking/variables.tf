variable "project" {
  type        = string
  description = "Project name — used as a prefix on all resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones to deploy into. Minimum 2 required."
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for high availability."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets (ALB). One per AZ — length must match availability_zones."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private app subnets (ECS). One per AZ."
}

variable "data_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for isolated data subnets (RDS). One per AZ."
}

variable "single_nat_gateway" {
  type        = bool
  description = "Deploy one shared NAT Gateway instead of one per AZ. Reduces cost in dev; not HA."
  default     = false
}
