# 3-tier-jenkins-shared-libraries-devsecops-project

## Database Tier

### mysql:9.6

Build → SAST → SCA → Image Build → Trivy → Push → Cosign Sign → Deploy


sudo apt install gitleaks

gitleaks --repo .

gitleaks detect --source .

    sh "gitleaks detect --source . -r gitleaks-report.json -f json" || true

trivy fs --scanners secret --skip-files "*.md" .

trivy repo --severity CRITICAL --skip-files "*.md" .

trivy repo --severity HIGH https://github.com/Plazmaz/leaky-repo.git



https://trivy.dev/docs/latest/supply-chain/sbom/

https://cyclonedx.github.io/Sunshine/
$ trivy image --format spdx-json --output result.json alpine:3.15

$ trivy fs --format cyclonedx --output result.json /app/myproject



https://docs.sigstore.dev/cosign/system_config/installation/

brew install cosign

curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign


cosign generate-key-pair

docker image ls --digests 

cosign sign --key cosign.key docker.io/harishnshetty/forntend-signed:@sha



trivy image --ignore-unfixed --format cosign-vuln --output vuln.json docker.io/harishnshetty/forntend-signed:@sha


cosign attest --key cosign.key --type vuln --predicate vuln.json docker.io/harishnshetty/forntend-signed:@sha

cosign verify-attestation --key cosign.pub --type vuln harishnshetty/forntend-signed:@sha





cosign sign --key cosign.key harishnshetty/test-signed:latest
cosign verify --key cosign.pub harishnshetty/test-signed


cosign verify-attestation \
  --key cosign.pub \
  --type cyclonedx \
  $IMAGE




https://kyverno.io/docs/installation/installation/

helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace



High Availability Installation

helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
--set admissionController.replicas=3 \
--set backgroundController.replicas=2 \
--set cleanupController.replicas=2 \
--set reportsController.replicas=2



apiVersion: kyverno.io/v1 
kind: ClusterPolicy 
metadata: 
  name: check-vulnerabilities 
spec: 
  validationFailureAction: Enforce 
  background: false 
  webhookTimeoutSeconds: 30 
  failurePolicy: Fail 
  rules: 
    - name: checking-vulnerability-scan-not-older-than-one-hour 
      match: 
        any: 
        - resources: 
            kinds: 
              - Pod 
      verifyImages: 
      - imageReferences: 
        - "*" 
        attestations: 
        - type: https://cosign.sigstore.dev/attestation/vuln/v1 
          conditions: 
          - all: 
            - key: "{{ time_since('','{{ metadata.scanFinishedOn }}', '') }}" 
              operator: LessThanOrEquals 
              value: "1h" 
          attestors: 
          - count: 1 
            entries: 
            - keys: 
                publicKeys: |- 
                  -----BEGIN PUBLIC KEY----- 
                  abc 
                  xyz 
                  -----END PUBLIC KEY----- 




                  apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
  annotations:
    policies.kyverno.io/title: Verify Container Image Signatures
    policies.kyverno.io/category: Security
    policies.kyverno.io/severity: high
    policies.kyverno.io/description: >-
      Ensures all container images are cryptographically signed
      before deployment to production clusters.
spec:
  validationFailureAction: Audit  # Start in Audit mode
  background: false
  webhookTimeoutSeconds: 30
  
  rules:
    - name: verify-signed-images
      match:
        any:
        - resources:
            kinds:
              - Pod
              - Deployment
              - StatefulSet
            namespaces:
              - production
      
      verifyImages:
      - imageReferences:
        - "*.dkr.ecr.*.amazonaws.com/*"
        
        attestors:
        - count: 1
          entries:
          - keys:
              secret:
                name: cosign-pub-key
                namespace: kyverno
        
        required: true
        mutateDigest: true
        verifyDigest: true