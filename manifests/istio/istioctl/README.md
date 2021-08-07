# Istioctl

## Setup istio in docker-desktop
Details: https://istio.io/latest/docs/setup/getting-started/

1. Download istio

    ```
    curl -L https://istio.io/downloadIstio | sh -
    ```

2. Copy istioctl to env path

    ```
    cp istio-1.10.3/bin/istioctl /usr/local/bin/
    ```

3. Initialize istioctl via demo config profile

    ```
    istioctl install --set profile=demo -y
    ```

4. Deploy all addons integrated with istio(probably need run twice)

    ```
    kubectl apply -f samples/addons
    ```
    More details: [README.md](istio-1.10.3/samples/addons/README.md)
