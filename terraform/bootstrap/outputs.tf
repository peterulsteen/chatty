output "state_bucket_name" {
  description = "S3 bucket name for Terraform state. Paste into environment backend.hcl files."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_lock_table_name" {
  description = "DynamoDB table name for state locking."
  value       = aws_dynamodb_table.terraform_locks.name
}

output "state_kms_key_arn" {
  description = "KMS key ARN used to encrypt state files."
  value       = aws_kms_key.terraform_state.arn
}

output "state_kms_key_alias" {
  description = "KMS key alias — shorter form for kms_key_id in backend.hcl."
  value       = aws_kms_alias.terraform_state.name
}
