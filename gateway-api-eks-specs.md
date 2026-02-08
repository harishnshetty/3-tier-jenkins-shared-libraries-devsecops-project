# Technical Specification: Gateway API on AWS EKS with NGINX Gateway Fabric

**Version:** 1.0  
**Date:** February 8, 2026  
**Status:** Draft

## 1. Executive Summary

This document provides technical specifications for implementing Kubernetes Gateway API using NGINX Gateway Fabric on Amazon Elastic Kubernetes Service (EKS). The solution enables standardized, role-oriented API gateway functionality with advanced traffic management capabilities.

## 2. System Overview

### 2.1 Purpose
Deploy NGINX Gateway Fabric as the Gateway API implementation on AWS EKS to provide:
- Ingress traffic management using Gateway API standards
- Advanced routing capabilities (HTTP, HTTPS, TLS termination)
- Service mesh integration readiness
- Multi-tenancy support through namespace-scoped routing

### 2.2 Scope
- EKS cluster configuration for Gateway API
- NGINX Gateway Fabric installation and configuration
- Gateway and HTTPRoute resource definitions
- TLS/SSL certificate management
- AWS integration (Load Balancer, Route53)

## 3. Architecture

### 3.1 Component Architecture

```
Internet
    ↓
AWS Network Load Balancer (NLB)
    ↓
NGINX Gateway Fabric (Gateway Controller)
    ↓
Gateway API Resources (Gateway, HTTPRoute)
    ↓
Kubernetes Services
    ↓
Application Pods
```

### 3.2 Key Components

| Component | Description | Version |
|-----------|-------------|---------|
| AWS EKS | Managed Kubernetes cluster | 1.28+ |
| NGINX Gateway Fabric | Gateway API implementation | 1.1.0+ |
| Gateway API CRDs | Kubernetes Gateway API resources | v1.0.0 |
| AWS Load Balancer Controller | AWS NLB/ALB integration | 2.7.0+ |
| cert-manager | Certificate management | 1.13.0+ |

## 4. Prerequisites

### 4.1 AWS Infrastructure
- **EKS Cluster**: Running cluster with version 1.28 or higher
- **Node Groups**: Minimum 3 nodes across multiple AZs
- **Instance Type**: t3.medium or larger (2 vCPU, 4GB RAM minimum)
- **VPC**: Configured with public and private subnets
- **IAM Roles**: 
  - EKS cluster role with required policies
  - Node group role with ECR, ELB, and EC2 permissions
  - AWS Load Balancer Controller IAM role

### 4.2 Kubernetes Requirements
- kubectl v1.28+
- Helm 3.12+
- Kubernetes RBAC enabled
- StorageClass configured for persistent volumes

### 4.3 AWS Services
- AWS Load Balancer Controller installed
- Amazon Route53 (for DNS management)
- AWS Certificate Manager or cert-manager for TLS certificates
- VPC CNI plugin configured

## 5. Installation Specifications

### 5.1 Gateway API CRDs Installation

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

**Validation:**
```bash
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get crd httproutes.gateway.networking.k8s.io
```

### 5.2 NGINX Gateway Fabric Installation

**Method: Helm Chart**

```bash
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update

helm install ngf nginx-stable/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --create-namespace \
  --set nginxGateway.gwAPIExperimentalFeatures.enable=true \
  --set service.type=LoadBalancer \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true"
```

**Configuration Parameters:**

| Parameter | Value | Description |
|-----------|-------|-------------|
| `service.type` | LoadBalancer | Expose via AWS NLB |
| `service.annotations` | aws-load-balancer-type: nlb | Use Network Load Balancer |
| `replicaCount` | 3 | High availability |
| `resources.requests.cpu` | 100m | Minimum CPU |
| `resources.requests.memory` | 128Mi | Minimum memory |
| `resources.limits.cpu` | 1000m | Maximum CPU |
| `resources.limits.memory` | 512Mi | Maximum memory |

### 5.3 AWS Load Balancer Controller Setup

**Prerequisites:**
- IAM OIDC provider configured on EKS cluster
- IAM policy for AWS Load Balancer Controller

