project     = "chatty"
environment = "dev"
aws_region  = "us-east-1"

# Single NAT gateway — saves ~$30/mo in dev. Not HA.
single_nat_gateway = true

# Replace with a real ACM certificate ARN for your dev subdomain.
acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"

# RDS disabled in dev — use docker compose locally.
create_rds              = false
rds_instance_class      = "db.t4g.micro"
rds_multi_az            = false
rds_deletion_protection = false

# Smallest viable Fargate size; scales to 2 tasks maximum.
container_image   = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/chatty-dev/chatty:latest"
ecs_cpu           = 256
ecs_memory        = 512
ecs_desired_count = 1
ecs_min_capacity  = 1
ecs_max_capacity  = 2

cors_origins = ["https://dev.example.com", "http://localhost:3000"]
