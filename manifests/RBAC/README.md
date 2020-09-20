# RBAC

  ```bash
        rolebinding            set-context
  role ------------- account --------------- cluster ==> context
  ```

## Create service account

  ```bash
  kubectl create namespace dev-monitor
  kubectl create serviceaccount showerlee -n dev-monitor
  ```

## Get account token

  ```bash
  kubectl describe serviceaccount -n dev-monitor | grep Tokens: | grep showerlee
  Tokens:              showerlee-token-n9bgt
  ```

  ```bash
  kubectl describe secret -n dev-monitor showerlee-token-n9bgt | grep token:
  token:      eyJhbGciOiJSUzI1NiIsImtpZCI6InVFMUYzMjFHbFBHVGh0NVdWUFZ6T25BSnFJNnlXOFdCbVdCWnhyY0RCVWMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZXYtbW9uaXRvciIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJzaG93ZXJsZWUtdG9rZW4tbjliZ3QiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoic2hvd2VybGVlIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiYjhmMjdiMGEtNWNjYy00Yjc4LWIzMDEtZWJlNWMyZGIxN2M4Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRldi1tb25pdG9yOnNob3dlcmxlZSJ9.M7yFsITrOF-E0X_2X-zLh7Ngwb2PfNBxrJyE6cZ6eZXUbjygmvGvou_ZcXJ8t1igJOWgODKPmLI2evt08nASc-Sm9qwoVN_U6mlwjM0sGwhlcksQpBtPTZYDCJHCZL6Xw44LFrGnZ7idvaRBRGQ8-VKtC1Esu4SZOC6pQdWzuyGWtnSwvtpdYkPmrUw4cmVGomv1JdNoL_PQS3m-erGq3jk7h3uqs1Jpb1KqMpilxOvICYwGE3Vq-inBu0a0elROTv_vSCAbEqHabV0EQnENv6fFL_xdWrsc5ZvnSAFB156hrd4rqToFBP1zU6iR97pcKlJGdRPFtNzUUEx05MMOJQ
  ```

## Bind account and token via `set-credentials`

  ```bash
  kubectl config set-credentials showerlee --token=eyJhbGciOiJSUzI1NiIsImtpZCI6InVFMUYzMjFHbFBHVGh0NVdWUFZ6T25BSnFJNnlXOFdCbVdCWnhyY0RCVWMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZXYtbW9uaXRvciIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJzaG93ZXJsZWUtdG9rZW4tbjliZ3QiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoic2hvd2VybGVlIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiYjhmMjdiMGEtNWNjYy00Yjc4LWIzMDEtZWJlNWMyZGIxN2M4Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRldi1tb25pdG9yOnNob3dlcmxlZSJ9.M7yFsITrOF-E0X_2X-zLh7Ngwb2PfNBxrJyE6cZ6eZXUbjygmvGvou_ZcXJ8t1igJOWgODKPmLI2evt08nASc-Sm9qwoVN_U6mlwjM0sGwhlcksQpBtPTZYDCJHCZL6Xw44LFrGnZ7idvaRBRGQ8-VKtC1Esu4SZOC6pQdWzuyGWtnSwvtpdYkPmrUw4cmVGomv1JdNoL_PQS3m-erGq3jk7h3uqs1Jpb1KqMpilxOvICYwGE3Vq-inBu0a0elROTv_vSCAbEqHabV0EQnENv6fFL_xdWrsc5ZvnSAFB156hrd4rqToFBP1zU6iR97pcKlJGdRPFtNzUUEx05MMOJQ
  ```

## Create `role`

  ```bash
  kubectl apply -f pod-reader.yml

  kubectl get role -n dev-monitor
  NAME         AGE
  pod-reader   66m
  ```

## Bind account and role via `rolebinding`

  ```bash
  kubectl apply -f pod-reader-binding.yml
  ```

## Create Cluster via `set-cluster`

  ```bash
  kubectl config set-cluster test-cluster \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=https://10.0.2.20:6443

  kubectl config get-clusters
  NAME
  kubernetes
  test-cluster
  ```

## Bind cluster and account to be a context via `set-context`

  ```bash
  kubectl config set-context test \
    --cluster=test-cluster \
    --user=showerlee

  kubectl config get-contexts
  CURRENT   NAME                          CLUSTER        AUTHINFO           NAMESPACE
  *         kubernetes-admin@kubernetes   kubernetes     kubernetes-admin
            test                          test-cluster   showerlee
  ```

## Switch to context `test`

  ```bash
  kubectl config use-context test
  Switched to context "test".
  ```
