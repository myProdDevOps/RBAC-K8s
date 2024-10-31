## Create role (template file)

if [ $# -lt 1 ]; then
  echo "Usage: $0 <username>"
  exit 1
fi

# Define params
selected_user=$1 # Username
home_user_dir="/home/$selected_user/rbac"

# shellcheck disable=SC2164
cd "$home_user_dir"

# Create role file (This is template file)
cat <<EOF > admin-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "create", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
EOF
kubectl apply -f admin-role.yaml

# Apply this role for user (This is template file)
cat <<EOF > bind-role-"$selected_user".yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: "$selected_user"-cluster-admin
subjects:
- kind: User
  name: "$selected_user"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
kubectl apply -f bind-role-"$selected_user".yaml

