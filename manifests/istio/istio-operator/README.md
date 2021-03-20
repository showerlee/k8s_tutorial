# Istio Operator

## Setup istio in docker-desktop via [Istio Operator](https://istio.io/latest/docs/setup/install/operator/)

0. Check requisite for docker-desktop

    https://istio.io/latest/docs/setup/platform-setup/docker/

1. Download istio CMD

    ```
    curl -L https://istio.io/downloadIstio | sh -
    ```

2. Copy latest istioctl to env path

    ```
    cp istio-<latest-version>/bin/istioctl /usr/local/bin/
    ```

3. Deploy the Istio operator
   
   ```
   $ istioctl operator init
   Installing operator controller in namespace: istio-operator using image: docker.io/istio/operator:1.9.1
    Operator controller will watch namespaces: istio-system
    ✔ Istio operator installed
    ✔ Installation complete
   ```
    This command runs the operator by creating the following resources in the istio-operator namespace:

    - The operator custom resource definition
    - The operator controller deployment
    - A service to access operator metrics
    - Necessary Istio operator RBAC rules

4. Switch the installation to the default profile
   
   Now, with the controller running, you can change the Istio configuration by editing or replacing the IstioOperator resource. The controller will detect the change and respond by updating the Istio installation correspondingly.

    ```
    kubectl apply -f ./default.yaml
    ```
   You can observe the changes that the controller makes in the cluster in response to IstioOperator CR updates by checking the operator controller logs:

    ```
    $ kubectl logs -f -n istio-operator $(kubectl get pods -n istio-operator -lname=istio-operator -o jsonpath='{.items[0].metadata.name}')
    ```

5. Execute the following command to determine if your Kubernetes cluster is running in an environment that supports external load balancers

    ```
    $ kubectl get svc istio-ingressgateway -n istio-system
    NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                                      AGE
    istio-ingressgateway   LoadBalancer   10.104.208.117   localhost     15021:31630/TCP,80:31360/TCP,443:30345/TCP,15012:31388/TCP,15443:32414/TCP   10m
    ```
    Istio successfully established `localhost` ELB in MacOS `docker-desktop` so that we can directly use localhost as external ip, 80/443 for external http/https ports.

6. Enable DNS host in local

    ```
    sudo echo -e "127.0.0.1 myapp.example.com" >> /etc/hosts
    ```

7. Deploy canary-demo in istio
   
    ```
    kubectl apply -f ./canary-demo/common/
    ```

8. Checkout details 

    ```
    $ kubectl get pod -o wide
    NAME                        READY   STATUS    RESTARTS   AGE     IP          NODE             NOMINATED NODE   READINESS GATES
    myapp-v1-86c67b56d6-rp7bb   2/2     Running   0          2m48s   10.1.0.72   docker-desktop   <none>           <none>
    myapp-v2-777cb445f9-t2jv5   2/2     Running   0          2m48s   10.1.0.73   docker-desktop   <none>           <none>

    $ kubectl get endpoints myapp-svc -o wide
    NAME        ENDPOINTS                   AGE
    myapp-svc   10.1.0.72:80,10.1.0.73:80   3m33s

    $ kubectl describe gateways myapp-gw
    ...
    Spec:
      Selector:
    Istio:  ingressgateway
      Servers:
        Hosts:
          myapp.example.com
        Port:
          Name:      http
          Number:    80
          Protocol:  HTTP
    ...

    $ kubectl describe virtualservices myapp-vs
    ...
    Spec:
      Gateways:
        myapp-gw
      Hosts:
        myapp.example.com
      Http:
        Route:
          Destination:
            Host:  myapp-svc
            Port:
              Number:  80
            Subset:    v1
          Weight:      90
          Destination:
            Host:  myapp-svc
            Port:
              Number:  80
            Subset:    v2
          Weight:      10
    ...
    ```
    Istio `gateways` will expose `myapp.example.com` with `80` port and bind to `virtualservices` so as to route the traffic of service `myapp-svc` with corresponding weight of each canary versions(v1,v2).

    In this demo:
    - v1 has weight 90 which means `nine tenth of the requests` will be sent to the canary version 1
    - v2 has weight 10 which means only `one tenth of the requests` will be sent to the canary version 2

9. Continue calling the host

    ```
    $ while true; do curl myapp.example.com; sleep 1; done
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v2 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    ```
    We are happy to see the requests output are based on the istio weight and canary deployment is achievable.

10. Adjust the route weight

    We could redeploy the route weight to determine what percentage of the requests will be sent to the certain canary version later depend on any metrics or testing that affect the availability of the canary versions, regardless of how many replicas of each version are running.

    In this demo, we just adjust it manually, feel free to automate via any metrics or testing standard

    ```
    # Each half for v1 and v2
    kubectl apply -f ./canary-demo/eachhalf.yaml
    # Rollback to v1
    kubectl apply -f ./canary-demo/rollback.yaml
    ```
    More details: https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRouteDestination

11. Autoscaling the deployments(optional)

    Because we don’t need to maintain replica ratios anymore, we can safely add Kubernetes horizontal pod autoscalers to manage the replicas for both version Deployments:

    ```
    $ kubectl autoscale deployment myapp-v1 --cpu-percent=50 --min=1 --max=10
    deployment "myapp-v1" autoscaled

    $ kubectl autoscale deployment myapp-v2 --cpu-percent=50 --min=1 --max=10
    deployment "myapp-v2" autoscaled

    $ kubectl get hpa
    NAME           REFERENCE                 TARGET  CURRENT  MINPODS  MAXPODS  AGE
    myapp-v1  Deployment/myapp-v1  50%     47%      1        10       17s
    myapp-v2  Deployment/myapp-v2  50%     40%      1        10       15s
    ```
    Details: https://istio.io/latest/blog/2017/0.1-canary/#autoscaling-the-deployments
