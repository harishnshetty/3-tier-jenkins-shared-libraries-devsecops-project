# Gateway API Setup - Deployment Guide

This guide provides step-by-step instructions for deploying NGINX Gateway Fabric on AWS EKS with multiple services.

## Prerequisites

Before starting, ensure you have:

- ✅ AWS EKS cluster running (Kubernetes 1.28+)
- ✅ `kubectl` configured to access your cluster
- ✅ `helm` installed (v3.12+)
- ✅ Terraform infrastructure applied (cert-manager IRSA, ALB controller)
- ✅ cert-manager installed in the cluster
- ✅ Backend services deployed (ArgoCD, Grafana, app1, app2)

## Step 1: Verify Prerequisites

```bash
# Verify kubectl access
kubectl cluster-info

# Check cert-manager is running
kubectl get pods -n cert-manager

# Verify backend services exist
kubectl get svc -n argocd argocd-server
kubectl get svc -n monitoring grafana
kubectl get svc -n default app1-service app2-service

# Get cert-manager IAM role ARN from Terraform
cd /home/harish/Desktop/demo-projects/3-tier-jenkins-shared-libraries-devsecops-project
terraform output cert_manager_role_arn
```

## Step 2: Install Gateway API CRDs

```bash
# Install Gateway API v1.2.0 CRDs
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml


# Verify CRDs are installed
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get crd httproutes.gateway.networking.k8s.io
kubectl get crd gatewayclasses.gateway.networking.k8s.io
```

## Step 3: Configure cert-manager ServiceAccount with IRSA

```bash
# Update the ServiceAccount with your IAM role ARN
# First, get the role ARN
CERT_MANAGER_ROLE_ARN=$(terraform output -raw cert_manager_role_arn)
echo "Cert Manager Role ARN: $CERT_MANAGER_ROLE_ARN"

# Update the ServiceAccount file
sed -i "s|arn:aws:iam::<ACCOUNT_ID>:role/cert-manager-iam-role|$CERT_MANAGER_ROLE_ARN|g" \
  new/cert-manager-serviceaccount.yaml

# Apply the ServiceAccount (this will patch the existing one)
kubectl apply -f new/cert-manager-serviceaccount.yaml

# Restart cert-manager pods to pick up the new annotation
kubectl rollout restart deployment cert-manager -n cert-manager
kubectl rollout status deployment cert-manager -n cert-manager
```

## Step 4: Install NGINX Gateway Fabric

```bash
# Create namespace
kubectl create namespace nginx-gateway --dry-run=client -o yaml | kubectl apply -f -

# Install NGINX Gateway Fabric using Helm with custom values
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --create-namespace -n nginx-gateway \
  --values new/nginx-gateway-fabric-helm-values.yaml


# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=nginx-gateway-fabric \
  -n nginx-gateway \
  --timeout=300s

# Verify installation
kubectl get pods -n nginx-gateway
kubectl get svc -n nginx-gateway
```

## Step 5: Apply Gateway API Resources

```bash
cd gatewayapi-nginx-fabric

# Apply resources in order
kubectl apply -f gatewayclass.yaml
kubectl apply -f clusterissuer.yaml
kubectl apply -f certificate.yaml
kubectl apply -f gateway.yaml

# Wait for Gateway to be ready (this may take a few minutes for NLB provisioning)
kubectl wait --for=condition=Programmed gateway/my-gateway \
  -n nginx-gateway \
  --timeout=600s

# Check Gateway status
kubectl get gateway my-gateway -n nginx-gateway
kubectl describe gateway my-gateway -n nginx-gateway
```

## Step 6: Apply ReferenceGrants

```bash
# Create namespaces if they don't exist
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Apply ReferenceGrants
kubectl apply -f referencegrant.yaml
```

## Step 7: Apply HTTPRoutes

```bash
# Apply HTTP to HTTPS redirect
kubectl apply -f HTTP-redirect.yaml

# Apply service routes
kubectl apply -f routes.yaml

# Verify HTTPRoutes
kubectl get httproute -n nginx-gateway
kubectl describe httproute -n nginx-gateway
```

## Step 8: Verify Certificate Issuance

```bash
# Check certificate status
kubectl get certificate -n nginx-gateway
kubectl describe certificate harishshetty-tls -n nginx-gateway

# Check for certificate secret
kubectl get secret harishshetty-tls -n nginx-gateway

# If certificate is not ready, check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Check for certificate request
kubectl get certificaterequest -n nginx-gateway
```

**Note:** Certificate issuance may take 2-5 minutes as Let's Encrypt validates DNS ownership via Route53.

## Step 9: Configure DNS in Route53

```bash
# Get the NLB DNS name
NLB_DNS=$(kubectl get svc -n nginx-gateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "NLB DNS: $NLB_DNS"

# Get the NLB Hosted Zone ID (for Route53 alias records)
NLB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='$NLB_DNS'].CanonicalHostedZoneId" \
  --output text)
echo "NLB Zone ID: $NLB_ZONE_ID"

# Get your Route53 hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name harishshetty.xyz \
  --query "HostedZones[0].Id" \
  --output text | cut -d'/' -f3)
echo "Hosted Zone ID: $HOSTED_ZONE_ID"
```

### Create Route53 Records

