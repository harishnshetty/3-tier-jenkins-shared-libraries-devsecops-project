resource "kubernetes_service_account_v1" "alb_controller_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller_role[0].arn
    }
  }
  depends_on = [aws_eks_cluster.eks_cluster, aws_eks_node_group.node-group]
}

