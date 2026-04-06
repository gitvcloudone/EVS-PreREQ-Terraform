# ── Phase 2: IAM Policy for EVS Deployment User ───────────────────────────────
# Attach this policy to the IAM user or role that will call CreateEnvironment.
# The EVS service-linked role (AWSServiceRoleForEVS) is managed in main.tf.

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "evs_deploy" {
  # Full EVS control plane access
  statement {
    sid       = "EVSFullAccess"
    effect    = "Allow"
    actions   = ["evs:*"]
    resources = ["*"]
  }

  # Permission to create the EVS service-linked role if it does not yet exist
  statement {
    sid     = "CreateEVSServiceLinkedRole"
    effect  = "Allow"
    actions = ["iam:CreateServiceLinkedRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/evs.amazonaws.com/AWSServiceRoleForEVS"
    ]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["evs.amazonaws.com"]
    }
  }

  # EC2 permissions needed to describe and manage EVS-created resources
  statement {
    sid    = "EC2Describe"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstances",
      "ec2:DescribeCapacityReservations",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeRouteTables",
      "ec2:DescribeVpcAttribute",
    ]
    resources = ["*"]
  }

  # EC2 write permissions required by EVS during CreateEnvironment.
  # No tag condition: EVS tags resources during creation, so restricting by
  # AmazonEVSManaged tag on write actions would deny EVS before it can tag.
  statement {
    sid    = "EC2ManageEVSResources"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:DetachNetworkInterface",
    ]
    resources = ["*"]
  }

  # Secrets Manager — EVS stores VCF credentials here during bring-up
  statement {
    sid    = "SecretsManager"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:evs-*"]
  }

  # KMS — required if using customer-managed keys for Secrets Manager encryption
  statement {
    sid    = "KMSDescribe"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:ListAliases",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "evs_deploy" {
  name        = "EVSDeploymentPolicy"
  description = "Minimum permissions required to create and manage an Amazon EVS environment."
  policy      = data.aws_iam_policy_document.evs_deploy.json
  tags        = { Name = "evs-deployment-policy" }
}
