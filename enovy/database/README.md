# 3-tier-jenkins-shared-libraries-devsecops-project

## Database Tier

### mysql:5.7

```bash
docker run --rm -it harishnshetty/mysql:1 sh
sh-5.1$ whoami
mysql
sh-5.1$ id
uid=999(mysql) gid=999(mysql) groups=999(mysql) 
```

docker build -t harishnshetty/mysql-signed:1 .

docker push harishnshetty/mysql-signed:1

docker image ls --digests

trivy image --ignore-unfixed --format cosign-vuln --output vuln.json docker.io/harishnshetty/mysql-signed@sha256:ff2ee817f9b36602b8ce491aeec24d02e482dcf3900c7572b3b5278c616d501b

cosign attest --key cosign.key --type vuln --predicate vuln.json docker.io/harishnshetty/mysql-signed@sha256:ff2ee817f9b36602b8ce491aeec24d02e482dcf3900c7572b3b5278c616d501b


cosign verify --key cosign.pub docker.io/harishnshetty/mysql-signed@sha256:ff2ee817f9b36602b8ce491aeec24d02e482dcf3900c7572b3b5278c616d501b


cosign sign --key cosign.key harishnshetty/test-signed:latest
cosign verify --key cosign.pub harishnshetty/test-signed


cosign verify-attestation \
  --key cosign.pub \
  --type cyclonedx \
  docker.io/harishnshetty/mysql-signed@sha256:ff2ee817f9b36602b8ce491aeec24d02e482dcf3900c7572b3b5278c616d501b