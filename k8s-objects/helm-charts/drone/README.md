TODO:
* Create the following in an initContainer if they don't exist:
  * The Gitea OAuth application at startup
  * The Prometheus user (https://cogarius.medium.com/3-3-complete-guide-to-ci-cd-pipelines-with-drone-io-on-kubernetes-drone-metrics-with-prometheus-c2668e42b03f) - probably by mounting the volume, using sqlite3 to parse out admin password, then using that to make API call