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
