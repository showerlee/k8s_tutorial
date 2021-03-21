# Istio Operator

This is the Istio operator manage the installation for you. This relieves you of the burden of managing different istioctl versions. Simply update the operator custom resource (CR) and the operator controller will apply the corresponding configuration changes for you.

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
