k8s(v1.12.0)learning

master:	    10.0.2.20/24
node01:     10.0.2.21/24
node02:     10.0.2.22/24
storage01:  10.0.2.30/24

0. keep all k8s node as least 2 CPUS

1. stop firewalld and selinux
# systemctl stop firewalld
# systemctl disable firewalld
# setenforce 0

2.install k8s package from aliyun
cd /etc/yum.repo.d/
# wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# wget https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
# wget https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg

# cat > kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes Repo
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
enabled=1
EOF

# rpm --import rpm-package-key.gpg
# rpm --import yum-key.gpg
# yum install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-selinux-17.03.2.ce-1.el7.centos.noarch.rpm
# yum install docker-ce-17.03.2.ce-1.el7.centos
# yum install kubelet-1.12.0 kubeadm-1.12.0 kubectl-1.12.0 -y

3. download docker image from ali docker mirrors 
# sh pullimages.sh
===============================
#!/bin/bash
images=(kube-apiserver:v1.12.0 kube-controller-manager:v1.12.0 kube-scheduler:v1.12.0 kube-proxy:v1.12.0 pause:3.1 etcd:3.2.24 coredns:1.2.2)

for img in ${images[@]}
do
   docker pull   registry.cn-hangzhou.aliyuncs.com/showerlee/$img
   docker tag    registry.cn-hangzhou.aliyuncs.com/showerlee/$img   k8s.gcr.io/$img
   docker rmi  -f  registry.cn-hangzhou.aliyuncs.com/showerlee/$img
done
========================================
# remove all images if the version is incorrect
# docker rmi $(docker images -q) -f

4. keep nf bridge to 1
# echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
# echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
# sysctl -p

5. check what is installed in kubelet
# rpm -ql kubelet
============================
/etc/kubernetes/manifests
/etc/sysconfig/kubelet
/etc/systemd/system/kubelet.service
/usr/bin/kubelet
============================

6.skip swap
# swapoff -a
# vi /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--fail-swap-on=false"

6.1.add ipvs mode(to be verified)
# vi /etc/sysconfig/kubelet
KUBE_PROXY_MODE=ipvs

ip_vs, ip_vs_rr, ip_vs_wrr, ip_vs_sh, nf_conntrack_ipv4

7.change docker Cgroup Driver config is same as k8s
# docker info |grep "Cgroup Driver"
if "Cgroup Driver" value is "cgroupfs", put it into kubeadm
# vim /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
=================================
...
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver="cgroupfs"
...
==========================================

8.add registry mirrors:
vi /etc/docker/daemon.json 
===================================
{
  "registry-mirrors": ["https://m3s64qon.mirror.aliyuncs.com"]
}
========================================

8.enable and start docker kubelet
# systemctl enable kubelet docker
# systemctl daemon-reload && systemctl restart docker
# systemctl restart kubelet

9.kubeadm init
9.1 master:
# kubeadm reset
# kubeadm init --kubernetes-version=v1.12.0 --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12 --ignore-preflight-errors=Swap
9.2 node:
# kubeadm join 10.0.2.20:6443 --token 4crrgs.6cqwa55hho7ffpk3 --discovery-token-ca-cert-hash sha256:7938726b3257bad9fcf01c19f29ac11a73b09f6d94250528ed0c75dfcfc7d045 --ignore-preflight-errors=Swap

10.set k8s env in master
# mkdir -p $HOME/.kube
# cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# chown $(id -u):$(id -g) $HOME/.kube/config

11.check componentstatus
# kubectl get componentstatus

12.check node
# kubectl get nodes
NAME     STATUS     ROLES    AGE   VERSION
master   NotReady   master   24m   v1.12.0

13.install flannel to make node ready
# wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

13.1 replace quay.io/coreos/ to quay-mirror.qiniu.com/coreos/
# sed -i "s#quay.io/coreos/#registry.cn-hangzhou.aliyuncs.com/showerlee/#g" kube-flannel.yml
tips: replace gcr.io/google_containers/ to registry.aliyuncs.com/google_containers/ if needed
# kubectl apply -f kube-flannel.yml
# docker image ls
# kubectl get nodes
NAME     STATUS   ROLES    AGE   VERSION
master   Ready    master   77m   v1.12.0
# kubectl get pods -n kube-system -o wide
NAME                             READY   STATUS    RESTARTS   AGE     IP           NODE     NOMINATED NODE
coredns-576cbf47c7-4kqs6         1/1     Running   1          127m    10.244.0.4   master   <none>
coredns-576cbf47c7-8kr8z         1/1     Running   1          127m    10.244.0.5   master   <none>
etcd-master                      1/1     Running   1          52m     10.0.2.20    master   <none>
kube-apiserver-master            1/1     Running   1          52m     10.0.2.20    master   <none>
kube-controller-manager-master   1/1     Running   1          52m     10.0.2.20    master   <none>
kube-flannel-ds-amd64-j6hpk      1/1     Running   0          6m21s   10.0.2.22    node02   <none>
kube-flannel-ds-amd64-ttgdx      1/1     Running   0          12m     10.0.2.21    node01   <none>
kube-flannel-ds-amd64-zxlz2      1/1     Running   2          53m     10.0.2.20    master   <none>
kube-proxy-9hg9h                 1/1     Running   0          12m     10.0.2.21    node01   <none>
kube-proxy-qlw24                 1/1     Running   0          6m21s   10.0.2.22    node02   <none>
kube-proxy-wljvz                 1/1     Running   1          127m    10.0.2.20    master   <none>
kube-scheduler-master            1/1     Running   1          52m     10.0.2.20    master   <none>

14.Check namespace
# kubectl get ns
NAME          STATUS   AGE
default       Active   85m
kube-public   Active   85m
kube-system   Active   85m

15.kubectl help
# kubectl

16.check node specific info
# kubectl describe node node01

17.check cmd version
# kubectl version

18.check cluster info
# kubectl cluster-info

19.run help
# kubectl run --help

20.run nginx
# kubectl run nginx-deploy --image=daocloud.io/library/nginx:1.14-alpine --port=80 --replicas=1 --dry-run=true
# kubectl run nginx-deploy --image=daocloud.io/library/nginx:1.14-alpine --port=80 --replicas=1
# kubectl get deployment
# kubectl describe deployment nginx-deploy
# kubectl get pods -o wide

21.visit the nginx webpage via pod ip
# curl 10.244.2.4

what if we need visit via node ip

22.expose nginx
# kubectl expose --help
# kubectl expose deployment nginx-deploy --name=nginx --port=80 --target-port=80 --protocol=TCP

23.service
# kubectl get svc
# kubectl get pods -n kube-system -o wide | grep coredns
# kubectl get svc -n kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP   4h10m
# yum install bind-utils -y

client can use domain "nginx" to visit nginx webpage whatever nginx pod deleted and re-created.
# kubectl run client --image=busybox --replicas=1 -it --restart=Never
/ # cat /etc/resolv.conf
/ # wget -O - -q http://nginx:80/
...
/ # exit
# dig -t A nginx.default.svc.cluster.local @10.96.0.10
...
nginx.default.svc.cluster.local. 5 IN	A	10.111.155.221
...
# kubectl delete pods nginx-deploy-6c884698c9-2s5jb
# kubectl exec -it nginx-deploy-6c884698c9-hszz5 sh
/ # wget -O - -q http://nginx:80/
...

24.Auto completion kubectl bash
yum install bash-completion -y
source /etc/profile.d/bash_completion.sh
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bash_profile

25.check service details info
# kubectl describe service nginx
================================
Name:              nginx
Namespace:         default
Labels:            run=nginx-deploy
Annotations:       <none>
Selector:          run=nginx-deploy
Type:              ClusterIP
IP:                10.111.155.221
Port:              <unset>  80/TCP
TargetPort:        80/TCP
Endpoints:         10.244.1.11:80
Session Affinity:  None
Events:            <none>
================================
service will bind with pods if service selector is same as pod label.


26.check pods labels
# kubectl get pods --show-labels

27. edit service
# kubectl edit svc nginx

28. delete service
# kubectl delete svc nginx

29. check deloyment Selector
# kubectl describe deployment nginx-deploy |grep Selector
controller also bind with pods if deployment controller selector is same as pods label

30.auto scaling
# kubectl run myapp --image=ikubernetes/myapp:v1 --replicas=2
# kubectl get deployment -w
# kubectl get pods -o wide |grep myapp
myapp-6946649ccd-qtlzb          1/1     Running   0          69s   10.244.1.14   node01   <none>
myapp-6946649ccd-z8zf9          1/1     Running   0          69s   10.244.2.11   node02   <none>
# kubectl exec -it client-6577567544-6vfst sh
/ # wget -O - -q 10.244.1.14/hostname.html
myapp-6946649ccd-qtlzb
/ # wget -O - -q 10.244.1.14
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
/ # exit
add service to "myapp"
# kubectl expose deployment myapp --name=myapp --port=80
# kubectl exec -it client-6577567544-6vfst sh
# wget -O - -q myapp
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
/ # wget -O - -q myapp/hostname.html
myapp-6946649ccd-z8zf9
/ # while true; do wget -O - -q myapp/hostname.html; sleep 1; done
# kubectl scale --replicas=5 deployment myapp
/ # while true; do wget -O - -q myapp/hostname.html; sleep 1; done
update version to v2
# kubectl set image deployment myapp myapp=ikubernetes/myapp:v2
check updating status
# kubectl rollout status deployment myapp
roll back to last version
# kubectl rollout undo deployment myapp

31.check iptables
# iptables -nvL -t nat

32.expose port to outside node
# kubectl edit svc myapp
change ClusterIP to NodePort
save and quit
# kubectl get svc myapp
NAME    TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
myapp   NodePort   10.108.118.124   <none>        80:30053/TCP   60m

Then we can vist NodeIP:30053
# curl 10.0.2.20:30053
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>

33.check pods yaml file
# kubectl get pods myapp-6946649ccd-7pvxx -o yaml 

34.check available apiversion
# kubectl api-versions

35.k8s instruction
check pods:
# kubectl explain pods

check metadata of pods
# kubectl explain pods.matadata

check spec of pods
# kubectl explain pods.spec

check containers of spec of pods
# kubectl explain pods.spec.containers

<string>: string
<[]string>: array
<integer>: int
<[]Object>: array Object
<Object>: Object
<boolean>: bool

# pod-demo.yaml
==================================
apiVersion: v1
kind: Pod
metadata:
  name: pod-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
  - name: busybox
    image: busybox:latest
    command:
    - "/bin/sh"
    - "-c"
    - "echo $(date) >> /usr/share/nginx/html/index.html; sleep 5"
=======================================
# kubectl create -f pod-demo.yaml
# kubectl get pods pod-demo -o wide
# kubectl describe pods pod-demo
# kubectl logs pod-demo myapp
# kubectl logs pod-demo busybox

# kubectl delete -f pod-demo.yaml


36.labels
# kubectl create -f pod-demo.yaml
show all pods with labels
# kubectl get pods --show-labels

display all pods that key=APP or not
# kubectl get pods -L app

display certain pods that key=APP only.
# kubectl get pods -l app

display all pods that "key=APP and key=RUN" or not

add labels
# kubectl label pods pod-demo release=canary
# kubectl get pods -l app --show-labels

update labels
# kubectl label pods pod-demo release=stable --overwrite

label selecter
# kubectl label pods nginx-deploy-6c884698c9-wdjwn release=canary
# kubectl get pods -l release=canary
# kubectl get pods -l release=stable,app=myapp
# kubectl get pods -l release!=canary
# kubectl get pods -l "release in (canary,beta,alpha)"
# kubectl get pods -l "release notin (canary,beta,alpha)"

show labels in nodes
# kubectl get nodes --show-labels

add label to node
# kubectl label nodes node01 disktype=ssd
# kubectl get nodes -l disktype
# kubectl get nodes --show-labels

nodeSelector:
===================================
apiVersion: v1
kind: Pod
metadata:
  name: pod-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    - name: https
      containerPort: 443
  - name: busybox
    image: busybox:latest
    imagePullPolicy: IfNotPresent
    command:
    - "/bin/sh"
    - "-c"
    - "sleep 100"
  nodeSelector:
    disktype: ssd
===================================

anotations
==================================
apiVersion: v1
kind: Pod
metadata:
  name: pod-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    - name: https
      containerPort: 443
  - name: busybox
    image: busybox:latest
    imagePullPolicy: IfNotPresent
    command:
    - "/bin/sh"
    - "-c"
    - "sleep 100"
  nodeSelector:
    disktype: ssd
=======================================

check pods CMD syntax
# kubectl explain pods.spec.containers

