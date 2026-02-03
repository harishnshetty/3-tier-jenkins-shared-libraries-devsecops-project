# 3-tier-jenkins-shared-libraries-devsecops-project

## Database Tier

### mysql:9.6

sudo apt install gitleaks

gitleaks --repo .

gitleaks detect --source .

    sh "gitleaks detect --source . -r gitleaks-report.json -f json" || true

trivy fs --scanners secret --skip-files "*.md" .

trivy repo --severity CRITICAL --skip-files "*.md" .

trivy repo --severity HIGH https://github.com/Plazmaz/leaky-repo.git


$ trivy image --format spdx-json --output result.json alpine:3.15

$ trivy fs --format cyclonedx --output result.json /app/myproject