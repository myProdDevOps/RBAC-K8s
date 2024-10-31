if [ $# -lt 1 ]; then
  echo "Usage: $0 <username>"
  exit 1
fi

# Define params
selected_user=$1 # Username


sudo mkdir -p /home/"$selected_user"/.kube
sudo cp ~/.kube/config-"$selected_user" /home/"$selected_user"/.kube/config-"$selected_user"
sudo chown "$selected_user":"$selected_user" /home/"$selected_user"/.kube/config-"$selected_user"
sudo chmod 600 /home/"$selected_user"/.kube/config-"$selected_user"
cd /etc/profile.d/ || exit



cp "$HOME"/user-credential/config-"$selected_user" /home/"$selected_user"/.kube/config-"$selected_user"

## Get default kubeconfig for logged user
cat <<EOF > k8s-config-startup.sh
#!/bin/bash
# Save this as /etc/profile.d/k8s-config.sh

# Function to set up Kubernetes config based on username
setup_k8s_config() {
    local username=$(whoami)
    local kubeconfig="/home/"$selected_user"/.kube/config-"$selected_user""

    if [ -f "$kubeconfig" ]; then
        export KUBECONFIG="$kubeconfig"
        echo "Kubernetes configuration set for user "$selected_user""
    else
        echo "No specific Kubernetes configuration found for "$selected_user""
    fi
}

# Call the function
setup_k8s_config
EOF
chmod +x k8s-config-startup.sh

