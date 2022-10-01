The [postgresql Helm chart](https://github.com/bitnami/charts/blob/master/bitnami/postgresql/templates/primary/statefulset.yaml#L462-L468) does not include capability to define the primary persistence volume as an NFS mount. Before deploying this Helm chart, we need to create an NFS provisioner and then create a PVC using it.

1. Referencing [this](https://www.phillipsj.net/posts/k3s-enable-nfs-storage/), create a file at `/var/lib/rancher/k3s/server/manifests/nfs.yaml` defining an NFS provisioner. Consider setting `storageClass.reclaimPolicy=Retain`
2. Wait until `kubectl get storageclasses` reports the newly-created storageclass
3. `kubectl apply -f pvc.yaml`

Then:

```
helm install dendrite k8s-at-home/dendrite \
    --set dendrite.global.server_name=matrix.scubbo.org \
    --set clientapi.config.registration_shared_secret=abcdef \
    --set postgresql.enabled=true \
    --set postgresql.image.repository=arm64v8/postgres \
    --set postgresql.image.tag=latest \
    --set postgresql.primary.persistence.enabled=true \
    --set postgresql.primary.persistence.existingClaim=claim-for-dendrite-database \
    --set postgresql.volumePermissions.enabled=true \
    --set postgresql.volumePermissions.image.registry=docker.io \
    --set postgresql.volumePermissions.image.repository=busybox \
    --set postgresql.volumePermissions.image.tag=latest
```

to set up the (persistent) Matrix server.

(Ensure you also set up a Cloudflared mapping!)

Create a user with:

```
kubectl exec -it \
  $(kubectl -n dendrite get pods -l app.kubernetes.io/name=dendrite -o jsonpath="{.items[0].metadata.name}") \
  -- /usr/bin/create-account -config /etc/dendrite/dendrite.yaml -url <url with scheme> -username <name> -password <password> -admin
```

## Debugging

### Getting logs from initContainer

`kubectl logs $(kubectl get pods -n dendrite -l "app.kubernetes.io/component=primary" -o jsonpath="{.items[0].metadata.name}") -c init-chmod-data`

### Password reset

```
USERNAME=...
PASSWORD=...
NEW_PASSWORD=...
# https://spec.matrix.org/v1.3/client-server-api/#get_matrixclientv3login
ACCESS_TOKEN=$(curl -s https://matrix.scubbo.org/_matrix/client/v3/login -d '{"type":"m.login.password","identifier":{"type":"m.id.user","user":"@$USERNAME:matrix.scubbo.org"},"password":"$PASSWORD"}' | jq --raw-output '.access_token')
# https://spec.matrix.org/v1.3/client-server-api/#post_matrixclientv3accountpassword
curl -s https://matrix.scubbo.org/_matrix/client/v3/account/password -H "Authorization: Bearer $ACCESS_TOKEN "-d '{"new_password":"$NEW_PASSWORD"}'
```
