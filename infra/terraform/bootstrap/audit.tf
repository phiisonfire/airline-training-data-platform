# Optional: existing organization/account trail is preferred over duplicate trails.
resource "aws_s3_bucket" "audit" {
  count         = var.enable_cloudtrail ? 1 : 0
  bucket        = "${local.name}-audit-${local.account}-${var.region}"
  force_destroy = true
  tags          = local.tags
}
resource "aws_s3_bucket_public_access_block" "audit" {
  count                   = var.enable_cloudtrail ? 1 : 0
  bucket                  = aws_s3_bucket.audit[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "audit" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.audit[0].id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.audit[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.control.arn
    }
  }
}
resource "aws_s3_bucket_policy" "audit" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.audit[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.audit[0].arn, "${aws_s3_bucket.audit[0].arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } },
    { Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:GetBucketAcl", Resource = aws_s3_bucket.audit[0].arn, Condition = { StringEquals = { "aws:SourceArn" = "${local.arn}:cloudtrail:${var.region}:${local.account}:trail/${local.name}" } } },
    { Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:PutObject", Resource = "${aws_s3_bucket.audit[0].arn}/AWSLogs/${local.account}/*", Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control", "aws:SourceArn" = "${local.arn}:cloudtrail:${var.region}:${local.account}:trail/${local.name}" } } }
  ] })
}
resource "aws_cloudtrail" "management" {
  lifecycle {
    precondition {
      condition     = var.audit_account_is_dedicated
      error_message = "Account-wide audit collection requires confirmed dedicated lab account; otherwise use approved existing audit coverage."
    }
  }
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = local.name
  s3_bucket_name                = aws_s3_bucket.audit[0].id
  kms_key_id                    = aws_kms_key.control.arn
  enable_log_file_validation    = true
  is_multi_region_trail         = true
  include_global_service_events = true
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
  tags       = local.tags
  depends_on = [aws_s3_bucket_policy.audit]
}
