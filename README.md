# RBAC-K8s

**Brief description**: Apply ***Role-based access control*** (RBAC) in Kubernetes for multiple users by creating
credentials in Kube API server and
binding roles for them.

## Table of Contents

### 1. Generate certificates for user

Kube API server recognizes users by their approved certificates. So, we need to generate certificates for each user to
communicate within the system.

In this case, I'll use user named "mrtux" as an example.

###### Output: mrtux.pem, mrtux.csr

```shell
# Generate private key and certificate signing request
openssl genrsa -out mrtux.pem
openssl req -new -key mrtux.pem -out mrtux.csr -subj "/CN=mrtux"
```

The `/CN=mrtux` field in the command above represents the Common Name (CN) field in the certificate. It's typically used
to identify the username in RBAC. Another reason for using it is that I prefer not to fill out all the information in
OpenSSL's Interactive Prompt.
___

### 2. Create Certificate Signing Request (CSR)

CSR is a request to a Certificate Authority (CA) to issue a certificate.

After successfully generating the private key, we need to create a CSR for the user from the content of `.csr` file
above in based64.

###### csr-mrtux.yaml

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: mrtux
spec:
  request: $(cat mrtux.csr | base64 | tr -d "\n")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # one day
  usages:
    - digital signature
    - key encipherment
    - client auth
```

The `expirationSeconds` field is the time in seconds that the CSR will expire, calculated by second.
___

### 3. Approve the CSR

The next step is to have the Kube API Server approve the CSR, enabling the user to use the certificate for communication
with the cluster.

```shell
kubectl certificate approve mrtux

## Output
certificatesigningrequest.certificates.k8s.io/mrtux approved

$ kubectl get csr                         
NAME     AGE   SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
mrtux    1m    kubernetes.io/kube-apiserver-client   kubernetes-admin   1m                  Approved,Issued
```

___

### 4. Extract the certificate from the approved CSR

Now we have the approved CSR, we can extract the certificate from it.

The default command `kubectl get csr/mrtux` only returns brief information for quick summary review. In this case, we
can use `kubectl get csr/mrtux -o json`, which will print the full information of the CSR in JSON format.

###### print output of CSR in json format

```shell
kubectl get csr/mrtux -o json

...
"status": {
        "certificate": "LS0tLS1CRUdJTiBDRVJUSUZJQ...."
        }
...
```

The `status.certificate` field in the JSON output contains the signed certificate in base64 format.
From this step, we can create a `.crt` file by using the output above.

###### Extract the certificate from the CSR

```shell
kubectl get csr/mrtux -o jsonpath="{.status.certificate}" | base64 -d > mrtux.crt
```

___

### 5. Setup credentials & user config file.

#### 5.1. Setup user config file.

The API Server in Kubernetes uses a `kubeconfig` file to authenticate and authorize users. Therefore, each user needs
their own `kubeconfig` file to access the Kubernetes cluster. In this step, we’ll create a new `kubeconfig` file for the
user `mrtux`.

###### Create a new kubeconfig file

```shell
kubectl --kubeconfig ~/.kube/config-mrtux config set-cluster cluster-mrtux --insecure-skip-tls-verify=true --server=https://YOUR_KUBERNETES-API-ADDRESS
```

**Explanation**:

* `--insecure-skip-tls-verify=true`: I don’t have TLS, so I skip this step to avoid SSL verification issues :D.
* `config set-cluster`: used to create a new `cluster entry` that stores configuration details of a Kubernetes cluster
  in the Kubernetes configuration file.

Remember to replace `YOUR_KUBERNETES-API-ADDRESS` with your server's actual IP address.

#### 5.2. Setup credentials

The next step is using the command `kubectl config set-credentials` to create a new user in the kubeconfig file by newly
created `.crt`,`.pem` and newly created `kubeconfig` file.

In this tutorial, I'm going to use just one name for all the files, which is `mrtux`. If you prefer using different
names, please remember to make appropriate changes.

###### Setup credentials

```shell
kubectl --kubeconfig ~/.kube/config-mrtux config set-credentials mrtux --client-certificate=mrtux.crt --client-key=mrtux.pem --embed-certs=true
```

___

### 6. Create & Setup context.

Another important concept in Kubernetes is `context`. A `context` in Kubernetes is a set of access parameters, provides
a simple way to switch between different Kubernetes environments (cluster, users, namespaces, ...).

I'll base on kubeconfig file amd cluster entry to create new context for user `mrtux`.

###### Create context for user `mrtux`

```shell
kubectl --kubeconfig ~/.kube/config-mrtux config set-context context-mrtux --cluster=cluster-mrtux --user=mrtux
# Use context
kubectl --kubeconfig ~/.kube/config-mrtux config use-context context-mrtux
```

After this step, we are able to communicate with API Server via `kubeconfig` file named `config-mrtux`. Here is the
usage:

###### Get pods in the default namespace

```shell
$ kubectl --kubeconfig ~/.kube/config-mrtux get pods
Error from server (Forbidden): pods is forbidden: User "mrtux" cannot list resource "pods" in API group "" in the namespace "default"
```

The error message means that user `mrtux` can communicate with the API Server, but it doesn't have permission to do
actions.

In the next step, we will create a role and bind it to the user `mrtux` to allow it to do actions in the cluster.

___

### 7. Create Role & RoleBinding

A Role is a Kubernetes resource that defines a set of permissions within a specific namespace or all of them. It
specifies what
actions (like get, list, create, delete, etc.) can be performed on which resources (like pods, services, deployments,
etc.).

A Role Binding is a Kubernetes resource that grants the permissions defined in a Role to a user or set of users. It
connects (or binds) a Role to the subjects (users, groups, or service accounts) that should have those permissions.

In this step, we will create a Role and RoleBinding for user `mrtux` to allow getting and listing pods in the namespace.

###### pod-reader.yaml

```yaml 
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  # use namespace spec if you want to point specific namespace.
rules:
  - apiGroups: [ "" ]
    resources: [ "pods" ]
    verbs: [ "get", "list" ]
