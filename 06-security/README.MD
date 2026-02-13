```bash
kubectl edit configmap aws-node -n kube-system
data:
  enableNetworkPolicy: "false"  --> true
```

```bash
aws eks update-addon \
  --cluster-name my-cluster \
  --addon-name vpc-cni \
  --configuration-values '{"enableNetworkPolicy":"true"}'
``` 

```bash
kubectl exec -it -n prod frontend-depo-d467684b7-4fbj4 -- sh
nc -zv mysql-write 3306
nc -zv backend-svc 4000

kubectl exec -it -n prod mysql-0 -- sh
nc -zv backend-svc 4000
nc -zv frontend-svc 80
```