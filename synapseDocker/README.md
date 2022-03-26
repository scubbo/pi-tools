1. Build Dockerfile - `docker build -t <image_name> .`
2. Run container - `docker run -d -p 9015:8008 <image_name>`
3. Create user on container - `docker exec -it <container_name> /bin/sh`
    then `register_new_matrix_user -c homeserver.yaml -u <username> -p <password> -a http://localhost:8008`
4. Run Cloudflared tunnel - `/usr/bin/cloudflared tunnel --hostname <hostname> --url localhost:9015`

If you instead want to host locally without Cloudflared tunnel, consider the `nginx.conf` file (untested!) and set the IP address of `<hostname>` directly to your Pi (and forward a port through your router firewall)