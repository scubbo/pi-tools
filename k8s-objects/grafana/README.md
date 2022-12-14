Consider instead installing via [this Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

Consider installing dashboards from [here](https://github.com/dotdc/grafana-dashboards-kubernetes)
* if you haven't used the Helm chart above, you'll need to install dependencies
* you'll also need to add the Prometheus data source, which is by-default available on 

You almost-certainly want to apply the files in the `prometheus` folder,  too.

Good dashboards sourced from [here](https://github.com/dotdc/grafana-dashboards-kubernetes#install-via-grafanacom).
TODO: currently can't get `node-exporter` to show up
as a target in Prometheus. And Global-view dashboard
shows 0 nodes, and doesn't have storage in it.

Look to add dashboard view (or reporting, or alerting) on
errored/stalled pods.

Consider also translating IPs to names in (e.g.)
"CPU Utilization by Node" in Global