terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.68.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

locals {
  bucket_name = "${var.test_name}-bucket"
}

module "bucket" {
  #source      = "hashicorp/hmrc/s3-bucket-core"
  source      = "../../"
  bucket_name = local.bucket_name

  log_bucket_id    = aws_s3_bucket.access_logs.id
  data_sensitivity = "low"
  force_destroy    = true
  data_expiry      = var.data_expiry
  kms_key_policy   = ""
  depends_on       = [aws_s3_bucket_public_access_block.access_logs, aws_s3_bucket_policy.access_logs]
}

data "aws_iam_policy_document" "bucket_kms_key" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "kms:*",
    ]

    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = [data.aws_iam_session_context.current.issuer_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket" {
  bucket = module.bucket.id
  policy = data.aws_iam_policy_document.bucket.json
}

data "aws_iam_policy_document" "bucket" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_session_context.current.issuer_arn]
    }
    actions = [
      "s3:*"
    ]
    resources = [
      module.bucket.arn,
      "${module.bucket.arn}/*",
    ]
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:*",
    ]
    resources = [
      module.bucket.arn,
      "${module.bucket.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

