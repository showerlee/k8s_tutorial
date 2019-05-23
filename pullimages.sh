#!/bin/bash
images=(kube-apiserver:v1.12.0 kube-controller-manager:v1.12.0 kube-scheduler:v1.12.0 kube-proxy:v1.12.0 pause:3.1 etcd:3.2.24 coredns:1.2.2)

for ima in ${images[@]}
do
   docker pull   registry.cn-shenzhen.aliyuncs.com/lurenjia/$ima
   docker tag    registry.cn-shenzhen.aliyuncs.com/lurenjia/$ima   k8s.gcr.io/$ima
   docker rmi  -f  registry.cn-shenzhen.aliyuncs.com/lurenjia/$ima
done
