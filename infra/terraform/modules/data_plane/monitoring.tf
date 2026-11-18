resource "aws_sns_topic" "alerts" {
  name              = "${var.name}-alerts"
  kms_master_key_id = aws_kms_key.tenant.arn
  tags              = var.tags
}
resource "aws_cloudwatch_metric_alarm" "worker_errors" {
  alarm_name          = "${var.name}-worker-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.extract.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}
resource "aws_cloudwatch_metric_alarm" "workflow_errors" {
  alarm_name          = "${var.name}-workflow-failures"
  namespace           = "AWS/States"
  metric_name         = "ExecutionsFailed"
  dimensions          = { StateMachineArn = aws_sfn_state_machine.extract.arn }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}
resource "aws_cloudwatch_metric_alarm" "dlq" {
  alarm_name          = "${var.name}-scheduler-dlq"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.scheduler_dlq.name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}
resource "aws_cloudwatch_dashboard" "tenant" {
  dashboard_name = var.name
  dashboard_body = jsonencode({ widgets = [
    { type = "metric", x = 0, y = 0, width = 12, height = 6, properties = { title = "Worker errors and duration", region = local.region, metrics = [["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.extract.function_name], ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.extract.function_name, { stat = "p95", yAxis = "right" }]] } },
    { type = "metric", x = 12, y = 0, width = 12, height = 6, properties = { title = "Workflow failures / scheduler DLQ", region = local.region, metrics = [["AWS/States", "ExecutionsFailed", "StateMachineArn", aws_sfn_state_machine.extract.arn], ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.scheduler_dlq.name]] } }
  ] })
}
