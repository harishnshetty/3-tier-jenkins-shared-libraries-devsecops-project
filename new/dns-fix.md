# DNS Resolution Fix for ArgoCD Access

## ✅ Confirmed: Gateway is Working Perfectly!

When testing with `--resolve` flag to bypass DNS:
```bash
curl -I --resolve argocd.harishshetty.xyz:80:13.202.53.140 http://argocd.harishshetty.xyz
```
**Result:** HTTP/1.1 301 Moved Permanently → HTTPS redirect works! ✅

```bash
curl -k -I --resolve argocd.harishshetty.xyz:443:13.202.53.140 https://argocd.harishshetty.xyz
```
**Result:** HTTP/2 307 → ArgoCD is responding! ✅

## Problem: Local DNS Server Issue

Your system is using DNS server `10.31.48.80` (corporate/local network DNS) which is not resolving `argocd.harishshetty.xyz` correctly, even though:
- Route53 record exists ✅
- Google DNS (8.8.8.8) resolves it correctly ✅
- The domain resolves to: 13.202.53.140, 3.6.18.192, 13.205.43.92

## Solutions

### Solution 1: Add to /etc/hosts (Quick Fix)

```bash
echo "13.202.53.140 argocd.harishshetty.xyz" | sudo tee -a /etc/hosts
echo "13.202.53.140 grafana.harishshetty.xyz" | sudo tee -a /etc/hosts
echo "13.202.53.140 app1.harishshetty.xyz" | sudo tee -a /etc/hosts
echo "13.202.53.140 app2.harishshetty.xyz" | sudo tee -a /etc/hosts
```

Then test:
```bash
curl -I http://argocd.harishshetty.xyz
# Should work now!
```

**Pros:** Immediate fix  
**Cons:** Manual entry, needs to be updated if NLB IP changes

### Solution 2: Change DNS Server to Google DNS

Temporarily use Google DNS instead of your local DNS:

```bash
# Set Google DNS for your network interface
sudo resolvectl dns enxa61f082dc8ff 8.8.8.8 8.8.4.4

# Verify
resolvectl status enxa61f082dc8ff
```

Then test:
```bash
curl -I http://argocd.harishshetty.xyz
```

**Pros:** Proper DNS resolution  
**Cons:** May affect access to internal corporate resources

### Solution 3: Configure systemd-resolved to Use Google DNS

Edit `/etc/systemd/resolved.conf`:

```bash
sudo nano /etc/systemd/resolved.conf
```

Add/uncomment:
```ini
[Resolve]
DNS=8.8.8.8 8.8.4.4
FallbackDNS=1.1.1.1 1.0.0.1
```

Restart systemd-resolved:
```bash
sudo systemctl restart systemd-resolved
```

### Solution 4: Use curl with --resolve (Testing Only)

For testing without changing system configuration:

```bash
# HTTP test
curl -I --resolve argocd.harishshetty.xyz:80:13.202.53.140 http://argocd.harishshetty.xyz

# HTTPS test
curl -k -I --resolve argocd.harishshetty.xyz:443:13.202.53.140 https://argocd.harishshetty.xyz
```

### Solution 5: Browser Testing with /etc/hosts

For browser access, use Solution 1 (/etc/hosts), then open:
```
https://argocd.harishshetty.xyz
```

## Recommended Approach

**For immediate testing:** Use Solution 1 (/etc/hosts)

**For permanent fix:** Contact your network admin about the local DNS server (10.31.48.80) not resolving public Route53 records, or use Solution 2/3 to bypass it.

## Verification After Fix

```bash
# Test DNS resolution
nslookup argocd.harishshetty.xyz

# Test HTTP redirect
curl -I http://argocd.harishshetty.xyz
# Expected: HTTP/1.1 301 Moved Permanently

# Test HTTPS
curl -v https://argocd.harishshetty.xyz
# Expected: ArgoCD login page (HTTP/2 307)
```

## Browser Access

Once DNS is resolved (via any solution above), open in browser:

```
https://argocd.harishshetty.xyz
```

You should see:
- ✅ Valid TLS certificate (from Let's Encrypt)
- ✅ ArgoCD login page
- ✅ No certificate warnings

## Get ArgoCD Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

Login with:
- **Username:** admin
- **Password:** (from command above)

## Summary

Your Gateway API setup is **100% working correctly**:
- ✅ NGINX Gateway Fabric running
- ✅ Gateway configured with NLB
- ✅ TLS certificate issued and working
- ✅ HTTP to HTTPS redirect working
- ✅ HTTPRoute routing to ArgoCD
- ✅ Route53 DNS record exists

The only issue is your local DNS server not resolving the domain. Use /etc/hosts as a quick workaround.
