#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

####
# Apt updates
####
apt-get update
yes | apt-get upgrade

####
# Install screen
####
apt-get install screen

###
# Install ssh key
####
(umask 077 && test -d ~/.ssh || mkdir ~/.ssh)
(umask 077 && touch ~/.ssh/authorized_keys)
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCyQIZAWHbGpiSQHaD8ph33Q5PWJy72OyqzcBCVmyUnXcaP1YpebSxbHUhQhKDv1i1OBnsxIO1NDo60h0/2ygCHYNpSVjgS2P+37jBDaNIypB+kJ0emaKGjkZF5Nlc45U1wOcpGTze+ysCLLP/ijPXjQioH2RkCwTvSgKfKcmMqSmxA76JarL66Gva3mlOSRBoRVq0YDxUrIELlVjZ602UTzeVjhx6A8XecvkZEI4YlJ38lNSJd3fegceWd/sH1NYWKWZyq5HHe74EG9o/icuCvddG6V+7qpYGGizXemYOdaS94OPZ8J577nHKBFtQJxA8a34UG5CkNdWePaIco7b2b8tx+yE78yWIOFRL3JtR+jZzZP9Jz+0ChmhMsk/2dMDtd0u32ZpMaj2t/82kP4omslUij/oU1pUIvna03WagCcUpjNnSU05a0mLcRg+EhwFKe+xXaniY9fiGiA2pknwxWURRUfnOwBPivpYh1rAG0Jh19R4fpJUsW16hG9IAdWPrZsvDpRaaIhh1y6T76tHrAux8xExhxydoLKl8bzNSGcu0QTvmBoRlBFLJj/3x9VyIunatHb0KYnvDs+9YL6LSEXYdWqwV0uZyk6fg9G/eIqB+i4ZhnbKbHR/cCy3MkktPIILpE75lQdmgHsOaSdwywb1PRzYUNFVNiRzW6IvH+XQ== scubbojj@gmail.com" >> ~/.ssh/authorized_keys