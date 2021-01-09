## Jenkins

## Namespace

- Create namespace

```
kubectl create namespace jenkins
```

### Credential

- Create username/password via `secret`

```
kubectl create secret -n jenkins generic jenkins-example-credential \
  --from-literal=username=admin \
  --from-literal=password=admin12345
```

- Decode `secret`

```
kubectl get secret jenkins-example-credential -o jsonpath='{.data}'
{"password":"YWRtaW4xMjM0NQ==","username":"YWRtaW4="}%

echo 'YWRtaW4xMjM0NQ==' | base64 --decode
echo 'YWRtaW4=' | base64 --decode
```
