output "bootstrap_contract" {
  value = {
    state_bucket         = aws_s3_bucket.control["state"].id
    state_key            = local.state_key
    state_kms_arn        = aws_kms_key.control.arn
    runtime_boundary_arn = aws_iam_policy.runtime_boundary.arn
    artifact_bucket      = aws_s3_bucket.control["artifacts"].id
    pipeline_name        = aws_codepipeline.platform.name
  }
}
