# MySQL Custom Image - Build, Sign & Deploy Guide

## Overview
This guide covers building a production-ready MySQL image with baked-in database schema, signing it with Cosign, and deploying to Kubernetes.

## Prerequisites
- Docker installed
- Cosign installed for image signing
- Docker Hub account (or your registry)
- Kubernetes cluster access

---

## Step 1: Build the MySQL Image

Navigate to the database directory and build:

```bash
cd /home/harish/Desktop/demo-projects/3-tier-jenkins-shared-libraries-devsecops-project/enovy/database

# Build the image
docker build -t harishnshetty/mysql-3tier:v1.0 .

# Tag as latest
docker tag harishnshetty/mysql-3tier:v1.0 harishnshetty/mysql-3tier:latest
```

**What this does:**
- Copies `appdb.sql` into the image at `/docker-entrypoint-initdb.d/`
- MySQL will automatically execute this SQL on first container startup
- Creates `webappdb` database with `transactions` table

---

## Step 2: Test the Image Locally (Optional)

```bash
# Run the container
docker run -d \
  --name mysql-test \
  -e MYSQL_ROOT_PASSWORD=password \
  -p 3306:3306 \
  harishnshetty/mysql-3tier:v1.0

# Wait for MySQL to initialize (check logs)
docker logs -f mysql-test

# Verify database was created
docker exec -it mysql-test mysql -uroot -ppassword -e "SHOW DATABASES;"
docker exec -it mysql-test mysql -uroot -ppassword -e "USE webappdb; SELECT * FROM transactions;"

# Cleanup
docker stop mysql-test && docker rm mysql-test
```

---

## Step 3: Push to Docker Registry

```bash
# Login to Docker Hub
docker login

# Push the image
docker push harishnshetty/mysql-3tier:v1.0
docker push harishnshetty/mysql-3tier:latest
```

---

## Step 4: Sign the Image with Cosign

### Generate Cosign Key Pair (if not already done)
```bash
cosign generate-key-pair
# This creates cosign.key (private) and cosign.pub (public)
```

### Sign the Image
```bash
# Sign with your private key
cosign sign --key cosign.key harishnshetty/mysql-3tier:v1.0

# Sign the latest tag as well
cosign sign --key cosign.key harishnshetty/mysql-3tier:latest
```

### Verify the Signature
```bash
# Verify with public key
cosign verify --key cosign.pub harishnshetty/mysql-3tier:v1.0
```

---

## Step 5: Update Kubernetes Deployment

Update `mysqldb.yaml` to use your custom signed image:

```yaml
containers:
  - name: mysql
    image: harishnshetty/mysql-3tier:v1.0  # Changed from mysql:8.0
    imagePullPolicy: IfNotPresent
```

**Remove the ConfigMap volume mount** since the SQL is now in the image:

```yaml
# REMOVE these lines from mysqldb.yaml:
volumeMounts:
  - name: mysql-init-script
    mountPath: /docker-entrypoint-initdb.d

volumes:
  - name: mysql-init-script
    configMap:
      name: mysql-init-script
```

---

## Step 6: Deploy to Kubernetes

```bash
# Delete existing MySQL pod to use new image
kubectl delete statefulset mysql -n default

# Apply the updated configuration
kubectl apply -f /home/harish/Desktop/demo-projects/3-tier-jenkins-shared-libraries-devsecops-project/enovy/mysqldb.yaml

# Watch the pod come up
kubectl get pods -n default -w

# Check logs to see database initialization
kubectl logs mysql-0 -n default
```

---

## Step 7: Verify Database Initialization

```bash
# Exec into the pod
kubectl exec -it mysql-0 -n default -- bash

# Inside the pod, check the database
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "USE webappdb; SHOW TABLES;"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "USE webappdb; SELECT * FROM transactions;"
```

Expected output:
```
+----+--------+-------------+
| id | amount | description |
+----+--------+-------------+
|  1 | 500.00 | bike        |
|  2 | 400.00 | groceries   |
+----+--------+-------------+
```

---

## Image Signing in CI/CD Pipeline

For Jenkins pipeline integration:

```groovy
stage('Build & Sign MySQL Image') {
    steps {
        script {
            // Build
            sh "docker build -t harishnshetty/mysql-3tier:${BUILD_NUMBER} ./database"
            
            // Push
            sh "docker push harishnshetty/mysql-3tier:${BUILD_NUMBER}"
            
            // Sign with Cosign
            sh "cosign sign --key cosign.key harishnshetty/mysql-3tier:${BUILD_NUMBER}"
            
            // Verify
            sh "cosign verify --key cosign.pub harishnshetty/mysql-3tier:${BUILD_NUMBER}"
        }
    }
}
```

---

## Benefits of This Approach

✅ **Immutable Infrastructure**: Database schema is versioned with the image  
✅ **Security**: Image is cryptographically signed and verifiable  
✅ **Consistency**: Same schema across dev, staging, and production  
✅ **Traceability**: Clear audit trail of what schema version is deployed  
✅ **GitOps Ready**: Schema changes go through version control  
✅ **No ConfigMap Dependency**: Self-contained image

---

## Schema Updates

When you need to update the database schema:

1. Update `appdb.sql`
2. Build new image with incremented version: `v1.1`, `v1.2`, etc.
3. Sign the new image
4. Update Kubernetes deployment to use new version
5. Apply migration strategy (rolling update, blue-green, etc.)

---

## Troubleshooting

**Issue**: Database not initialized  
**Solution**: Check logs with `kubectl logs mysql-0`. Ensure `appdb.sql` is in `/docker-entrypoint-initdb.d/`

**Issue**: Permission denied on SQL file  
**Solution**: Ensure `COPY --chown=mysql:mysql` is in Dockerfile

**Issue**: Cosign verification fails  
**Solution**: Ensure you're using the correct public key (`cosign.pub`)
