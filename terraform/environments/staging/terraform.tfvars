project     = "chatty"
environment = "staging"
aws_region  = "us-east-1"

# Two NAT gateways — AZ-resilient egress.
single_nat_gateway = false

acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"

# RDS enabled in staging — mirrors prod topology at reduced scale.
create_rds              = true
rds_instance_class      = "db.t4g.small"
rds_multi_az            = false # Enable if staging carries pre-prod load tests.
rds_deletion_protection = false

container_image   = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/chatty-staging/chatty:latest"
ecs_cpu           = 512
ecs_memory        = 1024
ecs_desired_count = 1
ecs_min_capacity  = 1
ecs_max_capacity  = 4

cors_origins = ["https://staging.example.com"]
