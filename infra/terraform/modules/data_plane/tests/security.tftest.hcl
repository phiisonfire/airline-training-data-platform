mock_provider "aws" {
  source          = "../../testing/aws"
  override_during = apply
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { name = "us-east-1" } }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0", map_public_ip_on_launch = false }
  }
}
variables {
  name                 = "atdp-dev-airline-a"
  tenant_id            = "airline-a"
  lambda_zip           = "../../../../build/lambda.zip"
  release_id           = "test-release"
  vpc_id               = "vpc-0123456789abcdef0"
  subnet_ids           = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  route_table_ids      = ["rtb-0123456789abcdef0"]
  sql_cidr             = "10.0.0.0/24"
  retention_days       = 30
  runtime_boundary_arn = "arn:aws:iam::123456789012:policy/test-boundary"
  tags                 = { Deployment = "atdp-dev-airline-a" }
}
run "tenant_security" {
  command = apply
  assert {
    condition     = aws_s3_bucket_public_access_block.data.block_public_policy && aws_s3_bucket_public_access_block.data.restrict_public_buckets && aws_s3_bucket_public_access_block.data.block_public_acls && aws_s3_bucket_public_access_block.data.ignore_public_acls
    error_message = "Data bucket must block all public access."
  }
  assert {
    condition     = aws_scheduler_schedule.extract.state == "DISABLED" && !aws_sfn_state_machine.extract.logging_configuration[0].include_execution_data
    error_message = "No automatic SQL reads before explicit enablement; execution payloads must not enter logs."
  }
  assert {
    condition     = aws_iam_role.worker.permissions_boundary == var.runtime_boundary_arn && aws_iam_role.workflow.permissions_boundary == var.runtime_boundary_arn && aws_iam_role.scheduler.permissions_boundary == var.runtime_boundary_arn
    error_message = "All runtime identities require the controller-owned boundary."
  }
  assert {
    condition     = aws_glue_catalog_table.pilots.parameters["projection.run_id.type"] == "injected"
    error_message = "Athena must require explicit snapshot selection to avoid double counting."
  }
}