```

After creating the role, the next step is binding the role to the user `mrtux`.

###### rolebinding-mrtux.yaml

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: rolebinding-mrtux
  # use namespace spec if you want to point specific namespace.
subjects:
  - kind: User
    name: mrtux
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

This role binding will bind the role `pod-reader` to the user `mrtux`. Now user `mrtux` can get and list pods in the
cluster.

###### Get pods in the default namespace after binding role

```shell
kubectl --kubeconfig ~/.kube/config-mrtux get pods -n default
## Output with created pod named "nginx-pod"
NAME        READY   STATUS    RESTARTS   AGE
nginx-pod   1/1     Running   0          23d
```

Now we can communicate with the API Server and perform actions in the cluster using the kubeconfig file. However, it's
inconvenient to keep typing the `--kubeconfig` flag every time we want to do something. In the next step, we will
configure Kubernetes to automatically load the `kubeconfig` file corresponding to the logged-in user.
___

### 8. Configure Kubernetes to automatically load the kubeconfig file

The `KUBECONFIG` environment variable is used to specify one or more `kubeconfig` files. It is a colon-separated list of
paths to `kubeconfig` files. The kubectl command will use the first file in the list that exists.

In this part, we will create `.kube` folder for storing the `kubeconfig` files and set the `KUBECONFIG` environment
variable when user SSHs to cluster.

###### Create folder for storing kubeconfig files
```shell
mkdir -p /home/mrtux/.kube
cp ~/.kube/config-mrtux /home/mrtux/.kube/config-mrtux
chown mrtux:mrtux /home/mrtux/.kube/config-mrtux
chmod 600 /home/mrtux/.kube/config-mrtux
```

The next step is to create a script file to set up the `KUBECONFIG` environment variable, placing it in the `/etc/profile.d/`
folder. This script will run every time a user SSHs into the cluster.

###### k8s-config-startup-mrtux.sh
```shell
## Get default kubeconfig for logged user
#!/bin/bash
# Save this as /etc/profile.d/k8s-config.sh

# Function to set up Kubernetes config based on username
setup_k8s_config() {
local username=$(whoami)
local kubeconfig="/home/"$username"/.kube/config-"$username""

    if [ -f "$kubeconfig" ]; then
        export KUBECONFIG="$kubeconfig"
        echo "Kubernetes configuration set for user "$username""
    else
        echo "No specific Kubernetes configuration found for "$username""
    fi
}

# Call the function
setup_k8s_config
```
Set up permission for the script that only the owner can execute it.
```shell
sudo chmod u=rx,go-rwx k8s-config-startup-mrtux.sh
```
After successfully setting up the script and reboot (or reload the profile), we can use Kubernetes with SSHs user without typing `--kubeconfig` flag.
```shell
kubectl get pods
NAME        READY   STATUS    RESTARTS   AGE
nginx-pod   1/1     Running   0          23d
```

Now we're done ! We have successfully set up Role-based access control (RBAC) in Kubernetes for user `mrtux`.

If you have external tools for managing Kubernetes like `k9s`, `kubectx`, `kubens`, etc., you can also use them with the `KUBECONFIG` file.
