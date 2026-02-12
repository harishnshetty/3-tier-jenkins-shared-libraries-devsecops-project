helm repo add elastic https://helm.elastic.co
helm repo update

# ELK Stack Setup (Secured)

## Prerequisites
- Cert Manager installed
- Gateway API installed
- Namespace `elk` created: `kubectl create namespace elk`

<!-- ## 1. Certificates
Apply the PKI configuration (Updated to use secret `elk-tls-certs`):
```bash
kubectl apply -f elk-pki.yaml
``` -->
<!-- Verify certificates are ready:
```bash
kubectl get certificates -n elk
``` -->

## 2. Elasticsearch
**Note:** If previous install failed, run `helm uninstall elasticsearch -n elk` first.

helm show values elastic/elasticsearch > elasticsearch-values.yaml
Install Elasticsearch (Version 8.5.1, using `elk-tls-certs`):
```bash
helm search repo elastic/elasticsearch
```
helm show values elastic/elasticsearch > elasticsearch-values1.yaml
```bash
helm install elasticsearch elastic/elasticsearch -n elk -f elasticsearch-values.yaml --version 8.5.1
```

**Wait for pods to be ready:**
```bash
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n elk --timeout=300s
```

## 3. Retrieve Password
Retrieve the auto-generated password for the `elastic` user:
```bash
NOTES:
1. Watch all cluster members come up.
  $ kubectl get pods --namespace=elk -l app=elasticsearch-master -w
2. Retrieve elastic user's password.
  $ kubectl get secrets --namespace=elk elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
3. Test cluster health using Helm test.
  $ helm --namespace=elk test elasticsearch
```

## 4. Kibana
Install Kibana (configured to use the secret):
```bash
helm search repo elastic/kibana
```

helm show values elastic/kibana > kibana-values1.yaml
```bash
helm install kibana elastic/kibana -n elk -f kibana-values.yaml --version 8.5.1
```
helm uninstall kibana elastic/kibana -n elk

```bash
1. Watch all containers come up.
  $ kubectl get pods --namespace=elk -l release=kibana -w
2. Retrieve the elastic user's password.
  $ kubectl get secrets --namespace=elk elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
3. Retrieve the kibana service account token.
  $ kubectl get secrets --namespace=elk kibana-kibana-es-token -ojsonpath='{.data.token}' | base64 -d
```

## 5. Logstash & Filebeat
Install Logstash and Filebeat:


helm show values elastic/logstash > logstash-values1.yaml
helm show values elastic/filebeat > filebeat-values1.yaml
```bash
helm install logstash elastic/logstash -n elk -f logstash-values.yaml --version 8.5.1
helm install filebeat elastic/filebeat -n elk -f filebeat-values.yaml --version 8.5.1
```

## 6. Access & Monitoring
Apply the ReferenceGrant and HTTPRoute to expose Kibana:
```bash
kubectl apply -f elk-referencegrant.yaml
kubectl apply -f http.yaml
```

Access Kibana at: `https://kibana.harishshetty.xyz`
Login with user: `elastic` and the password retrieved in Step 3.

## Uninstall
```bash
helm uninstall filebeat -n elk
helm uninstall logstash -n elk
helm uninstall kibana -n elk
helm uninstall elasticsearch -n elk
```
