I only really learned how to use Helm in late September, so there are a lot of "manually-crafted Kubernetes manifests"
elsewhere in `k8s-objects/` that could easily have just been charts.

`install-all-charts.sh` should, well - install all the charts :P

Naming convention is that each directory contains:
* `chart-info.yaml`, of format:
  * `chartRepos` - (possibly empty/absent) list of objects representing repos that need to be added before continuing. Of form:
    * `name` - name the repo should be registered as
    * `url` - url of repo
  * `chartReference` - reference to chart to install
  * `chartName` - name to install to
  * `namespace` - namespace to install to
* `values.yaml` - (possibly absent) argument to `--values`

`chart-info.yaml` is optional, as are the values `chartReference`, `chartName`, and `namespace`. In their absence, `chartReference` will default to `helm/`, and `chartName` and `namespace` to the name of the directory.

Pseudocode, this would result in:
```pseudo
for repo in chartRepos:
  helm repo add repo.name repo.url

helm install --create-namespace -n <namespace> <chartName> <chartReference> [--values values.yaml]
```

## Post-install notes

Note that the full output and err of each directory will be available in `out/<name>.{out,err}` - these are just some things that you should make sure not to forget!

### Argo

Initial credentials:
Username: `admin`
Password: `$(kubectl -n argo get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)`