LivenessProbe:
ExecAction:
# kubectl explain pods.spec.containers.livenessProbe.exec
# vi liveness-exec.yaml
=======================================
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec-pod
  namespace: default
spec:
  containers:
  - name: liveness-exec-container
    image: busybox:latest
    imagePullPolicy: IfNotPresent
    command: ["/bin/sh","-c","touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 3600"]
    livenessProbe:
      exec:
        command: ["test","-e","/tmp/healthy"]
      initialDelaySeconds: 1
      periodSeconds: 3
=======================================
# kubectl get pods -w

HTTPGetAction:
# kubectl explain pods.spec.containers.livenessProbe.httpGet
# vi liveness-httpget.yaml
=======================================
apiVersion: v1
kind: Pod
metadata:
  name: liveness-httpget-pod
  namespace: default
spec:
  containers:
  - name: liveness-httpget-container
    image: ikubernetes/myapp:v1
    imagePullPolicy: IfNotPresent
    ports:
    - name: http
      containerPort: 80
    livenessProbe:
      httpGet:
        port: http
        path: /index.html
      initialDelaySeconds: 1
      periodSeconds: 3
=======================================
We can try to login to the pod and delete nginx home page to see if Liveness Probe HTTPGetAction is triggered.
# kubectl exec -it liveness-httpget-pod -- /bin/sh
/ # rm -rf /usr/share/nginx/html/index.html
/ # command terminated with exit code 137
After the HTTPGetAction is triggered, the pods will be restart and the home page is back to normal


ReadinessProbe:
HTTPGetAction:
# vi readiness-httpget.yaml
=======================================
apiVersion: v1
kind: Pod
metadata:
  name: readiness-httpget-pod
  namespace: default
spec:
  containers:
  - name: readiness-httpget-container
    image: ikubernetes/myapp:v1
    imagePullPolicy: IfNotPresent
    ports:
    - name: http
      containerPort: 80
    readinessProbe:
      httpGet:
        port: http
        path: /index.html
      initialDelaySeconds: 1
      periodSeconds: 3
=======================================
We can try to login to the pod and delete nginx home page to see if the ReadinessProbe HTTPGetAction is triggered.
# kubectl exec -it liveness-httpget-pod -- /bin/sh
/ # rm -rf /usr/share/nginx/html/index.html
/ # exit
# kubectl get pods readiness-httpget-pod
NAME                    READY   STATUS    RESTARTS   AGE
readiness-httpget-pod   0/1     Running   0          6m7s
# kubectl exec -it liveness-httpget-pod -- /bin/sh
/ # echo "Hello World!!!" >> /usr/share/nginx/html/index.html
/ # exit
# kubectl get pods readiness-httpget-pod
NAME                    READY   STATUS    RESTARTS   AGE
readiness-httpget-pod   1/1     Running   0          8m6s

After the HTTPGetAction is triggered, the pods will not be ready until the home page is retrieved

Pod Lifecycle:
# kubectl explain pods.spec.containers.lifecycle
# kubectl explain pods.spec.containers.lifecycle.postStart
# kubectl explain pods.spec.containers.lifecycle.preStop

PostStart:
# cat poststart-pod.yaml
========================================================================
apiVersion: v1
kind: Pod
metadata:
  name: poststart-pod
  namespace: default
spec:
  containers:
  - name: busybox-httpd
    image: busybox:latest
    imagePullPolicy: IfNotPresent
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh","-c","echo Home_Page >> /tmp/index.html"]
    #command: ["/bin/sh", "-c", "sleep 3600"]
    command: ["/bin/httpd"]
    args: ["-f", "-h /tmp/"]
========================================================================
check if the index.html is created after pod startup
# kubectl exec -it poststart-pod -- /bin/sh
# cat /tmp/index.html
Home_Page


ReplicaSet:
# kubectl explain rs
# cat rs-demo.yaml
========================================================================
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: myapp
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      release: canary
  template:
    metadata:
      name: myapp-pod
      labels:
        app: myapp
        release: canary
        env: qa
    spec:
      containers:
      - name: myapp-container
        image: ikubernetes/myapp:v1
        ports:
        - name: http
          containerPort: 80
========================================================================
# kubectl get rs
# kubectl get pods
# kubectl describe pods myapp-bvxcq
# curl 10.244.1.35
pod will be re-created if one of the pods deleted
# kubectl delete pods myapp-bvxcq
# kubectl get pods --show-labels

change replicas number
# kubectl edit rs myapp
change "replicas: 2" to "replicas: 5"
# kubectl get pods

change image version
# kubectl edit rs myapp
change "image: ikubernetes/myapp:v1" to "image: ikubernetes/myapp:v2"
# kubectl get rs -o wide
# kubectl get pods -o wide
# curl 10.244.2.33
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>

pod will not update image version until any of them deleted
# kubectl delete pods myapp-4hx5r
# kubectl get pods -o wide
# curl 10.244.1.38
Hello MyApp | Version: v2 | <a href="hostname.html">Pod Name</a>

Deployment
# kubectl explain deploy
# kubectl explain deploy.spec.strategy
# kubectl explain deploy.spec.strategy.rollingUpdate

# cat deploy-demo.yaml
========================================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deploy
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      release: canary
  template:
    metadata:
      labels:
        app: myapp
        release: canary
    spec:
      containers:
      - name: myapp
        image: ikubernetes/myapp:v1
        ports:
        - name: http
          containerPort: 80
========================================================================
# kubectl get pods
# kubectl get rs
# kubectl get deploy

update replicas
alter deploy-demo.yaml and update "replicas: 2" to "replicas: 3"
# kubectl apply -f deploy-demo.yaml
# kubectl get pods
# kubectl describe deploy myapp
# kubectl get pods -l app=myapp -w

update version
alter deploy-demo.yaml and update "image: ikubernetes/myapp:v1" to "image: ikubernetes/myapp:v2"
# kubectl apply -f deploy-demo.yaml
# kubectl get pods -l app=myapp -w
# kubectl get rs -o wide

check rollout history
# kubectl rollout history deployment myapp-deploy

update replicas via cmd patch
# kubectl patch deployment myapp-deploy -p '{"spec":{"replicas":5}}'
# kubectl get pods

canary
# kubectl patch deployment myapp-deploy -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'
# kubectl describe deploy myapp-deploy

update version via set
# kubectl set image deployment myapp-deploy myapp=ikubernetes/myapp:v2 && kubectl rollout pause deployment myapp-deploy
check canary status
# kubectl get pods -l app=myapp -w
# kubectl rollout status deployment myapp-deploy

resume canary rollout
# kubectl rollout resume deployment myapp-deploy

get rs info
# kubectl get rs -o wide

check rollout history
# kubectl rollout history deployment myapp-deploy

rollout
# kubectl rollout undo deployment myapp-deploy --to-revision=1

daemonset
# kubectl explain ds
# docker pull daocloud.io/hadwinzhy/filebeat-docker:latest
# docker tag 287c306d65f7 ikubernetes/filebeat
# cat ds-demo.yaml
------------------------------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
      role: logstor
  template:
    metadata:
      labels:
        app: redis
        role: logstor
    spec:
      containers:
      - name: redis
        image: redis:4.0-alpine
        imagePullPolicy: IfNotPresent
        ports:
        - name: redis
          containerPort: 6379
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat-ds
  namespace: default
spec:
  selector:
    matchLabels:
      app: filebeat
      release: stable
  template:
    metadata:
      labels:
        app: filebeat
        release: stable
    spec:
      containers:
      - name: filebeat
        image: ikubernetes/filebeat:5.6.5-alpine
        imagePullPolicy: IfNotPresent
        env:
        - name: REDIS_HOST
          value: redis.default.svc.cluster.local
        - name: REDIS_LOG_LEVEL
          value: info
------------------------------
# kubectl apply -f ds-demo.yaml

expose redis port via service
# kubectl expose deployment redis --port=6379
# kubectl get svc

reload filebeat in pods
# kubectl exec -it filebeat-ds-pp8qs -- /bin/sh
# ps aux
# cat /etc/filebeat/filebeat.yml
# printenv
# kill -1 1

check cluster data in pods
# kubectl exec -it redis-664bbc646b-x5fvv  -- /bin/sh
/data # nestat -tnl
/data # nslookup redis.default.svc.cluster.local
redis.default.svc.cluster.local:6379> keys *

# check if the daemonSet created in each nodes
# kubectl get pods -l app=filebeat -o wide

rolling update
# kubectl explain ds.spec.updateStrategy.rollingUpdate

describe filebeat
# kubectl describe ds filebeat

update image version for filebeat
# kubectl set image daemonsets filebeat-ds filebeat=ikubernetes/filebeat:5.6.6-alpine
check version
# kubectl get ds -o wide

Service
# kubectl explain svc
# create a Service
# cat redis-svc.yaml
-----------------------------
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: default
spec:
  selector:
    app: redis
    role: logstor
  clusterIP: 10.97.97.97
  type: ClusterIP
  ports:
  - ports: 6379 # service port
    targetPort: 6379 # pod port
----------------------------------
# kubectl apply -f redis-svc.yaml
# kubectl get svc
# kubectl describe svc redis

service --> endpoint --> pod

# cat myapp-svc.yaml
--------------------------
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: default
spec:
  selector:
    app: myapp
    release: canary
  clusterIP: 10.99.99.99
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080 # node port
--------------------------
# dig -t A myapp.default.svc.cluster.local. @10.96.0.10
# kubectl apply -f myapp-svc.yaml
# kubectl get svc

visit nodeIP(10.0.2.20) to test myapp http connection
# while true; do curl http://10.0.2.20:30080/hostname.html; sleep 1; done
# while true; do curl http://10.0.2.20:30080; sleep 1; done

session affinity
return the same http response that comes from a fixed IP request 
# kubectl patch svc myapp -p '{"spec":{"sessionAffinity":"ClientIP"}}'
# kubectl describe svc myapp
# while true; do curl http://10.0.2.20:30080/hostname.html; sleep 1; done
myapp-deploy-574965d786-hnw67
myapp-deploy-574965d786-hnw67
myapp-deploy-574965d786-hnw67
myapp-deploy-574965d786-hnw67
return the same hostname

# kubectl patch svc myapp -p '{"spec":{"sessionAffinity":"None"}}'
# while true; do curl http://10.0.2.20:30080/hostname.html; sleep 1; done
myapp-deploy-574965d786-hnw67
myapp-deploy-574965d786-gf8z9
myapp-deploy-574965d786-gf8z9
return different hostname

headless service
# cat myapp-svc-headless.yaml
-------------------------
apiVersion: v1
kind: Service
metadata:
  name: myapp-svc
  namespace: default
spec:
  selector:
    app: myapp
    release: canary
  clusterIP: None
  ports:
  - port: 80
    targetPort: 80
--------------------------
# kubectl apply -f myapp-svc-headless.yaml
# kubectl get svc
NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.96.0.1     <none>        443/TCP        30d
myapp        NodePort    10.99.99.99   <none>        80:30080/TCP   62m
myapp-svc    ClusterIP   None          <none>        80/TCP         6s
redis        ClusterIP   10.97.97.97   <none>        6379/TCP       106m
# dig -t A myapp-svc.default.svc.cluster.local. @10.96.0.10
10.96.0.10 is kube-dns IP address.
should get from "kubectl get svc -n kube-system"

# kubectl get pods -o wide -l app=myapp

Ingress
# kubectl explain ingress
# kubectl explain ingress.spec


Create ingress controller
# kubectl create namespace ingress-nginx
# kubectl get ns
# mkdir ingress-nginx
# cd ingress-nginx
# for file in namespace.yaml configmap.yaml rbac.yaml with-rbac.yaml tcp-services-configmap.yaml default-backend.yaml; do wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.17.0/deploy/$file; done

Download alicloud docker repo in k8s nodes(Optional)
# docker pull registry.cn-hangzhou.aliyuncs.com/yindun/defaultbackend:1.5
# docker pull registry.cn-hangzhou.aliyuncs.com/gongdao-pub/nginx-ingress-controller:0.20.0
change image URL from origin to the above in default-backend.yaml and with-rbac.yaml

Create service for ingress controller
# vi service-nodeport.yaml
---------------------------
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
    nodePort: 30080
  - name: https
    port: 443
    targetPort: 443
    protocol: TCP
    nodePort: 30443
  selector:
    # need match "labels" in ingress controller
    app: ingress-nginx
---------------------------
# kubectl apply -f namespace.yaml
# kubectl apply -f ./
# kubectl get pods -n ingress-nginx

Create backend(service, deployment)integrated with ingress-controller(ingress, ingress controller) 
# cd ..
# mkdir ingress

