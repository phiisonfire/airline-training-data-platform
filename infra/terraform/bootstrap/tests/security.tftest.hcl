mock_provider "aws" {
  source          = "../testing/aws"
  override_during = apply
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_partition" { defaults = { partition = "aws" } }
}
variables {
  project         = "atdp"
  environment     = "dev"
  tenant_id       = "airline-a"
  region          = "us-east-1"
  repository_name = "example-repository"
  branch          = "main"
}
run "controller_security" {
  command = apply
  assert {
    condition     = alltrue([for bucket in aws_s3_bucket.control : bucket.force_destroy]) && aws_kms_key.control.deletion_window_in_days == 7
    error_message = "Lab resources must support destructive cleanup with minimal deletion delays."
  }
  assert {
    condition     = aws_codepipeline.platform.stage[0].action[0].provider == "CodeCommit" && aws_codepipeline.platform.stage[0].action[0].configuration["RepositoryName"] == var.repository_name && aws_codepipeline.platform.stage[0].action[0].configuration["PollForSourceChanges"] == "true"
    error_message = "Source must poll the selected CodeCommit repository."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.pipeline.policy).Statement[0].Resource == "arn:aws:codecommit:us-east-1:123456789012:example-repository" && toset(jsondecode(aws_iam_role_policy.pipeline.policy).Statement[0].Action) == toset(["codecommit:GetBranch", "codecommit:GetCommit", "codecommit:UploadArchive", "codecommit:GetUploadArchiveStatus", "codecommit:CancelUploadArchive"])
    error_message = "Pipeline source permissions must be limited to the selected repository."
  }
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
