# Nginx Gateway Fabric Setup on EKS

This guide outlines the steps to set up Nginx Gateway Fabric on your Amazon EKS cluster.

## Prerequisites

1.  **EKS Cluster**: Ensure you have an active EKS cluster.
2.  **AWS Load Balancer Controller**: Must be installed and running in the `kube-system` namespace.
    *   *Important*: The controller's IAM role must have the correct policy attached to allow `elasticloadbalancing:DescribeLoadBalancers` and other actions.
3.  **kubectl**: Installed and configured to communicate with your cluster.
    ```bash
    aws eks update-kubeconfig --name <cluster-name> --region <region>
    ```
4.  **Helm**: Installed for package management.

## Installation Steps

### 1. Install Gateway API CRDs

The Gateway API Custom Resource Definitions (CRDs) are required before installing Nginx Gateway Fabric.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

### 2. Install Nginx Gateway Fabric via Helm

Install the Nginx Gateway Fabric using the OCI Helm chart.

```bash
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway
```

### 3. Verify Installation

Check if the pods are running and the LoadBalancer service is provisioned.

```bash
kubectl get pods -n nginx-gateway
kubectl get svc -n nginx-gateway
```

The `my-gateway-nginx` service should eventually have an `EXTERNAL-IP` assigned (this may take a few minutes).

## Troubleshooting

### Pending External IP
If the `my-gateway-nginx` service remains in `<pending>` state:
1.  Check the AWS Load Balancer Controller logs:
    ```bash
    kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
    ```
2.  Look for `AccessDenied` errors. If found, ensure the IAM role for the controller has the necessary permissions policy attached.

## Cert-Manager (Optional)

If you need to set up Cert-Manager for TLS termination:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.19.3 \
  --set installCRDs=true
```












































---


https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/config/crd/gateway/gateway-crds.yaml


helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=my-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --set vpcId=vpc-0366077d37eaa0c7e \
  --set "controllerConfig.featureGates.ALBGatewayAPI=true"