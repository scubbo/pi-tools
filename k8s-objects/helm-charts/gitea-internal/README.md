This sets up a Gitea instance that is _only_ accessible on the internal address (`gitea.avril`). This is necessary to
solve the cold-start problem:

* Public accessibility of services is provided by Cloudflared tunnels
* My current setup of Cloudflared tunnels requires an image to run in initContainers to update DNS
* If Gitea is not available on the public endpoint, we have a deadlock
  * Note that it is not sufficient to have Kubernetes reference Gitea via the private name, since the `docker pull` will still fail at login if Gitea's not available on the `ROOT_URL` configured for Gitea: see [here](https://github.com/go-gitea/gitea/issues/22033).

