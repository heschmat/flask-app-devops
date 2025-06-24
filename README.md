
# Flask App Postgres + EKS

## 1. create cluster
```sh
eksctl create cluster -f ./k8s/cluster-config.yaml
k config current-context

```

## 2. ECR ...

```sh
# authenticate/login to ecr
aws ecr get-login-password --region us-east-1 | \
docker login \
  --username AWS \
  --password-stdin \
  $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com


# 
output=$(aws ecr create-repository --repository-name flask-app-ecr --region us-east-1)
repo_uri=$(echo "$output" | jq -r '.repository.repositoryUri')
account_id=$(echo "$output" | jq -r '.repository.registryId')

echo "Repository URI: $repo_uri"
echo "Account ID: $account_id"

## if repo already exists:
repoName="flask-app-ecr"
output=$(aws ecr describe-repositories)
repo_uri=$(echo "$output" | jq -r --arg name "$repoName" '.repositories[] | select(.repositoryName == $name) | .repositoryUri')
echo $repo_uri

# build, tag, push to ecr
cd app/
docker build -t my-flask-app .
IMG_TAG=v1
docker tag my-flask-app:latest ${repo_uri}:${IMG_TAG}
docker push ${repo_uri}:${IMG_TAG}


sed -i "s|\(image: 717546795560.dkr.ecr.us-east-1.amazonaws.com/flask-app-ecr:\).*|\1$IMG_TAG|" k8s/manifests/flask-app.yaml

```


### 3. aws ebs csi driver

```sh

helm upgrade --install aws-ebs-csi-driver \
  aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.create=true \
  --set controller.serviceAccount.name=ebs-csi-controller-sa \
  --set node.serviceAccount.create=true \
  --set node.serviceAccount.name=ebs-csi-node-sa


kubectl get pods -n kube-system -l "app.kubernetes.io/name=aws-ebs-csi-driver,app.kubernetes.io/instance=aws-ebs-csi-driver"

k get sa -n kube-system | grep ebs


# 
aws iam list-roles --query "Roles[?contains(RoleName, 'flask')].RoleName" --output table
aws iam list-policies --scope AWS --query "Policies[?contains(PolicyName, 'EBS')].[PolicyName,Arn]" --output table

# Extract the role name and save to a variable
NODE_ROLE_NAME=$(aws iam list-roles \
  --query "Roles[?contains(RoleName, 'nodegroup') && contains(RoleName, 'NodeInstanceRole')].RoleName | [0]" \
  --output text)

echo "Node role: $NODE_ROLE_NAME"

# give node permission to provision and attach EBS volumes to pods 
aws iam attach-role-policy \
  --role-name "$NODE_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy


```

## postgres seed

```sh
cd app

kubectl create configmap postgres-init-scripts \
  --from-file=1_create_tables.sql=db/1_create_tables.sql \
  --from-file=2_seed_users.sql=db/2_seed_users.sql

```

## Helm

```sh
mkdir helm
cd helm
helm create flask-app
# This creates a directory flask-app/ with a standard Helm structure:
flask-app/
├── charts/
├── templates/
├── values.yaml
├── Chart.yaml


rm -rf charts/ templates/
mkdir templates

# after parameterizing the raw manifests files, test & install the app:
helm template flask-app ./flask-app

helm install flask-app ./flask-app

```

## ArgoCD

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


# get password for the GUI
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo

# expose Argo CD using a LoadBalancer service
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Wait a few minutes for the LoadBalancer to provision
kubectl get svc argocd-server -n argocd


## ******************************** ##
# image pull policy but via irsa:
./gitops/argocd/setup-irsa-ecr.sh

```


## CICD
```sh
# image pull policy for GHA to pull from ECR
 ./.github/create-github-actions-role.sh 

```


## k apply -f 

```sh
k apply -f ./k8s/manifests/

k get nodes -o wide

# liveness & readiness check
# e.g., NODE_IP=3.85.85.57 and open port 32123
curl -i ${NODE_IP}:32123/health_check
curl -i ${NODE_IP}:32123/readiness_check

# argocd app
 k apply -f ./k8s/argo-app.yaml 
```
