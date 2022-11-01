Mostly created from [this guide](https://cogarius.medium.com/3-3-complete-guide-to-ci-cd-pipelines-with-drone-io-on-kubernetes-drone-metrics-with-prometheus-c2668e42b03f)  - but see also `prometheus-additional`!

Some useful snippets:

## See `scrape_configs`

```
$ kubectl get secret prometheus-prometheus-kube-prometheus-prometheus -o jsonpath='{.data}' |\
    jq '."prometheus.yaml.gz"' -r | base64 -d | gzip -d - | less
```

## See labels that ServiceMonitors must have to be picked up

```
$ kubectl get prometheus prometheus-kube-prometheus-prometheus -o json | jq '.spec.serviceMonitorSelector.matchLabels'
```