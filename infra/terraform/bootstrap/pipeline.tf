resource "aws_codebuild_project" "stage" {
  for_each       = toset(["build", "plan", "apply", "verify"])
  name           = "${local.name}-${each.key}"
  service_role   = aws_iam_role.build[each.key].arn
  build_timeout  = 30
  queued_timeout = 60
  encryption_key = aws_kms_key.control.arn
  artifacts { type = "CODEPIPELINE" }
  source {
    type      = "CODEPIPELINE"
    buildspec = "ci/codebuild/${each.key}.yml"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    environment_variable {
      name  = "TF_STATE_BUCKET"
      value = aws_s3_bucket.control["state"].id
    }
    environment_variable {
      name  = "TF_STATE_KEY"
      value = local.state_key
    }
    environment_variable {
      name  = "TF_STATE_KMS_ARN"
      value = aws_kms_key.control.arn
    }
    environment_variable {
      name  = "RUNTIME_BOUNDARY_ARN"
      value = aws_iam_policy.runtime_boundary.arn
    }
    environment_variable {
      name  = "TF_IN_AUTOMATION"
      value = "true"
    }
  }
  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.build[each.key].name
      stream_name = "build"
    }
  }
  tags       = local.tags
  depends_on = [aws_iam_role_policy.build_base]
}
resource "aws_iam_role" "pipeline" {
  name               = "${local.name}-codepipeline"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "codepipeline.amazonaws.com" }, Action = "sts:AssumeRole", Condition = { StringEquals = { "aws:SourceAccount" = local.account } } }] })
  tags               = local.tags
}
resource "aws_iam_role_policy" "pipeline" {
  role = aws_iam_role.pipeline.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["codecommit:GetBranch", "codecommit:GetCommit", "codecommit:UploadArchive", "codecommit:GetUploadArchiveStatus", "codecommit:CancelUploadArchive"], Resource = "${local.arn}:codecommit:${var.region}:${local.account}:${var.repository_name}" },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"], Resource = "${aws_s3_bucket.control["artifacts"].arn}/*" },
    { Effect = "Allow", Action = ["s3:GetBucketVersioning", "s3:GetBucketLocation"], Resource = aws_s3_bucket.control["artifacts"].arn },
    { Effect = "Allow", Action = ["kms:Decrypt", "kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"], Resource = aws_kms_key.control.arn },
    { Effect = "Allow", Action = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"], Resource = [for p in aws_codebuild_project.stage : p.arn] }
  ] })
}
resource "aws_codepipeline" "platform" {
  name           = local.name
  role_arn       = aws_iam_role.pipeline.arn
  pipeline_type  = "V2"
  execution_mode = "QUEUED"
  artifact_store {
    location = aws_s3_bucket.control["artifacts"].id
    type     = "S3"
    encryption_key {
      id   = aws_kms_key.control.arn
      type = "KMS"
    }
  }
  stage {
    name = "Source"
    action {
      name             = "Repository"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["SourceOutput"]
      configuration = {
        RepositoryName       = var.repository_name
        BranchName           = var.branch
        PollForSourceChanges = "true"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }
  stage {
    name = "Build"
    action {
      name             = "CheckAndPackage"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]
      configuration    = { ProjectName = aws_codebuild_project.stage["build"].name }
    }
  }
  stage {
    name = "Plan"
    action {
      name             = "TerraformPlan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["BuildOutput"]
      output_artifacts = ["PlanOutput"]
      configuration    = { ProjectName = aws_codebuild_project.stage["plan"].name }
    }
  }
  stage {
    name = "Approve"
    action {
      name          = "ReviewSavedPlan"
      category      = "Approval"
      owner         = "AWS"
      provider      = "Manual"
      version       = "1"
      configuration = { CustomData = "Review source revision, tfplan.txt and metadata.json in encrypted PlanOutput; approve only the exact plan. Plans expire after 24h." }
    }
  }
  stage {
    name = "Apply"
    action {
      name             = "ApplySavedPlan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["BuildOutput", "PlanOutput"]
      output_artifacts = ["DeployOutput"]
      configuration = {
        ProjectName   = aws_codebuild_project.stage["apply"].name
        PrimarySource = "BuildOutput"
      }
    }
  }
  stage {
    name = "Verify"
    action {
      name            = "VerifyPublishedRelease"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["BuildOutput", "DeployOutput"]
      configuration = {
        ProjectName   = aws_codebuild_project.stage["verify"].name
        PrimarySource = "BuildOutput"
      }
    }
  }
  tags       = local.tags
  depends_on = [aws_iam_role_policy.pipeline, aws_iam_role_policy_attachment.apply, aws_iam_role_policy.refresh, aws_iam_role_policy.state, aws_iam_role_policy.state_write]
}
