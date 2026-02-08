region = "ap-south-1"

cluster_name                    = "my-cluster"
cluster_version                 = "1.35"
node_group_name                 = "ondemand-node-group"
cluster_endpoint_private_access = true
cluster_endpoint_public_access  = true
desired_size                    = 3
min_size                        = 3
max_size                        = 4


instance_types = ["t3.medium"]

addons = {
  "vpc-cni" = {
    name    = "vpc-cni"
    version = "v1.21.1-eksbuild.3"
  },
  "coredns" = {
    name    = "coredns"
    version = "v1.13.2-eksbuild.1"
  },
  "kube-proxy" = {
    name    = "kube-proxy"
    version = "v1.35.0-eksbuild.2"
  },
  "aws-ebs-csi-driver" = {
    name    = "aws-ebs-csi-driver"
    version = "v1.55.0-eksbuild.2"
  },
  "metrics-server" = {
    name    = "metrics-server"
    version = "v0.8.1-eksbuild.1"
  }
}
