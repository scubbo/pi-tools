```
curl https://raw.githubusercontent.com/scubbo/pi-tools/main/scripts-on-pi/kube_setup/universal_setup.sh > setup.sh
sudo chmod +x setup.sh
./setup.sh
```

(Can't just `curl | bash` because there is `read` call)
