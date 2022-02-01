output "id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.s3_bucket.id
}

output "arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.s3_bucket.arn
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
}

output "kms_alias_arn" {
  description = "The ARN of the created KMS key alias"
  value       = aws_kms_alias.bucket_kms_alias.arn
}

output "kms_key_arn" {
  description = "The ARN of the created KMS key"
  value       = aws_kms_key.bucket_kms_key.arn
}

output "kms_key_id" {
  description = "The ID of the created KMS key"
  value       = aws_kms_key.bucket_kms_key.id
}
