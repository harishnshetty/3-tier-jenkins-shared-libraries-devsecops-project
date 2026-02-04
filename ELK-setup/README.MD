kubectl get pods -l app=filebeat
kubectl logs -l app=filebeat
Connected to Elasticsearch

✅ Step 8: View logs in Kibana

Open Kibana UI

Go to Stack Management → Index Patterns

Create index:

filebeat-*


Go to Discover

Filter:

kubernetes.container.name: frontend

kubernetes.pod.name: frontend-depo-*

🎉 You’ll now see all Nginx access + error logs from all replicas.

```bash
helm repo add elastic https://helm.elastic.co
helm repo update
helm search repo elastic/elasticsearch
helm search repo elastic/kibana
helm search repo elastic/filebeat
helm install elasticsearch elastic/elasticsearch -n elk --create-namespace
helm install kibana elastic/kibana -n elk
helm install filebeat elastic/filebeat -n elk

helm repo add elastic https://helm.elastic.co
helm repo update
# helm install elastic-operator elastic/eck-operator -n elastic-system --create-namespace
helm install elasticsearch elastic/elasticsearch -f elasticsearch-values.yaml -n elk --create-namespace


helm install filebeat elastic/filebeat -f filebeat-values.yaml -n elk

helm install logstash elastic/logstash -f logstash-values.yaml -n elk

helm install kibana elastic/kibana -f kibana-values.yaml -n elk


## find the kibana port
kubectl get svc kibana-kibana -n elk -o jsonpath="{.spec.ports[0].nodePort}"


## find the elasticsearch username and password
kubectl get secret elasticsearch-master-credentials -o jsonpath="{.data.username}" | base64 --decode

kubectl get secret elasticsearch-master-credentials -o jsonpath="{.data.password}" | base64 --decode


## check the connectivity
kubectl exec -it elasticsearch-master-0 -- curl -XGET -u elastic -vk 'https://elasticsearch-master:9200/_cluster/health?pretty'



6️⃣ Kibana setup (one-time)

Open Kibana UI

Go to Stack Management → Index Patterns

Create index:

filebeat-*


Time field:

@timestamp


Go to Discover