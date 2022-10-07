Hand-crafted Helm chart, rather than using the [officially provided one](https://gitea.com/gitea/helm-chart/), since
I have an existing working Gitea setup and I'm trying to port that with minimal disruption rather than update to new
dependencies.

Note you may need to reset the password - log onto a pod, and run `su git -c "gitea admin user change-password --username <username> --password <password>"`

Note also that the `NodePort` Service is set up like so because Cloudflare Tunnels cannot handle ssh traffic ([without installing custom software on the client](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/use_cases/ssh/)). You will also need to update the Router for your LAN to Port Forward to this NodePort, and set up a public DNS record pointing to your network.
