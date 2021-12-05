1. Change password (`$ passwd`)
2. `sudo apt-get install git`
3. Run `sudo raspi-config`, and set up locale (TODO: find a way to do this automatically)
4. `scp ~/.ssh/id_rsa* pi@<ip>:/home/pi/.ssh/` (TODO: figure out if it's sensible to instead create a standalone ssh key?)
5. `git clone git@github.com:scubbo/pi-tools.git /tmp/pi-tools`
6. Run `1_setup_screen_and_ssh.sh` first so that you can run later scripts in screens and login with ssh-key. Check that a new terminal window can ssh with `~/.ssh/id_rsa`
7. Run `updateDNS.py` and set to run regularly with crontab
8. Run `2_full_setup.sh -h <hostname>`
