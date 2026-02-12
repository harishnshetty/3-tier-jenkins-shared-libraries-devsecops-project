# MySQL StatefulSet - Production Deployment Guide

## Current Setup Analysis

Your current deployment in `three-tier-deploy/` has:
- ✅ **StatefulSet** (correct for databases)
- ✅ **PersistentVolumeClaim** (data persistence)
- ✅ **Headless Service** (stable network identity)
- ✅ **Security Context** (non-root user, dropped capabilities)
- ✅ **Resource limits** (CPU/memory)
- ✅ **Health probes** (liveness/readiness)
- ⚠️ **Mixed approach**: Custom image + ConfigMap (needs decision)

---

## 🔴 Critical Production Issues to Address

### 1. Schema Management Strategy

**Current Problem**: You're using BOTH approaches:
- Custom Docker image: `harishnshetty/mysql:100`
- ConfigMap: `mysql-init-script` mounted at `/docker-entrypoint-initdb.d`

**Production Decision Required**:

#### **Option A: Baked-in Schema (Recommended for Production)**
```yaml
# Remove ConfigMap volume mount
containers:
  - name: mysql
    image: harishnshetty/mysql:100  # Contains appdb.sql
    # REMOVE these lines:
    # volumeMounts:
    #   - name: mysql-init-script
    #     mountPath: /docker-entrypoint-initdb.d
```

**Pros**:
- ✅ Immutable, versioned schema
- ✅ Signed image with Cosign
- ✅ GitOps friendly
- ✅ Consistent across environments

**Cons**:
- ❌ Requires image rebuild for schema changes
- ❌ Slower iteration during development

#### **Option B: ConfigMap (Development/Testing)**
```yaml
containers:
  - name: mysql
    image: mysql:8.0  # Official image
    volumeMounts:
      - name: mysql-init-script
        mountPath: /docker-entrypoint-initdb.d
```

**Pros**:
- ✅ Fast schema updates (just update ConfigMap)
- ✅ No image rebuild needed

**Cons**:
- ❌ Schema not versioned with image
- ❌ ConfigMap can be modified without audit trail
- ❌ Not suitable for production

---

## 🏭 Real-World Production Deployment

### Production-Ready MySQL StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: production
  labels:
    app: mysql
    tier: database
    environment: production
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
      tier: database
  
  template:
    metadata:
      labels:
        app: mysql
        tier: database
        environment: production
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9104"  # MySQL exporter
    
    spec:
      # Anti-affinity to spread across nodes (for HA)
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - mysql
                topologyKey: kubernetes.io/hostname
      
      securityContext:
        fsGroup: 999
        runAsNonRoot: true
      
      # Init container for permissions
      initContainers:
        - name: init-mysql
          image: busybox:1.35
          command:
            - sh
            - -c
            - |
              chown -R 999:999 /var/lib/mysql
          volumeMounts:
            - name: mysql-data
              mountPath: /var/lib/mysql
      
      containers:
        - name: mysql
          image: harishnshetty/mysql:100  # Your signed image
          imagePullPolicy: IfNotPresent
          
          args:
            - --default-authentication-plugin=mysql_native_password
            - --max-connections=500
            - --innodb-buffer-pool-size=512M
            - --slow-query-log=1
            - --long-query-time=2
          
          ports:
            - name: mysql
              containerPort: 3306
              protocol: TCP
          
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-root-secret
                  key: password
            - name: MYSQL_DATABASE
              value: webappdb
            - name: TZ
              value: "UTC"
          
          securityContext:
            runAsUser: 999
            runAsNonRoot: true
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false  # MySQL needs to write
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE  # For port 3306
          
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "2000m"
              memory: "2Gi"
          
          volumeMounts:
            - name: mysql-data
              mountPath: /var/lib/mysql
              subPath: mysql
            - name: mysql-config
              mountPath: /etc/mysql/conf.d
              readOnly: true
          
          livenessProbe:
            exec:
              command:
                - mysqladmin
                - ping
                - -h
                - localhost
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          
          readinessProbe:
            exec:
              command:
                - mysql
                - -h
                - localhost
                - -uroot
                - -p${MYSQL_ROOT_PASSWORD}
                - -e
                - "SELECT 1"
            initialDelaySeconds: 30
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
        
        # Sidecar: MySQL Exporter for Prometheus
        - name: mysql-exporter
          image: prom/mysqld-exporter:v0.15.1
          ports:
            - name: metrics
              containerPort: 9104
          env:
            - name: DATA_SOURCE_NAME
              value: "root:$(MYSQL_ROOT_PASSWORD)@(localhost:3306)/"
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-root-secret
                  key: password
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "100m"
              memory: "128Mi"
      
      volumes:
        - name: mysql-config
          configMap:
            name: mysql-config
  
  volumeClaimTemplates:
    - metadata:
        name: mysql-data
        labels:
          app: mysql
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: gp3  # Use gp3 for better performance
        resources:
          requests:
            storage: 20Gi  # Production size

---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: production
  labels:
    app: mysql
spec:
  type: ClusterIP
  clusterIP: None  # Headless service
  selector:
    app: mysql
  ports:
    - name: mysql
      port: 3306
      targetPort: 3306
    - name: metrics
      port: 9104
      targetPort: 9104
```

---

## 🔐 Production Secrets Management

### Don't Use Plain Secrets

**Current (Not Production-Ready)**:
```yaml
# secrets.yaml - Base64 is NOT encryption!
data:
  password: cGFzc3dvcmQK  # Anyone can decode this
