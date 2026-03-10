# Populated from bootstrap outputs. After running terraform/bootstrap:
#   cd terraform/bootstrap && terraform output
#
# Then fill in the values below and run:
#   terraform init -backend-config=backend.hcl

bucket         = "chatty-terraform-state-ACCOUNT_ID"
key            = "chatty/dev/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
kms_key_id     = "alias/chatty/terraform-state"
dynamodb_table = "chatty-terraform-locks"
