mock_provider "aws" {
  source          = "../testing/aws"
  override_during = apply
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { name = "us-east-1" } }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0", map_public_ip_on_launch = false }
  }
}
variables {
  deployment = {
    project              = "atdp", environment = "dev", tenant_id = "airline-a", region = "us-east-1",
    vpc_id               = "vpc-0123456789abcdef0", subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"],
    route_table_ids      = ["rtb-0123456789abcdef0"], sql_cidr = "10.0.0.0/24", sql_port = 1433,
    source_schema        = "devops", source_table = "pilot_source", retention_days = 30, max_rows = 100,
    schedule_enabled     = false, schedule_expression = "rate(1 day)", release_id = "test-release",
    runtime_boundary_arn = "arn:aws:iam::123456789012:policy/test-boundary"
  }
}
run "safe_defaults" {
  command = apply
  assert {
    condition     = module.data_plane.deployment_contract.tenant_id == "airline-a"
    error_message = "Output must preserve trusted tenant provenance."
  }
}
