#!/bin/bash

# === COMMON CONFIGURATION ===
CLUSTER_NAME="flask-app"
NAMESPACE="default"
SERVICE_ACCOUNT_NAME="argocd-image-access"
IAM_ROLE_NAME="ArgoCDECRRole"
POLICY_NAME="ECRAccessPolicy"
