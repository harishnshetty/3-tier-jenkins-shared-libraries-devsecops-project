
# IAM Policy for Route53 Access (DNS-01 Challenge)
resource "aws_iam_policy" "cert_manager_route53" {
  name        = "cert-manager-route53-policy"
  path        = "/"
  description = "Policy for cert-manager to manage Route53 records for DNS-01 challenge"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "route53:GetChange"
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect   = "Allow"
        Action   = "route53:ListHostedZonesByName"
        Resource = "*"
      }
    ]
  })
}

# IAM Role for Cert Manager Service Account (IRSA)
# Requires OIDC Provider to be configured in your AWS account and Terraform
# If you don't have the data sources below, you must ensure 'module.cert_manager_irsa_role' has the correct OIDC provider ARN.

# data "aws_eks_cluster" "cluster" {
#   name = var.cluster_name
# }

# data "aws_iam_openid_connect_provider" "oidc" {
#   url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
# }

module "cert_manager_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "cert-manager-role"

  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = ["arn:aws:route53:::hostedzone/Z*"]

  oidc_providers = {
    ex = {
      # Replace with your OIDC Provider ARN if not using data source
      # provider_arn               = "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/EXAMPLED539D18..."
      # Or use data source:
      # provider_arn               = data.aws_iam_openid_connect_provider.oidc.arn

      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }

  role_policy_arns = {
    additional = aws_iam_policy.cert_manager_route53.arn
  }
}

output "cert_manager_role_arn" {
  value = module.cert_manager_irsa_role.iam_role_arn
}
