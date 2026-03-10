bucket         = "chatty-terraform-state-ACCOUNT_ID"
key            = "chatty/prod/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
kms_key_id     = "alias/chatty/terraform-state"
dynamodb_table = "chatty-terraform-locks"
