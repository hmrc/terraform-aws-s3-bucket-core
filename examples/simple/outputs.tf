output "bucket_name" {
  value = module.bucket.id
}

output "access_logs_bucket_name" {
  value = aws_s3_bucket.access_logs.id
}

