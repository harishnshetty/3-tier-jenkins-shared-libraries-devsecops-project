kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml


helm repo add jetstack https://charts.jetstack.io
helm repo update
helm search repo jetstack/cert-manager

helm install cert-manager jetstack/cert-manager \
 --namespace cert-manager \
 --create-namespace \
 --version v1.19.3 \
 --set installCRDs=true \
 --set "extraArgs={--feature-gates=GatewayAPI=true}"


 kubectl apply -f clusterissuer.yaml

 helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway