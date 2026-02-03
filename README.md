# 3-tier-jenkins-shared-libraries-devsecops-project

## Database Tier

### mysql:9.6

sudo apt install gitleaks

gitleaks --repo .

gitleaks detect --source .

    sh "gitleaks detect --source . -r gitleaks-report.json -f json" || true