```

### Production Options

#### **Option 1: External Secrets Operator (Recommended)**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: mysql-root-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: mysql-root-secret
  data:
    - secretKey: password
      remoteRef:
        key: prod/mysql/root-password
```

#### **Option 2: Sealed Secrets**
```bash
# Encrypt the secret
kubectl create secret generic mysql-root-secret \
  --from-literal=password='YourStrongPassword123!' \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-mysql-secret.yaml

# Commit to Git (encrypted)
git add sealed-mysql-secret.yaml
```

#### **Option 3: AWS Secrets Manager + IRSA**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mysql
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/mysql-secrets-role
---
# Pod uses IRSA to fetch secrets from AWS Secrets Manager
```

---

## 💾 Backup Strategy (CRITICAL for Production)

### Automated Backup CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
  namespace: production
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: mysql-backup
          containers:
            - name: backup
              image: mysql:8.0
              command:
                - /bin/bash
                - -c
                - |
                  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                  BACKUP_FILE="/backup/mysql_backup_${TIMESTAMP}.sql.gz"
                  
                  mysqldump -h mysql.production.svc.cluster.local \
                    -uroot -p${MYSQL_ROOT_PASSWORD} \
                    --all-databases \
                    --single-transaction \
                    --quick \
                    --lock-tables=false | gzip > ${BACKUP_FILE}
                  
                  # Upload to S3
                  aws s3 cp ${BACKUP_FILE} s3://my-mysql-backups/production/
                  
                  # Keep only last 30 days locally
                  find /backup -name "mysql_backup_*.sql.gz" -mtime +30 -delete
              env:
                - name: MYSQL_ROOT_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: mysql-root-secret
                      key: password
              volumeMounts:
                - name: backup-storage
                  mountPath: /backup
          volumes:
            - name: backup-storage
              persistentVolumeClaim:
                claimName: mysql-backup-pvc
          restartPolicy: OnFailure
```

---

## 📊 Monitoring & Alerting

### Prometheus ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mysql
  namespace: production
spec:
  selector:
    matchLabels:
      app: mysql
  endpoints:
    - port: metrics
      interval: 30s
```

### Key Metrics to Monitor

- **Connections**: `mysql_global_status_threads_connected`
- **Queries**: `rate(mysql_global_status_queries[5m])`
- **Slow Queries**: `rate(mysql_global_status_slow_queries[5m])`
- **Replication Lag**: `mysql_slave_status_seconds_behind_master`
- **Disk Usage**: `kubelet_volume_stats_used_bytes`

---

## 🚀 High Availability (Multi-Master)

For production, consider MySQL InnoDB Cluster or Percona XtraDB Cluster:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  replicas: 3  # 3-node cluster
  # ... with MySQL Group Replication configured
```

**Alternatives**:
- **Managed Services**: AWS RDS, Google Cloud SQL, Azure Database
- **Operators**: Percona Operator, Oracle MySQL Operator, Vitess

---

## 📦 Helm Chart Approach (Production Standard)

```bash
# Install MySQL with Helm
helm repo add bitnami https://charts.bitnami.com/bitnami

helm install mysql bitnami/mysql \
  --namespace production \
  --create-namespace \
  --set auth.rootPassword=SecurePassword123! \
  --set primary.persistence.size=20Gi \
  --set primary.persistence.storageClass=gp3 \
  --set metrics.enabled=true \
  --set metrics.serviceMonitor.enabled=true \
  --values custom-values.yaml
```

---

## 🔄 GitOps Deployment (ArgoCD)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mysql
  namespace: argocd
spec:
  project: production
  source:
    repoURL: https://github.com/your-org/k8s-manifests
    targetRevision: main
    path: production/mysql
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: false  # Don't auto-delete database!
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## ✅ Production Checklist

- [ ] **Schema in Docker image** (not ConfigMap)
- [ ] **Image signed with Cosign**
- [ ] **Secrets in external vault** (AWS Secrets Manager, Vault)
- [ ] **Automated backups** to S3/GCS
- [ ] **Backup restore tested** regularly
- [ ] **Monitoring enabled** (Prometheus + Grafana)
- [ ] **Alerts configured** (PagerDuty, Slack)
- [ ] **Resource limits** appropriate for load
- [ ] **Storage class** = gp3 (not gp2)
- [ ] **Storage size** >= 20Gi
- [ ] **Network policies** to restrict access
- [ ] **Pod disruption budget** configured
- [ ] **Disaster recovery plan** documented
- [ ] **High availability** (if required)

---

## 🎯 Recommendation for Your Setup

**For Production**:
1. ✅ Use your custom image `harishnshetty/mysql:100` with `appdb.sql` baked in
2. ❌ Remove the ConfigMap volume mount (lines 60-61, 79-82 in your YAML)
3. ✅ Implement automated backups to S3
4. ✅ Use External Secrets Operator for password management
5. ✅ Add MySQL exporter sidecar for monitoring
6. ✅ Increase storage to 20Gi minimum
7. ✅ Switch to gp3 storage class

**Updated Deployment**:
```yaml
# Remove these lines from your mysqldb.yaml:
volumeMounts:
  - name: mysql-init-script  # DELETE
    mountPath: /docker-entrypoint-initdb.d  # DELETE

volumes:
  - name: mysql-init-script  # DELETE
    configMap:  # DELETE
      name: mysql-init-script  # DELETE
```

This ensures your database schema is immutable, versioned, and signed with your image.
