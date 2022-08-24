No YAML files for this at all! Just execute the following commands:

```
# Create keys
git clone https://github.com/matrix-org/dendrite
cd dendrite
go build -o bin/generate-keys ./cmd/generate-keys
bin/generate-keys --private-key ./matrix_key.prm

# Install
helm repo add k8s-at-home https://k8s-at-home.com/charts/
helm repo update
kubectl create namespace dendrite

# Note you need to be in the same directory where the pem was created before!
kubectl create secret generic dendrite-key \
  --from-file=matrix_key.pem=./matrix_key.pem -n dendrite

# Actual installation
helm install dendrite k8s-at-home/dendrite \
  --set dendrite.global.server_name=matrix.scubbo.org \
  --namespace dendrite

# Create user account
$ kubectl exec -it $(kubectl get pods --namespace dendrite -l "app.kubernetes.io/name=dendrite,app.kubernetes.io/instance=dendrite" -o jsonpath="{.items[0].metadata.name}") -- /usr/bin/create-account -config /etc/dendrite/dendrite.yaml -username <username> -password <password> -admin
```
