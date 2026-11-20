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
    condition = alltrue([for role in ["plan", "apply", "verify"] : anytrue([
      for statement in jsondecode(aws_iam_role_policy.refresh[role].policy).Statement :
      try(contains(statement.Action, "states:ListStateMachineVersions"), false) &&
      statement.Resource == "arn:aws:states:us-east-1:123456789012:stateMachine:atdp-dev-airline-a-*"
    ])])
    error_message = "Refresh roles must list versions on deployment state machines."
  }
  assert {
    condition = alltrue([for role in ["plan", "apply"] : anytrue([
      for statement in concat(jsondecode(aws_iam_role_policy.refresh[role].policy).Statement, flatten([for policy in aws_iam_policy.apply : jsondecode(policy.policy).Statement if role == "apply"])) :
      try(statement.Action == "states:ValidateStateMachineDefinition" && statement.Resource == "*" && statement.Condition.StringEquals["aws:RequestedRegion"] == var.region, false)
    ])])
    error_message = "Both Plan and Apply roles require regional ASL validation."
  }
  assert {
    condition = anytrue([for statement in local.apply_statements :
      try(statement.Sid == "DeleteDeploymentDatabaseFunctions" && statement.Action == "glue:DeleteDatabase" && statement.Resource == "arn:aws:glue:us-east-1:123456789012:userDefinedFunction/atdp_dev_airline_a/*", false)
      ]) && anytrue([for statement in local.apply_statements :
      try(statement.Sid == "ValidateWorkflowDefinition" && statement.Action == "states:ValidateStateMachineDefinition" && statement.Resource == "*" && statement.Condition.StringEquals["aws:RequestedRegion"] == var.region, false)
    ])
    error_message = "Apply requires scoped Glue descendant deletion and regional ASL validation."
  }
  assert {
    condition = alltrue([for role in ["plan", "apply", "verify"] : anytrue([
      for statement in jsondecode(aws_iam_role_policy.refresh[role].policy).Statement :
      try(contains(statement.Action, "glue:GetTags"), false) &&
      try(contains(statement.Resource, "arn:aws:glue:us-east-1:123456789012:database/atdp_dev_airline_a"), false) &&
      try(!contains(statement.Resource, "*"), false)
    ])])
    error_message = "Refresh roles must read tags on deployment Glue resources."
  }
  assert {
    condition = alltrue([for role in ["plan", "apply", "verify"] : anytrue([
      for statement in jsondecode(aws_iam_role_policy.refresh[role].policy).Statement :
      try(contains(statement.Action, "s3:GetAccelerateConfiguration"), false) &&
      try(contains(statement.Action, "s3:GetReplicationConfiguration"), false) &&
      statement.Resource == "arn:aws:s3:::atdp-dev-airline-a-123456789012-us-east-1"
    ])])
    error_message = "Refresh roles must read acceleration and replication metadata on the deployment bucket."
  }
  assert {
    condition = alltrue([for statement in local.apply_statements :
      try(contains(statement.Action, "glue:CreateDatabase"), false) ?
      contains(statement.Action, "glue:TagResource") && contains(statement.Action, "glue:UntagResource") : true
    ])
    error_message = "Glue database provisioning must support default tag creation and removal."
  }
  assert {
    condition = length([for statement in local.apply_statements : statement if try(statement.Sid, "") == "SourceSecretKeyValidation" &&
      try(toset(statement.Action) == toset(["kms:GenerateDataKey", "kms:Decrypt"]), false) &&
      try(statement.Resource == "arn:aws:kms:us-east-1:123456789012:key/*", false) &&
      try(statement.Condition.StringEquals["aws:ResourceTag/Deployment"] == "atdp-dev-airline-a", false) &&
      try(statement.Condition.StringEquals["kms:ViaService"] == "secretsmanager.us-east-1.amazonaws.com", false) &&
      try(statement.Condition.ArnLike["kms:EncryptionContext:SecretARN"] == "arn:aws:secretsmanager:us-east-1:123456789012:secret:atdp-dev-airline-a/sql-source-??????", false)
    ]) == 1
    error_message = "Secret key validation must be scoped to the deployment key, service and source secret."
  }
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