Create a file `route53-records.json`:

```json
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "argocd.harishshetty.xyz",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "REPLACE_WITH_NLB_ZONE_ID",
          "DNSName": "REPLACE_WITH_NLB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "grafana.harishshetty.xyz",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "REPLACE_WITH_NLB_ZONE_ID",
          "DNSName": "REPLACE_WITH_NLB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app1.harishshetty.xyz",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "REPLACE_WITH_NLB_ZONE_ID",
          "DNSName": "REPLACE_WITH_NLB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app2.harishshetty.xyz",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "REPLACE_WITH_NLB_ZONE_ID",
          "DNSName": "REPLACE_WITH_NLB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
```

Apply the DNS records:

```bash
# Replace placeholders in the JSON file
sed -i "s/REPLACE_WITH_NLB_ZONE_ID/$NLB_ZONE_ID/g" route53-records.json
sed -i "s/REPLACE_WITH_NLB_DNS/$NLB_DNS/g" route53-records.json

# Apply the changes
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://route53-records.json

# Verify DNS propagation (may take 30-60 seconds)
dig argocd.harishshetty.xyz
dig grafana.harishshetty.xyz
dig app1.harishshetty.xyz
dig app2.harishshetty.xyz
```

## Step 10: Verification

### Test HTTP to HTTPS Redirect

```bash
# Test redirect (should return 301)
curl -I http://argocd.harishshetty.xyz
curl -I http://grafana.harishshetty.xyz
```

### Test HTTPS Endpoints

```bash
# Test HTTPS connectivity
curl -v https://argocd.harishshetty.xyz
curl -v https://grafana.harishshetty.xyz
curl -v https://app1.harishshetty.xyz
curl -v https://app2.harishshetty.xyz
```

### Verify Certificate

```bash
# Check certificate details
echo | openssl s_client -connect argocd.harishshetty.xyz:443 -servername argocd.harishshetty.xyz 2>/dev/null | \
  openssl x509 -noout -dates -subject -issuer
```

### Check Gateway and HTTPRoute Status

```bash
# Gateway status
kubectl get gateway my-gateway -n nginx-gateway -o yaml

# HTTPRoute status
kubectl get httproute -n nginx-gateway
kubectl describe httproute argocd-route -n nginx-gateway
kubectl describe httproute grafana-route -n nginx-gateway
kubectl describe httproute app1-route -n nginx-gateway
kubectl describe httproute app2-route -n nginx-gateway
```

## Troubleshooting

### Gateway Not Ready

```bash
# Check NGINX Gateway Fabric logs
kubectl logs -n nginx-gateway -l app.kubernetes.io/name=nginx-gateway-fabric --tail=100

# Check Gateway events
kubectl get events -n nginx-gateway --sort-by='.lastTimestamp'
```

### Certificate Not Issuing

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100

# Check certificate request details
kubectl describe certificaterequest -n nginx-gateway

# Verify IRSA configuration
kubectl describe sa cert-manager -n cert-manager

# Test Route53 access from cert-manager pod
kubectl exec -n cert-manager deploy/cert-manager -- \
  aws route53 list-hosted-zones
```

### HTTPRoute Not Working

```bash
# Check HTTPRoute status
kubectl describe httproute <route-name> -n nginx-gateway

# Verify backend service exists
kubectl get svc -n <namespace> <service-name>

# Check ReferenceGrant
kubectl get referencegrant -n <backend-namespace>
kubectl describe referencegrant -n <backend-namespace>

# Check NGINX config
kubectl exec -n nginx-gateway deploy/ngf-nginx-gateway-fabric -- nginx -T
```

### NLB Not Provisioning

```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Verify service annotations
kubectl get svc -n nginx-gateway -o yaml
```

## Maintenance

### Update NGINX Gateway Fabric

```bash
# Update to latest version
helm upgrade ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --values new/nginx-gateway-fabric-helm-values.yaml \
  --reuse-values

# Monitor rollout
kubectl rollout status deployment/ngf-nginx-gateway-fabric -n nginx-gateway
```

### Renew Certificates

Certificates auto-renew 30 days before expiration. To force renewal:

```bash
# Delete certificate to trigger re-issuance
kubectl delete certificate harishshetty-tls -n nginx-gateway

# Reapply
kubectl apply -f gatewayapi-nginx-fabric/certificate.yaml
```

## Clean Up

To remove the Gateway API setup:

```bash
# Delete HTTPRoutes
kubectl delete -f gatewayapi-nginx-fabric/routes.yaml
kubectl delete -f gatewayapi-nginx-fabric/HTTP-redirect.yaml

# Delete Gateway and Certificate
kubectl delete -f gatewayapi-nginx-fabric/gateway.yaml
kubectl delete -f gatewayapi-nginx-fabric/certificate.yaml

# Delete ReferenceGrants
kubectl delete -f gatewayapi-nginx-fabric/referencegrant.yaml

# Uninstall NGINX Gateway Fabric
helm uninstall ngf -n nginx-gateway

# Delete namespace
kubectl delete namespace nginx-gateway
```

## Next Steps

- Set up monitoring with Prometheus/Grafana for Gateway metrics
- Configure rate limiting and WAF policies
- Implement canary deployments using HTTPRoute traffic splitting
- Add additional services as needed
