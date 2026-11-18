resource "aws_glue_catalog_database" "tenant" {
  name        = replace(var.name, "-", "_")
  description = "Synthetic pilot snapshots; tenant restricted; query explicit successful run_id"
}
resource "aws_glue_catalog_table" "pilots" {
  name          = "pilot_snapshot"
  database_name = aws_glue_catalog_database.tenant.name
  table_type    = "EXTERNAL_TABLE"
  parameters = {
    EXTERNAL                    = "TRUE"
    classification              = "json"
    "projection.enabled"        = "true"
    "projection.run_id.type"    = "injected"
    "storage.location.template" = "s3://${aws_s3_bucket.data.id}/${local.prefix}curated/pilots/run_id=$${run_id}/"
    owner                       = "lab-platform-engineer"
    classification_level        = "synthetic-tenant-restricted"
    contract_version            = "devops-pilot-snapshot-v1"
  }
  partition_keys {
    name = "run_id"
    type = "string"
  }
  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data.id}/${local.prefix}curated/pilots/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters            = { "ignore.malformed.json" = "false" }
    }
    columns {
      name = "tenant_id"
      type = "string"
    }
    columns {
      name = "pilot_id"
      type = "int"
    }
    columns {
      name = "pilot_name"
      type = "string"
    }
    columns {
      name = "employment_date"
      type = "string"
    }
  }
}
resource "aws_athena_workgroup" "tenant" {
  name = var.name
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 104857600
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data.id}/${local.prefix}query-results/"
      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.tenant.arn
      }
    }
  }
  tags = var.tags
}
resource "aws_iam_policy" "analytics" {
  name        = "${var.name}-analytics"
  description = "Attach only to an authorized tenant reader; no raw/secret access"
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["athena:StartQueryExecution", "athena:GetQueryExecution", "athena:GetQueryResults", "athena:StopQueryExecution", "athena:GetWorkGroup"], Resource = aws_athena_workgroup.tenant.arn },
    { Effect = "Allow", Action = ["glue:GetDatabase", "glue:GetTable", "glue:GetPartitions"], Resource = ["${local.arn}:glue:${local.region}:${local.account}:catalog", aws_glue_catalog_database.tenant.arn, aws_glue_catalog_table.pilots.arn] },
    { Effect = "Allow", Action = "s3:ListBucket", Resource = aws_s3_bucket.data.arn, Condition = { StringLike = { "s3:prefix" = ["${local.prefix}curated/*", "${local.prefix}manifests/*", "${local.prefix}query-results/*"] } } },
    { Effect = "Allow", Action = "s3:GetObject", Resource = ["${aws_s3_bucket.data.arn}/${local.prefix}curated/*", "${aws_s3_bucket.data.arn}/${local.prefix}manifests/*", "${aws_s3_bucket.data.arn}/${local.prefix}query-results/*"] },
    { Effect = "Allow", Action = ["s3:PutObject", "s3:AbortMultipartUpload"], Resource = "${aws_s3_bucket.data.arn}/${local.prefix}query-results/*" },
    { Effect = "Allow", Action = "s3:GetBucketLocation", Resource = aws_s3_bucket.data.arn },
    { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = aws_kms_key.tenant.arn, Condition = { StringEquals = { "kms:ViaService" = "s3.${local.region}.amazonaws.com" } } }
  ] })
  tags = var.tags
}
