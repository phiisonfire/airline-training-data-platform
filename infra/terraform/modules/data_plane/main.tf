data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_subnet" "selected" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}
locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name
  prefix  = "tenant=${var.tenant_id}/"
  arn     = "arn:${data.aws_partition.current.partition}"
  log_arn = "${local.arn}:logs:${local.region}:${local.account}:log-group:/platform/${var.name}/*"
}
resource "aws_kms_key" "tenant" {
  description             = "Tenant-bound data platform encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "AccountDelegation", Effect = "Allow", Principal = { AWS = "${local.arn}:iam::${local.account}:root" }, Action = "kms:*", Resource = "*" },
    { Sid = "TenantLogs", Effect = "Allow", Principal = { Service = "logs.${local.region}.amazonaws.com" }, Action = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"], Resource = "*", Condition = { ArnLike = { "kms:EncryptionContext:aws:logs:arn" = local.log_arn } } },
    { Sid = "AlarmNotifications", Effect = "Allow", Principal = { Service = "cloudwatch.amazonaws.com" }, Action = ["kms:Decrypt", "kms:GenerateDataKey*"], Resource = "*", Condition = { StringEquals = { "aws:SourceAccount" = local.account } } }
  ] })
  tags = var.tags
}
resource "aws_kms_alias" "tenant" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.tenant.key_id
}
resource "aws_s3_bucket" "data" {
  bucket        = "${var.name}-${local.account}-${local.region}"
  force_destroy = true
  tags          = var.tags
}
resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tenant.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "TLSOnly", Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }
  ] })
}
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    id     = "tenant-retention"
    status = "Enabled"
    filter { prefix = local.prefix }
    expiration { days = var.retention_days }
    noncurrent_version_expiration { noncurrent_days = var.retention_days }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}
