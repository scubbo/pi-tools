**NOTE** that this setup will hopefully soon be replaced by
the Kubernetes-based setup in `kube_setup` (much of which, hopefully, will do all of this in a single publicly-accessible script)

Refs for noninteractive `raspi-config` setup [here](https://raspberrypi.stackexchange.com/a/66939/118884) and [here](https://loganmarchione.com/2021/07/raspi-configs-mostly-undocumented-non-interactive-mode/)
1. `sudo raspi-config nonint do_expand_rootfs`
2. `sudo raspi-config nonint do_change_locale en_US.UTF-8`
3. `sudo raspi-config nonint do_wifi_country US`
4. `sudo raspi-config nonint do_hostname <hostname>`
   * Need a reboot for this to take effect
5. `sudo apt-get install -y git`
6. Add ssh key to Github:
   * Run `ssh-keygen -t ed25519 -C "<email>"`
   * `eval "$(ssh-agent -s)"`
   * `ssh-add ~/.ssh/id_ed25519`
   * `cat ~/.ssh/id_ed25519.pub` and copy
   * In GitHub, go to Settings, SSH and GPG keys, New SSH Key, and paste
   * Confirm connection by running `ssh -T git@github.com`
5. `git clone git@github.com:scubbo/pi-tools.git "$HOME/pi-tools"`
6. Run `1_setup_screen_and_ssh.sh` first so that you can run later scripts in screens and login with ssh-key. Check that a new terminal window can ssh with `~/.ssh/id_rsa`
7. Run `updateDNS.py` and set to run regularly with crontab
8. Run `2_full_setup.sh -h <hostname>`
