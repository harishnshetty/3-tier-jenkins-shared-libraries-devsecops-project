# eks-terraform creation using jenkins pipeline


## create the secret text in jenkins
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY


## Create the following files:
1. Jenkinsfile
2. dev.tfvars
3. prod.tfvars
4. EKS directory with main.tf, variables.tf, outputs.tf, terraform.tfvars


# Auto certificate manager installation using terraform
```bash
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.19.3" # Using a stable recent version
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "cert-manager"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cert-manager-iam-role.arn
  }

  values = [
    yamlencode({
      installCRDs = true
      config = {
        apiVersion       = "controller.config.cert-manager.io/v1alpha1"
        kind             = "ControllerConfiguration"
        enableGatewayAPI = true
      }
    })
  ]
}
```
```bash
helm search repo jetstack/cert-manager

helm repo add jetstack https://charts.jetstack.io ; helm repo update jetstack

helm install  cert-manager jetstack/cert-manager -n cert-manager  --create-namespace --version v1.16.2 -f cert-manager/values.yaml
```