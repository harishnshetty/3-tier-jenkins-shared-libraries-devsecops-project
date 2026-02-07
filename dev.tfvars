region = "ap-south-1"

cluster_name                    = "my-cluster"
cluster_version                 = "1.34"
node_group_name                 = "ondemand-node-group"
cluster_endpoint_private_access = true
cluster_endpoint_public_access  = true
desired_size                    = 2
min_size                        = 2
max_size                        = 3


instance_types = ["t3.medium"]

addons = {
  "vpc-cni" = {
    name    = "vpc-cni"
    version = "v1.18.0-eksbuild.1"
  },
  "coredns" = {
    name    = "coredns"
    version = "v1.11.1-eksbuild.1"
  },
  "kube-proxy" = {
    name    = "kube-proxy"
    version = "v1.28.0-eksbuild.1"
  },
  "aws-ebs-csi-driver" = {
    name    = "aws-ebs-csi-driver"
    version = "v1.28.0-eksbuild.1"
  }
}
