terraform {
  required_version = ">= 0.13.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.4"
    }
  }
}

locals {

  noncurrent_version_expiration_in_days = 90

  retention_periods = {
    "1-day" : 1
    "1-week" : 7
    "1-month" : 31
    "90-days" : 90
    "6-months" : 183
    "18-months" : 549
    "1-year" : 366
    "7-years" : 2557
    "10-years" : 3653
  }

}

resource "aws_s3_bucket" "bucket" {
  bucket              = var.bucket_name
  acl                 = "private"
  object_lock_enabled = var.object_lock

  versioning {
    enabled = var.versioning_enabled
  }

  force_destroy = var.force_destroy

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.use_default_encryption ? null : aws_kms_key.bucket_kms_key[0].arn
        sse_algorithm     = var.use_default_encryption ? "AES256" : "aws:kms"
      }
    }
  }

  tags = merge({
    Name             = var.bucket_name
    data_sensitivity = var.data_sensitivity
    data_expiry      = var.data_expiry
  }, var.tags)

  lifecycle_rule {
    id                                     = "AbortIncompleteMultipartUpload"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 7
  }

  lifecycle_rule {
    id      = "Expiration days"
    enabled = true

    dynamic "transition" {
      for_each = var.transition_to_glacier_days == 0 ? [] : [1]
      content {
        days          = var.transition_to_glacier_days
        storage_class = "GLACIER"
      }
    }

    dynamic "expiration" {
      for_each = var.data_expiry == "forever-config-only" ? [] : [1]
      content {
        days = lookup(local.retention_periods, var.data_expiry)
      }
    }

    noncurrent_version_expiration {
      days = local.noncurrent_version_expiration_in_days
    }
  }

  logging {
    target_bucket = var.log_bucket_id
    target_prefix = "${data.aws_caller_identity.current.account_id}/${var.bucket_name}/"
  }
}

resource "aws_s3_bucket_ownership_controls" "bucket_owner_enforced" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "public_blocked" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "bucket_kms_key" {
  count               = var.use_default_encryption ? 0 : 1
  description         = "KMS key used to encrypt files for ${var.bucket_name}"
  enable_key_rotation = true
  policy              = var.kms_key_policy
}

resource "aws_kms_alias" "bucket_kms_alias" {
  count         = var.use_default_encryption ? 0 : 1
  name          = "alias/s3-${var.bucket_name}"
  target_key_id = aws_kms_key.bucket_kms_key[0].key_id
}

resource "aws_s3_bucket_object_lock_configuration" "object_lock" {
  count  = var.object_lock && var.versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  rule {
    default_retention {
      mode = var.object_lock_mode
      days = var.data_expiry == "forever-config-only" ? "1000" : lookup(local.retention_periods, var.data_expiry)
    }
  }
}

data "aws_caller_identity" "current" {}
