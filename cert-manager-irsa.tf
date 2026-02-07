resource "aws_iam_policy" "cert_manager_route53" {
  name        = "cert-manager-route53-policy"
  description = "Cert Manager policy to allow management of Route53 hosted zone records"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "route53:GetChange",
        "Resource" : "arn:aws:route53:::change/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "route53:ListResourceRecordSets",
        "Resource" : "arn:aws:route53:::hostedzone/*"
      },
      {
        "Effect" : "Allow",
        "Action" : "route53:ChangeResourceRecordSets",
        "Resource" : "arn:aws:route53:::hostedzone/*"
      }
    ]
  })
}

resource "aws_iam_role" "cert-manager-iam-role" {
  name = "cert-manager-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:cert-manager:cert-manager"
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cert_manager_route53_attachment" {
  policy_arn = aws_iam_policy.cert_manager_route53.arn
  role       = aws_iam_role.cert-manager-iam-role.name
}

output "cert_manager_role_arn" {
  value = aws_iam_role.cert-manager-iam-role.arn
}
