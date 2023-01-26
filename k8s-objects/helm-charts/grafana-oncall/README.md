Note - if deleting a RabbitMqCluster hangs, do:

```
$ kubectl patch rabbitmqclusters.rabbitmq.com/grafana-oncall-rabbitmq-cluster -p '{"metadata":{"finalizers":[]}}' --type=merge
```

and retry