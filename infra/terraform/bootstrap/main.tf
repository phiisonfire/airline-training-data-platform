terraform {
  required_version = ">= 1.14.6, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 5.100.0" }
  }
}
provider "aws" {
  region = var.region
  default_tags { tags = local.tags }
}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
locals {
  account     = data.aws_caller_identity.current.account_id
  arn         = "arn:${data.aws_partition.current.partition}"
  name        = "${var.project}-${var.environment}-${var.tenant_id}"
  state_key   = "platform/${local.name}/terraform.tfstate"
  data_bucket = "${local.name}-${local.account}-${var.region}"
  tags = { Project = var.project, Environment = var.environment, Tenant = var.tenant_id,
  Deployment = local.name, ManagedBy = "terraform", Owner = "lab-platform-engineer" }
}
resource "aws_kms_key" "control" {
  description             = "Terraform state and encrypted CI artifacts; no source credentials"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Principal = { AWS = "${local.arn}:iam::${local.account}:root" }, Action = "kms:*", Resource = "*" },
    { Effect = "Allow", Principal = { Service = "logs.${var.region}.amazonaws.com" }, Action = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"], Resource = "*", Condition = { ArnLike = { "kms:EncryptionContext:aws:logs:arn" = "${local.arn}:logs:${var.region}:${local.account}:log-group:/codebuild/${local.name}-*" } } },
    { Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "kms:GenerateDataKey*", Resource = "*", Condition = { StringEquals = { "aws:SourceArn" = "${local.arn}:cloudtrail:${var.region}:${local.account}:trail/${local.name}" } } }
  ] })
  tags = local.tags
}
resource "aws_s3_bucket" "control" {
  for_each      = toset(["state", "artifacts"])
  bucket        = "${local.name}-${each.key}-${local.account}-${var.region}"
  force_destroy = false
  tags          = local.tags
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_public_access_block" "control" {
  for_each                = aws_s3_bucket.control
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "control" {
  for_each = aws_s3_bucket.control
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "control" {
  for_each = aws_s3_bucket.control
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.control.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_policy" "control" {
  for_each = aws_s3_bucket.control
  bucket   = each.value.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [each.value.arn, "${each.value.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }
  ] })
}
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.control["artifacts"].id
  rule {
    id     = "expire-ci-artifacts"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = 7 }
    noncurrent_version_expiration { noncurrent_days = 7 }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}
