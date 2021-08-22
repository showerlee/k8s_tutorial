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
    OR
    istioctl manifest generate > ./generated-manifest.yaml
    kubectl apply -f ./generated-manifest.yaml
    ```

4. Deploy all addons integrated with istio(probably need run twice)

    ```
    kubectl apply -f istio-1.10.3/samples/addons
    ```
    More details: [README.md](istio-1.10.3/samples/addons/README.md)

5. Check crd and api resource.

    ```
    $ kubectl get crd | grep istio
    authorizationpolicies.security.istio.io    2021-08-07T13:45:19Z
    destinationrules.networking.istio.io       2021-08-07T13:45:19Z
    envoyfilters.networking.istio.io           2021-08-07T13:45:19Z
    gateways.networking.istio.io               2021-08-07T13:45:19Z
    istiooperators.install.istio.io            2021-08-07T13:45:19Z
    peerauthentications.security.istio.io      2021-08-07T13:45:19Z
    requestauthentications.security.istio.io   2021-08-07T13:45:19Z
    serviceentries.networking.istio.io         2021-08-07T13:45:19Z
    sidecars.networking.istio.io               2021-08-07T13:45:19Z
    telemetries.telemetry.istio.io             2021-08-07T13:45:19Z
    virtualservices.networking.istio.io        2021-08-07T13:45:19Z
    workloadentries.networking.istio.io        2021-08-07T13:45:20Z
    workloadgroups.networking.istio.io         2021-08-07T13:45:20Z

    $ kubectl api-resources | grep istio
    istiooperators                    iop,io       install.istio.io/v1alpha1              true         IstioOperator
    destinationrules                  dr           networking.istio.io/v1beta1            true         DestinationRule
    envoyfilters                                   networking.istio.io/v1alpha3           true         EnvoyFilter
    gateways                          gw           networking.istio.io/v1beta1            true         Gateway
    serviceentries                    se           networking.istio.io/v1beta1            true         ServiceEntry
    sidecars                                       networking.istio.io/v1beta1            true         Sidecar
    virtualservices                   vs           networking.istio.io/v1beta1            true         VirtualService
    workloadentries                   we           networking.istio.io/v1beta1            true         WorkloadEntry
    workloadgroups                    wg           networking.istio.io/v1alpha3           true         WorkloadGroup
    authorizationpolicies                          security.istio.io/v1beta1              true         AuthorizationPolicy
    peerauthentications               pa           security.istio.io/v1beta1              true         PeerAuthentication
    requestauthentications            ra           security.istio.io/v1beta1              true         RequestAuthentication
    telemetries                       telemetry    telemetry.istio.io/v1alpha1            true         Telemetry
    ```

6. Confirm the installation

    - Check via manifest
    
    ```
    istioctl verify-install -f ./generated-manifest.yaml
    ```

    - Check via dashboard
    ```
    istioctl dashboard kiali
    ```

## Demo(bookinfo)

![bookinfo](./docs/bookinfo.png)

1. Inject sidecar

    ```
    kubectl label namespace default istio-injection=enabled --overwrite=true
    ```

2. Deploy bookinfo

    ```
    kubectl apply -f istio-1.10.3/samples/bookinfo/platform/kube/bookinfo.yaml
    ```

3. Create Ingress gateway

    ```
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/bookinfo-gateway.yaml
    ```

4. Visit bookinfo

    ```
    curl http://localhost/productpage
    ```

5. Change traffic route to v1 only

    ```
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/virtual-service-all-v1.yaml
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/destination-rule-all.yaml
    ```

6. Change traffic route to v2 only
    ```
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/virtual-service-all-v2.yaml
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/destination-rule-all.yaml
    ```

7. Expose details via gateway.
    ```
    # Allow any domains to access
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/details-gateway.yaml
    # Check details output
    curl localhost/details/0
    # Check health output
    curl localhost/health
    ```
    ```
    # Only allow details.example.com to access
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/details-gateway-custom-host.yaml
    # Check details output
    curl --header "host: details.example.com" localhost/details/0
    # Check health output
    curl --header "host: details.example.com" localhost/health
    ```

8. Registry `httpbin` as internal serice in Mesh via ServiceEntry
    - Add sleep service to act as curl
        ```
        kubectl apply -f istio-1.10.3/samples/sleep/sleep.yaml
        ```
    
    - Visit external `httpbin.org` site to test if it is accessable
        ```
        kubectl exec -it sleep-557747455f-lktr5 -c sleep curl http://httpbin.org/headers
        {
            "headers": {
                "Accept": "*/*",
                "Host": "httpbin.org",
                "User-Agent": "curl/7.78.0-DEV",
                "X-Amzn-Trace-Id": "Root=1-611fb2b9-0c35890f1f2b65c1051eff72",
                "X-B3-Sampled": "0",
                "X-B3-Spanid": "56749a32650e0108",
                "X-B3-Traceid": "1ec3b070b77a3ecf56749a32650e0108",
                "X-Envoy-Attempt-Count": "1",
                "X-Envoy-Peer-Metadata": "ChkKDkFQUF9DT05UQUlORVJTEgcaBXNsZWVwChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwoZCg1JU1RJT19WRVJTSU9OEggaBjEuMTAuMwrfAQoGTEFCRUxTEtQBKtEBCg4KA2FwcBIHGgVzbGVlcAoZCgxpc3Rpby5pby9yZXYSCRoHZGVmYXVsdAohChFwb2QtdGVtcGxhdGUtaGFzaBIMGgo1NTc3NDc0NTVmCiQKGXNlY3VyaXR5LmlzdGlvLmlvL3Rsc01vZGUSBxoFaXN0aW8KKgofc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtbmFtZRIHGgVzbGVlcAovCiNzZXJ2aWNlLmlzdGlvLmlvL2Nhbm9uaWNhbC1yZXZpc2lvbhIIGgZsYXRlc3QKGgoHTUVTSF9JRBIPGg1jbHVzdGVyLmxvY2FsCiAKBE5BTUUSGBoWc2xlZXAtNTU3NzQ3NDU1Zi1sa3RyNQoWCglOQU1FU1BBQ0USCRoHZGVmYXVsdApJCgVPV05FUhJAGj5rdWJlcm5ldGVzOi8vYXBpcy9hcHBzL3YxL25hbWVzcGFjZXMvZGVmYXVsdC9kZXBsb3ltZW50cy9zbGVlcAoXChFQTEFURk9STV9NRVRBREFUQRICKgAKGAoNV09SS0xPQURfTkFNRRIHGgVzbGVlcA==",
                "X-Envoy-Peer-Metadata-Id": "sidecar~10.1.0.94~sleep-557747455f-lktr5.default~default.svc.cluster.local"
            }
        }
        ```

    - Disable `ALLOW_ANY` access in outbound Traffic (outboundTrafficPolicy=REGISTRY_ONLY)
        ```
        istioctl manifest generate --set meshConfig.outboundTrafficPolicy.mode=REGISTRY_ONLY meshConfig.accessLogFile=/dev/stdout > ./generated-manifest.yaml
        kubectl apply -f ./generated-manifest.yaml
        ```
    - Check the accessiability again
        ```
        kubectl exec -it sleep-557747455f-lktr5 -c sleep curl http://httpbin.org/headers
        # No more output refers the global traffic setting blocks all outbound access.
        ```
    - Create `ServiceEntry` to allow the outbound traffic for `httpbin.org`
        ```
        kubectl apply -f istio-1.10.3/samples/bookinfo/networking/service-entry-httpbin.yaml
        ```
    - Check whether the accessiability is back.
        ```
        kubectl exec -it sleep-557747455f-lktr5 -c sleep curl http://httpbin.org/headers
        {
            "headers": {
                "Accept": "*/*",
                "Host": "httpbin.org",
                "User-Agent": "curl/7.78.0-DEV",
                "X-Amzn-Trace-Id": "Root=1-611fb2b9-0c35890f1f2b65c1051eff72",
                "X-B3-Sampled": "0",
                "X-B3-Spanid": "56749a32650e0108",
                "X-B3-Traceid": "1ec3b070b77a3ecf56749a32650e0108",
                "X-Envoy-Attempt-Count": "1",
                "X-Envoy-Peer-Metadata": "ChkKDkFQUF9DT05UQUlORVJTEgcaBXNsZWVwChoKCkNMVVNURVJfSUQSDBoKS3ViZXJuZXRlcwoZCg1JU1RJT19WRVJTSU9OEggaBjEuMTAuMwrfAQoGTEFCRUxTEtQBKtEBCg4KA2FwcBIHGgVzbGVlcAoZCgxpc3Rpby5pby9yZXYSCRoHZGVmYXVsdAohChFwb2QtdGVtcGxhdGUtaGFzaBIMGgo1NTc3NDc0NTVmCiQKGXNlY3VyaXR5LmlzdGlvLmlvL3Rsc01vZGUSBxoFaXN0aW8KKgofc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtbmFtZRIHGgVzbGVlcAovCiNzZXJ2aWNlLmlzdGlvLmlvL2Nhbm9uaWNhbC1yZXZpc2lvbhIIGgZsYXRlc3QKGgoHTUVTSF9JRBIPGg1jbHVzdGVyLmxvY2FsCiAKBE5BTUUSGBoWc2xlZXAtNTU3NzQ3NDU1Zi1sa3RyNQoWCglOQU1FU1BBQ0USCRoHZGVmYXVsdApJCgVPV05FUhJAGj5rdWJlcm5ldGVzOi8vYXBpcy9hcHBzL3YxL25hbWVzcGFjZXMvZGVmYXVsdC9kZXBsb3ltZW50cy9zbGVlcAoXChFQTEFURk9STV9NRVRBREFUQRICKgAKGAoNV09SS0xPQURfTkFNRRIHGgVzbGVlcA==",
                "X-Envoy-Peer-Metadata-Id": "sidecar~10.1.0.94~sleep-557747455f-lktr5.default~default.svc.cluster.local"
            }
        }
        ```

9. Canary release via `VirtualService`
    ```
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml
    ```
    ```
    # Route to v2 version if browser is Chrome
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/virtual-service-reviews-50-v2-chrome.yaml
    ```

10. Setup ingress for `httpbin`
    ```
    # Deploy httpbin
    kubectl apply -f istio-1.10.3/samples/httpbin/httpbin.yaml
    # Deploy Gateway for httpbin
    kubectl apply -f istio-1.10.3/samples/httpbin/httpbin-gateway.yaml
    # Test interface /status
    curl -I -H host:httpbin.example.com http://localhost/status/200
    # Test interface /delay
    curl -I -H host:httpbin.example.com http://localhost/delay/5
    ```

11. Registry `httpbin` as internal serice in Mesh via `egress`

    ![egress](./docs/egress.png)
    ```
    # Check wheather egress exists
    kubectl get pods -n istio-system |grep egress
    istio-egressgateway-5547fcc8fc-24ckx    1/1     Running   0          104m

    # Apply serviceEntry for egress
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/service-entry-httpbin-egress.yaml

    # Get ip from outside httpbin
    kubectl exec -it sleep-557747455f-l8jwc -c sleep curl http://httpbin.org/ip
    # No more outcome

    # Config egressgateway and virtualservice
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/egress-gateway.yaml

    # Deploy DestinationRule
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/destination-rule-egress.yaml

    # Check egressgateway log
    kubectl logs -n istio-system istio-egressgateway-5547fcc8fc-24ckx -f

    # Use `sleep` to curl
    kubectl exec -it sleep-557747455f-l8jwc -c sleep curl http://httpbin.org/ip
    {
    "origin": "x.x.x.x, x.x.x.x"
    }
    ```

12. Timeout retry: improve the robustness and availability of the system

    ![retry-timeout](./docs/retry-timeout.png)

    ```
    # Route review to v2 version
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/virtual-service-reviews-v2.yaml

    # Ratings retry(2s latency)
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/virtual-service-ratings-retry.yaml

    # Visit productpage where ratings has 2s latency and 2 attempts
    curl http://localhost/productpage

    # Review 1s timeout
    kubectl apply -f istio-1.10.3/samples/bookinfo/networking/virtual-service-review-timeout.yaml

    # Visit productpage where review has 1s timeout, but since ratings has 2s latency, it would have internal unavailability.
    curl http://localhost/productpage

    # Check if any logs print ratings performs 2 attempts
    kubectl logs -f ratings-v1-b6994bb9-l4j29 -c istio-proxy
    ```
