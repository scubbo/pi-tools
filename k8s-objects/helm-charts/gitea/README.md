Hand-crafted Helm chart, rather than using the [officially provided one](https://gitea.com/gitea/helm-chart/), since
I have an existing working Gitea setup and I'm trying to port that with minimal disruption rather than update to new
dependencies.

Note you may need to reset the password - log onto a pod, and run `gitea admin user change-password` as user `git`