resource "aws_cloudwatch_log_group" "build" {
  for_each          = toset(["build", "plan", "apply", "verify"])
  name              = "/codebuild/${local.name}-${each.key}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.control.arn
  tags              = local.tags
}
resource "aws_iam_policy" "runtime_boundary" {
  name = "${local.name}-runtime-boundary"
  # Maximum permissions; role identity policies further restrict every resource.
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"], Resource = ["${local.arn}:s3:::${local.data_bucket}", "${local.arn}:s3:::${local.data_bucket}/tenant=${var.tenant_id}/*"] },
    { Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = "${local.arn}:secretsmanager:${var.region}:${local.account}:secret:${local.name}/*" },
    { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = "${local.arn}:kms:${var.region}:${local.account}:key/*", Condition = { "ForAnyValue:StringEquals" = { "kms:ResourceAliases" = "alias/${local.name}" } } },
    { Effect = "Allow", Action = "lambda:InvokeFunction", Resource = "${local.arn}:lambda:${var.region}:${local.account}:function:${local.name}-*:live" },
    { Effect = "Allow", Action = "states:StartExecution", Resource = "${local.arn}:states:${var.region}:${local.account}:stateMachine:${local.name}-*" },
    { Effect = "Allow", Action = "sqs:SendMessage", Resource = "${local.arn}:sqs:${var.region}:${local.account}:${local.name}-*" },
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${local.arn}:logs:${var.region}:${local.account}:log-group:/platform/${local.name}/*:*" },
    { Effect = "Allow", Action = ["logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery", "logs:DeleteLogDelivery", "logs:ListLogDeliveries", "logs:PutResourcePolicy", "logs:DescribeResourcePolicies", "logs:DescribeLogGroups", "ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSubnets", "ec2:DeleteNetworkInterface", "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses"], Resource = "*" }
  ] })
  tags = local.tags
}
resource "aws_iam_role" "build" {
  for_each           = toset(["build", "plan", "apply", "verify"])
  name               = "${local.name}-ci-${each.key}"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" }, Action = "sts:AssumeRole", Condition = { StringEquals = { "aws:SourceAccount" = local.account }, ArnEquals = { "aws:SourceArn" = "${local.arn}:codebuild:${var.region}:${local.account}:project/${local.name}-${each.key}" } } }] })
  tags               = local.tags
}
resource "aws_iam_role_policy" "build_base" {
  for_each = aws_iam_role.build
  role     = each.value.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"], Resource = "${aws_s3_bucket.control["artifacts"].arn}/*" },
    { Effect = "Allow", Action = ["s3:GetBucketLocation", "s3:GetBucketVersioning"], Resource = aws_s3_bucket.control["artifacts"].arn },
    { Effect = "Allow", Action = ["kms:Decrypt", "kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"], Resource = aws_kms_key.control.arn },
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.build[each.key].arn}:*" },
    { Effect = "Deny", Action = ["secretsmanager:GetSecretValue", "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"], Resource = "*" }
  ] })
}
resource "aws_iam_role_policy" "state" {
  for_each = toset(["plan", "apply"])
  role     = aws_iam_role.build[each.key].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = "s3:ListBucket", Resource = aws_s3_bucket.control["state"].arn, Condition = { StringLike = { "s3:prefix" = [local.state_key, "${local.state_key}.tflock", "env:/"] } } },
    { Effect = "Allow", Action = "s3:GetObject", Resource = "${aws_s3_bucket.control["state"].arn}/${local.state_key}" },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.control["state"].arn}/${local.state_key}.tflock" }
  ] })
}
resource "aws_iam_role_policy" "state_write" {
  role   = aws_iam_role.build["apply"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "s3:PutObject", Resource = "${aws_s3_bucket.control["state"].arn}/${local.state_key}" }] })
}
resource "aws_iam_role_policy" "refresh" {
  for_each = toset(["plan", "apply", "verify"])
  role     = aws_iam_role.build[each.key].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ec2:Describe*", "kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListResourceTags", "kms:ListAliases", "logs:Describe*", "logs:ListTagsForResource", "cloudwatch:DescribeAlarms", "cloudwatch:GetDashboard", "cloudwatch:ListTagsForResource", "scheduler:GetSchedule", "scheduler:ListTagsForResource", "sts:GetCallerIdentity"], Resource = "*" },
    { Effect = "Allow", Action = ["s3:GetBucket*", "s3:GetEncryptionConfiguration", "s3:GetLifecycleConfiguration", "s3:ListBucket"], Resource = "${local.arn}:s3:::${local.data_bucket}" },
    { Effect = "Allow", Action = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions", "iam:ListRoleTags", "iam:ListPolicyTags"], Resource = ["${local.arn}:iam::${local.account}:role/${local.name}-*", "${local.arn}:iam::${local.account}:policy/${local.name}-*"] },
    { Effect = "Allow", Action = ["lambda:Get*", "lambda:ListVersionsByFunction", "lambda:ListAliases", "lambda:ListTags"], Resource = "${local.arn}:lambda:${var.region}:${local.account}:function:${local.name}-*" },
    { Effect = "Allow", Action = ["states:DescribeStateMachine", "states:ListTagsForResource"], Resource = "${local.arn}:states:${var.region}:${local.account}:stateMachine:${local.name}-*" },
    { Effect = "Allow", Action = ["secretsmanager:DescribeSecret", "secretsmanager:GetResourcePolicy"], Resource = "${local.arn}:secretsmanager:${var.region}:${local.account}:secret:${local.name}/*" },
    { Effect = "Allow", Action = ["sqs:GetQueueAttributes", "sqs:ListQueueTags"], Resource = "${local.arn}:sqs:${var.region}:${local.account}:${local.name}-*" },
    { Effect = "Allow", Action = ["sns:GetTopicAttributes", "sns:ListTagsForResource"], Resource = "${local.arn}:sns:${var.region}:${local.account}:${local.name}-*" },
    { Effect = "Allow", Action = ["glue:GetDatabase", "glue:GetTable"], Resource = ["${local.arn}:glue:${var.region}:${local.account}:catalog", "${local.arn}:glue:${var.region}:${local.account}:database/${replace(local.name, "-", "_")}", "${local.arn}:glue:${var.region}:${local.account}:table/${replace(local.name, "-", "_")}/*"] },
    { Effect = "Allow", Action = ["athena:GetWorkGroup", "athena:ListTagsForResource"], Resource = "${local.arn}:athena:${var.region}:${local.account}:workgroup/${local.name}" }
  ] })
}
