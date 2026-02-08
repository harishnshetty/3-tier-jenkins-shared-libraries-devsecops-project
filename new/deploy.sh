#!/bin/bash
# Gateway API Deployment Script
# This script automates the deployment of NGINX Gateway Fabric with Gateway API

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Gateway API Deployment Script ===${NC}\n"

# Change to project directory
cd "$(dirname "$0")/.."
PROJECT_DIR=$(pwd)

echo -e "${YELLOW}Step 1: Verifying prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Check helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}helm not found. Please install helm.${NC}"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot connect to Kubernetes cluster. Please configure kubectl.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites verified${NC}\n"

echo -e "${YELLOW}Step 2: Getting cert-manager IAM role ARN...${NC}"

# Get cert-manager role ARN from Terraform
if [ -f "cert-manager-irsa.tf" ]; then
    CERT_MANAGER_ROLE_ARN=$(terraform output -raw cert_manager_role_arn 2>/dev/null || echo "")
    if [ -z "$CERT_MANAGER_ROLE_ARN" ]; then
        echo -e "${RED}Could not get cert-manager role ARN from Terraform.${NC}"
        echo -e "${YELLOW}Please run 'terraform apply' first or manually update new/cert-manager-serviceaccount.yaml${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Got cert-manager role ARN: $CERT_MANAGER_ROLE_ARN${NC}\n"
else
    echo -e "${RED}cert-manager-irsa.tf not found. Please ensure you're in the correct directory.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 3: Updating cert-manager ServiceAccount...${NC}"

# Update ServiceAccount with actual role ARN
sed -i "s|arn:aws:iam::<ACCOUNT_ID>:role/cert-manager-iam-role|$CERT_MANAGER_ROLE_ARN|g" \
  new/cert-manager-serviceaccount.yaml

kubectl apply -f new/cert-manager-serviceaccount.yaml

# Restart cert-manager to pick up new annotation
kubectl rollout restart deployment cert-manager -n cert-manager
echo -e "${GREEN}✓ cert-manager ServiceAccount updated${NC}\n"

echo -e "${YELLOW}Step 4: Installing Gateway API CRDs...${NC}"

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

echo -e "${GREEN}✓ Gateway API CRDs installed${NC}\n"

echo -e "${YELLOW}Step 5: Creating nginx-gateway namespace...${NC}"

kubectl create namespace nginx-gateway --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Namespace created${NC}\n"

echo -e "${YELLOW}Step 6: Installing NGINX Gateway Fabric...${NC}"

helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --values new/nginx-gateway-fabric-helm-values.yaml

echo -e "${GREEN}✓ NGINX Gateway Fabric installed${NC}\n"

echo -e "${YELLOW}Step 7: Waiting for NGINX Gateway Fabric pods to be ready...${NC}"

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=nginx-gateway-fabric \
  -n nginx-gateway \
  --timeout=300s || echo -e "${YELLOW}Warning: Pods may still be starting${NC}"

echo -e "${GREEN}✓ NGINX Gateway Fabric pods ready${NC}\n"

echo -e "${YELLOW}Step 8: Applying Gateway API resources...${NC}"

cd gatewayapi-nginx-fabric

kubectl apply -f gatewayclass.yaml
echo "  ✓ GatewayClass applied"

kubectl apply -f clusterissuer.yaml
echo "  ✓ ClusterIssuer applied"

kubectl apply -f certificate.yaml
echo "  ✓ Certificate applied"

kubectl apply -f gateway.yaml
echo "  ✓ Gateway applied"

echo -e "${GREEN}✓ Gateway API resources applied${NC}\n"

echo -e "${YELLOW}Step 9: Creating required namespaces for ReferenceGrants...${NC}"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Namespaces created${NC}\n"

echo -e "${YELLOW}Step 10: Applying ReferenceGrants...${NC}"

kubectl apply -f referencegrant.yaml

echo -e "${GREEN}✓ ReferenceGrants applied${NC}\n"

echo -e "${YELLOW}Step 11: Applying HTTPRoutes...${NC}"

kubectl apply -f HTTP-redirect.yaml
echo "  ✓ HTTP redirect applied"

kubectl apply -f routes.yaml
echo "  ✓ Service routes applied"

echo -e "${GREEN}✓ HTTPRoutes applied${NC}\n"

echo -e "${YELLOW}Step 12: Waiting for Gateway to be ready...${NC}"

echo "This may take a few minutes while AWS provisions the NLB..."

kubectl wait --for=condition=Programmed gateway/my-gateway \
  -n nginx-gateway \
  --timeout=600s || echo -e "${YELLOW}Warning: Gateway may still be provisioning${NC}"

echo -e "${GREEN}✓ Gateway ready${NC}\n"

echo -e "${YELLOW}Step 13: Getting NLB DNS name...${NC}"

sleep 10  # Wait for service to be fully updated

NLB_DNS=$(kubectl get svc -n nginx-gateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$NLB_DNS" ]; then
    echo -e "${YELLOW}NLB DNS not yet available. Check status with:${NC}"
    echo "  kubectl get svc -n nginx-gateway"
else
    echo -e "${GREEN}✓ NLB DNS: $NLB_DNS${NC}\n"
    
    echo -e "${YELLOW}Step 14: Next steps for DNS configuration:${NC}"
    echo ""
    echo "1. Get the NLB Hosted Zone ID:"
    echo "   NLB_ZONE_ID=\$(aws elbv2 describe-load-balancers \\"
    echo "     --query \"LoadBalancers[?DNSName=='$NLB_DNS'].CanonicalHostedZoneId\" \\"
    echo "     --output text)"
    echo ""
    echo "2. Create Route53 A records (alias) for:"
    echo "   - argocd.harishshetty.xyz"
    echo "   - grafana.harishshetty.xyz"
    echo "   - app1.harishshetty.xyz"
    echo "   - app2.harishshetty.xyz"
    echo ""
    echo "See new/deployment-guide.md for detailed DNS configuration instructions."
fi

echo ""
echo -e "${GREEN}=== Deployment Complete! ===${NC}\n"

echo -e "${YELLOW}Verification commands:${NC}"
echo "  kubectl get gateway my-gateway -n nginx-gateway"
echo "  kubectl get httproute -n nginx-gateway"
echo "  kubectl get certificate harishshetty-tls -n nginx-gateway"
echo "  kubectl get pods -n nginx-gateway"
echo ""
echo -e "${YELLOW}For troubleshooting, see: new/deployment-guide.md${NC}"
