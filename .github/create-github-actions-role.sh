#!/bin/bash

set -e

AWS_ACCOUNT_ID="717546795560"
GITHUB_REPO="heschmat/flask-app-devops"
BRANCH="main"
ROLE_NAME="GitHubActionsRole"
OIDC_PROVIDER_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"

echo "Creating IAM role: $ROLE_NAME for GitHub OIDC access..."

# Step 1: Create OIDC provider if it doesn't exist
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn $OIDC_PROVIDER_ARN >/dev/null 2>&1; then
  echo "OIDC provider not found, creating..."
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"  # GitHub's current thumbprint
else
  echo "OIDC provider already exists."
fi

# Step 2: Create the trust policy
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:$GITHUB_REPO:ref:refs/heads/$BRANCH"
        }
      }
    }
  ]
}
EOF
)

echo "$TRUST_POLICY" > trust-policy.json

# Step 3: Create the IAM role
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json

# Step 4: Attach ECR permissions
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name GitHubECRPushPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage"
        ],
        "Resource": "*"
      }
    ]
  }'

echo "✅ IAM role '$ROLE_NAME' created and ready to use."
echo "Role ARN: arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME"

# Cleanup
rm trust-policy.json
