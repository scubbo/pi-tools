## Prep work

Some of the services required for Plausible do not have images released for ARM architecture, and Plausible itself had a bug in the latest commit (at time of writing), so you will need to prepare specific images and make them available in your choice of cotnainer registry (see [here](https://blog.scubbo.org/posts/secure-docker-registry/) for a blog post on setting up secure access to your own registry).

* `bytemark/smtp` needs to be built on ARM architecture
* `plausible/analytics` needs to be built **on commit** `3242327d` on ARM architecure (note - please do experiment with the latest commit and let me know if I can resolve this to simply building on latest!)

## Kubernetes creation

0. `kubectl apply -f namespace.yaml`
1. Create the following secrets and keys (using `kubectl -n plausible create secret generic --from-file=./<filename> --from-file=/<filename2> ...`):

```
postgres-secrets:
  password: <arbitrary string>
plausible-secrets:
  email: <your email>
  password: <arbitrary string>
  username: <admin username>
  secret-key-base: <arbitrary string>
```

Suggestions for generation method: `openssl rand -base64 64 | tr -d '\n' ; echo` for secret key, and any option from [here](https://www.howtogeek.com/howto/30184/10-ways-to-generate-a-random-password-from-the-command-line/) for the password.

Make sure to use `echo -n ... > <file_name>` to create the file containing the secret value, rather than writing as usual with `vi` or another editor, to prevent newlines being included in the secret.

2. (If you are not me - that is, if you are working with a different site or a different-addressed Container Registry) update the appropriate values (image locations of `bytemark` and `plausible`, and `BASE_URL` env value for Plausible container) in the appropriate files (`dependencies.yaml` and `main-deployment.yaml`). You probably also want to change the definition of the Persistent Volume Claims, since your NFS setup will be different from mine.
3. Apply the files.
