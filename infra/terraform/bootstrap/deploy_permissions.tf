locals {
  runtime_roles = [for role in ["worker", "workflow", "scheduler"] : "${local.arn}:iam::${local.account}:role/${local.name}-${role}"]
}
locals {
  apply_statements = [
    # Provisioning scope deliberately excludes bootstrap/controller IAM identities.
    { Effect = "Allow", Action = "iam:CreateRole", Resource = local.runtime_roles, Condition = { ArnEquals = { "iam:PermissionsBoundary" = aws_iam_policy.runtime_boundary.arn } } },
    { Effect = "Allow", Action = ["iam:DeleteRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:PutRolePolicy", "iam:DeleteRolePolicy"], Resource = local.runtime_roles },
    { Effect = "Allow", Action = "iam:PutRolePermissionsBoundary", Resource = local.runtime_roles, Condition = { ArnEquals = { "iam:PermissionsBoundary" = aws_iam_policy.runtime_boundary.arn } } },
    { Effect = "Allow", Action = "iam:PassRole", Resource = local.runtime_roles, Condition = { StringEquals = { "iam:PassedToService" = ["lambda.amazonaws.com", "states.amazonaws.com", "scheduler.amazonaws.com"] } } },
    { Effect = "Allow", Action = ["iam:CreatePolicy", "iam:DeletePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion", "iam:TagPolicy", "iam:UntagPolicy"], Resource = "${local.arn}:iam::${local.account}:policy/${local.name}-analytics" },
    { Effect = "Allow", Action = "s3:*", Resource = "${local.arn}:s3:::${local.data_bucket}" },
    { Effect = "Deny", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:GetObjectVersion", "s3:DeleteObjectVersion"], Resource = "${local.arn}:s3:::${local.data_bucket}/*" },
    { Effect = "Allow", Action = "kms:CreateKey", Resource = "*", Condition = { StringEquals = { "aws:RequestTag/Deployment" = local.name } } },
    { Effect = "Allow", Action = ["kms:PutKeyPolicy", "kms:EnableKeyRotation", "kms:DisableKeyRotation", "kms:UpdateKeyDescription", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion", "kms:TagResource", "kms:UntagResource"], Resource = "${local.arn}:kms:${var.region}:${local.account}:key/*", Condition = { StringEquals = { "aws:ResourceTag/Deployment" = local.name } } },
    { Effect = "Allow", Action = ["kms:CreateAlias", "kms:UpdateAlias", "kms:DeleteAlias"], Resource = ["${local.arn}:kms:${var.region}:${local.account}:alias/${local.name}", "${local.arn}:kms:${var.region}:${local.account}:key/*"] },
    { Effect = "Allow", Action = ["lambda:CreateFunction", "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration", "lambda:DeleteFunction", "lambda:PublishVersion", "lambda:CreateAlias", "lambda:UpdateAlias", "lambda:DeleteAlias", "lambda:PutFunctionConcurrency", "lambda:DeleteFunctionConcurrency", "lambda:TagResource", "lambda:UntagResource"], Resource = "${local.arn}:lambda:${var.region}:${local.account}:function:${local.name}-*" },
    { Effect = "Allow", Action = ["states:CreateStateMachine", "states:UpdateStateMachine", "states:DeleteStateMachine", "states:TagResource", "states:UntagResource"], Resource = "${local.arn}:states:${var.region}:${local.account}:stateMachine:${local.name}-*" },
    { Effect = "Allow", Action = ["scheduler:CreateSchedule", "scheduler:UpdateSchedule", "scheduler:DeleteSchedule"], Resource = "${local.arn}:scheduler:${var.region}:${local.account}:schedule/default/${local.name}-*" },
    { Effect = "Allow", Action = ["secretsmanager:CreateSecret", "secretsmanager:UpdateSecret", "secretsmanager:DeleteSecret", "secretsmanager:RestoreSecret", "secretsmanager:TagResource", "secretsmanager:UntagResource"], Resource = "${local.arn}:secretsmanager:${var.region}:${local.account}:secret:${local.name}/*" },
    { Effect = "Allow", Action = ["sqs:CreateQueue", "sqs:DeleteQueue", "sqs:SetQueueAttributes", "sqs:TagQueue", "sqs:UntagQueue"], Resource = "${local.arn}:sqs:${var.region}:${local.account}:${local.name}-*" },
    { Effect = "Allow", Action = ["sns:CreateTopic", "sns:DeleteTopic", "sns:SetTopicAttributes", "sns:TagResource", "sns:UntagResource"], Resource = "${local.arn}:sns:${var.region}:${local.account}:${local.name}-*" },
    { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy", "logs:AssociateKmsKey", "logs:DisassociateKmsKey", "logs:TagResource", "logs:UntagResource", "logs:ListTagsLogGroup"], Resource = "${local.arn}:logs:${var.region}:${local.account}:log-group:/platform/${local.name}/*" },
    { Effect = "Allow", Action = ["cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards", "cloudwatch:TagResource", "cloudwatch:UntagResource"], Resource = ["${local.arn}:cloudwatch:${var.region}:${local.account}:alarm:${local.name}-*", "${local.arn}:cloudwatch::${local.account}:dashboard/${local.name}"] },
    { Effect = "Allow", Action = ["athena:CreateWorkGroup", "athena:UpdateWorkGroup", "athena:DeleteWorkGroup", "athena:TagResource", "athena:UntagResource"], Resource = "${local.arn}:athena:${var.region}:${local.account}:workgroup/${local.name}" },
    { Effect = "Allow", Action = ["glue:CreateDatabase", "glue:UpdateDatabase", "glue:DeleteDatabase", "glue:CreateTable", "glue:UpdateTable", "glue:DeleteTable", "glue:TagResource", "glue:UntagResource"], Resource = ["${local.arn}:glue:${var.region}:${local.account}:catalog", "${local.arn}:glue:${var.region}:${local.account}:database/${replace(local.name, "-", "_")}", "${local.arn}:glue:${var.region}:${local.account}:table/${replace(local.name, "-", "_")}/*"] },
    # EC2 create/endpoint routing uses existing network resources. Review this regional
    # lab deployment authority before use; runtime role is far narrower.
    { Effect = "Allow", Action = ["ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress", "ec2:ModifySecurityGroupRules", "ec2:CreateTags", "ec2:DeleteTags", "ec2:CreateVpcEndpoint", "ec2:ModifyVpcEndpoint", "ec2:DeleteVpcEndpoints"], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = var.region } } },
    # Secrets Manager validates customer-key access even without a secret value.
    # Allow only this deployment's key, via Secrets Manager, for its source secret.
    { Sid = "SourceSecretKeyValidation", Effect = "Allow", Action = ["kms:GenerateDataKey", "kms:Decrypt"], Resource = "${local.arn}:kms:${var.region}:${local.account}:key/*", Condition = {
      StringEquals = { "aws:ResourceTag/Deployment" = local.name, "kms:ViaService" = "secretsmanager.${var.region}.amazonaws.com" },
      ArnLike      = { "kms:EncryptionContext:SecretARN" = "${local.arn}:secretsmanager:${var.region}:${local.account}:secret:${local.name}/sql-source-??????" }
    } },
    # DeleteDatabase also checks permissions on all descendant UDFs.
    { Sid = "DeleteDeploymentDatabaseFunctions", Effect = "Allow", Action = "glue:DeleteDatabase", Resource = "${local.arn}:glue:${var.region}:${local.account}:userDefinedFunction/${replace(local.name, "-", "_")}/*" },
    # Validation takes a definition, not a state machine ARN; resource scoping is unsupported.
    { Sid = "ValidateWorkflowDefinition", Effect = "Allow", Action = "states:ValidateStateMachineDefinition", Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = var.region } } }
  ]
}
resource "aws_iam_policy" "apply" {
  for_each = { for index, statements in chunklist([for statement in local.apply_statements : jsonencode(statement)], 5) : tostring(index) => statements }
  name     = "${local.name}-ci-apply-${each.key}"
  policy   = jsonencode({ Version = "2012-10-17", Statement = [for statement in each.value : jsondecode(statement)] })
  tags     = local.tags
}
resource "aws_iam_role_policy_attachment" "apply" {
  for_each   = aws_iam_policy.apply
  role       = aws_iam_role.build["apply"].name
  policy_arn = each.value.arn
}
