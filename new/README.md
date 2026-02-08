# Gateway API Setup with NGINX Gateway Fabric

This directory contains all the configuration files and deployment guide for setting up NGINX Gateway Fabric on AWS EKS with multiple services.

## Overview

This setup provides:
- **NGINX Gateway Fabric** as the Gateway API implementation
- **Wildcard TLS certificates** (*.harishshetty.xyz) via cert-manager and Let's Encrypt
- **Route53 DNS-01 challenge** for certificate validation using IRSA
- **AWS Network Load Balancer** for internet-facing access
- **HTTPRoutes** for multiple services: ArgoCD, Grafana, app1, app2

## Directory Structure

```
new/
├── README.md                              # This file
├── deployment-guide.md                    # Complete deployment instructions
├── nginx-gateway-fabric-helm-values.yaml  # Helm values for NGINX Gateway Fabric
└── cert-manager-serviceaccount.yaml       # ServiceAccount with IRSA for cert-manager
```

## Services Configuration

The setup routes traffic to the following services:

| Service | Subdomain | Namespace | Service Name | Port |
|---------|-----------|-----------|--------------|------|
| ArgoCD | argocd.harishshetty.xyz | argocd | argocd-server | 80 |
| Grafana | grafana.harishshetty.xyz | monitoring | grafana | 80 |
| App1 | app1.harishshetty.xyz | default | app1-service | 80 |
| App2 | app2.harishshetty.xyz | default | app2-service | 80 |

## Quick Start

### Prerequisites

1. EKS cluster with cert-manager installed
2. Terraform infrastructure applied (cert-manager IRSA)
3. Backend services deployed
4. kubectl and helm installed

### Deployment Steps

1. **Get cert-manager IAM role ARN:**
   ```bash
   cd /home/harish/Desktop/demo-projects/3-tier-jenkins-shared-libraries-devsecops-project
   CERT_MANAGER_ROLE_ARN=$(terraform output -raw cert_manager_role_arn)
   ```

2. **Update cert-manager ServiceAccount:**
   ```bash
   sed -i "s|arn:aws:iam::<ACCOUNT_ID>:role/cert-manager-iam-role|$CERT_MANAGER_ROLE_ARN|g" \
     new/cert-manager-serviceaccount.yaml
   kubectl apply -f new/cert-manager-serviceaccount.yaml
   kubectl rollout restart deployment cert-manager -n cert-manager
   ```

3. **Install Gateway API CRDs:**
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
   ```

4. **Install NGINX Gateway Fabric:**
   ```bash
   helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
     --namespace nginx-gateway \
     --create-namespace \
     --values new/nginx-gateway-fabric-helm-values.yaml
   ```

5. **Apply Gateway API resources:**
   ```bash
   cd gatewayapi-nginx-fabric
   kubectl apply -f gatewayclass.yaml
   kubectl apply -f clusterissuer.yaml
   kubectl apply -f certificate.yaml
   kubectl apply -f gateway.yaml
   kubectl apply -f referencegrant.yaml
   kubectl apply -f HTTP-redirect.yaml
   kubectl apply -f routes.yaml
   ```

6. **Configure DNS in Route53** (see deployment-guide.md for details)

For complete step-by-step instructions, see [deployment-guide.md](deployment-guide.md).

## Architecture

```
Internet
    ↓
AWS Network Load Balancer (NLB)
    ↓
NGINX Gateway Fabric (Gateway Controller)
    ↓
Gateway API Resources (Gateway, HTTPRoute)
    ↓
Kubernetes Services (ArgoCD, Grafana, app1, app2)
    ↓
Application Pods
```

## Key Features

- ✅ **Automatic HTTP to HTTPS redirect** for all services
- ✅ **Wildcard TLS certificate** covering all subdomains
- ✅ **Cross-namespace routing** via ReferenceGrants
- ✅ **High availability** with 3 replicas and pod anti-affinity
- ✅ **AWS NLB integration** with cross-zone load balancing
- ✅ **IRSA authentication** for cert-manager Route53 access

## Configuration Files

### In `new/` directory:

- **deployment-guide.md**: Complete deployment instructions with all commands
- **nginx-gateway-fabric-helm-values.yaml**: Production-ready Helm configuration
- **cert-manager-serviceaccount.yaml**: ServiceAccount with IRSA annotation

### In `gatewayapi-nginx-fabric/` directory:

- **gatewayclass.yaml**: GatewayClass definition for NGINX
- **clusterissuer.yaml**: Let's Encrypt ClusterIssuer with Route53 DNS-01
- **certificate.yaml**: Wildcard certificate for *.harishshetty.xyz
- **gateway.yaml**: Gateway resource with HTTP/HTTPS listeners
- **routes.yaml**: HTTPRoutes for all services
- **HTTP-redirect.yaml**: HTTP to HTTPS redirect rule
- **referencegrant.yaml**: Cross-namespace access grants

## Verification

After deployment, verify the setup:

```bash
# Check Gateway status
kubectl get gateway my-gateway -n nginx-gateway

# Check HTTPRoutes
kubectl get httproute -n nginx-gateway

# Check certificate
kubectl get certificate harishshetty-tls -n nginx-gateway

# Get NLB DNS
kubectl get svc -n nginx-gateway

# Test endpoints
curl -I http://argocd.harishshetty.xyz  # Should redirect to HTTPS
curl -v https://argocd.harishshetty.xyz
```

## Troubleshooting

See the [Troubleshooting section](deployment-guide.md#troubleshooting) in the deployment guide for common issues and solutions.

## Customization

### Adding New Services

To add a new service:

1. Create a new HTTPRoute in `routes.yaml`:
   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   metadata:
     name: myapp-route
     namespace: nginx-gateway
   spec:
     parentRefs:
       - name: my-gateway
         namespace: nginx-gateway
         sectionName: https
     hostnames:
       - "myapp.harishshetty.xyz"
     rules:
       - backendRefs:
           - name: myapp-service
             namespace: myapp-namespace
             port: 80
   ```

2. Add ReferenceGrant if service is in a different namespace
3. Add subdomain to `HTTP-redirect.yaml`
4. Create Route53 DNS record

### Changing Service Ports or Names

Update the corresponding HTTPRoute in `routes.yaml` with the correct:
- `namespace`: Where the service is deployed
- `name`: Kubernetes service name
- `port`: Service port number

## Maintenance

### Update NGINX Gateway Fabric

```bash
helm upgrade ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --values new/nginx-gateway-fabric-helm-values.yaml \
  --reuse-values
```

### Certificate Renewal

Certificates auto-renew 30 days before expiration. No manual intervention required.

## Resources

- [NGINX Gateway Fabric Documentation](https://docs.nginx.com/nginx-gateway-fabric/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

## Support

For issues or questions:
1. Check the [deployment guide](deployment-guide.md) troubleshooting section
2. Review NGINX Gateway Fabric logs: `kubectl logs -n nginx-gateway -l app.kubernetes.io/name=nginx-gateway-fabric`
3. Check Gateway status: `kubectl describe gateway my-gateway -n nginx-gateway`
