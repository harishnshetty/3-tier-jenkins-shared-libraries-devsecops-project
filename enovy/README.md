kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml


kubectl get crd | grep gateway


 Install Envoy Gateway

https://gateway.envoyproxy.io/docs/install/install-helm/

helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.6.3 -n envoy-gateway-system --create-namespace


kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.6.3/quickstart.yaml -n default


kubectl wait --timeout=2m -n envoy-gateway-system \
 deployment/envoy-gateway --for=condition=Available

 kubectl get pods -n envoy-gateway-system

 kubectl get gatewayclass


helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.19.3 \
  --set installCRDs=true


  helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --reuse-values \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::970378220457:role/cert-manager-iam-role"



kubectl create namespace argocd

helm install argocd argo/argo-cd --namespace argocd \
  --set server.extraArgs[0]="--insecure" \
  --set server.service.type=ClusterIP

----
```bash
server:
  extraArgs:
    - --insecure
  service:
    type: ClusterIP

helm install argocd argo/argo-cd --namespace argocd -f argocd-values.yaml
```

kubectl delete pod -n cert-manager -l app.kubernetes.io/name=cert-manager


kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
HrNBnIX8v7htKqSH┌



helm repo add stable https://charts.helm.sh/stable
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm search repo prometheus-community


# 1. Create namespace
kubectl create namespace prometheus

# 2. Install Prometheus stack with Grafana configuration
helm install stable prometheus-community/kube-prometheus-stack --version 81.0.0 -n prometheus -f prometheus-values.yaml --timeout 10m
helm upgrade stable prometheus-community/kube-prometheus-stack --version 81.0.0 -n prometheus -f prometheus-values.yaml --timeout 10m

helm install stable prometheus-community/prometheus-blackbox-exporter --version 11.8.0 -n prometheus
# 3. Apply the ReferenceGrant (after namespace exists)
kubectl apply -f prometheus-referencegrant.yaml

# 4. Apply the Grafana HTTPRoute (you already have this in http.yaml)
kubectl apply -f http.yaml

# 5. Get Grafana admin password
kubectl get secret -n prometheus stable-grafana -o jsonpath="{.data.admin-password}" | base64 -d



helm repo add elastic https://helm.elastic.co
helm repo update

helm repo add elastic https://helm.elastic.co
helm repo update

# Install Elasticsearch (Single Node - Minimal Resource)
helm install elasticsearch elastic/elasticsearch -n elk --create-namespace -f elasticsearch-values.yaml --version 7.17.3

# Install Kibana (Minimal Resource)
helm install kibana elastic/kibana -n elk --create-namespace -f kibana-values.yaml --version 7.17.3

# Apply ReferenceGrant for Kibana access
kubectl apply -f elk-referencegrant.yaml

# Create Kibana HTTPRoute
kubectl apply -f http.yaml

# Add Kibana DNS entry
echo "43.204.189.86 kibana.harishshetty.xyz" | sudo tee -a /etc/hosts


# Install Logstash (Minimal Resource)
helm install logstash elastic/logstash -n elk --create-namespace -f logstash-values.yaml --version 7.17.3

# Install Filebeat (Minimal Resource)
helm install filebeat elastic/filebeat -n elk --create-namespace -f filebeat-values.yaml --version 7.17.3

1. Watch all cluster members come up.
  $ kubectl get pods --namespace=elk -l app=elasticsearch-master -w
2. Retrieve elastic user's password.
  $ kubectl get secrets --namespace=elk elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
3. Test cluster health using Helm test.
  $ helm --namespace=elk test elasticsearch