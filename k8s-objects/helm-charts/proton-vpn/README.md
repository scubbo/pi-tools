Implements [this guide](https://docs.k8s-at-home.com/guides/pod-gateway/).


## Dependencies

### Cert-manager

Depends on the CRDs installed as part of `cert-manager`, which apparently will not be installed if that chart is a dependency of this one - so it's installed manually in its own directory.

The `install-chart.sh` script should take care of installation for you, but if you need to install it manually, run `helm repo add jetstack https://charts.jetstack.io; helm repo update; helm install --create-namespace -n security jetstack/cert-manager cert-manager --set installCRDs=true`

## Secrets

Note that the names of both of these secrets are arbitrary (though the keys within them are not) - the expected names are set in `values.yaml`.

### Config file

Depends on the existence of a secret called `openvpn-config`, with a key `vpnConfigfile` that contains the appropriate config file. Download it from [here](https://account.protonvpn.com/downloads) and upload it with:

```
kubectl -n proton-vpn create secret generic openvpn-config --from-file=vpnConfigfile=<path_to_config_file>
```

### OpenVPN creds

Fetch from [here](https://account.protonvpn.com/account) (note - these are different from your OpenVPN credentials!), then upload with:

```
kubectl -n proton-vpn create secret generic openvpn-creds --from-literal="VPN_AUTH=<username>;<password>"
```

Note that you can (apparently!) append various suffices to the OpenVPN username to enable extra features if you are a paying member:

* `<username>+f1` as username to enable anti-malware filtering
* `<username>+f2` as username to additionally enable ad-blocking filtering
* `<username>+nr` as username to enable Moderate NAT

I haven't tested - use at your own risk! Probably best to get a functioning connection working before messing around with extra features.

### update-resolv-conf

TODO: (Not sure if this is required for all servers...) This is required by the ProtonVPN OpenVPN configuration (line 124)

## Debugging

### `GATEWAY_IP=';; connection timed out; no servers could be reached'`

As per [here](https://docs.k8s-at-home.com/guides/pod-gateway/#routed-pod-fails-to-init), "_try setting the_ `NOT_ROUTED_TO_GATEWAY_CIDRS:` _with your cluster cidr and service cidrs_". The way to find those values is described [here](https://stackoverflow.com/questions/44190607/how-do-you-find-the-cluster-service-cidr-of-a-kubernetes-cluster)

## More info

Some OpenVPN server configurations rely on a script at `/etc/openvpn/update-resolv-conf.sh`, which isn't provided by default. It [looks like](https://github.com/dperson/openvpn-client/issues/90) it's been replaced with `/etc/openvpn/up.sh` and `.../down.sh` - you should be able to manually edit the `.ovpn` file to reference those scripts instead.

If you really need the original file - get it from [here](https://github.com/alfredopalhares/openvpn-update-resolv-conf) and provide it in a ConfigMap:

```
curl -s https://raw.githubusercontent.com/alfredopalhares/openvpn-update-resolv-conf/master/update-resolv-conf.sh -o /tmp/update-resolv-conf
```

### Debugging image

Useful tools to install:

```
apt update -y
apt install -y traceroute net-tools iputils-ping dnsutils
```

## References

* [Values definition for VPN](https://github.com/k8s-at-home/library-charts/blob/2b4e0aa1ef5f8c6ef4ac14c2335fc9a008394ed6/charts/stable/common/values.yaml#L479)
* [Charts for VPN](https://github.com/k8s-at-home/library-charts/tree/2b4e0aa1ef5f8c6ef4ac14c2335fc9a008394ed6/charts/stable/common/templates/addons/vpn)
* [Pod Gateway templates](https://github.com/k8s-at-home/charts/tree/master/charts/stable/pod-gateway/templates)