```bash
# Create IAM policy
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json

# Install controller via Helm
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<iam-role-arn>
```

## 6. Configuration Specifications

### 6.1 Gateway Resource Definition

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: gateway.nginx.org/nginx-gateway-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: nginx-gateway
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    protocol: HTTPS
    port: 443
    allowedRoutes:
      namespaces:
        from: All
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: gateway-tls-cert
        namespace: nginx-gateway
```

### 6.2 HTTPRoute Configuration

**Example Route:**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: api-route
  namespace: default
spec:
  parentRefs:
  - name: main-gateway
    namespace: nginx-gateway
    sectionName: https
  hostnames:
  - "api.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /v1
    backendRefs:
    - name: api-service-v1
      port: 8080
  - matches:
    - path:
        type: PathPrefix
        value: /v2
    backendRefs:
    - name: api-service-v2
      port: 8080
```

### 6.3 TLS Certificate Management

**Option 1: AWS Certificate Manager (ACM)**
- Certificates managed in ACM
- Annotation-based attachment to NLB
- Automatic renewal

**Option 2: cert-manager with Let's Encrypt**

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gateway-tls-cert
  namespace: nginx-gateway
spec:
  secretName: gateway-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "*.example.com"
  - "example.com"
```

## 7. Network Configuration

### 7.1 AWS Security Groups

**Gateway Controller Security Group:**
- Inbound: 80/TCP from Internet (0.0.0.0/0)
- Inbound: 443/TCP from Internet (0.0.0.0/0)
- Inbound: Health check ports from NLB subnets
- Outbound: All traffic

**Node Security Group:**
- Inbound: NodePort range (30000-32767) from Gateway Controller SG
- Inbound: Pod-to-pod communication within cluster CIDR

### 7.2 Network Load Balancer Configuration

```yaml
service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "http"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "8081"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
```

### 7.3 Route53 DNS Configuration

```bash
# Get NLB DNS name
NLB_DNS=$(kubectl get svc -n nginx-gateway ngf-nginx-gateway-fabric \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create Route53 alias record
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "<nlb-zone-id>",
          "DNSName": "'"$NLB_DNS"'",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'
```

## 8. Security Specifications

### 8.1 RBAC Configuration

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx-gateway-fabric
  namespace: nginx-gateway
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: nginx-gateway-fabric
rules:
- apiGroups: ["gateway.networking.k8s.io"]
  resources: ["gateways", "httproutes", "gatewayclasses"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: [""]
  resources: ["services", "endpoints", "secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: nginx-gateway-fabric
subjects:
- kind: ServiceAccount
  name: nginx-gateway-fabric
  namespace: nginx-gateway
roleRef:
  kind: ClusterRole
  name: nginx-gateway-fabric
  apiGroup: rbac.authorization.k8s.io
```

### 8.2 Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nginx-gateway
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 8.3 Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nginx-gateway-policy
  namespace: nginx-gateway
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: nginx-gateway-fabric
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 8080
```

## 9. Monitoring and Observability

### 9.1 Prometheus Metrics

NGINX Gateway Fabric exposes metrics at `:9113/metrics`

**Key Metrics:**
- `nginx_gateway_nginx_reloads_total` - Configuration reloads
- `nginx_gateway_nginx_reload_errors_total` - Reload failures
- `nginx_http_requests_total` - HTTP request count
- `nginx_http_request_duration_seconds` - Request latency

**ServiceMonitor Configuration:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx-gateway-fabric
  namespace: nginx-gateway
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: nginx-gateway-fabric
  endpoints:
  - port: metrics
    interval: 30s
```

### 9.2 CloudWatch Integration

```yaml
# FluentBit configuration for log shipping
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: nginx-gateway
data:
  output.conf: |
    [OUTPUT]
        Name cloudwatch_logs
        Match *
        region us-east-1
        log_group_name /aws/eks/nginx-gateway
        log_stream_prefix nginx-
        auto_create_group true
```

### 9.3 Health Checks

**Liveness Probe:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8081
  initialDelaySeconds: 30
  periodSeconds: 10
```

**Readiness Probe:**
```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8081
  initialDelaySeconds: 10
  periodSeconds: 5
```

## 10. High Availability and Scaling

### 10.1 Replica Configuration

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
```

### 10.2 Pod Disruption Budget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nginx-gateway-pdb
  namespace: nginx-gateway
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: nginx-gateway-fabric
```

### 10.3 Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-gateway-hpa
  namespace: nginx-gateway
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-gateway-fabric
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 10.4 Multi-AZ Deployment

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values:
          - nginx-gateway-fabric
      topologyKey: topology.kubernetes.io/zone
```

## 11. Disaster Recovery

### 11.1 Backup Strategy

**Configuration Backup:**
```bash
# Backup Gateway API resources
kubectl get gateways,httproutes -A -o yaml > gateway-backup.yaml

# Backup NGINX Gateway Fabric configuration
helm get values ngf -n nginx-gateway > ngf-values-backup.yaml
```

### 11.2 Recovery Procedures

**Gateway Restoration:**
1. Reinstall NGINX Gateway Fabric via Helm
2. Apply backed-up Gateway API resources
3. Verify DNS propagation
4. Validate routing functionality

**RTO/RPO Targets:**
- **RTO**: < 15 minutes
- **RPO**: < 5 minutes

## 12. Testing and Validation

### 12.1 Smoke Tests

```bash
# Verify Gateway status
kubectl get gateway main-gateway -n nginx-gateway

# Check NLB creation
kubectl get svc -n nginx-gateway

# Test HTTP routing
curl -H "Host: api.example.com" http://<nlb-dns>/v1/health

# Test HTTPS routing
curl https://api.example.com/v1/health
```

### 12.2 Load Testing

```bash
# Using Apache Bench
ab -n 10000 -c 100 https://api.example.com/v1/health

# Using K6
k6 run --vus 100 --duration 30s load-test.js
```

### 12.3 Failover Testing

```bash
# Simulate pod failure
kubectl delete pod -n nginx-gateway -l app.kubernetes.io/name=nginx-gateway-fabric

# Verify automatic recovery
kubectl get pods -n nginx-gateway -w
```

## 13. Operational Procedures

### 13.1 Deployment Process

1. **Pre-deployment Validation**
   - Review YAML manifests
   - Validate in staging environment
   - Backup existing configurations

2. **Deployment Steps**
   - Apply Gateway API CRDs
   - Install NGINX Gateway Fabric via Helm
   - Create Gateway resources
   - Deploy HTTPRoute configurations
   - Configure TLS certificates
   - Update DNS records

3. **Post-deployment Validation**
   - Execute smoke tests
   - Monitor metrics and logs
   - Verify SSL/TLS certificates
   - Conduct load testing

### 13.2 Update Strategy

```bash
# Update NGINX Gateway Fabric
helm upgrade ngf nginx-stable/nginx-gateway-fabric \
  -n nginx-gateway \
  --reuse-values \
  --version <new-version>

# Monitor rollout
kubectl rollout status deployment/nginx-gateway-fabric -n nginx-gateway
```

### 13.3 Rollback Procedures

```bash
# Helm rollback
helm rollback ngf -n nginx-gateway

# Verify previous version
helm history ngf -n nginx-gateway
```

## 14. Troubleshooting

### 14.1 Common Issues

| Issue | Symptoms | Resolution |
|-------|----------|------------|
| Gateway not ready | Gateway status shows Pending | Check controller logs, verify CRDs installed |
| 502 Bad Gateway | HTTP 502 responses | Verify backend service health, check service endpoints |
| TLS handshake failures | SSL certificate errors | Validate certificate, check secret in correct namespace |
| NLB not created | Service LoadBalancer pending | Check AWS LB Controller logs, verify IAM permissions |

### 14.2 Debug Commands

```bash
# Check Gateway status
kubectl describe gateway main-gateway -n nginx-gateway

# View controller logs
kubectl logs -n nginx-gateway -l app.kubernetes.io/name=nginx-gateway-fabric

# Inspect HTTPRoute
kubectl describe httproute api-route -n default

# Check service endpoints
kubectl get endpoints -n default

# View events
kubectl get events -n nginx-gateway --sort-by='.lastTimestamp'
```

## 15. Cost Optimization

### 15.1 Resource Sizing

- Start with 3 replicas using t3.medium instances
- Monitor actual usage for 2 weeks
- Right-size based on observed metrics
- Use Spot instances for non-production environments

### 15.2 NLB Optimization

- Enable cross-zone load balancing to reduce data transfer costs
- Use single NLB for multiple services via path-based routing
- Consider ALB if Layer 7 features reduce backend complexity

## 16. Compliance and Governance

### 16.1 Audit Logging

Enable Kubernetes audit logging for Gateway API resources:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  resources:
  - group: gateway.networking.k8s.io
    resources: ["gateways", "httproutes"]
```

### 16.2 Access Control

- Limit Gateway creation to platform team
- Allow developers to create HTTPRoutes in their namespaces
- Use namespace-scoped RoleBindings for HTTPRoute management

## 17. Maintenance Windows

### 17.1 Scheduled Maintenance

- **Frequency**: Monthly
- **Window**: Sunday 2:00-4:00 AM UTC
- **Activities**: 
  - Security patching
  - Version upgrades
  - Certificate renewal
  - Configuration audits

## 18. Dependencies

### 18.1 External Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Kubernetes | 1.28+ | Container orchestration |
| Helm | 3.12+ | Package management |
| AWS CLI | 2.x | AWS resource management |
| kubectl | 1.28+ | Kubernetes CLI |

### 18.2 AWS Service Dependencies

- EKS (control plane)
- EC2 (worker nodes)
- VPC (networking)
- ELB (load balancing)
- Route53 (DNS)
- IAM (authentication/authorization)
- CloudWatch (monitoring)

## 19. Documentation and Training

### 19.1 Reference Documentation

- [NGINX Gateway Fabric Official Docs](https://docs.nginx.com/nginx-gateway-fabric/)
- [Kubernetes Gateway API Spec](https://gateway-api.sigs.k8s.io/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

### 19.2 Runbooks

Required runbooks:
- Gateway deployment procedure
- HTTPRoute creation and validation
- Certificate renewal process
- Incident response for gateway failures
- Scaling procedures

## 20. Success Criteria

### 20.1 Performance Targets

- **Latency**: P95 < 100ms for API requests
- **Throughput**: > 10,000 requests/second
- **Availability**: 99.9% uptime
- **Time to Deploy**: < 30 minutes for new routes

### 20.2 Acceptance Criteria

- ✓ Gateway API resources successfully deployed
- ✓ NGINX Gateway Fabric operational with 3 replicas
- ✓ TLS termination functional with valid certificates
- ✓ HTTPRoutes routing to backend services
- ✓ Monitoring and alerting configured
- ✓ Load testing passed with target metrics
- ✓ Failover testing validated
- ✓ Documentation complete

## 21. Appendices

### Appendix A: Sample Values File

```yaml
# values.yaml for NGINX Gateway Fabric
nginxGateway:
  gwAPIExperimentalFeatures:
    enable: true
  
replicaCount: 3

image:
  repository: ghcr.io/nginxinc/nginx-gateway-fabric
  tag: 1.1.0
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 1000m
    memory: 512Mi

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values:
          - nginx-gateway-fabric
      topologyKey: topology.kubernetes.io/zone
```

### Appendix B: Deployment Checklist

- [ ] EKS cluster created and accessible
- [ ] VPC and subnets configured
- [ ] IAM roles and policies created
- [ ] AWS Load Balancer Controller installed
- [ ] Gateway API CRDs installed
- [ ] NGINX Gateway Fabric deployed
- [ ] Gateway resource created
- [ ] TLS certificates configured
- [ ] HTTPRoutes deployed
- [ ] DNS records created
- [ ] Monitoring configured
- [ ] Smoke tests passed
- [ ] Load tests passed
- [ ] Documentation updated
- [ ] Team trained

---

**Document Control**
- **Author**: Technical Architecture Team
- **Reviewers**: Platform Engineering, Security Team
- **Approval**: Engineering Lead
- **Next Review**: Quarterly