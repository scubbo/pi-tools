Note - if deleting a RabbitMqCluster hangs, do:

```
$ kubectl patch rabbitmqclusters.rabbitmq.com/grafana-oncall-rabbitmq-cluster -p '{"metadata":{"finalizers":[]}}' --type=merge
```

and retry

---

The example given in [README](https://github.com/grafana/oncall/tree/dev/helm) seems to rely on the `kind` installation contents - gives `ensure CRDs are installed first, resource mapping not found for name: "<name>" namespace: "" from "": no matches for kind "PodSecurityPolicy" in version "policy/v1beta1"`

---

Full "Nuke it from orbit" deletion command:

```
kubectl patch persistentvolumeclaim/persistence-grafana-oncall-cluster-server-0 -p '{"metadata":{"finalizers":[]}}' --type=merge; kubectl patch rabbitmqclusters.rabbitmq.com/grafana-oncall-rabbitmq-cluster -p '{"metadata":{"finalizers":[]}}' --type=merge; kubectl patch pod grafana-oncall-rabbitmq-cluster-server-0 -p '{"metadata":{"finalizers":[]}}' --type=merge; helm uninstall -n grafana grafana-oncall; kubectl delete secret postgres-auth-secret; kubectl delete rabbitmqcluster.rabbitmq.com/grafana-oncall-rabbitmq-cluster; kubectl get persistentvolumeclaims | grep -v 'NAME' | grep 'oncall' | awk '{print $1}' | xargs kubectl delete persistentvolumeclaim
```

Expects a secret named `telegram-auth-secret` with key `token`