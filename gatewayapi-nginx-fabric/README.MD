kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml


helm repo add jetstack https://charts.jetstack.io
helm repo update
helm search repo jetstack/cert-manager

helm install cert-manager jetstack/cert-manager \
 --namespace cert-manager \
 --create-namespace \
 --version v1.19.3 \
 --set installCRDs=true


 kubectl apply -f clusterissuer.yaml

 helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway


 kubectl annotate serviceaccount -n cert-manager cert-manager eks.amazonaws.com/role-arn=arn:aws:iam::970378220457:role/cert-manager-role --overwrite
kubectl rollout restart deployment cert-manager -n cert-manager