Manual setup steps (I'm still learning, not clear whether it's better practice to reference the existing external yaml files or to set up your own versions here? Or is this where I'm supposed to learn helm?):

```
sudo mkdir /home/pi/.kube
sudo chown pi:pi /home/pi/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/pi/.kube/config
export KUBECONFIG=/home/pi/.kube/config
# Base resources that are not aligned to specific app
kubectl apply -R -f global
# Not sure whether we should declare all namespaces in yaml files, or create them manually? One-offs and rare, so probably doesn't matter _that_ much?
kubectl create namespace kubernetes-dashboard
kubens kubernetes-dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml
kubectl apply -f dashboard_user_resources
```

Grab a Token with `kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}" | pbcopy`

Then you can `kubectl apply -R -f <dir>` whatever directories you want! (Though note that any that declare namespaces, you probably need to create those namespaces first?)

## Helm Charts

Some services are best installed via Helm rather than direct Kubernetes application.

### Matrix

[README.md](dendrite/README.md)