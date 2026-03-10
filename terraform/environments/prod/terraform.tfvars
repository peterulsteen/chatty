project     = "chatty"
environment = "prod"
aws_region  = "us-east-1"

# One NAT per AZ — required for HA egress.
single_nat_gateway = false

acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"

# RDS — Multi-AZ, larger instance, deletion protection enabled.
create_rds              = true
rds_instance_class      = "db.t4g.medium"
rds_multi_az            = true
rds_deletion_protection = true

# Minimum 2 tasks for AZ redundancy; scales to 10 under load.
container_image   = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/chatty-prod/chatty:latest"
ecs_cpu           = 1024
ecs_memory        = 2048
ecs_desired_count = 2
ecs_min_capacity  = 2
ecs_max_capacity  = 10

cors_origins = ["https://example.com", "https://www.example.com"]
