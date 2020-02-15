#!/bin/bash

images=(kube-apiserver:v1.17.2 kube-controller-manager:v1.17.2 kube-scheduler:v1.17.2 kube-proxy:v1.17.2 pause:3.1 etcd:3.4.3-0 coredns:1.17.2 nginx-ingress-controller:0.28.0)

for img in ${images[@]}
do
  docker pull registry.cn-hangzhou.aliyuncs.com/showerlee/$img
done
