mock_provider "aws" {
  source          = "../testing/aws"
  override_during = apply
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_partition" { defaults = { partition = "aws" } }
}
variables {
  project        = "atdp"
  environment    = "dev"
  tenant_id      = "airline-a"
  region         = "us-east-1"
  connection_arn = "arn:aws:codeconnections:us-east-1:123456789012:connection/00000000-0000-0000-0000-000000000000"
  repository_id  = "example/repository"
  branch         = "main"
}
run "controller_security" {
  command = apply
  assert {
    condition     = alltrue([for p in aws_iam_policy.apply : length(p.policy) <= 6144])
    error_message = "A managed deploy policy exceeds AWS IAM policy size quota."
  }
  assert {
    condition     = alltrue([for key in ["build", "plan", "apply"] : length(aws_iam_role_policy.build_base[key].policy) + try(length(aws_iam_role_policy.refresh[key].policy), 0) + try(length(aws_iam_role_policy.state[key].policy), 0) + (key == "apply" ? length(aws_iam_role_policy.state_write.policy) : 0) <= 10240])
    error_message = "CodeBuild role inline policies exceed IAM aggregate size quota."
  }
  assert {
    condition     = aws_codepipeline.platform.execution_mode == "QUEUED"
    error_message = "Do not allow concurrent plan/apply executions to race for the same state."
  }
  assert {
    condition     = length(aws_cloudtrail.management) == 0
    error_message = "Do not create duplicate account audit trails by default."
  }
}
