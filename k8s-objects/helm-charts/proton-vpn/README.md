Implements [this guide](https://docs.k8s-at-home.com/guides/pod-gateway/).

Note that this chart depends on the CRDs installed as part of `cert-manager`, which apparently will not be installed if that chart is a dependency of this one - so it's installed manually in its own directory.

## Debugging

### `GATEWAY_IP=';; connection timed out; no servers could be reached'`

As per [here](https://docs.k8s-at-home.com/guides/pod-gateway/#routed-pod-fails-to-init), "_try setting the_ `NOT_ROUTED_TO_GATEWAY_CIDRS:` _with your cluster cidr and service cidrs_". The way to find those values is described [here](https://stackoverflow.com/questions/44190607/how-do-you-find-the-cluster-service-cidr-of-a-kubernetes-cluster) 