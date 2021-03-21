# Canary-demo
This is a canary-demo that helps you achieve the canary deployment via istio with baby steps

## Setup Istio env via [Istio Operator](../README.md)
  https://istio.io/latest/docs/setup/install/operator/

## Steps by steps to deploy canary-demo

1. Enable DNS host in local

    ```
    sudo echo -e "127.0.0.1 myapp.example.com" >> /etc/hosts
    ```

2. Generate client and server certificates and keys

    - Create a root certificate and private key to sign the certificate for your services:

        ```
        openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=example Inc./CN=example.com' -keyout example.com.key -out example.com.crt
        ```

    - Create a certificate and a private key for myapp.example.com:

        ```
        openssl req -out myapp.example.com.csr -newkey rsa:2048 -nodes -keyout myapp.example.com.key -subj "/CN=myapp.example.com/O=myapp organization"
        openssl x509 -req -days 365 -CA example.com.crt -CAkey example.com.key -set_serial 0 -in myapp.example.com.csr -out myapp.example.com.crt
        ```

    - Create a Kubernetes Secret to hold the server’s certificate.

        ```
        kubectl create -n istio-system secret tls myapp-credential --key=myapp.example.com.key --cert=myapp.example.com.crt
        ```
    More details: https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/

3. Deploy canary-demo in istio

    ```
    kubectl apply -f ./common/
    ```

4.  Checkout detailed outcome

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
        Hosts:
          myapp.example.com
        Port:
          Name:      https
          Number:    443
          Protocol:  HTTPS
        Tls:
          Credential Name:  myapp-credential
          Mode:             SIMPLE
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
    Istio `gateways` will expose `myapp.example.com` with `80`/`443` ports and bind to `virtualservices` so as to route the traffic of service `myapp-svc` with corresponding weight of each canary versions(v1,v2).

    In this demo:
    - v1 has weight 90 which means `nine tenth of the requests` will be sent to the canary version 1
    - v2 has weight 10 which means only `one tenth of the requests` will be sent to the canary version 2

5.  Continue calling the host

    ```
    $ while true; do curl --insecure https://myapp.example.com; sleep 1; done
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v2 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    Hello MyApp | Version: v1 | <a href="hostname.html">Pod Name</a>
    ```
    We are happy to see the https request output are based on the istio weight and canary deployment is achievable.

6.  Adjust the route weight

    We could redeploy the route weight to determine what percentage of the requests will be sent to the certain canary version later depend on any metrics or testing that affect the availability of the canary versions, regardless of how many replicas of each version are running.

    In this demo, we just adjust it manually, feel free to automate via any metrics or testing standard

    ```
    # Each half for v1 and v2
    kubectl apply -f ./eachhalf.yaml
    # Rollback to v1
    kubectl apply -f ./rollback.yaml
    ```
    More details: https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRouteDestination

7.  Autoscaling the deployments(optional)

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
    More Details: https://istio.io/latest/blog/2017/0.1-canary/#autoscaling-the-deployments

8.  HTTPMatchRequest

    HttpMatchRequest specifies a set of criterion to be met in order for the rule to be applied to the HTTP request. 
    
    For example, the following restricts the rule to match only requests where the URL path starts with / and the request contains a custom `end-user` header with value `leon`.

    Les's say only the following request pattern would call `myapp.example.com` successfully.

    ```
    curl --location --request GET 'myapp.example.com' \
    --header 'end-user: leon'
    ```
    More details: https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPMatchRequest

9.  HTTPFaultInjection

    HTTPFaultInjection can be used to specify one or more faults to inject while forwarding HTTP requests to the destination specified in a route. Fault specification is part of a VirtualService rule. Faults include aborting the Http request from downstream service, and/or delaying proxying of requests. A fault rule MUST HAVE delay or abort or both.

    - Delay specification is used to inject latency into the request forwarding path. The following example will introduce a 5 second delay in 100% requests to the “v1” version
        ```
        kubectl apply -f ./delay.yaml
        ```

    - Abort specification is used to prematurely abort a request with a pre-specified error code. The following example will return an HTTP 404 error code for 100% requests to the “ratings” service “v1” and "v2"
        ```
        kubectl apply -f ./abort.yaml
        ```
    More details: https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPFaultInjection
