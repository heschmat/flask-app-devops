#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
source "$(dirname "$0")/irsa-config.sh"

# === GET AWS ACCOUNT ID ===
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS ACCOUNT ID: $AWS_ACCOUNT_ID"

# === GET OIDC PROVIDER ===
OIDC_ISSUER_URL=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query "cluster.identity.oidc.issuer" --output text)

OIDC_PROVIDER_HOST=$(echo "$OIDC_ISSUER_URL" | sed -e "s/^https:\/\///")
OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER_HOST}"

echo "OIDC Provider ARN: $OIDC_PROVIDER_ARN"

# === CREATE TRUST POLICY JSON ===
cat > trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER_HOST}:sub": "system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT_NAME}"
        }
      }
    }
  ]
}
EOF

# === CREATE IAM ROLE ===
echo "Creating IAM role: ${IAM_ROLE_NAME}"
aws iam create-role \
  --role-name "${IAM_ROLE_NAME}" \
  --assume-role-policy-document file://trust.json || echo "Role already exists"

# === CREATE ECR ACCESS POLICY ===
echo "Creating ECR policy: ${POLICY_NAME}"
aws iam create-policy \
  --policy-name "${POLICY_NAME}" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        "Resource": "*"
      }
    ]
  }' || echo "Policy already exists"

# === ATTACH POLICY TO ROLE ===
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
aws iam attach-role-policy \
  --role-name "${IAM_ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}"

# === CREATE K8S SERVICEACCOUNT WITH ROLE ANNOTATION ===
echo "Creating service account: ${SERVICE_ACCOUNT_NAME}"
kubectl create serviceaccount "${SERVICE_ACCOUNT_NAME}" -n "${NAMESPACE}" || echo "ServiceAccount already exists"

kubectl annotate serviceaccount "${SERVICE_ACCOUNT_NAME}" \
  -n "${NAMESPACE}" \
  "eks.amazonaws.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}" \
  --overwrite

echo "✅ IRSA setup complete. Patch your Deployment with:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}"
