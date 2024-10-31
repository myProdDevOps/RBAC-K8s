#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: $0 <username> <cluster_entry_name> <cert-duration>"
  exit 1
fi

# Define params
selected_user=$1 # Username
cluster_entry_name=$2 # Cluster entry name
cert_duration=$3 # Certificate duration
home_user_dir="/home/$selected_user/rbac" # Home directory for user storing rbac
server_address=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}') # IP address of master node
# End define params

## Step 1: Create init folder

# Create default folder for user credentials
if [ -d "$HOME/user-credential" ]; then
  echo "Access to $HOME/user-credential folder"
  cd "$HOME/user-credential" || exit # Exit case when cd fails
else
  echo "Creating $HOME/user-credential folder for storing user credentials"
  mkdir ~/user-credentical
fi

# Check if the cert folder for the selected user exists
if [ -d "${home_user_dir}" ]; then
  echo "Accessing ${selected_user}'s folder at ${home_user_dir}"
  cd "${home_user_dir}" || exit # Exit if cd fails
else
  echo "Creating ${selected_user}'s folder at ${home_user_dir}"
  mkdir -p "${home_user_dir}"  # -p option ensures all necessary directories are created
  cd "${home_user_dir}" || exit # Ensure cd to newly created user-specific folder
fi

## Step 2: Generate user credentials
openssl genrsa -out "$selected_user".pem
openssl req -new -key "$selected_user".pem -out "$selected_user".csr -subj "/CN=$selected_user"

## Step 3: Create Certificate Signing Request (CSR)
cat <<EOF > create-csr-"$selected_user".yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: "$selected_user"
spec:
  request: $(cat "$selected_user".csr | base64 | tr -d "\n")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: "$cert_duration"  # one day
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

kubectl apply -f create-csr-"$selected_user".yaml

## Step 4: Approve CSR
kubectl certificate approve "$selected_user"
kubectl describe csr/"$selected_user"

## Step 5: Create kubeconfig file
kubectl get csr/"$selected_user" -o jsonpath="{.status.certificate}" | base64 -d > "$selected_user".crt

## Step 6: Create new config for selected user
kubectl --kubeconfig ~/.kube/config-"$selected_user" config set-cluster "$cluster_entry_name" --insecure-skip-tls-verify=true --server="$server_address"

## Step 7: Set user credentials
kubectl --kubeconfig ~/.kube/config-"$selected_user" config set-credentials "$selected_user" --client-certificate="$selected_user".crt --client-key="$selected_user".pem --embed-certs=true

## Step 8: Set context == set-context `context_name`
kubectl --kubeconfig ~/.kube/config-"$selected_user" config set-context context_"$selected_user" --cluster="$cluster_entry_name" --user="$selected_user"

## Step 9: Use context
kubectl --kubeconfig ~/.kube/config-"$selected_user" config use-context context_"$selected_user"

## Step 10: Notify success
echo "The credentials of user $selected_user has been created successfully, please continue to create role&binding-role for this user"
