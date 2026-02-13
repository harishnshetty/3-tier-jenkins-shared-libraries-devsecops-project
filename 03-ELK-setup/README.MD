# ELK Setup

## 1. install the helm repo
```bash
helm repo add elastic https://helm.elastic.co
helm repo update

helm search repo elastic/elasticsearch

kubectl create namespace elk
```

## 1.1 install the elasticsearch

```bash
helm show values elastic/elasticsearch > elasticsearch-values.yaml
```
## 1.2 Install Elasticsearch (Version 8.5.1)
```bash
helm install elasticsearch elastic/elasticsearch -f elasticsearch-values.yaml -n elk --create-namespace --version 8.5.1
```

## 1.3 Wait for pods to be ready
```bash
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n elk --timeout=300s
```

## 1.4 Retrieve Password
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

## 2. Kibana install
```bash
helm search repo elastic/kibana
```
## 2.1 show the values
```bash
helm show values elastic/kibana > kibana-values.yaml
```
## 2.2 install the kibana
```bash
helm install kibana elastic/kibana -n elk -f 02-kibana-values.yaml --version 8.5.1
```

## 2.3 uninstall the kibana
```bash
helm uninstall kibana elastic/kibana -n elk
```

```bash
1. Watch all containers come up.
  $ kubectl get pods --namespace=elk -l release=kibana -w
2. Retrieve the elastic user's password.
  $ kubectl get secrets --namespace=elk elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
3. Retrieve the kibana service account token.
  $ kubectl get secrets --namespace=elk kibana-kibana-es-token -ojsonpath='{.data.token}' | base64 -d
```

## 3. Logstash & Filebeat
Install Logstash and Filebeat:

## 3.1 show the values
```bash
helm show values elastic/logstash > logstash-values.yaml
helm show values elastic/filebeat > filebeat-values.yaml
```
## 3.2 install the logstash and filebeat
```bash
helm install logstash elastic/logstash -n elk -f logstash-values.yaml --version 8.5.1
helm install filebeat elastic/filebeat -n elk -f filebeat-values.yaml --version 8.5.1
```
## 3.3 uninstall the logstash and filebeat
```bash
helm uninstall logstash elastic/logstash -n elk
helm uninstall filebeat elastic/filebeat -n elk
```

## 6. Access & Monitoring
Apply the ReferenceGrant and HTTPRoute to expose Kibana:
```bash
kubectl apply -f 05-http.yaml
kubectl apply -f 06-elk-referencegrant.yaml

```
```bash
Access Kibana at: `https://kibana.harishshetty.xyz`
Login with user: `elastic` and the password retrieved from Step 2.3
dont change the elastic password if you want to use the same password for all the services or update the password in all secrets elk-master-credentials
```

## 7. Uninstall
```bash
helm uninstall filebeat -n elk
helm uninstall logstash -n elk
helm uninstall kibana -n elk
helm uninstall elasticsearch -n elk
```