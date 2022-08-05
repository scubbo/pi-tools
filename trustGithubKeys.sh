cat ~/.ssh/authorized_keys <(curl -s https://github.com/scubbo.keys) | sort | uniq > ~/.ssh/authorized_keys
