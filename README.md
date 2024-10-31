# RBAC-K8s

**Brief description**: Apply RBAC in Kubernetes for multiple users by creating credentials in Kube API server and
binding roles for them.
***

## Table of Contents

### 1. Generate certificates for user

Kube API server recognizes users by their approved certificates. So, we need to generate certificates for each user to
communicate within the system.

In this case, I'll use user named "mrtux" as an example.


```shell title="Generate certificates for user"
openssl genrsa -out mrtux.pem
openssl req -new -key mrtux.pem -out mrtux.csr -subj "/CN=mrtux"
```
___
### 2. Create Certificate Signing Request (CSR)

CSR is a request to a Certificate Authority (CA) to issue a certificate.

After successfully generating the certificate, we need to create a CSR for the user.

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: mrtux-csr
spec:
  request: $(cat mrtux.csr | base64 | tr -d "\n")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # one day
  usages:
  - digital signature
  - key encipherment
  - client auth
```

### 3. Approve the CSR

