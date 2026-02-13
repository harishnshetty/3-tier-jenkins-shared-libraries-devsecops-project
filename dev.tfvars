region = "ap-south-1"

cluster_name                    = "my-cluster"
cluster_version                 = "1.35"
node_group_name                 = "ondemand-node-group" #spot-node-group
cluster_endpoint_private_access = true
cluster_endpoint_public_access  = true
desired_size                    = 4
min_size                        = 4
max_size                        = 6


spot_instance_types = ["c5a.large", "c5a.xlarge", "m5a.large", "m5a.xlarge", "c5.large", "m5.large", "t3a.large", "t3a.xlarge", "t3a.medium"]


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
