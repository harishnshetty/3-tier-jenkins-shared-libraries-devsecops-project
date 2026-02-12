
## 4. Install ArgoCD

[ArgoCD Helm Link ](https://github.com/argoproj/argo-helm/blob/main/README.md)

```bash
helm repo add argo https://argoproj.github.io/argo-helm

helm repo update

helm search repo argocd
```

## install argocd with clusterip
```bash
kubectl create namespace argocd

helm install argocd argo/argo-cd --namespace argocd \
  --set server.extraArgs[0]="--insecure" \
  --set server.service.type=ClusterIP
```

## install argocd with values.yaml
```bash
server:
  extraArgs:
    - --insecure
  service:
    type: ClusterIP

helm install argocd argo/argo-cd --namespace argocd -f argocd-values.yaml
```

## delete argocd
```bash
kubectl delete pod -n cert-manager -l app.kubernetes.io/name=cert-manager
```

## get argocd admin password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```


## 5. Install Prometheus

[Prometheus Helm Link ](https://github.com/prometheus-community/helm-charts)

```bash 
helm repo add stable https://charts.helm.sh/stable
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm search repo prometheus-community
```

# 5.1 Create namespace
```bash
kubectl create namespace prometheus
```

# 5.2 Install Prometheus stack with Grafana configuration
```bash
helm install stable prometheus-community/kube-prometheus-stack --version 81.0.0 -n prometheus -f prometheus-values.yaml --timeout 10m
helm upgrade stable prometheus-community/kube-prometheus-stack --version 81.0.0 -n prometheus -f prometheus-values.yaml --timeout 10m
```

# 5.3 Install Prometheus Blackbox Exporter
```bash
helm install stable prometheus-community/prometheus-blackbox-exporter --version 11.8.0 -n prometheus
```

# 5.4 Apply the ReferenceGrant (after namespace exists)
```bash
kubectl apply -f prometheus-referencegrant.yaml
```

# 5.5 Apply the Grafana HTTPRoute (you already have this in http.yaml)
```bash
kubectl apply -f http.yaml
```

# 5.6 Get Grafana admin password
```bash
kubectl get secret -n prometheus stable-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

