#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
source "$(dirname "$0")/irsa-config.sh"

# === GET AWS ACCOUNT ID ===
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}"

# === DELETE SERVICE ACCOUNT (optional) ===
echo "Deleting Kubernetes service account: ${SERVICE_ACCOUNT_NAME} (namespace: ${NAMESPACE})"
kubectl delete serviceaccount "${SERVICE_ACCOUNT_NAME}" -n "${NAMESPACE}" || echo "Service account not found or already deleted"

# === DETACH POLICY FROM ROLE ===
echo "Detaching policy ${POLICY_NAME} from role ${IAM_ROLE_NAME}"
aws iam detach-role-policy \
  --role-name "${IAM_ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}" || echo "Detach failed or policy not attached"

# === DELETE IAM ROLE ===
echo "Deleting IAM role: ${IAM_ROLE_NAME}"
aws iam delete-role \
  --role-name "${IAM_ROLE_NAME}" || echo "Role not found or already deleted"

# === DELETE IAM POLICY ===
echo "Deleting IAM policy: ${POLICY_NAME}"
aws iam delete-policy \
  --policy-arn "${POLICY_ARN}" || echo "Policy not found or already deleted"

# === REMOVE TRUST POLICY FILE IF EXISTS ===
rm -f trust.json

echo "✅ Cleanup complete."
