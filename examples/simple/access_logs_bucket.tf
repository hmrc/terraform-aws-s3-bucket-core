locals {
  log_bucket_name = "${var.test_name}-access-logs"
}

resource "aws_s3_bucket" "access_logs" {
  bucket = local.log_bucket_name

  force_destroy = true

  tags = {
    Name             = local.log_bucket_name
    data_sensitivity = "high"
    data_expiry      = "7-days"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "AbortIncompleteMultipartUpload"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "Expiration days"
    status = "Enabled"

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = ""
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket     = aws_s3_bucket.access_logs.id
  policy     = data.aws_iam_policy_document.access_logs.json
  depends_on = [aws_s3_bucket.access_logs]
}

data "aws_iam_policy_document" "access_logs" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    actions = [
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.access_logs.arn}/*"]
  }

  statement {
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl",
    ]
    resources = [aws_s3_bucket.access_logs.arn]
  }

  statement {
    principals {
      identifiers = [data.aws_iam_session_context.current.issuer_arn]
      type        = "AWS"
    }
    actions = [
      "s3:*",
    ]
    resources = [
      aws_s3_bucket.access_logs.arn,
      "${aws_s3_bucket.access_logs.arn}/*",
    ]
  }
}