#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
AWS_ACCOUNT_ID="717546795560"
REPO="heschmat/flask-app-devops"
BRANCH="main"
ROLE_NAME="GitHubActionsRole"
OIDC_PROVIDER="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

# === CREATE TRUST POLICY JSON ===
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${REPO}:ref:refs/heads/${BRANCH}"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

echo "✅ Generated trust-policy.json"

# === UPDATE IAM ROLE'S TRUST POLICY ===
aws iam update-assume-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-document file://trust-policy.json

echo "✅ Updated IAM role '${ROLE_NAME}' trust policy to allow GitHub Actions access for:"
echo "- Repository: ${REPO}"
echo "- Branch: ${BRANCH}"
