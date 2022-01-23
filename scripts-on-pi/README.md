# https://raspberrypi.stackexchange.com/a/66939/118884
1. `sudo raspi-config nonint do_expand_rootfs`
2. Change password (`$ passwd`)
3. `sudo apt-get instal -y git`
4. Run `sudo raspi-config`, and set up locale (TODO: find a way to do this automatically)
5. Add ssh key to Github:
   * Run `ssh-keygen -t ed25519 -C "<email>"`
   * `eval "$(ssh-agent -s)"`
   * `ssh-add ~/.ssh/id_ed25519`
   * `cat ~/.ssh/id_ed25519.pub` and copy
   * In GitHub, go to Settings, SSH and GPG keys, New SSH Key, and paste
   * Confirm connection by running `ssh -T git@github.com`
6. `git clone git@github.com:scubbo/pi-tools.git "$HOME/pi-tools"`
7. Run `1_setup_screen_and_ssh.sh` first so that you can run later scripts in screens and login with ssh-key. Check that a new terminal window can ssh with `~/.ssh/id_rsa`
8. Run `updateDNS.py` and set to run regularly with crontab
9. Run `2_full_setup.sh -h <hostname>`
