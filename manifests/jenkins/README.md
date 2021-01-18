## Jenkins

These manifests intent to create Jenkins cluster in k8s which supports the Jenkins slaves as pods ochestrate in k8s automatically.

## Preparation

- Docker desktop on MacOS
- Kubernetes v1.19.3 via Docker desktop

## Network

We bind the Jenkins master and slave pods with corresponding k8s services so that each pods could talk with each other via k8s service name as domain names.

Furthermore, we embed `Nodeport` to Jenkins master so that we can visit Jenkins UI via http://localhost:31080

## Configuration
### Setup k8s namespace

```
kubectl create namespace jenkins
```

### Setup credential

- Create Jenkins username/password via `secret`

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

### Deploy jenkins cluster in k8s

```bash
kubectl apply -f manifests/jenkins/deployment.yml
```

### Check volumes.hostPath `jenkins_home` on Docker VM of docker-desktop

```bash
docker run -it --rm --privileged --pid=host justincormack/nsenter1
cd /containers/services/docker/tmp/upper/var/jenkins_home
...
```

### Jenkins pieline

We can simply create a Jenkins pipeline job and config our current github repo with relative path of Jenkinsfile `manifests/jenkins/Jenkinsfile`

Finally, run the build and just see the magic happens.
