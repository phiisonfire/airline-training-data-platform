output "deployment_contract" {
  description = "Versioned output interface that a future CDK implementation must preserve"
  value = {
    contract_version     = "1"
    tenant_id            = var.tenant_id
    data_bucket          = aws_s3_bucket.data.id
    source_secret_arn    = aws_secretsmanager_secret.source.arn
    workflow_arn         = aws_sfn_state_machine.extract.arn
    worker_alias_arn     = aws_lambda_alias.live.arn
    kms_key_arn          = aws_kms_key.tenant.arn
    catalog_database     = aws_glue_catalog_database.tenant.name
    athena_workgroup     = aws_athena_workgroup.tenant.name
    analytics_policy_arn = aws_iam_policy.analytics.arn
    alert_topic_arn      = aws_sns_topic.alerts.arn
    log_groups           = [aws_cloudwatch_log_group.worker.name, aws_cloudwatch_log_group.workflow.name]
    release_id           = var.release_id
  }
}
