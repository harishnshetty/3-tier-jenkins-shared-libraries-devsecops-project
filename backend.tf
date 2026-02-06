terraform {
  backend "s3" {
    bucket       = "my-tf-demo-harish-bucket-2025"
    key          = "eks-cluster/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
