# ISTIO

## Setup istio in docker-desktop
Details: https://istio.io/latest/docs/setup/getting-started/

1. Download istio

    ```
    curl -L https://istio.io/downloadIstio | sh -
    ```

2. Copy istioctl to env path

    ```
    cp istio-1.9.1/bin/istioctl /usr/local/bin/
    ```

3. Initialize istioctl via demo config profile

    ```
    istioctl install --set profile=demo -y
    ```

4. Add a namespace label to instruct Istio to automatically inject Envoy sidecar proxies when you deploy your application later

    ```
    kubectl label namespace default istio-injection=enabled
    ```

5. Deploy the Bookinfo sample application

    ```
    kubectl apply -f istio-1.9.1/samples/bookinfo/platform/kube/bookinfo.yaml
    ```

6. The application will start. As each pod becomes ready, the Istio sidecar will be deployed along with it
   
    ```
    $ kubectl get svc
    NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
    details       ClusterIP   10.106.68.115    <none>        9080/TCP   6m25s
    kubernetes    ClusterIP   10.96.0.1        <none>        443/TCP    26m
    productpage   ClusterIP   10.98.241.7      <none>        9080/TCP   6m25s
    ratings       ClusterIP   10.103.108.170   <none>        9080/TCP   6m25s
    reviews       ClusterIP   10.97.156.61     <none>        9080/TCP   6m25s
    $ kubectl get pod
    NAME                              READY   STATUS    RESTARTS   AGE
    details-v1-79f774bdb9-9gpt7       2/2     Running   0          5m52s
    productpage-v1-6b746f74dc-grbbc   2/2     Running   0          5m53s
    ratings-v1-b6994bb9-6mb57         2/2     Running   0          5m52s
    reviews-v1-545db77b95-qpz5c       2/2     Running   0          5m52s
    reviews-v2-7bf8c9648f-bn7zh       2/2     Running   0          5m53s
    reviews-v3-84779c7bbc-v6nmc       2/2     Running   0          5m53s
    ```

7. Verify everything is working correctly up to this point. Run this command to see if the app is running inside the cluster and serving HTML pages by checking for the page title in the response:

    ```
    kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -sS productpage:9080/productpage | grep -o "<title>.*</title>"
    ```

8. Open the application to outside traffic
The Bookinfo application is deployed but not accessible from the outside. To make it accessible, you need to create an Istio Ingress Gateway, which maps a path to a route at the edge of your mesh.

    ```
    kubectl apply -f istio-1.9.1/samples/bookinfo/networking/bookinfo-gateway.yaml
    ```

9. Execute the following command to determine if your Kubernetes cluster is running in an environment that supports external load balancers

    ```
    kubectl get svc istio-ingressgateway -n istio-system
    NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                                      AGE
    istio-ingressgateway   LoadBalancer   10.109.183.245   localhost     15021:30530/TCP,80:31460/TCP,443:30035/TCP,31400:32190/TCP,15443:31590/TCP   57m
    ```
    Istio successfully established `localhost` ELB in MacOS `docker-desktop` so that we can directly use localhost as external ip, 80/443 for external http/https ports.

10. Run the following command to retrieve the external address of the Bookinfo application

    ```
    curl localhost/productpage
    ```

11. Use the following instructions to deploy the Kiali dashboard, along with Prometheus, Grafana, and Jaeger.

    ```
    # Run double time
    kubectl apply -f istio-1.9.1/samples/addons
    kubectl rollout status deployment/kiali -n istio-system
    ```

12. Access the Kiali dashboard

    ```
    istioctl dashboard kiali
    ```

## Notice

- Once you encounter the following error, that's because `istio-ingressgateway` is running for a long time and `SSLV3_ALERT_CERTIFICATE_EXPIRED` means cert is expired.

    ```
    $ curl localhost/productpage
    upstream connect error or disconnect/reset before headers. reset reason: connection failure, transport failure reason: TLS error: 268436501:SSL routines:OPENSSL_internal:SSLV3_ALERT_CERTIFICATE_EXPIRED%
    ```

    Checking `istio-ingressgateway` logs which confimred the issue as well

    ```
    $ kubectl logs istio-egressgateway-5d748f86d5-xxgmw -n istio-system
    "GET /productpage HTTP/1.1" 503 UF,URX upstream_reset_before_response_started{connection_failure,TLS_error:_268436501:SSL_routines:OPENSSL_internal:SSLV3_ALERT_CERTIFICATE_EXPIRED} - "TLS error: 268436501:SSL routines:OPENSSL_internal:SSLV3_ALERT_CERTIFICATE_EXPIRED" 0 201 17 - "192.168.65.3" "curl/7.64.1" "7551a421-5b82-9f0d-a2a8-f37ee91ed618" "localhost" "10.1.0.38:9080" outbound|9080||productpage.default.svc.cluster.local - 10.1.0.7:8080 192.168.65.3:59734 - -
    ```

    The easy alternative is just to restart the pod `istio-ingressgateway` and the issue should be getting fixed.

    ```
    $ kubectl delete pod -n istio-system istio-ingressgateway-67d647b4-hjc4t
    ```