Create service and deployment for demo
# vi deploy-demo.yaml
-----------------------------
apiVersion: v1
kind: Service
metadata:
  name: myapp-svc
  namespace: default
spec:
  selector:
    app: myapp
    release: canary
  ports:
  - name: http
    targetPort: 80
    port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deploy
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      release: canary
  template:
    metadata:
      labels:
        app: myapp
        release: canary
    spec:
      containers:
      - name: myapp
        image: ikubernetes/myapp:v1
        ports:
        - name: http
          containerPort: 80
-----------------------------
# kubectl apply -f deploy-demo.yaml
# kubectl get pods

create ingress imports into ingress controller
# vi ingress-myapp.yaml
---------------------------
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path:
        backend:
          # need match backend service name
          serviceName: myapp-svc
          servicePort: 80
--------------------------------
# kubectl apply -f ingress-myapp.yaml
# kubectl get ingress
# kubectl describe ingress myapp-ingress
# kubectl exec -it -n ingress-nginx nginx-ingress-controller-76c86d76c4-n4bbq -- /bin/sh

Set master DNS on any client could visit k8s master
# echo "10.0.2.20 myapp.example.com" >> /etc/hosts
# curl myapp.example.com:30080/hostname.html

Deploy tomcat and expose http via ingress
# vi tomcat-deploy.yaml
--------------------------------
apiVersion: v1
kind: Service
metadata:
  name: tomcat
  namespace: default
spec:
  selector:
    app: tomcat
    release: canary
  ports:
  - name: http
    targetPort: 8080
    port: 8080
  - name: ajp
    targetPort: 8009
    port: 8009
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tomcat-deploy
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tomcat
      release: canary
  template:
    metadata:
      labels:
        app: tomcat
        release: canary
    spec:
      containers:
      - name: tomcat
        image: tomcat:8.5.32-jre8-alpine
        ports:
        - name: http
          containerPort: 8080
        - name: ajp
          containerPort: 8009
------------------------------------
# kubectl apply -f tomcat-deploy.yaml

# vi ingress-tomcat.yaml
----------------------------------
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: tomcat-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: tomcat.example.com
    http:
      paths:
      - path:
        backend:
          serviceName: tomcat
          servicePort: 8080
--------------------------------------
# kubectl apply -f ingress-tomcat.yaml

Set master DNS on any client could visit k8s master
# echo "10.0.2.20 tomcat.example.com" >> /etc/hosts
# curl tomcat.example.com:30080

Deploy tomcat and expose https via ingress
# cd /opt/k8s/manifests/ingress
Create ssl private key
# openssl genrsa -out tls.key 2048

export self sign certificate
# openssl req -new -x509 -key tls.key -out tls.crt -subj /C=CN/ST=SX/L=XIAN/O=DevOps/CN=tomcat.example.com

create secret object via ssl cert
# kubectl create secret tls tomcat-ingress-secret --cert=tls.crt --key=tls.key
# kubectl get secret
# kubectl describe secret tomcat-ingress-secret

# kubectl explain ingress.spec.tls

Create ingress for tomcat tls
# vi ingress-tomcat-tls.yaml
------------------------------------
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: tomcat-ingress-tls
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  tls:
  - hosts:
    - tomcat.example.com
    secretName: tomcat-ingress-secret
  rules:
  - host: tomcat.example.com
    http:
      paths:
      - path:
        backend:
          serviceName: tomcat
          servicePort: 8080
------------------------------------
# kubectl apply -f ingress-tomcat-tls.yaml

# check ingress status
# kubectl get ingress
# kubectl describe ingress tomcat-ingress-tls
# kubectl exec -it -n ingress-nginx nginx-ingress-controller-567546b896-9h6sm -- /bin/sh

Set master DNS on any client could visit k8s master
# echo "10.0.2.20 tomcat.example.com" >> /etc/hosts
# curl https://tomcat.example.com:30443

Volumes
# kubectl explain pods.spec.volumes

emptyDir
# kubectl explain pods.spec.volumes.emptyDir
# kubectl explain pods.spec.containers
# cd /opt/k8s/manifests/
# mkdir volumes
# cd volumes

Create emptyDir volume
# vi pod-vol-demo.yaml
----------------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    volumeMounts:
    - name: html
      mountPath: /data/web/html/
  - name: busybox
    image: busybox:latest
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: html
      mountPath: /data/
    command:
    - "/bin/sh"
    - "-c"
    - "sleep 7200"
  volumes:
  - name: html
    emptyDir: {}
----------------------------------
# kubectl apply -f pod-vol-demo.yaml
# kubectl get pods

Write datetime to /data/index.html in busybox
# kubectl exec -it pod-demo -c busybox -- /bin/sh
/ # echo $(date) >> /data/index.html
/ # cat /data/index.html
Wed Mar 13 11:49:51 UTC 2019
/ # exit

Check datetime file in myapp
# kubectl exec -it pod-demo -c myapp -- /bin/sh
/ # cat /data/web/html/index.html
Wed Mar 13 11:49:51 UTC 2019

Create a pod with tomcat service and sidecar
# cat pod-vol-demo-sidecar.yaml
--------------------------------
apiVersion: v1
kind: Service
metadata:
  name: pod-demo-svc
  namespace: default
spec:
  selector:
    app: myapp
    tier: frontend
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30081
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    imagePullPolicy: IfNotPresent
    ports:
    - name: http
      containerPort: 80
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html/
  - name: busybox
    image: busybox:latest
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: html
      mountPath: /data/
    command:
    - "/bin/sh"
    - "-c"
    - "while true; do echo `date` >> /data/index.html; sleep 2; done"
  volumes:
  - name: html
    emptyDir: {}
-------------------------------
# kubectl apply -f pod-vol-demo-sidecar.yaml

Visit nodeIP:30081 to check if date wrote in nginx rootdir
# curl 10.0.2.20:30081

HostPath
Create hostpath volumes on node01 and node02
node01:
# mkdir -p /data/pod/volume1
# echo "node01.example.com"
node02:
# mkdir -p /data/pod/volume1
# echo "node02.example.com"
# vi pod-hostpath-vol.yaml
----------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-vol-hostpath
  namespace: default
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: html
    hostPath:
      path: /data/pod/volume1
      type: DirectoryOrCreate
------------------------------
# kubectl apply -f pod-hostpath-vol.yaml
# HOSTPATH_POD_IP=`kubectl get pods -o wide |grep pod-vol-hostpath | awk '{print $6}'`
# curl ${HOSTPATH_POD_IP}

NFS volume
Install NFS packages on each nodes
# yum -y install nfs-utils

Create NFS volume on storage01 
# mkdir -pv /data/volumes
# echo "<h1>NFS storage01</h1>" >> /data/volumes/index.html
# echo "/data/volumes 10.0.2.0/24(rw,no_root_squash)" > /etc/exports
# systemctl restart nfs
# ss -tnl |grep 2049

Set DNS host on each nodes
# echo "10.0.2.30 storage01" >> /etc/hosts

test to mount NFS volume on node01
# mount -t nfs storage01:/data/volumes /mnt
# umount /mnt

wirte nfs yaml on master
# vi pod-nfs-vol.yaml
---------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-vol-nfs
  namespace: default
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: html
    nfs:
      path: /data/volumes
      server: storage01
---------------------------
# kubectl apply -f pod-nfs-vol.yaml
# NFS_POD_IP=`kubectl get pods -o wide |grep pod-vol-hostpath | awk '{print $6}'`
# curl ${NFS_POD_IP}


PVC(persistentVolumeClaim)
# kubectl explain pods.spec.volumes.persistentVolumeClaim

storage01:
Create 5 NFS volumes
# cd /data/volumes/
# mkdir v{1,2,3,4,5}
# vi /etc/exports
------------------------------
/data/volumes/v1 10.0.2.0/24(rw,no_root_squash)
/data/volumes/v2 10.0.2.0/24(rw,no_root_squash)
/data/volumes/v3 10.0.2.0/24(rw,no_root_squash)
/data/volumes/v4 10.0.2.0/24(rw,no_root_squash)
/data/volumes/v5 10.0.2.0/24(rw,no_root_squash)
---------------------------------
# exportfs -arv
# showmount -e

Create PV
tip: PV is in cluster class, no need to set namespace
Master:
# kubectl explain pv.spec
# cd /opt/k8s/manifests/volumes
# vi pv-demo.yaml
------------------------
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv001
  labels:
    name: pv001
spec:
  nfs:
    path: /data/volumes/v1
    server: storage01
  accessModes: ["ReadWriteMany", "ReadWriteOnce"]
  capacity:
    storage: 1Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv002
  labels:
    name: pv002
spec:
  nfs:
    path: /data/volumes/v2
    server: storage01
  accessModes: ["ReadWriteOnce"]
  capacity:
    storage: 1Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv003
  labels:
    name: pv003
spec:
  nfs:
    path: /data/volumes/v3
    server: storage01
  accessModes: ["ReadWriteMany", "ReadWriteOnce"]
  capacity:
    storage: 1Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv004
  labels:
    name: pv004
spec:
  nfs:
    path: /data/volumes/v4
    server: storage01
  accessModes: ["ReadWriteMany", "ReadWriteOnce"]
  capacity:
    storage: 1.5Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv005
  labels:
    name: pv005
spec:
  nfs:
    path: /data/volumes/v5
    server: storage01
  accessModes: ["ReadWriteMany", "ReadWriteOnce"]
  capacity:
    storage: 1Gi
----------------------------
# kubectl apply -f pv-demo.yaml
# kubectl get pv
NAME    CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
pv001   1Gi        RWO,RWX        Retain           Available                                   5s
pv002   1Gi        RWO            Retain           Available                                   5s
pv003   1Gi        RWO,RWX        Retain           Available                                   5s
pv004   1536Mi     RWO,RWX        Retain           Available                                   5s
pv005   1Gi        RWO,RWX        Retain           Available                                   5s

Create pvc bound pv on pod
# cat pod-vol-pvc.yaml
------------------------------
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mypvc
  namespace: default
