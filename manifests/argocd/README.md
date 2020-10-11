# Argo CD

## Getting Started

### Setup argocd in k8s

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Setup Argo CD CLI

```bash
brew install argocd
```

### Access Argo CD

Kubectl port-forwarding can also be used to connect to the API server without exposing the service.

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

The API server can then be accessed using the `localhost:8080`

### Authentication

#### Initialize password

```bash
Username: admin
Password: $(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2)
```

#### login via CLI

```bash
argocd login <ARGOCD_SERVER>
```

#### Reset password

```bash
argocd account update-password
```

### Register A Cluster To Deploy Apps To (Optional)

This step registers a cluster's credentials to Argo CD, and is only necessary when deploying to an external cluster. When deploying internally (to the same cluster that Argo CD is running in), https://kubernetes.default.svc should be used as the application's K8s API server address.

First list all clusters contexts in your current kubeconfig:

```bash
argocd cluster add
```

Choose a context name from the list and supply it to argocd cluster add CONTEXTNAME. For example, for docker-for-desktop context, run:

```bash
argocd cluster add docker-for-desktop
```

The above command installs a ServiceAccount (argocd-manager), into the kube-system namespace of that kubectl context, and binds the service account to an admin-level ClusterRole. Argo CD uses this service account token to perform its management tasks (i.e. deploy/monitoring).

### Demo

Follow https://argoproj.github.io/argo-cd/getting_started/#6-create-an-application-from-a-git-repository to create a demo in Argo CD
