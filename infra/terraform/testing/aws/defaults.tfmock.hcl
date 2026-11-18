mock_resource "aws_iam_role" {
  defaults = { arn = "arn:aws:iam::123456789012:role/atdp-dev-airline-a-mock" }
}
mock_resource "aws_iam_policy" {
  defaults = { arn = "arn:aws:iam::123456789012:policy/atdp-dev-airline-a-mock" }
}
mock_resource "aws_kms_key" {
  defaults = { arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000", key_id = "00000000-0000-0000-0000-000000000000" }
}
mock_resource "aws_s3_bucket" {
  defaults = { arn = "arn:aws:s3:::atdp-mock-bucket", id = "atdp-mock-bucket" }
}
mock_resource "aws_cloudwatch_log_group" {
  defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:/platform/atdp-mock" }
}
mock_resource "aws_codebuild_project" {
  defaults = { arn = "arn:aws:codebuild:us-east-1:123456789012:project/atdp-mock" }
}
mock_resource "aws_lambda_function" {
  defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:function:atdp-mock", version = "1" }
}
mock_resource "aws_lambda_alias" {
  defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:function:atdp-mock:live" }
}
mock_resource "aws_sfn_state_machine" {
  defaults = { arn = "arn:aws:states:us-east-1:123456789012:stateMachine:atdp-mock" }
}
mock_resource "aws_secretsmanager_secret" {
  defaults = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:atdp-mock/sql-source-AbCdEf" }
}
mock_resource "aws_sqs_queue" {
  defaults = { arn = "arn:aws:sqs:us-east-1:123456789012:atdp-mock", name = "atdp-mock" }
}
mock_resource "aws_sns_topic" {
  defaults = { arn = "arn:aws:sns:us-east-1:123456789012:atdp-mock" }
}
mock_resource "aws_glue_catalog_database" {
  defaults = { arn = "arn:aws:glue:us-east-1:123456789012:database/atdp_mock" }
}
mock_resource "aws_glue_catalog_table" {
  defaults = { arn = "arn:aws:glue:us-east-1:123456789012:table/atdp_mock/pilot_snapshot" }
}
mock_resource "aws_athena_workgroup" {
  defaults = { arn = "arn:aws:athena:us-east-1:123456789012:workgroup/atdp-mock" }
}
