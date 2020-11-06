#!/bin/bash

# firewall on
sudo sed -i 's/ENABLED=no/ENABLED=yes/g' /target/etc/ufw/ufw.conf

# add pkgs
#chroot /target sudo apt update
#chroot /target sudo apt install -y gparted unalz
#chroot /target sudo apt install -y google-chrome-stable

# reset machin-id
cat /dev/null | sudo tee /target/etc/machine-id

# add installed user count
RD=`head -c 16 /dev/urandom | md5sum | head -c 32`
CODE="jin"
VER="4.0"
curl -XPOST "http://pms.invesume.com:8086/write?db=hamonikr" --data-binary "machineid,codename=$CODE,version=$VER value=\"$RD\""