resource "aws_secretsmanager_secret" "source" {
  name                    = "${var.name}/sql-source"
  kms_key_id              = aws_kms_key.tenant.arn
  recovery_window_in_days = 0
  tags                    = var.tags
  # Secret value deliberately NOT managed in Terraform/state.
}
resource "aws_security_group" "worker" {
  name_prefix = "${var.name}-worker-"
  description = "No ingress; SQL and private AWS endpoints only"
  vpc_id      = var.vpc_id
  tags        = var.tags
  lifecycle {
    precondition {
      condition     = alltrue([for s in data.aws_subnet.selected : s.vpc_id == var.vpc_id && !s.map_public_ip_on_launch])
      error_message = "All worker subnets must belong to the selected VPC and disable public IP assignment; verify private routing separately."
    }
  }
}
resource "aws_security_group" "endpoints" {
  name_prefix = "${var.name}-endpoints-"
  description = "Secrets Manager endpoint accepts worker only"
  vpc_id      = var.vpc_id
  tags        = var.tags
}
resource "aws_vpc_security_group_egress_rule" "sql" {
  security_group_id = aws_security_group.worker.id
  cidr_ipv4         = var.sql_cidr
  ip_protocol       = "tcp"
  from_port         = var.sql_port
  to_port           = var.sql_port
}
resource "aws_vpc_security_group_egress_rule" "secrets" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_security_group_ingress_rule" "secrets" {
  security_group_id            = aws_security_group.endpoints.id
  referenced_security_group_id = aws_security_group.worker.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = var.vpc_id
  service_name    = "com.amazonaws.${local.region}.s3"
  route_table_ids = var.route_table_ids
  policy          = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = "*", Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"], Resource = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"] }] })
  tags            = var.tags
}
resource "aws_vpc_security_group_egress_rule" "s3" {
  security_group_id = aws_security_group.worker.id
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
resource "aws_vpc_endpoint" "secrets" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${local.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  policy              = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = "*", Action = "secretsmanager:GetSecretValue", Resource = aws_secretsmanager_secret.source.arn }] })
  tags                = var.tags
}
resource "aws_cloudwatch_log_group" "worker" {
  name              = "/platform/${var.name}/worker"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.tenant.arn
  tags              = var.tags
}
resource "aws_cloudwatch_log_group" "workflow" {
  name              = "/platform/${var.name}/workflow"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.tenant.arn
  tags              = var.tags
}
resource "aws_iam_role" "worker" {
  permissions_boundary = var.runtime_boundary_arn
  name                 = "${var.name}-worker"
  assume_role_policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  tags                 = var.tags
}
resource "aws_iam_role_policy" "worker" {
  role = aws_iam_role.worker.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = "${aws_s3_bucket.data.arn}/${local.prefix}*" },
    { Effect = "Allow", Action = "s3:ListBucket", Resource = aws_s3_bucket.data.arn, Condition = { StringLike = { "s3:prefix" = "${local.prefix}*" } } },
    { Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = aws_secretsmanager_secret.source.arn },
    { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = aws_kms_key.tenant.arn, Condition = { StringEquals = { "kms:ViaService" = ["s3.${local.region}.amazonaws.com", "secretsmanager.${local.region}.amazonaws.com"] } } },
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.worker.arn}:*" },
    # EC2 ENI APIs cannot all be resource-scoped; AWS Lambda VPC attachment requirement.
    { Effect = "Allow", Action = ["ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSubnets", "ec2:DeleteNetworkInterface", "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses"], Resource = "*" }
  ] })
}
resource "aws_lambda_function" "extract" {
  function_name                  = "${var.name}-extract"
  role                           = aws_iam_role.worker.arn
  filename                       = var.lambda_zip
  source_code_hash               = filebase64sha256(var.lambda_zip)
  handler                        = "pipelines.sql_to_s3.handler.handler"
  runtime                        = "python3.12"
  architectures                  = ["x86_64"]
  timeout                        = 180
  memory_size                    = 512
  reserved_concurrent_executions = 1
  publish                        = true
  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.worker.name
  }
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.worker.id]
  }
  environment {
    variables = {
      TENANT_ID         = var.tenant_id
      SOURCE_SCHEMA     = var.source_schema
      SOURCE_TABLE      = var.source_table
      RELEASE_ID        = var.release_id
      MAX_ROWS          = tostring(var.max_rows)
      DATA_BUCKET       = aws_s3_bucket.data.id
      KMS_KEY_ARN       = aws_kms_key.tenant.arn
      SOURCE_SECRET_ARN = aws_secretsmanager_secret.source.arn
    }
  }
  tags       = var.tags
  depends_on = [aws_iam_role_policy.worker, aws_vpc_endpoint.secrets, aws_vpc_security_group_egress_rule.s3]
}
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.extract.function_name
  function_version = aws_lambda_function.extract.version
}
resource "aws_iam_role" "workflow" {
  permissions_boundary = var.runtime_boundary_arn
  name                 = "${var.name}-workflow"
  assume_role_policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "states.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  tags                 = var.tags
}
resource "aws_iam_role_policy" "workflow" {
  role = aws_iam_role.workflow.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = "lambda:InvokeFunction", Resource = aws_lambda_alias.live.arn },
    # CloudWatch Logs delivery APIs require wildcard resources.
    { Effect = "Allow", Action = ["logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery", "logs:DeleteLogDelivery", "logs:ListLogDeliveries", "logs:PutResourcePolicy", "logs:DescribeResourcePolicies", "logs:DescribeLogGroups"], Resource = "*" }
  ] })
}
resource "aws_sfn_state_machine" "extract" {
  name     = "${var.name}-extract"
  role_arn = aws_iam_role.workflow.arn
  type     = "STANDARD"
  definition = templatefile("${path.module}/../../../../orchestration/sql-to-s3.asl.json", {
    partition        = data.aws_partition.current.partition
    worker_alias_arn = aws_lambda_alias.live.arn
  })
  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.workflow.arn}:*"
    include_execution_data = false
    level                  = "ERROR"
  }
  tags       = var.tags
  depends_on = [aws_iam_role_policy.workflow]
}
resource "aws_sqs_queue" "scheduler_dlq" {
  name                      = "${var.name}-scheduler-dlq"
  sqs_managed_sse_enabled   = true
  message_retention_seconds = 1209600
  tags                      = var.tags
}
resource "aws_iam_role" "scheduler" {
  permissions_boundary = var.runtime_boundary_arn
  name                 = "${var.name}-scheduler"
  assume_role_policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "scheduler.amazonaws.com" }, Action = "sts:AssumeRole", Condition = { StringEquals = { "aws:SourceAccount" = local.account } } }] })
  tags                 = var.tags
}
resource "aws_iam_role_policy" "scheduler" {
  role = aws_iam_role.scheduler.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = "states:StartExecution", Resource = aws_sfn_state_machine.extract.arn },
    { Effect = "Allow", Action = "sqs:SendMessage", Resource = aws_sqs_queue.scheduler_dlq.arn }
  ] })
}
resource "aws_scheduler_schedule" "extract" {
  name                = "${var.name}-extract"
  schedule_expression = var.schedule_expression
  state               = var.schedule_enabled ? "ENABLED" : "DISABLED"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_sfn_state_machine.extract.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = "{}"
    dead_letter_config { arn = aws_sqs_queue.scheduler_dlq.arn }
    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 2
    }
  }
  depends_on = [aws_iam_role_policy.scheduler]
}
