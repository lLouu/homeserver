#!/bin/sh
repository=$1
branch=$2
inventory_hostname=$3
sudo /usr/bin/wget https://raw.githubusercontent.com$repository/$branch/sub_scripts/0trust/anti_lock -O /etc/sudoers.d/anti_lock
sudo /usr/bin/wget https://raw.githubusercontent.com$repository/$branch/sub_scripts/0trust/$inventory_hostname\_zt -O /etc/sudoers.d/ansible_zt
sudo /bin/chmod 0644 /etc/sudoers.d/ansible_zt
sudo /bin/rm /etc/sudoers.d/ansible 2>/dev/null