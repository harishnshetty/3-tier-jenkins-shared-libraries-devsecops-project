output "eks_cluster_role_arn" {
  value = var.is_eks_role_enabled ? aws_iam_role.eks_cluster_role.arn : null
}


output "alb_controller_role_arn" {
  value = var.is_alb_controller_enabled ? aws_iam_role.alb_controller_role[0].arn : null
}
