#!/bin/bash

# Inspired by https://www.raspberrypi.org/forums/viewtopic.php?t=114484
SPEED=`ethtool eth0 2>/dev/null | grep -i "Speed" | awk '{print $2}' | grep -o '[0-9]*'`
if ifconfig | grep -i "eth0"  > /dev/null 2>&1; then
  echo "Ethernet interface is up. Checking connection speed"
  echo "DEBUG - speed is $SPEED"
  if [ $SPEED -gt "200" ]; then
    echo "Ethernet has good enough speed - disabling Wifi"
    ifdown --force wlan0
  else
    echo "Ethernet speed is too low - (re-)enabling WiFi"
    ifup wlan0
  fi
else
  echo "Ethernet interface is not up - (re-)enabling WiFi"
  ifup wlan0
fi
