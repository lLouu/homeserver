#! /bin/bash

start=$(date +%s)

banner (){
        echo '______  __                     ________                               ';
        echo '___  / / /____________ __________  ___/______________   ______________';
        echo '__  /_/ /_  __ \_  __ `__ \  _ \____ \_  _ \_  ___/_ | / /  _ \_  ___/';
        echo '_  __  / / /_/ /  / / / / /  __/___/ //  __/  /   __ |/ //  __/  /    ';
        echo '/_/ /_/  \____//_/ /_/ /_/\___//____/ \___//_/    _____/ \___//_/     ';
        echo ""
        echo "Author : lLou_"
        echo "Script version : V0.1"
        echo ""
        echo ""
}

# Get current user
usr=$(whoami)
if [[ $usr == "root" ]];then
        echo "[-] Running as root. Please run in rootless mode... Exiting..."
        exit 1
fi

stop (){
   if [[ -f "/etc/sudoers.d/tmp" ]];then sudo rm /etc/sudoers.d/tmp; fi
   exit 1
}
trap stop INT

# Get sudoer ticket
printf "Defaults\ttimestamp_timeout=-1\n" | sudo tee /etc/sudoers.d/tmp > /dev/null

banner

###############

# Update system
echo "[~] Updating system"
sudo apt-get update > /dev/null
echo "[~] Updating done, upgrading system"
sudo apt-get upgrade -y > /dev/null
sudo apt-get autoremove -y > /dev/null
echo "[+] Updating and upgrading done"
echo ""

# Proxmox installation
## Hostname management
echo "[~] Redefine hostname ip"
ip=$(ip a | grep "inet " | grep -v 127.0.0.1 | awk '{print($2)}' | cut -d'/' -f1)
sudo cp /etc/hosts /etc/hosts.bck
sudo sed -i -e "s/127.0.1.1/$ip/g" /etc/hosts
if [[ "$(hostname --ip-address)" != "$ip" ]]; then
    echo "[-] Failed to change hostname ip to $ip"
    sudo mv /etc/hosts.bck /etc/hosts
    exit 1
fi
sudo rm /etc/hosts.bck
echo "[+] Hostname ip setted to $ip"

## Add proxmox VE repo
echo "[~] Adding proxmox VE repo"
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" | sudo tee /etc/apt/sources.list.d/pve-install-repo.list > /dev/null
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O ~/proxmox-release-bookworm.gpg >/dev/null
if [[ "$(sha512sum ~/proxmox-release-bookworm.gpg | awk '{print($1)}')" != "7da6fe34168adc6e479327ba517796d4702fa2f8b4f0a9833f5ea6e6b48f6507a6da403a274fe201595edc86a84463d50383d07f64bdde2e3658108db7d6dc87" ]]; then
    echo "[-] Failed to fetch gpg key for proxmox repo"
    rm ~/proxmox-release-bookworm.gpg >/dev/null 2>/dev/null
    exit 1
fi
sudo mv ~/proxmox-release-bookworm.gpg /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
sudo apt-get update -y > /dev/null
sudo apt-get upgrade -y > /dev/null
sudo apt-get full-upgrade -y > /dev/null
echo "[+] Proxmox VE registered"

## Set step 2 on run after reboot - TODO

## Install proxmox
echo "[~] Installing proxmox kernel"
sudo apt-get install proxmox-default-kernel -y > /dev/null
echo "[~] Installing proxmox ve"
sudo apt-get install proxmox-ve open-iscsi chrony -y > /dev/null
### Non-interactive postfix install TODO
sudo apt-get install postfix -y > /dev/null
### setup bridge inets


## Reboot
systemctl reboot

