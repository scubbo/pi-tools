## PreReqs

There is no arm64 compatible RabbitMQOperator available ([issue](https://github.com/rabbitmq/cluster-operator/issues/366))
so you will have to build your own:

* `git clone git@github.com:rabbitmq/cluster-operator.git`
* `cd cluster-operator`
* `sed -i'' 's/GOARCH=amd64/GOARCH=arm64/' Dockerfile`
  * Note - on Mac, you need a space between `-i` and `''` 
* Build and push the image to your favourite Image Repository. E.g.:
  * `docker build -t <your_registry_address>/rabbitmq/cluster-operator .`
  * `docker push <your_registry_address>/rabbitmq/cluster-operator`

## Installation

Oncall can be installed with [this Helm chart](https://github.com/grafana/oncall/tree/dev/helm/oncall). Notes:
* Create password-secret first:
  * `PASSWORD=$(date +%s | sha256sum | base64 | head -c 32); echo $PASSWORD; kubectl create secret -n grafana generic oncall-mysql-password --from-file=password=<(echo -n $PASSWORD)`
  * (Note that `echo -n` is very important, otherwise the trailing newline will get included in the secret, and various systems are inconsistent in how they handle that. Don't run the risk!)
* Run MySQL as per [here](https://kubernetes.io/docs/tasks/run-application/run-single-instance-stateful-application/),
    with `kubectl apply -f mysql.yaml`
* Run RabbitMQ as per [here](https://www.rabbitmq.com/kubernetes/operator/quickstart-operator.html)
    but using your previously-built image:
```
kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"
kubectl set image -n rabbitmq-system deploy/rabbitmq-cluster-operator operator=<name_of_image>
```

(note that this installs to a namespace named `rabbitmq-system` - I'm not messing
with that until I properly understand what's being set up)
* Create a RabbitMQ Cluster: `kubectl apply -f rabbitmq-cluster.yaml`
  * (Note that this creates in `grafana` namespace)
* Install oncall:

```
helm install -f values.yaml \
--set externalMysql.password=$(kubectl get secret -n grafana oncall-mysql-password --template={{.data.password}} | base64 --decode) \
--set externalRabbitmq.user=$(kubectl get secret -n grafana grafana-oncall-rabbitmq-cluster-default-user --template={{.data.username}} | base64 --decode) \
--set externalRabbitmq.password=$(kubectl get secret -n grafana grafana-oncall-rabbitmq-cluster-default-user --template={{.data.password}} | base64 --decode) \
oncall grafana/oncall
```

* Manually install the Ingress (since the Helm chart doesn't permit setting `ingressClassName`, and so it ends up
    clashing with the existint Traefik installation provided by k3s):
  * `kubectl apply -f ingress.yaml`
  * Remember to set an appropriate DNS record!


## Uninstalling

```bash
helm uninstall oncall

kubectl delete pvc data-release-oncall-mariadb-0 data-release-oncall-rabbitmq-0 \
redis-data-release-oncall-redis-master-0 redis-data-release-oncall-redis-replicas-0 \
redis-data-release-oncall-redis-replicas-1 redis-data-release-oncall-redis-replicas-2

kubectl delete secrets certificate-tls release-oncall-cert-manager-webhook-ca release-oncall-ingress-nginx-admission
```