spec:
  accessModes: ["ReadWriteMany"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-vol-pvc
  namespace: default
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: html
    persistentVolumeClaim:
      claimName: mypvc
------------------------------
# kubectl apply -f pod-vol-pvc.yaml

Check pv
# kubectl get pv
NAME    CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM           STORAGECLASS   REASON   AGE
pv001   1Gi        RWO,RWX        Retain           Bound       default/mypvc                           13m
pv002   1Gi        RWO            Retain           Available                                           13m
pv003   1Gi        RWO,RWX        Retain           Available                                           13m
pv004   1536Mi     RWO,RWX        Retain           Available                                           13m
pv005   1Gi        RWO,RWX        Retain           Available                                           13m

Check pvc
# kubectl get pvc
NAME    STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mypvc   Bound    pv001    1Gi        RWO,RWX                       2m19s

Check pod bound pvc
# kubectl describe pods pod-vol-pvc

Secret and Configmap volumes
# kubectl explain pod.spec.volumes

# kubctl explain pods.spec.containers.env
# kubectl explain configmap

Create a configmap via CLI
# kubectl create configmap nginx-config --from-literal=nginx_port=8080 --from-literal=server_name=myapp.example.com
# kubectl get configmaps
# kubectl describe configmaps
Name:         nginx-config
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
nginx_port:
----
8080
server_name:
----
myappexample.com
Events:  <none>

Create a configmap from a file
# mkdir configmap
# cd configmap
# vi www.conf
----------------------
server {
        server_name myapp.example.com;
        listen 80;
        root /data/web/html;
}
------------------------
# kubectl create configmap nginx-www --from-file=./www.conf
check configmap
# kubectl get cm nginx-www -o yaml
# kubectl describe cm nginx-www

Create a pod applied configmap as a property
# vi pod-configmap.yaml
---------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-cm-1
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    env:
    - name: NGINX_SERVER_PORT
      valueFrom:
        configMapKeyRef:
          name: nginx-config
          key: nginx_port
    - name: NGINX_SERVER_NAME
      valueFrom:
        configMapKeyRef:
          name: nginx-config
          key: server_name
------------------------------
# kubectl apply -f pod-configmap.yaml

Check env inside pod
# kubectl exec -it pod-cm-1 -- /bin/sh
/ # env 

Create a pod applied configmap as a volume for transfering all properties
# vi pod-configmap-2.yaml
--------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-cm-2
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    volumeMounts:
    - name: nginxconf
      mountPath: /etc/nginx/config.d/
      readOnly: true
  volumes:
  - name: nginxconf
    configMap:
      name: nginx-config
-----------------------------
# kubectl apply -f pod-configmap-2.yaml
# kubectl get pods
# kubectl exec -it pod-cm-2 -- /bin/sh
/ # cd /etc/nginx/config.d
/ # ls
nginx_port   server_name

Change configmap and pod will automatically apply this change.
# kubectl edit configmap nginx-conf
change 8080 to 8088
# kubectl exec -it pod-cm-2 -- /bin/sh
/ # cat /etc/nginx/conf.d/nginx_port
8088

Create a pod applied configmap as a volume for mount file
# vi pod-configmap-3.yaml
--------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-cm-3
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    volumeMounts:
    - name: nginxconf
      mountPath: /etc/nginx/conf.d/
      readOnly: true
  volumes:
  - name: nginxconf
    configMap:
      name: nginx-www
-----------------------------
# kubectl apply -f pod-configmap-2.yaml
# kubectl get pods
# kubectl exec -it pod-cm-3 -- /bin/sh
/ # cd /etc/nginx/conf.d
/ # cat www.conf
server {
	server_name myapp.example.com;
	listen 80;
	root /data/web/html;
}

Check if nginx applied www.conf configuration
/ # nginx -h
/ # nginx -T

Write index.html in /data/web/heml
/ # mkdir -p /data/web/html 
/ # echo "<h1>Nginx server configured by CM </h1>" >> /data/web/html/index.html
/ # exit

Visit the nginx website
# CM_POD_IP=`kubectl get pods -o wide |grep pod-cm-3 | awk '{print $6}'`
# echo "$CM_POD_IP myapp.example.com" >> /etc/hosts
# curl myapp.example.com
<h1>Nginx server configured by CM </h1>

Change configmap and pod will automatically apply this change.
# kubectl edit configmap nginx-www
change 80 to 8080
# kubectl exec -it pod-cm-3 -- /bin/sh

Waiting pod applied this change
/ # watch cat /etc/nginx/conf.d/www.conf

Check if 8080 port is listening.
/ # netstat -tnl
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN

Need to reload nginx to applies the running setting.
/ # nginx -s reload

Check again
/ # netstat -tnl
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State
tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN

/ # exit
# curl myapp.example.com:8080

Secret
# kubectl create secret --help
Available Commands:
  docker-registry Create a secret for use with a Docker registry
  generic         Create a secret from a local file, directory or literal value
  tls             Create a TLS secret

generic:
# kubectl create secret generic mysql-root-password --from-literal=password=MyP@ss123
# kubectl get secret
# kubectl describe secret mysql-root-password
# kubectl get secret mysql-root-password -o yaml
# echo TXlQQHNzMTIz | base64 -d
# vi pod-secret-1.yaml
------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-secret-1
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    env:
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysql-root-password
          key: password
--------------------------
# kubectl apply -f pod-secret-1.yaml
# kubectl exec pod-secret-1 -- printenv

StatefulSet
# kubectl explain sts.spec
# vi stateful-demo.yaml
---------------------------
apiVersion: v1
kind: Service
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: myapp-pod
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: myapp
spec:
  serviceName: myapp
  replicas: 3
  selector:
    matchLabels:
      app: myapp-pod
  template:
    metadata:
      labels:
        app: myapp-pod
    spec:
      containers:
      - name: myapp
        image: ikubernetes/myapp:v1
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: myappdata
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: myappdata
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 2Gi
------------------------------
# kubectl apply -f stateful-demo.yaml
# kubectl get svc
# kubectl get sts
# kubectl get pvc

Parse statefulSet DNS
# kubectl exec -it myapp-0 -- /bin/sh
/ # nslookup myapp-0.myapp.default.svc.cluster.local
/ # nslookup myapp-1.myapp.default.svc.cluster.local
/ # nslookup myapp-2.myapp.default.svc.cluster.local

Rolling update
Scale up replicas to 5
# kubectl scale sts myapp --replicas=5

Scale down replicas to 2
# kubectl patch sts myapp -p '{"spec":{"replicas":2}}'

Upgrade version(canary release)
# kubectl explain sts.spec.updateStrategy.rollingUpdate
# kubectl scale sts myapp --replicas=5

Set partition=4, so only myapp-4 will upgrade
# kubectl patch sts myapp -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":4}}}}'
# kubectl describe sts myapp

upgrade version
# kubectl set image sts/myapp myapp=ikubernetes/myapp:v2
# kubectl get sts -o wide

check myapp-4 image version
# kubectl get pods myapp-4 -o yaml | grep image
checkout myapp-4 image version is v2

check myapp-3 image version
# kubectl get pods myapp-3 -o yaml | grep image
checkout myapp-3 image version is v1

Set partition=2, so myapp-2 myapp-3 myapp-4 will upgrade
# kubectl patch sts myapp -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'

check myapp-2 image version
# kubectl get pods myapp-2 -o yaml | grep image
checkout myapp-2 image version is v2

Set partition=0, so all pods will upgrade
# kubectl patch sts myapp -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'

check myapp-0 image version
# kubectl get pods myapp-0 -o yaml | grep image
checkout myapp-0 image version is v2

Authentication:
# kubectl api-versions

Open k8s proxy:
# kubectl proxy --port=8080 &
# ss -tnl | grep 8080
# curl http://localhost:8080/api/v1/namespaces/
k8s api server will response json data related to k8s namespaces
the yaml file we fill in k8s will transfer to json file that k8s understands.

we can check info from kubectl:
# kubectl get deploy coredns -n kube-system
Or:
# curl http://localhost:8080/apis/apps/v1/namespaces/kube-system/deployments/coredns

Serviceaccount
# kubectl explain pods.spec.serviceAccountName
# kubectl create serviceaccount --help
# kubectl create serviceaccount mysa -o yaml --dry-run > test.yaml
# kubectl create serviceaccount mysa -o yaml --export
# kubectl get pods myapp-deploy-574965d786-4brhs -o yaml --export

# kubectl create serviceaccount admin
# kubectl get sa
# kubectl describle sa admin
# kubectl get secret

create pod vi customize serviceaccount
# vi pod-sa-demo.yaml
-------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-sa-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
    ports:
    - name: http
      containerPort: 80
    - name: https
      containerPort: 443
  serviceAccountName: admin
-------------------------
# kubectl apply -f pod-sa-demo.yaml
# kubectl describe pods pod-sa-demo.yaml

k8s API authentication
# kubectl config --help       
# kubectl config view
-------------------------
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://10.0.2.20:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: REDACTED
    client-key-data: REDACTED
---------------------------
# cat ~/.kube/config

k8s pki dir
# ls /etc/kubernetes/pki 

Create k8s user, context, cluster
safely create a private key 
# cd /etc/kubernetes/pki
# (umask 077; openssl genrsa -out example.key 2048)

sign a new crt via ca.crt based on the private key
# openssl req -new -key example.key -out example.csr -subj "/CN=example"
# openssl x509 -req -in example.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out example.crt -days 365

check the new crt info
# openssl x509 -in example.crt -text -noout
 
Set k8s user
# kubectl config set-credentials example --client-certificate=./example.crt --client-key=./example.key --embed-certs=true

Set k8s context
# kubectl config set-context example@kubernetes --cluster=kubernetes --user=example

Check new user and context
# kubectl config view

Switch current-context
# kubectl config use-context example@kubernetes

cannot list resource due to example is lack of k8s proper permission
# kubectl get pods
Error from server (Forbidden): pods is forbidden: User "example" cannot list resource "pods" in API group "" in the namespace "default"

# Switch k8s admin back
# kubectl config use-context kubernetes-admin@kubernetes

Set k8s cluster
# kubectl config set-cluster --help
# kubectl config set-cluster --kubeconfig
# kubectl config set-cluster mycluster --server="https://10.0.2.20:6443" --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs=true 

Set a customize kubeconfig(Default is ~/.kube/config)
# kubectl config set-cluster mycluster --kubeconfig=/tmp/test.conf --server="https://10.0.2.20:6443" --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs=true
# check customize kubeconfig
# kubectl config view --kubeconfig=/tmp/test.conf


RBAC(Role-based access control)
Create role
# cd /opt/k8s/manifests
# kubectl create role --help
# kubectl create role pods-reader --verb=get,list,watch --resource=pods --dry-run
# kubectl create role pods-reader --verb=get,list,watch --resource=pods --dry-run -o yaml > role-demo.yaml
# vi role-demo.yaml
-----------------------------
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pods-reader
  namespace: default
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
---------------------------------
# kubectl apply -f role-demo.yaml
# kubectl get role
# kubectl describe role pods-reader

Create rolebinding
# kubectl create rolebinding --help
# kubectl create rolebinding example-read-pods --role=pods-reader --user=example --dry-run -o yaml > rolebinding-demo.yaml
# kubect apply -f rolebinding-demo.yaml
# kubectl describe rolebinding example-read-pods

switch user:
# kubectl config use-context example@kubernetes
# kubectl get pods # pass
# kubectl logs myapp-0 # failed
# kubectl get pods -n kube-system
switch back:
# kubectl config use-context kubernetes-admin@kubernetes

Create clusterrole
# kubectl create clusterrole cluster-reader --verb=get,list,watch --resource=pods -o yaml --dry-run > clusterrole-demo.yaml
# kubectl apply -f clusterrole-demo.yaml

create new system user and bind the role to this user
# useradd ik8s
# cp -rf ~/.kube /home/ik8s/
# chown -R ik8s.ik8s /home/ik8s/
# su - ik8s
$ kubectl config use-context example@kubernetes
$ kubectl config view

Delete rolebinding example-read-pods and apply a new clusterrolebinding
# kubectl delete rolebinding example-read-pods
# kubectl create clusterrolebinding example-read-all-pods --clusterrole=cluster-reader --user=example --dry-run -o yaml > clusterrolebinding-demo.yaml
# kubectl apply -f clusterrolebinding-demo.yaml
# kubectl get clusterrolebinding
# kubectl describe clusterrolebinding example-read-all-pods

Check if ik8s user has all read permission through out all namespaces
$ kubectl get pods -n kube-system
...

Delete clusterrolebinding and create rolebinding to apply a clusterrole
# kubectl delete clusterrolebinding example-read-all-pods
# kubectl create rolebinding example-read-pods --clusterrole=cluster-reader --user=example --dry-run -o yaml > rolebinding-clusterrole-demo.yaml
# vi rolebinding-clusterrole-demo.yaml
-----------------------------------------
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: example-read-pods
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-reader
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: example
----------------------------------------------
# kubectl apply -f rolebinding-clusterrole-demo.yaml
# kubectl describe rolebinding example-read-pods

Check if ik8s user has all read permission in default rather than other namespaces
$ kubectl get pods -n default
...
$ kubectl get pods -n kube-system
Error from server (Forbidden): pods is forbidden: User "example" cannot list resource "pods" in API group "" in the namespace "kube-system"
So rolebinding applied a clusterrole will be downgrade to only visit the namespace that defined in rolebinding

Check out system build-in clusterrole
# kubectl get clusterrole
# kubectl get clusterrole admin -o yaml

Create default-admin rolebinding
# kubectl create rolebinding default-ns-admin --clusterrole=admin --user=example

Check if ik8s user has delete permission in default namespace
$ kubectl delete pods myapp-deploy-574965d786-46ls2
pod "myapp-deploy-574965d786-46ls2" deleted

Check if ik8s user has read permission in kube-system namespace
$ kubectl get pods -n kube-system
Error from server (Forbidden): pods is forbidden: User "example" cannot list resource "pods" in API group "" in the namespace "kube-system

Check out cluster-admin clusterrolebinding
# kubectl get clusterrolebinding cluster-admin -o yaml
---------------------------------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  creationTimestamp: 2019-03-08T10:06:24Z
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: cluster-admin
  resourceVersion: "113"
  selfLink: /apis/rbac.authorization.k8s.io/v1/clusterrolebindings/cluster-admin
  uid: d4a7aec8-4189-11e9-8f4c-080027741c63
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:masters
----------------------------------------

Check out if kubernetes-admin in group of system:masters
# cd /etc/kubernetes/pki/
# openssl x509 -in ./apiserver-kubelet-client.crt -text -noout

Build Dashboard
1.Download dashboard yaml
# cd /opt/k8s/
# wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
2.Change image repo
# sed -i 's#k8s.gcr.io#registry.cn-hangzhou.aliyuncs.com/showerlee#g' kubernetes-dashboard.yaml

Authenticate via token
# kubectl apply -f kubernetes-dashboard.yaml
# kubectl get pods -n kube-system
# kubectl get svc -n kube-system
# kubectl patch svc kubernetes-dashboard -p '{"spec": {"ports": [{"port": 443,"protocol": "TCP","targetPort": 8443,"nodePort": 32443}],"type": "NodePort"}}' -n kube-system

Create serviceaccount for dashboard
# kubectl create serviceaccount dashboard-admin -n kube-system

Create clusterrolebinding for serviceaccount
# kubectl create clusterrolebinding dashboard-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin 

# SECRET_INS=`kubectl get secret -n kube-system | grep dashboard-admin | awk '{print $1}'`
# TOKEN_CODE=`kubectl describe secret $SECRET_INS -n kube-system | grep token: | awk '{print $2}'`
# echo $TOKEN_CODE
visit https://10.0.2.20:32443 via chrome and use this TOKEN_CODE

Authenticate via kubeconfig
1.Create private cert for dashboard (to be verified)
创建dashboard私钥
# cd /etc/kubernetes/pki
# (umask 077; openssl genrsa -out dashboard.key 2048)
创建证书签署请求
# openssl req -new -key dashboard.key -out dashboard.csr -subj "/O=example/CN=dashboard.example.com"
使用系统ca.crt, ca.key给我们的证书签证,并生成私钥证书
# openssl x509 -req -in dashboard.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out dashboard.crt -days 365

2.Create generic secret via dashboard private cert
# cd /etc/kubernetes/pki
# kubectl create secret generic dashboard-cert -n kube-system --from-file=dashboard.crt=./dashboard.crt --from-file=dashboard.key=./dashboard.key

3.Create serviceaccount
# kubectl create serviceaccount def-ns-admin -n default 

4,Create rolebinding
# kubectl create rolebinding def-ns-admin --clusterrole=admin --serviceaccount=default:def-ns-admin

5.set kube config
# kubectl config set-cluster kubernetes --certificate-authority=./ca.crt --server="https://10.0.2.20:6443" --embed-certs=true --kubeconfig=/root/def-ns-admin.conf
# kubectl config view --kubeconfig=/root/def-ns-admin.conf

# SECRET_NAME=`kubectl get secrets |grep def-ns-admin | awk '{print $1}'`
# DEF_NS_ADMIN_SECRET=`kubectl get secret $SECRET_NAME -o jsonpath={.data.token} | base64 -d`

# kubectl config set-credentials def-ns-admin --token=$DEF_NS_ADMIN_SECRET --kubeconfig=/root/def-ns-admin.conf
# kubectl config set-context def-ns-admin@kubernetes --cluster=kubernetes --user=def-ns-admin --kubeconfig=/root/def-ns-admin.conf

# kubectl config use-context def-ns-admin@kubernetes --kubeconfig=/root/def-ns-admin.conf
# kubectl config view --kubeconfig=/root/def-ns-admin.conf

# kubectl apply -f kubernetes-dashboard.yaml
# kubectl get pods -n kube-system
# kubectl get svc -n kube-system
# kubectl patch svc kubernetes-dashboard -p '{"spec": {"ports": [{"port": 443,"protocol": "TCP","targetPort": 8443,"nodePort": 32443}],"type": "NodePort"}}' -n kube-system

visit https://10.0.2.20:32443 via chrome
scp master's kube config to local
# scp -P10020 root@127.0.0.1:/root/def-ns-admin.conf ./def-ns-admin.conf
use def-ns-admin.conf for the dashboard authentication

Flannel
Be configured as DaemonSet controller(DaemonSet num=node num), each node will run one flannel.
# kubectl get configmap -n kube-system
# kubectl get daemonset -n kube-system

Flannel config
# kubectl get configmap -n kube-system
# kubectl get configmap kube-flannel-cfg -o json -n kube-system
Default flannel type is vxlan

Change vxlan to directrouting
# cd /opt/k8s/manifest/
# kubectl apply -f deploy-demo.yaml
# kubectl get pods -o wide
# kubectl exec -it myapp-deploy-574965d786-4bdmx -- /bin/sh
# kubectl exec -it myapp-deploy-574965d786-plj5m -- /bin/sh
myapp-deploy in node1 can't ping myapp-deploy in node2

grab icmp pack
# yum install tcpdump
# tcpdump -i enp0s3 -nn icmp
check bridge info
# yum install bridge-utils
# brctl show cni0

So we need to add directrouting to get myapp-deploy in node1 ping myapp-deploy in node2
# mkdir flannel
# cd flannel/
# wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

replace quay.io/coreos/ to quay-mirror.qiniu.com/coreos/
# sed -i "s#quay.io/coreos/#quay-mirror.qiniu.com/coreos/#g" kube-flannel.yml

# vi kube-flannel.yml
add "Directrouting": true after vxlan
# kubectl delete -f kube-flannel.yml
# kubectl apply -f kube-flannel.yml
# cd ../manifests
# kubectl delete -f deploy-demo.yaml
# kubectl apply -f deploy-demo.yaml
# kubectl get configmaps kube-flannel-cfg -o json -n kube-system
# kubectl edit configmaps kube-flannel-cfg -n kube-system
# ip route show
# yum install net-tools -y
# route -n
# kubectl exec -it myapp-deploy-574965d786-4bdmx -- /bin/sh
# kubectl exec -it myapp-deploy-574965d786-plj5m -- /bin/sh
grab icmp package in node01 or node02
# tcpdump -i enp0s3 -nn icmp
myapp-deploy in node1 can ping myapp-deploy in node2

canel(Flannel+calico)
# curl https://docs.projectcalico.org/v3.7/manifests/canal.yaml -O
# sed -i "s#quay.io/coreos/#quay-mirror.qiniu.com/coreos/#g" canal.yaml
# kubectl apply -f canal.yaml
# kubectl get pod -n kube-system -o wide

two pods in separate namespaces, can they talk to each other? if they can, how to cut them off.
# kubectl explain networkpolicy
# kubectl create namespace dev
# kubectl create namespace prod
# mkdir networkpolicy
# cd networkpolicy
# vi ingress-def.yaml
---------------------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
----------------------------
any client outside dev namespace prohibite visiting pods in dev.
# kubectl apply -f ingress-def.yaml -n dev
# kubectl get netpol -n dev
# vi pod-a.yaml
---------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod1
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
----------------------------
Create pod1 in dev namespace
# kubectl apply -f pod-a.yaml -n dev
# kubectl get pods -n dev -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP           NODE     NOMINATED NODE
pod1   1/1     Running   0          22s   10.244.1.6   node01   <none>

Check if master node can visit pod1 in dev
# curl 10.244.1.6
...
no response

Create pod1 in prod namespace
# kubectl apply -f pod-a.yaml -n prod
# kubectl get pods -n prod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP           NODE     NOMINATED NODE
pod1   1/1     Running   0          3s    10.244.2.4   node02   <none>

Check if master node can visit pod1 in prod
# curl 10.244.2.4
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
prod doesn't set any protocal

whitelist pod1 all traffic in dev for the ingress protocol
so that any client allow to visit pod1 in dev
# vi ingress-def.yaml
----------------------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  ingress:
  - {}
  policyTypes:
  - Ingress
--------------------------
# kubectl apply -f ingress-def.yaml -n dev

Check if master node can visit pod1 in dev
# curl 10.244.1.6
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
it allows to visit

allow specific pods in whitelist via label, green light specific ingress traffic
# kubectl delete -f ingress-def.yaml
# kubectl label pods pod1 app=myapp -n dev
# vi allow-netpolicy-demo.yaml
----------------------------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-myapp-ingress
spec:
  podSelector:
    matchLabels:
      app: myapp
  ingress:
  - from:
    - ipBlock:
        cidr: 10.244.0.0/16
        except:
        - 10.244.1.2/32
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
---------------------------------
# kubectl apply -f allow-netpolicy-demo.yaml -n dev
# kubectl get netpol -n dev
# curl 10.244.1.6
Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
# curl 10.244.1.6:443
curl: (7) Failed connect to 10.244.1.6:443; Connection refused
# curl 10.244.1.6:8080
...
no response

Define egress protocol to block all output traffic
# vi egress-def.yaml
-----------------------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress 
--------------------------
# kubectl apply -f egress-def.yaml -n prod
# kubectl apply -f pod-a.yaml -n prod
# kubectl exec pod1 -it -n prod -- /bin/sh

Check if pod1 can ping coredns(10.244.0.44)
/ # ping 10.244.0.44
...
no response

Define egress protocol to unblock all output traffic
# vi egress-def.yaml
-----------------------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector: {}
  egress:
  - {}
  policyTypes:
  - Egress 
--------------------------
# kubectl apply -f egress-def.yaml -n prod
Check if pod1 can ping coredns(10.244.0.44)
/ # ping 10.244.0.44
PING 10.244.0.44 (10.244.0.44): 56 data bytes
64 bytes from 10.244.0.44: seq=0 ttl=62 time=1.054 ms
64 bytes from 10.244.0.44: seq=1 ttl=62 time=0.899 ms
...


Highlevel-scheduler
1.nodeSelector
# kubectl explain pods.spec.nodeSelector
# cd /opt/k8s/manifest/
# mkdir schedule
# cd schedule
# cp ../pod-demo.yaml ./
# vi pod-demo.yaml
-------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
  nodeSelector:
    disktype: ssd
-----------------------------
# kubectl label nodes node01 disktype=ssd
# kubectl apply -f pod-demo.yaml
# kubectl get pods pod-demo -o wide
NAME       READY   STATUS    RESTARTS   AGE     IP           NODE     NOMINATED NODE
pod-demo   1/1     Running   0          4m42s   10.244.1.7   node01   <none>
# kubectl get nodes --show-labels

# kubectl delete -f pod-demo.yaml
# vi pod-demo.yaml
-------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
  nodeSelector:
    disktype: harddisk
-----------------------------
# kubectl apply -f pod-demo.yaml
# kubectl get pods pod-demo -o wide
NAME       READY   STATUS    RESTARTS   AGE   IP       NODE     NOMINATED NODE
pod-demo   0/1     Pending   0          16s   <none>   <none>   <none>
# kubectl describe pods pod-demo
So nodeSelector is mandatory, it won't pass the predicate until matches node label

We can set label in node02, then pod-demo will settle in node02 that matches the nodeSelector
# kubectl label nodes node02 disktype=harddisk
# kubectl get pods pod-demo -o wide
NAME       READY   STATUS    RESTARTS   AGE     IP           NODE     NOMINATED NODE
pod-demo   1/1     Running   0          3m13s   10.244.2.5   node02   <none>

2.nodeAffinity
required nodeAffinity
# kubectl explain pods.spec.affinity.nodeAffinity
# vi pod-nodeaffinity-demo.yaml
--------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-node-affinity-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: zone
            operator: In
            values:
            - foo
            - bar
-----------------------------
# kubectl apply -f pod-nodeaffinity-demo.yaml
# kubectl get pods pod-node-affinity-demo
NAME                     READY   STATUS    RESTARTS   AGE
pod-node-affinity-demo   0/1     Pending   0          100s

prefered nodeAffinity
# vi pod-nodeaffinity-demo-2.yaml
--------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-node-affinity-demo-2
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - preference:
          matchExpressions:
          - key: zone
            operator: In
            values:
            - foo
            - bar
        weight: 60
-----------------------------
# kubectl apply -f pod-nodeaffinity-demo-2.yaml
# kubectl get pods pod-node-affinity-demo-2
NAME                       READY   STATUS    RESTARTS   AGE
pod-node-affinity-demo-2   1/1     Running   0          9s

podAffinity
Affinity between pods in nodes, certain IT technology required pods with same feature tend to stick together in a node.
For example:
apache, mysql should stick together as a LAMP cluster in a node.
LAMP clusters should be separate with each other in different nodes. 

podAntiAffinity
vice versa

podAffinity demo
# kubectl explain pods.spec.affinity.podAffinity
# vi pod-required-affinity-demo.yaml
--------------------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-first
  namespace: default
  labels:
    app: myapp
    tier: frontend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-secend
  namespace: default
  labels:
    app: db
    tier: backend
  annotations:
    example.com/created-by: "cluster admin"
spec:
  containers:
  - name: busybox
    image: busybox:latest
    imagePullPolicy: IfNotPresent
    command: ["sh", "-c", "sleep 3600"]
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - {key: app, operator: In, values: ["myapp"]}
        topologyKey: kubernetes.io/hostname
--------------------------------------------
# kubectl apply -f pod-required-affinity-demo.yaml

pod AntiAffinity
# kubectl explain pods.spec.affinity.podAntiAffinity
# vi pod-required-anti-affinity-demo.yaml
--------------------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-first
  namespace: default
  labels:
    app: myapp
    tier: frontend
spec:
  containers:
  - name: myapp
    image: ikubernetes/myapp:v1
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-secend
  namespace: default
  labels:
    app: db
    tier: backend
spec:
  containers:
  - name: busybox
    image: busybox:latest
    imagePullPolicy: IfNotPresent
    command: ["sh", "-c", "sleep 3600"]
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - {key: app, operator: In, values: ["myapp"]}
        topologyKey: kubernetes.io/hostname
--------------------------------------------
# kubectl apply -f pod-required-anti-affinity-demo.yaml


taint schedule
taint for node, toleration for pod.
# kubectl explain nodes.spec.taints
# kubectl describe node master |grep Taints
Taints:             node-role.kubernetes.io/master:NoSchedule
# kubectl describe pods -n kube-system kube-flannel-ds-amd64-74kgn | grep Tolerations
Tolerations:     :NoSchedule

# kubectl taint --help
Examples:
  # Update node 'foo' with a taint with key 'dedicated' and value 'special-user' and effect
'NoSchedule'.
  # If a taint with that key and effect already exists, its value is replaced as specified.
  kubectl taint nodes foo dedicated=special-user:NoSchedule

  # Remove from node 'foo' the taint with key 'dedicated' and effect 'NoSchedule' if one exists.
  kubectl taint nodes foo dedicated:NoSchedule-

  # Remove from node 'foo' all the taints with key 'dedicated'
  kubectl taint nodes foo dedicated-

  # Add a taint with key 'dedicated' on nodes having label mylabel=X
  kubectl taint node -l myLabel=X  dedicated=foo:PreferNoSchedule

Set taint for node01 only applied pods that with toleration of "node-type=production", otherwise no pods would settle on node01
# kubectl taint node node01 node-type=production:NoSchedule
# vi deploy-demo.yaml
-------------------------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deploy
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      release: canary
  template:
    metadata:
      labels:
        app: myapp
        release: canary
    spec:
      containers:
      - name: myapp
        image: ikubernetes/myapp:v1
        ports:
        - name: http
          containerPort: 80
------------------------------
# kubectl apply -f deploy-demo.yaml
# kubectl get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP            NODE     NOMINATED NODE
myapp-deploy-574965d786-9f27v      1/1     Running   0          89m   10.244.2.10   node02   <none>
myapp-deploy-574965d786-9l4wt      1/1     Running   0          89m   10.244.2.9    node02   <none>
myapp-deploy-574965d786-rcrm9      1/1     Running   0          89m   10.244.2.11   node02   <none>

So all pods will go to node02 as node02 have no taint restriction.

Set taint with NoExecute on node02, so pods will be banished from node02 at once and have no node to go.
# kubectl taint node node02 node-type=dev:NoExecute
# kubectl get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP            NODE     NOMINATED NODE
myapp-deploy-574965d786-464wh      0/1     Pending   0          12s   <none>        <none>   <none>
myapp-deploy-574965d786-f4v7t      0/1     Pending   0          12s   <none>        <none>   <none>
myapp-deploy-574965d786-pw5bn      0/1     Pending   0          12s   <none>        <none>   <none>

In order to give way to the pods, we can set toleration to the pods
# vi deploy-demo-1.yaml
-------------------------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deploy
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      release: canary
  template:
    metadata:
      labels:
        app: myapp
        release: canary
    spec:
      containers:
      - name: myapp
        image: ikubernetes/myapp:v1
        ports:
        - name: http
          containerPort: 80
      tolerations:
      - key: "node-type"
        operator: "Equal"
        value: "production"
        effect: "NoSchedule" 
------------------------------
# kubectl apply -f deploy-demo-1.yaml
# kubectl get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP            NODE     NOMINATED NODE
myapp-deploy-6949c46f89-2l7w9      1/1     Running   0          9s    10.244.1.69   node01   <none>
myapp-deploy-6949c46f89-8k5lj      1/1     Running   0          4s    10.244.1.71   node01   <none>
myapp-deploy-6949c46f89-h9fbr      1/1     Running   0          6s    10.244.1.70   node01   <none>


Requests and limits
we need define requests as lower and upper limit in yaml file
# kubectl explain pods.spec.containers.resources
# cd /opt/k8s/manifest/
# mkdir metrics/
# cd metrics/
# vi pod-demo.yaml
------------------------------
apiVersion: v1
kind: Pod
metadata:
  name: pod-demo
  namespace: default
  labels:
    app: myapp
    tier: frontend
spec:
  containers:
  - name: myapp
    image: ikubernetes/stress-ng
    command: ["/usr/bin/stress-ng", "-m 1", "-c 1", "--metrics-brief"]
    resources:
      requests:
        cpu: "200m"
        memory: "128Mi"
      limits:
        cpu: "500"
        memory: "200Mi"
------------------------------------
# kubectl apply -f pod-demo.yaml

untainted node01 and node02
# kubectl taint node node01 node-type-
# kubectl taint node node02 node-type-

# check how many resources that pod-demo used.
# kubectl exec -it pod-demo -- /bin/sh
/ # top
-----------------------------------------------------------------------------
Mem: 1696048K used, 188328K free, 65692K shrd, 1096K buff, 545800K cached
CPU:  88% usr  11% sys   0% nic   0% idle   0% io   0% irq   0% sirq
Load average: 5.81 4.86 2.88 6/883 3630
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
    5     1 root     R     6896   0%   1  53% {stress-ng-cpu} /usr/bin/stress-ng -m 1 -c 1 --metrics-brie
 3630     6 root     R     262m  14%   0   0% {stress-ng-vm} /usr/bin/stress-ng -m 1 -c 1 --metrics-brief
    6     1 root     S     6248   0%   0   0% {stress-ng-vm} /usr/bin/stress-ng -m 1 -c 1 --metrics-brief
    1     0 root     S     6248   0%   1   0% /usr/bin/stress-ng -m 1 -c 1 --metrics-brief
 3008     0 root     S     1512   0%   1   0% /bin/sh
 3629  3008 root     R     1504   0%   0   0% top
-----------------------------------------------------------------------------
# kubectl describe pods pod-demo | grep "QoS Class"
QoS Class:       Burstable


Heapster:
1.setup dependent DB influxDB in k8s
# wget https://raw.githubusercontent.com/kubernetes-retired/heapster/master/deploy/kube-config/influxdb/influxdb.yaml
# vi influxdb.yaml
-------------------------------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitoring-influxdb
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      task: monitoring
      k8s-app: influxdb
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: influxdb
    spec:
      containers:
      - name: influxdb
        image: registry.cn-hangzhou.aliyuncs.com/showerlee/heapster-influxdb-amd64:v1.5.2
        volumeMounts:
        - mountPath: /data
          name: influxdb-storage
      volumes:
      - name: influxdb-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  labels:
    task: monitoring
    # For use as a Cluster add-on (https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
    # If you are NOT using this as an addon, you should comment out this line.
    kubernetes.io/cluster-service: 'true'
    kubernetes.io/name: monitoring-influxdb
  name: monitoring-influxdb
  namespace: kube-system
spec:
  ports:
  - port: 8086
    targetPort: 8086
  selector:
    k8s-app: influxdb
-----------------------------------
# kubectl apply -f influxdb.yaml
# kubectl get svc -n kube-system
# kubectl get pods -n kube-system

2.set heapster RBAC
# wget https://raw.githubusercontent.com/kubernetes-retired/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml
# vi heapster-rbac.yaml
-------------------------
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: heapster
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin # need highest auth
subjects:
- kind: ServiceAccount
  name: heapster
  namespace: kube-system
--------------------------------
# kubectl apply -f heapster-rbac.yaml

3.setup heapster
# wget https://raw.githubusercontent.com/kubernetes-retired/heapster/master/deploy/kube-config/influxdb/heapster.yaml
# vi heapster.yaml
--------------------------------
apiVersion: v1
kind: ServiceAccount
metadata:
  name: heapster
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: heapster
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      task: monitoring
      k8s-app: heapster
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: heapster
    spec:
      serviceAccountName: heapster
      containers:
      - name: heapster
        image: registry.cn-hangzhou.aliyuncs.com/showerlee/heapster-amd64:v1.5.4
        imagePullPolicy: IfNotPresent
        command:
        - /heapster
        - --source=kubernetes:https://kubernetes.default?kubeletHttps=true&kubeletPort=10250&insecure=true
        - --sink=influxdb:http://monitoring-influxdb.kube-system.svc.cluster.local:8086
---
apiVersion: v1
kind: Service
metadata:
  labels:
    task: monitoring
    # For use as a Cluster add-on (https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
    # If you are NOT using this as an addon, you should comment out this line.
    kubernetes.io/cluster-service: 'true'
    kubernetes.io/name: Heapster
  name: heapster
  namespace: kube-system
spec:
  ports:
  - port: 80
    targetPort: 8082
  type: NodePort
  selector:
    k8s-app: heapster
------------------------------------
# kubectl apply -f heapster.yaml
# kubectl get svc -n kube-system
# kubectl get pods -n kube-system
# kubectl logs heapster-6f8b8d7875-58s5j -n kube-system
 
4.setup grafana
# wget https://raw.githubusercontent.com/kubernetes-retired/heapster/master/deploy/kube-config/influxdb/grafana.yaml
# vi grafana.yaml
--------------------------------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitoring-grafana
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      task: monitoring
      k8s-app: grafana
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: grafana
    spec:
      containers:
      - name: grafana
        image: registry.cn-hangzhou.aliyuncs.com/showerlee/heapster-grafana-amd64:v5.0.4
        ports:
        - containerPort: 3000
          protocol: TCP
        volumeMounts:
        - mountPath: /etc/ssl/certs
          name: ca-certificates
          readOnly: true
        - mountPath: /var
          name: grafana-storage
        env:
        - name: INFLUXDB_HOST
          value: monitoring-influxdb
        - name: GF_SERVER_HTTP_PORT
          value: "3000"
          # The following env variables are required to make Grafana accessible via
          # the kubernetes api-server proxy. On production clusters, we recommend
          # removing these env variables, setup auth for grafana, and expose the grafana
          # service using a LoadBalancer or a public IP.
        - name: GF_AUTH_BASIC_ENABLED
          value: "false"
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "true"
        - name: GF_AUTH_ANONYMOUS_ORG_ROLE
          value: Admin
        - name: GF_SERVER_ROOT_URL
          # If you're only using the API Server proxy, set this value instead:
          # value: /api/v1/namespaces/kube-system/services/monitoring-grafana/proxy
          value: /
      volumes:
      - name: ca-certificates
        hostPath:
          path: /etc/ssl/certs
      - name: grafana-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  labels:
    # For use as a Cluster add-on (https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
    # If you are NOT using this as an addon, you should comment out this line.
    kubernetes.io/cluster-service: 'true'
    kubernetes.io/name: monitoring-grafana
  name: monitoring-grafana
  namespace: kube-system
spec:
  # In a production setup, we recommend accessing Grafana through an external Loadbalancer
  # or through a public IP.
  # type: LoadBalancer
  # You could also use NodePort to expose the service at a randomly-generated port
  # type: NodePort
  ports:
  - port: 80
    targetPort: 3000
    nodePort: 30152 # node port
  selector:
    k8s-app: grafana
  type: NodePort
--------------------------------------
# kubectl apply -f grafana.yaml
# kubectl get svc -n kube-system
# kubectl get pods -n kube-system

visit http://10.0.2.20:30152 via chrome

# kubectl top nodes
NAME     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
node02   59m          2%     448Mi           25%


Metrics-server
1.Setup metrics api
# kubectl api-versions
# kubectl resources
# mkdir -p /opt/k8s/manifests/metrics/metrics-server/
# cd /opt/k8s/manifests/metrics/metrics-server/
# for file in aggregated-metrics-reader.yaml auth-delegator.yaml auth-reader.yaml metrics-apiservice.yaml metrics-server-deployment.yaml metrics-server-service.yaml resource-reader.yaml; do wget https://raw.githubusercontent.com/kubernetes-incubator/metrics-server/master/deploy/1.8%2B/$file; done
# grep -r "image" .
# sed -i 's#k8s.gcr.io#registry.cn-hangzhou.aliyuncs.com/showerlee#g' metrics-server-deployment.yaml

add rule resource
# vi resource-reader.yaml 
---------------------------
kind: ClusterRole
metadata:
  name: system:metrics-server
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - nodes
  - namespaces # add this line
  - nodes/stats
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:metrics-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:metrics-server
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
-------------------------------

add "hostNetwork: true" and command for metrics-server-deployment.yaml
# vi metrics-server-deployment.yaml
-------------------------------
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-server
  namespace: kube-system
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
  labels:
    k8s-app: metrics-server
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  template:
    metadata:
      name: metrics-server
      labels:
        k8s-app: metrics-server
    spec:
      serviceAccountName: metrics-server
      volumes:
      # mount in tmp so we can safely use from-scratch images and/or read-only containers
      - name: tmp-dir
        emptyDir: {}
      hostNetwork: true # highly required
      containers:
      - name: metrics-server
        image: registry.cn-hangzhou.aliyuncs.com/showerlee/metrics-server-amd64:v0.3.3
        imagePullPolicy: IfNotPresent
        command: # highly required
        - /metrics-server 
        - --kubelet-insecure-tls
        - --kubelet-preferred-address-types=InternalIP
        volumeMounts:
        - name: tmp-dir
          mountPath: /tmp
-----------------------------------
# kubectl apply -f ./
# kubectl api-versions |grep metrics
metrics.k8s.io/v1beta1
# kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

2.test metrics api
open k8s proxy
# kubectl proxy --port=8091 &
# curl http://localhost:8091/apis/metrics.k8s.io/v1beta1
-------------------------------
{
  "kind": "APIResourceList",
  "apiVersion": "v1",
  "groupVersion": "metrics.k8s.io/v1beta1",
  "resources": [
    {
      "name": "nodes",
      "singularName": "",
      "namespaced": false,
      "kind": "NodeMetrics",
      "verbs": [
        "get",
        "list"
      ]
    },
    {
      "name": "pods",
      "singularName": "",
      "namespaced": true,
      "kind": "PodMetrics",
      "verbs": [
        "get",
        "list"
      ]
    }
  ]
}
------------------------------------

get raw api
# kubectl get --raw "/apis/metrics.k8s.io/v1beta1/" 
-----------------------------
{"kind":"APIResourceList","apiVersion":"v1","groupVersion":"metrics.k8s.io/v1beta1","resources":[{"name":"nodes","singularName":"","namespaced":false,"kind":"NodeMetrics","verbs":["get","list"]},{"name":"pods","singularName":"","namespaced":true,"kind":"PodMetrics","verbs":["get","list"]}]}
-------------------------------------

3.check pod and node resources
# kubectl top pods
NAME                               CPU(cores)   MEMORY(bytes)
wordpress-557bfb4d8b-9gzvv         1m           27Mi
wordpress-mysql-7977b9588d-g9f7p   1m           449Mi
# kubectl top pods -n kube-system
NAME                                  CPU(cores)   MEMORY(bytes)
canal-89r9s                           18m          48Mi
canal-bq9xn                           17m          61Mi
canal-znbgx                           16m          49Mi
coredns-576cbf47c7-h4p9n              2m           12Mi
coredns-576cbf47c7-rmcsr              2m           12Mi
etcd-master                           16m          125Mi
kube-apiserver-master                 36m          465Mi
kube-controller-manager-master        40m          64Mi
kube-flannel-ds-amd64-9jwnz           2m           15Mi
kube-flannel-ds-amd64-bzb7g           2m           25Mi
kube-flannel-ds-amd64-vmckr           2m           16Mi
kube-proxy-cw5vd                      2m           22Mi
kube-proxy-fbjz7                      2m           14Mi
kube-proxy-wljvz                      2m           14Mi
kube-scheduler-master                 10m          13Mi
kubernetes-dashboard-85db5fb4-7vphw   1m           11Mi
metrics-server-6f4fd98f79-8fl2t       1m           13Mi

# kubectl top nodes
NAME     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
master   177m         8%     1083Mi          39%
node01   63m          3%     1014Mi          58%
node02   70m          3%     366Mi           21%


Custom Metrics API
Prometheus
1.download promethenus k8s yaml file
# cd /opt/k8s/manifests/metrics/
# git clone https://github.com/iKubernetes/k8s-prom.git
# cd k8s-prom/
# sed -i 's#gcr.io#gcr.azk8s.cn#g' ./kube-state-metrics/kube-state-metrics-deploy.yaml

2.setup namespace
# kubectl apply -f namespace.yaml

3.setup node-exporter
# cd node_exporter/
# kubectl apply -f ./
# kubectl get pods -n prom

4. setup prometheus
# cd ../prometheus/
# sed -i 's#memory: 2Gi#memory: 1Gi#g' prometheus-deploy.yaml
# kubectl apply -f ./
# kubectl get all -n prom
# kubectl logs -n prom prometheus-server-69c85b79b-h88sl
visit prometheus web site via chrome
http://10.0.2.20:30090

5.setup metrics server
# cd ../kube-state-metrics/
# kubectl apply -f .
# kubectl get all -n prom

6.create prometheus adapter cert
# cd /etc/kubernetes/pki/
create private key
# (umask 077; openssl genrsa -out serving.key 2048)
create cert sign request
# openssl req -new -key serving.key -out serving.csr -subj "/CN=serving"
create certificate
# openssl x509 -req -in serving.csr -CA ./ca.crt -CAkey ./ca.key -CAcreateserial -out serving.crt -days 3650
create k8s secret
# kubectl create secret generic cm-adapter-serving-certs --from-file=serving.crt=./serving.crt --from-file=serving.key=./serving.key -n prom

7.setup prometheus adapter
# cd ../k8s-prometheus-adapter/
# mv custom-metrics-apiserver-deployment.yaml{,.bak}
# wget https://raw.githubusercontent.com/DirectXMan12/k8s-prometheus-adapter/master/deploy/manifests/custom-metrics-apiserver-deployment.yaml
# sed -i 's#namespace: custom-metrics#namespace: prom#g' custom-metrics-apiserver-deployment.yaml
# wget https://raw.githubusercontent.com/DirectXMan12/k8s-prometheus-adapter/master/deploy/manifests/custom-metrics-config-map.yaml
# sed -i 's#namespace: custom-metrics#namespace: prom#g' custom-metrics-config-map.yaml
# kubectl apply -f ./
# kubectl get all -n prom

8.check k8s api applied custom metrics api
# kubectl api-versions | grep custom
custom.metrics.k8s.io/v1beta1
# curl http://localhost:8091/apis/custom.metrics.k8s.io/v1beta1/ 
-------------------------------------------
{
  "kind": "APIResourceList",
  "apiVersion": "v1",
  "groupVersion": "custom.metrics.k8s.io/v1beta1",
  "resources": [
    {
      "name": "pods/go_goroutines",
      "singularName": "",
      "namespaced": true,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    },
    {
      "name": "namespaces/kube_daemonset_status_number_available",
      "singularName": "",
      "namespaced": false,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    },
...
-------------------------------------------------

9.setup grafana integrated with prometheus
# cd /opt/k8s/manifests/metrics/k8s-prom/
# cp -a /opt/k8s/manifests/metrics/heapster/grafana.yaml .
# sed -i 's#namespace: kube-system#namespace: prom#g' grafana.yaml
# sed -i 's/- name: INFLUXDB_HOST/# - name: INFLUXDB_HOST/g' grafana.yaml
# sed -i 's/value: monitoring-influxdb/# value: monitoring-influxdb/g' grafana.yaml
# kubectl apply -f grafana.yaml
# kubectl get svc -n prom

10.visit grafana web page http://10.0.2.20:30152/datasources/edit/1
Data Sources / prometheus
Name: prometheus
Type: Prometheus

HTTP
URL http://prometheus.prom.svc:9090

Save & Test

11.download grafana dashboard json file
# wget https://grafana.com/api/dashboards/6417/revisions/1/download -O kubernetes-cluster-prometheus_rev1.json

12.import the file in grafana backend
visit http://127.0.0.1:30152/dashboard/import
import kubernetes-cluster-prometheus_rev1.json into the web page

the fancy dashboard is setup properly
http://127.0.0.1:30152/d/4XuMd2Iiz/kubernetes-cluster-prometheus?orgId=1

need to sync datetime via if k8s cluster is nap
# /usr/sbin/ntpdate pool.ntp.org

HPA(HorizontalPodAutoscaler)
# kubectl explain hpa
# kubectl api-versions | grep autoscaling
autoscaling/v1
autoscaling/v2beta1
autoscaling/v2beta2
 
Create a myapp deployment via autoscaling/v1 
# kubectl run myapp --image=ikubernetes/myapp:v1 --replicas=1 --requests='cpu=50m,memory=256Mi' --limits='cpu=50m,memory=256Mi' --labels='app=myapp' --expose --port=80

Set autoscaling for myapp
# kubectl autoscale deployment myapp --min=1 --max=8 --cpu-percent=60

Get hpa info
# kubectl get hpa

# patch service
# kubectl get svc
# kubectl patch svc myapp -p '{"spec":{"type":"NodePort"}}'

# pressure test in Storage01 node
# yum install httpd-tools-2.4.6-89.el7.centos.x86_64 -y
# ab -c 100 -n 500000 http://10.0.2.20:32041/index.html

# check change in hpa
# kubectl describe hpa
# kubectl get hpa
-------------------------
NAME    REFERENCE          TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
myapp   Deployment/myapp   93%/60%    1         8         4          23m
----------------------------------
the replicas autoscaling to 4
# kubectl get pods
NAME                               READY   STATUS    RESTARTS   AGE
myapp-76d858cd4c-288bl             1/1     Running   0          49s
myapp-76d858cd4c-2p8j4             1/1     Running   0          5m49s
myapp-76d858cd4c-bdjcw             1/1     Running   0          49s
myapp-76d858cd4c-x78zt             1/1     Running   0          31m

Create a myapp deployment via autoscaling/v2
# kubectl explain --api-version=autoscaling/v2beta1 hpa.spec.metrics.resource
# kubectl delete hpa myapp
# vi hpa-v2-demo.yaml
--------------------
apiVersion: autoscaling/v2beta1
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa-v2
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      targetAverageUtilization: 55
  - type: Resource
    resource:
      name: memory
      targetAverageValue: 50Mi
-------------------------
# kubectl apply -f hpa-v2-demo.yaml
# kubectl get hpa
support memory
NAME           REFERENCE          TARGETS                  MINPODS   MAXPODS   REPLICAS   AGE
myapp-hpa-v2   Deployment/myapp   <unknown>/50Mi, 0%/55%   1         10        1          36s
# kubectl describe hpa 
# kubectl get hpa

Create a custom demo deployment via autoscaling/v2
# vi hpa-v2-custom.yaml
-------------------------
apiVersion: autoscaling/v2beta1
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa-v2
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metricsName: http_requests
      targetAverageVaule: 800m
-----------------------------


Helm:
1.install helm client
# mkdir /opt/src
# cd /opt/src
# wget https://storage.googleapis.com/kubernetes-helm/helm-v2.14.0-linux-amd64.tar.gz
# tar zxvf helm-v2.14.0-linux-amd64.tar.gz
# cd linux-amd64/
# mv helm /usr/bin 
# helm --help

2. install tiller server in k8s
# mkdir /opt/k8s/manifest/helm
# vi tiller-rbac.yaml
----------------------------
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
--------------------------------
# kubectl apply -f tiller-rbac.yaml
# kubectl get sa -n kube-system tiller
# mkdir -p /root/.helm/repository/cache
# vi /root/.helm/repository/repositories.yaml
---------------------------------
apiVersion: v1
generated: 2019-05-28T11:18:19.490774427-04:00
repositories:
- caFile: ""
  cache: /root/.helm/repository/cache/stable-index.yaml
  certFile: ""
  keyFile: ""
  name: stable
  password: ""
  url: http://mirror.azure.cn/kubernetes/charts/
  username: ""
- caFile: ""
  cache: /root/.helm/repository/cache/incubator-index.yaml
  certFile: ""
  keyFile: ""
  name: incubator
  password: ""
  url: http://mirror.azure.cn/kubernetes/charts-incubator/
  username: ""
- caFile: ""
  cache: /root/.helm/repository/cache/local-index.yaml
  certFile: ""
  keyFile: ""
  name: local
  password: ""
  url: http://127.0.0.1:8879/charts
  username: ""
------------------------------------
# vi /root/.helm/repository/cache/local-index.yaml
-------------------------
apiVersion: v1
entries: {}
generated: "2019-05-28T17:07:04.094451405+08:00"
--------------------------------

# helm init --service-account tiller --upgrade --tiller-image=registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.14.0

Check tiller pod
# kubectl get pods -n kube-system
# helm version
Client: &version.Version{SemVer:"v2.14.0", GitCommit:"05811b84a3f93603dd6c2fcfe57944dfa7ab7fd0", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.14.0", GitCommit:"05811b84a3f93603dd6c2fcfe57944dfa7ab7fd0", GitTreeState:"clean"}

Update helm repo
# helm repo update
tips: find more official chart in https://hub.kubeapps.com

check helm repo URL
# helm repo list

search chart in available repos
# helm search 
# helm search stable/jenkins

Install memcached via helm chart
# helm install --name mem1 stable/memcached

Check helm deploy info
# helm list

Check details info
# helm inspect

Upgrade/rollout helm release
# helm upgrade/rollout

Delete memcached
# helm delete mem1

Create chart
# helm create

Download a chart package
# helm get

Download a chart and unpack
# helm fetch

install redis via chart
# helm install --name redis-demo -f values.yaml stable/redis --version 3.7.6

Check helm release status info
# helm status

Customize helm chart
# helm create myapp 
# tree ./myapp/
./myapp/
├── charts
├── Chart.yaml
├── templates
│   ├── deployment.yaml
│   ├── _helpers.tpl
│   ├── ingress.yaml
│   ├── NOTES.txt
│   ├── service.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml

# cd myapp/
# vi Chart.yaml
------------------------
apiVersion: v1
appVersion: "1.0"
description: A Helm chart for Kubernetes myapp chart
name: myapp
version: 0.0.1
maintainer:
- name: admin
  email: admin@example.com
  url: http://www.example.com/
-----------------------------
# vi values.yaml
-----------------------
# Default values for myapp.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

replicaCount: 2

image:
  repository: ikubernetes/myapp:v1
  tag: v1
  pullPolicy: IfNotPresent

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  annotations: {}
  #  kubernetes.io/ingress.class: nginx
  #  kubernetes.io/tls-acme: "true"
  hosts:
    - host: chart-example.local
      paths: []

  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local

resources:
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi

nodeSelector: {}

tolerations: []

affinity: {}
-----------------------------
# cd ..

Check the grammar syntax
# helm lint myapp
# touch /root/.helm/repository/local/index.yaml

Package myapp
# helm package myapp

Open local repo service
# helm serve

Check myapp in local repo
# helm search myapp
AME       	CHART VERSION	APP VERSION	DESCRIPTION
local/myapp	0.0.1        	1.0        	A Helm chart for Kubernetes myapp chart

install myapp from local repp
# helm install --name myapp-demo local/myapp

Setup 
Install elasticsearch
# cd /opt/k8s/manifest/helm/charts
# helm fetch incubator/elasticsearch --version 1.4.1
# tar xf elasticsearch-1.4.1.tgz
# cd elasticsearch/
# vi values.yaml
---------------------------
# Default values for elasticsearch.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.
appVersion: "6.4.2"

image:
  repository: "docker.elastic.co/elasticsearch/elasticsearch-oss"
  tag: "6.4.2"
  pullPolicy: "IfNotPresent"
  # If specified, use these secrets to access the image
  # pullSecrets:
  #   - registry-secret

initImage:
  repository: "busybox"
  tag: "latest"
  pullPolicy: "Always"

cluster:
  name: "elasticsearch"
  # If you want X-Pack installed, switch to an image that includes it, enable this option and toggle the features you want
  # enabled in the environment variables outlined in the README
  xpackEnable: false
  # Some settings must be placed in a keystore, so they need to be mounted in from a secret.
  # Use this setting to specify the name of the secret
  # keystoreSecret: eskeystore
  config: {}
  # Custom parameters, as string, to be added to ES_JAVA_OPTS environment variable
  additionalJavaOpts: ""
  env:
    # IMPORTANT: https://www.elastic.co/guide/en/elasticsearch/reference/current/important-settings.html#minimum_master_nodes
    # To prevent data loss, it is vital to configure the discovery.zen.minimum_master_nodes setting so that each master-eligible
    # node knows the minimum number of master-eligible nodes that must be visible in order to form a cluster.
    MINIMUM_MASTER_NODES: "2"

client:
  name: client
  replicas: 2
  serviceType: ClusterIP
  loadBalancerIP: {}
  loadBalancerSourceRanges: {}
## (dict) If specified, apply these annotations to the client service
#  serviceAnnotations:
#    example: client-svc-foo
  heapSize: "512m"
  antiAffinity: "soft"
  nodeAffinity: {}
  nodeSelector: {}
  tolerations: []
  resources:
    limits:
      cpu: "1"
      # memory: "1024Mi"
    requests:
      cpu: "25m"
      memory: "512Mi"
  priorityClassName: ""
  ## (dict) If specified, apply these annotations to each client Pod
  # podAnnotations:
  #   example: client-foo
  podDisruptionBudget:
    enabled: false
    minAvailable: 1
    # maxUnavailable: 1

master:
  name: master
  exposeHttp: false
  replicas: 2
  heapSize: "512m"
  persistence:
    enabled: false
    accessMode: ReadWriteOnce
    name: data
    size: "4Gi"
    # storageClass: "ssd"
  antiAffinity: "soft"
  nodeAffinity: {}
  nodeSelector: {}
  tolerations: []
  resources:
    limits:
      cpu: "1"
      # memory: "1024Mi"
    requests:
      cpu: "25m"
      memory: "512Mi"
  priorityClassName: ""
  ## (dict) If specified, apply these annotations to each master Pod
  # podAnnotations:
  #   example: master-foo
  podDisruptionBudget:
    enabled: false
    minAvailable: 2  # Same as `cluster.env.MINIMUM_MASTER_NODES`
    # maxUnavailable: 1
  updateStrategy:
    type: OnDelete

data:
  name: data
  exposeHttp: false
  replicas: 1
  heapSize: "1536m"
  persistence:
    enabled: false
    accessMode: ReadWriteOnce
    name: data
    size: "30Gi"
    # storageClass: "ssd"
  terminationGracePeriodSeconds: 3600
  antiAffinity: "soft"
  nodeAffinity: {}
  nodeSelector: {}
  tolerations: []
  resources:
    limits:
      cpu: "1"
      # memory: "2048Mi"
    requests:
      cpu: "25m"
      memory: "1536Mi"
  priorityClassName: ""
  ## (dict) If specified, apply these annotations to each data Pod
  # podAnnotations:
  #   example: data-foo
  podDisruptionBudget:
    enabled: false
    # minAvailable: 1
    maxUnavailable: 1
  updateStrategy:
    type: OnDelete

## Additional init containers
extraInitContainers: |
-----------------------------------
# kubectl create ns efk
# helm install --name els1 --namespace=efk -f values.yaml incubator/elasticsearch --version 1.10.2
create a pods for testing els1
# kubectl run cirror-$RANDOM --rm -it --image=cirros -- /bin/sh
/ # nslookup els1-elasticsearch-client.efk.svc.cluster.local
/ # curl els1-elasticsearch-client.efk.svc.cluster.local:9200
----------------------------------------
{
  "name" : "els1-elasticsearch-client-667b977b7f-vcgrl",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "_na_",
  "version" : {
    "number" : "6.3.1",
    "build_flavor" : "oss",
    "build_type" : "tar",
    "build_hash" : "eb782d0",
    "build_date" : "2018-06-29T21:59:26.107521Z",
    "build_snapshot" : false,
    "lucene_version" : "7.3.1",
    "minimum_wire_compatibility_version" : "5.6.0",
    "minimum_index_compatibility_version" : "5.0.0"
  },
  "tagline" : "You Know, for Search"
}
--------------------------------------------------
/ # curl els1-elasticsearch-client.efk.svc.cluster.local:9200/_cat/nodes
/ # curl els1-elasticsearch-client.efk.svc.cluster.local:9200/_cat/indices

deploy fluentd to collect logs from each nodes and send logs to elasticsearch
# cd /opt/k8s/manifest/helm/charts
# helm fetch stable/fluentd-elasticsearch --version 1.0.0
# tar xf fluentd-elasticsearch-1.0.0.tgz
# cd fluentd-elasticsearch/
# vi values.yaml
change hosts: value to "els1-elasticsearch-client.efk.svc.cluster.local"
change:
-------------------
tolerations: {}
  # - key: node-role.kubernetes.io/master
  #   operator: Exists
  #   effect: NoSchedule
--------------------
to: 
--------------------
tolerations:
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
--------------------

change:
--------------------
annotations: {}
  # prometheus.io/scrape: "true"
  # prometheus.io/port: "24231"
--------------------
to
--------------------
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "24231"
--------------------

change:
----------------------
service: {}
  # type: ClusterIP
  # ports:
  #   - name: "monitor-agent"
  #     port: 24231
---------------------------
to
-----------------------
service:
  type: ClusterIP
  ports:
    - name: "monitor-agent"
      port: 24231
---------------------------
# helm install --name flu1 --namespace=efk -f values.yaml stable/fluentd-elasticsearch --version 1.0.0
# helm status
# helm list
# kubectl get pods -n efk

install kibana for ui virtualization
# helm fetch stable/kibana --version 0.10.0
# tar xf kibana-0.10.0.tgz
# cd kibana
# vi value.yaml
---------------------
image:
  repository: "docker.elastic.co/kibana/kibana-oss"
  tag: "6.3.1"
  pullPolicy: "IfNotPresent"

commandline:
  args:

env:
  # All Kibana configuration options are adjustable via env vars.
  # To adjust a config option to an env var uppercase + replace `.` with `_`
  # Ref: https://www.elastic.co/guide/en/kibana/current/settings.html
  #
  # ELASTICSEARCH_URL: http://elasticsearch-client:9200
  # SERVER_PORT: 5601
  # LOGGING_VERBOSE: "true"
  # SERVER_DEFAULTROUTE: "/app/kibana"

files:
  kibana.yml:
    ## Default Kibana configuration from kibana-docker.
    server.name: kibana
    server.host: "0"
    elasticsearch.url: http://els1-elasticsearch-client.efk.svc.cluster.local:9200

    ## Custom config properties below
    ## Ref: https://www.elastic.co/guide/en/kibana/current/settings.html
    # server.port: 5601
    # logging.verbose: "true"
    # server.defaultRoute: "/app/kibana"

service:
  type: NodePort
  externalPort: 443
  internalPort: 5601
  ## External IP addresses of service
  ## Default: nil
  ##
  # externalIPs:
  # - 192.168.0.1
  #
  ## LoadBalancer IP if service.type is LoadBalancer
  ## Default: nil
  ##
  # loadBalancerIP: 10.2.2.2
  # nodePort: 30000
  annotations:
    # Annotation example: setup ssl with aws cert when service.type is LoadBalancer
    # service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:us-east-1:EXAMPLE_CERT
  labels:
    ## Label example: show service URL in `kubectl cluster-info`
    # kubernetes.io/cluster-service: "true"

ingress:
  enabled: false
  # hosts:
    # - chart-example.local
  # annotations:
  #   kubernetes.io/ingress.class: nginx
  #   kubernetes.io/tls-acme: "true"
  # tls:
    # - secretName: chart-example-tls
    #   hosts:
    #     - chart-example.local

# service account that will run the pod. Leave commented to use the default service account.
# serviceAccountName: kibana

resources: {}
  # limits:
  #   cpu: 100m
  #   memory: 300Mi
  # requests:
  #   cpu: 100m
  #   memory: 300Mi

priorityClassName: ""

# Affinity for pod assignment
# Ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
# affinity: {}

# Tolerations for pod assignment
# Ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
tolerations: []

# Node labels for pod assignment
# Ref: https://kubernetes.io/docs/user-guide/node-selection/
nodeSelector: {}

podAnnotations: {}
replicaCount: 1
-------------------------
# helm install --name kib1 --namespace=efk -f values.yaml stable/kibana --version 0.10.0
# kubectl get pods -n efk
NAME                                        READY   STATUS    RESTARTS   AGE
els1-elasticsearch-client-b898c9d47-gjgsr   1/1     Running   0          62m
els1-elasticsearch-client-b898c9d47-m8q56   1/1     Running   0          62m
els1-elasticsearch-data-0                   1/1     Running   0          62m
els1-elasticsearch-master-0                 1/1     Running   0          62m
els1-elasticsearch-master-1                 1/1     Running   0          60m
flu1-fluentd-elasticsearch-7z9xg            1/1     Running   2          21h
flu1-fluentd-elasticsearch-vxfpd            1/1     Running   1          21h
flu1-fluentd-elasticsearch-zphtg            1/1     Running   3          21h
kib1-kibana-6d75d85fdb-bsnsn                1/1     Running   0          4m3s
# kubectl get svc -n efk
NAME                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
els1-elasticsearch-client      ClusterIP   10.102.207.162   <none>        9200/TCP        63m
els1-elasticsearch-discovery   ClusterIP   None             <none>        9300/TCP        63m
flu1-fluentd-elasticsearch     ClusterIP   10.107.53.28     <none>        24231/TCP       21h
kib1-kibana                    NodePort    10.108.223.225   <none>        443:30830/TCP   5m39s

visit kibana for elasticsearch ui virtualization
http://127.0.0.1:30830

1.click Management in middle left
2.fill in "logstash*" in Index pattern, and click Next step
3.choose @timestamp in Time Filter field name
4.back to Discover
5.click visualize in middle left
6.create a visualization-Basic Chart-pie
















