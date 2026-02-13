## Install Kyverno

[Kyverno Helm Link ](https://kyverno.io/docs/installation/installation/)
```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm search repo kyverno

helm install kyverno kyverno/kyverno -n kyverno --create-namespace
```

## High Availability Installation
Use Helm to create a Namespace and install Kyverno in a highly-available configuration.

```bash
helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
--set admissionController.replicas=3 \
--set backgroundController.replicas=2 \
--set cleanupController.replicas=2 \
--set reportsController.replicas=2
```