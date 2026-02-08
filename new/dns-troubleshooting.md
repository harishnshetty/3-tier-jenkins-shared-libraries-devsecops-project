# DNS Troubleshooting Guide for ArgoCD Access

## Problem Identified

✅ **Gateway is working correctly**  
✅ **HTTPRoute is configured properly**  
✅ **TLS certificate is ready**  
✅ **HTTP to HTTPS redirect is working**  

❌ **DNS is NOT resolving** - `argocd.harishshetty.xyz` returns NXDOMAIN

## Test Results

### Direct NLB Test (Working)
```bash
curl -I -H "Host: argocd.harishshetty.xyz" http://k8s-nginxgat-mygatewa-61b257a5a3-a846ff32907655a1.elb.ap-south-1.amazonaws.com
```
**Result:** HTTP/1.1 301 Moved Permanently → Redirects to HTTPS ✅

### DNS Resolution Test (Failing)
```bash
nslookup argocd.harishshetty.xyz
```
**Result:** NXDOMAIN (domain not found) ❌

## Solution: Fix Route53 DNS Records

### Step 1: Verify Hosted Zone

```bash
aws route53 list-hosted-zones --query "HostedZones[?Name=='harishshetty.xyz.'].{Id:Id,Name:Name}"
```

### Step 2: Get NLB Information

```bash
# NLB DNS Name
NLB_DNS="k8s-nginxgat-mygatewa-61b257a5a3-a846ff32907655a1.elb.ap-south-1.amazonaws.com"

# Get NLB Hosted Zone ID
NLB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='$NLB_DNS'].CanonicalHostedZoneId" \
  --output text)

echo "NLB Zone ID: $NLB_ZONE_ID"
```

### Step 3: Get Your Route53 Hosted Zone ID

```bash
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name harishshetty.xyz \
  --query "HostedZones[0].Id" \
  --output text | cut -d'/' -f3)

echo "Hosted Zone ID: $HOSTED_ZONE_ID"
```

### Step 4: Create Route53 A Record (Alias)

Create a file `route53-argocd.json`:

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
          "DNSName": "k8s-nginxgat-mygatewa-61b257a5a3-a846ff32907655a1.elb.ap-south-1.amazonaws.com",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
```

### Step 5: Apply the DNS Record

```bash
# Replace placeholders
sed -i "s/REPLACE_WITH_NLB_ZONE_ID/$NLB_ZONE_ID/g" route53-argocd.json

# Apply the change
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://route53-argocd.json
```

### Step 6: Verify DNS Propagation

```bash
# Wait 30-60 seconds, then test
dig argocd.harishshetty.xyz +short

# Should return the NLB IP addresses
```

## Alternative: Using AWS Console

1. Go to **Route53** → **Hosted zones**
2. Click on **harishshetty.xyz**
3. Click **Create record**
4. Configure:
   - **Record name:** `argocd`
   - **Record type:** `A - Routes traffic to an IPv4 address`
   - **Alias:** Toggle ON
   - **Route traffic to:** 
     - Choose: **Alias to Application and Classic Load Balancer**
     - Region: **ap-south-1**
     - Load balancer: Select the NLB (starts with `k8s-nginxgat-mygatewa`)
   - **Evaluate target health:** Yes
5. Click **Create records**

## Verification After DNS Fix

### 1. Test DNS Resolution
```bash
nslookup argocd.harishshetty.xyz
# Should return NLB IP addresses
```

### 2. Test HTTP Redirect
```bash
curl -I http://argocd.harishshetty.xyz
# Should return: HTTP/1.1 301 Moved Permanently
# Location: https://argocd.harishshetty.xyz/
```

### 3. Test HTTPS Access
```bash
curl -v https://argocd.harishshetty.xyz
# Should return ArgoCD login page
```

### 4. Test in Browser
Open: `https://argocd.harishshetty.xyz`

You should see the ArgoCD login page with a valid TLS certificate.

## Common Issues

### Issue: DNS Still Not Resolving After Creating Record

**Causes:**
- DNS propagation delay (wait 1-2 minutes)
- Wrong hosted zone
- Typo in record name
- Record type is CNAME instead of A (Alias)

**Solution:**
```bash
# Check if record exists
aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --query "ResourceRecordSets[?Name=='argocd.harishshetty.xyz.']"
```

### Issue: Certificate Error in Browser

**Cause:** Certificate might not be fully propagated to Gateway

**Solution:**
```bash
# Check certificate status
kubectl get certificate harishshetty-tls -n nginx-gateway

# Check Gateway listener status
kubectl describe gateway my-gateway -n nginx-gateway | grep -A 20 "https"
```

### Issue: 502 Bad Gateway

**Cause:** ArgoCD service not ready

**Solution:**
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD service
kubectl get svc argocd-server -n argocd
```

## Quick Test Without DNS

If you want to test immediately without waiting for DNS:

```bash
# Add to /etc/hosts (requires sudo)
echo "$(dig k8s-nginxgat-mygatewa-61b257a5a3-a846ff32907655a1.elb.ap-south-1.amazonaws.com +short | head -1) argocd.harishshetty.xyz" | sudo tee -a /etc/hosts

# Then test in browser
# https://argocd.harishshetty.xyz
```

**Remember to remove this entry after DNS is working!**

## Summary

The Gateway API setup is working perfectly. The only issue is DNS configuration. Once you create the proper A (Alias) record in Route53 pointing to the NLB, everything will work.

**NLB DNS:** `k8s-nginxgat-mygatewa-61b257a5a3-a846ff32907655a1.elb.ap-south-1.amazonaws.com`

Create the same DNS records for:
- grafana.harishshetty.xyz
- app1.harishshetty.xyz
- app2.harishshetty.xyz
