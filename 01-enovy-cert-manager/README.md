# Envoy Gateway and Cert Manager Setup


## 1. Update Kubeconfig
```bash
aws eks update-kubeconfig --name my-cluster --region ap-south-1
```

[Gateway API Link ](https://gateway-api.sigs.k8s.io/guides/getting-started/#installing-a-gateway-controller)

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
```

```bash
kubectl get crd | grep gateway
```
---

## 2. Install Envoy Gateway

[Envoy Gateway Helm Link ](https://gateway.envoyproxy.io/docs/install/install-helm/)

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.7.0 -n envoy-gateway-system --create-namespace



kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available



kubectl get pods -n envoy-gateway-system

kubectl get gatewayclass -A

# kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.6.3/quickstart.yaml -n default
```
---
## 3. Install Cert Manager

[Cert Manager Link ](https://artifacthub.io/packages/helm/cert-manager/cert-manager)

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

helm search repo cert-manager
```

** Replace <your-aws-account-id> with your actual AWS account ID **

```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.19.3 \
  --set crds.enabled=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::<your-aws-account-id>:role/cert-manager-iam-role"
```

```bash
helm uninstall cert-manager -n cert-manager
```
## delete argocd
```bash
kubectl delete pod -n cert-manager -l app.kubernetes.io/name=cert-manager
```


