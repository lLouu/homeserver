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
        echo "Script version : V0.4"
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
sudo apt-get upgrade -yq > /dev/null
sudo apt-get autoremove -yq > /dev/null
echo "[+] Updating and upgrading done"
echo ""

# Manage data 
echo "[~] Mounting drives"
sudo apt-get install mergerfs -yq > /dev/null

# Mount disks
sudo mkdir /mnt/drives /mnt/merged
echo "[*] Please ensure to have done your partitionning before the script execution. CTRL+C if that has not be done yet"
echo "[#] Here are all partitions :"
lsblk -o NAME,SIZE
part="1"
id="1"
while [[ "$part" ]];do
    part=""
    while [[ ! $part ]];do
        echo "[*] Select partition :"
        read -p "[>] " inputed_part
        part="$(ls dev | grep ^$inputed_part$)"
        if [[ ! $part ]];then
            echo "[!] Invalid partition"
        fi
    done

    type=""
    while [[ ! $type ]];do
        echo "[*] Type (vram, hot, cold, temp_hot, temp_cold):"
        read -p "[>] " inputed_type
        type=$(echo -e "vram\nhot\ncold\ntemp_hot\ntemp_cold\nthot\ntcold" | grep ^$inputed_type)
        if [[ ! $type || $(echo $type) != $(echo "$type") ]];then
            echo "[!] Invalid type"
        fi
    done

    sudo mkdir /mnt/drives/$type$id
    echo "/dev/$part /mnt/drives/$type$id ext4 defaults 0 2" | sudo tee -a /etc/fstab > /dev/null
    id=$((id+1))
done
# configure mergerfs
## /mnt/merged/vram is used for vram, /mnt/storage is under RAID, /mnt/temp is not, hot is for caching (SSD), cold for archivage (HDD)
echo "[~] Configuring mergerfs"
sudo mkdir /mnt/merged/vram /mnt/merged/hot /mnt/merged/cold /mnt/merged/temp_hot /mnt/merged/temp_cold /mnt/storage /mnt/temp
echo "/mnt/drives/vram* /mnt/merged/vram fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/drives/hot* /mnt/merged/hot fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/drives/cold* /mnt/merged/cold fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/merged/hot:/mnt/merged/cold /mnt/storage fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/drives/temp_cold*:/mnt/drives/tcold* /mnt/merged/temp_cold fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/drives/temp_hot*:/mnt/drives/thot* /mnt/merged/temp_hot fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/merged/temp_hot:/mnt/merged/temp_cold /mnt/temp fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
# mount
sudo mount -a
# configure swap
echo "[~] Configuring swap"
size=$(df -h /mnt/merged/vram | tail -n1 | awk '{print($4)}')
sudo fallocate -l $size /mnt/merged/vram/swapfile
sudo chmod 600 /mnt/merged/vram/swapfile
sudo mkswap /mnt/merged/vram/swapfile
sudo swapon /mnt/merged/vram/swapfile
echo "/mnt/merged/vram/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
# hot-cold storage management - TODO

echo "[+] Mounting done"

# Unlock vGPU
echo "[~] Starting vGPU unlock"
echo "[~] Downloading dependencies"
sudo apt-get install python3 python3-pip dkms git jq mdevctl megatools -yq > /dev/null
for py in $(ls /usr/lib/ | grep python3.);do
    if [[ -f /usr/lib/$py/EXTERNALLY-MANAGED ]];then
        sudo mv /usr/lib/$py/EXTERNALLY-MANAGED /usr/lib/$py/EXTERNALLY-MANAGED.old
    fi
done
pip3 install frida

echo "[~] Fetching script"
git clone https://github.com/DualCoder/vgpu_unlock
chmod -R +x vgpu_unlock
sudo mv vgpu_unlock /lib/

echo "[~] Setting up iommu"
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"/' /etc/default/grub
sudo update-grub

echo -e "\nvfio\nvfio_iommu_typel\nvfio_pci\nvfio_virqfd\n" | sudo tee -a /etc/modules >/dev/null
echo "options vfio_iommu_typel allow_unsafe_interrupts=1" | sudo tee /etc/modprobe.d/iommu_unsafe_interrupts.conf >/dev/null
echo "options kvm ignore_msrs=1" | sudo tee /etc/modprobe.d/kvm_msrs.conf >/dev/null
echo "blacklist nouveau" | sudo tee -a /etc/modprobe.d/blacklist.conf >/dev/null
sudo update-initramfs -u

echo "[~] Fetching Drivers"
# https://github.com/wvthoog/proxmox-vgpu-installer/blob/main/proxmox-installer.sh
version="550.54.10"
megadl https://mega.nz/file/JjtyXRiC#cTIIvOIxu8vf-RdhaJMGZAwSgYmqcVEKNNnRRJTwDFI
chmod +x NVIDIA-Linux-x86_64-$version-vgpu-kvm
sudo ./NVIDIA-Linux-x86_64-$version-vgpu-kvm --dkms
sudo sed -i 's/ExecStart=/ExecStart=\/lib\/vgpu_unlock\/vgpu_unlock /' /lib/systemd/system/nvidia-vgpud.service
sudo sed -i 's/ExecStart=/ExecStart=\/lib\/vgpu_unlock\/vgpu_unlock /' /lib/systemd/system/nvidia-vgpu-mgr.service
systemctl daemon-reload
sudo sed -i 's/cpuset.h>/cpuset.h>\n#include "\/lib\/vgpu_unlock\/vgpu_unlock_hooks.c"/' /usr/src/nvidia-$version/nvidia/os-interface.c
echo "ldflags-y += -T /lib/vgpu_unlock/kern.ld" | sudo tee -a /usr/src/nvidia-$version/nvidia/nvidia.Kbuild >/dev/ull
echo "[~] Building driver"
dkms remove -m nvidia -v $version --all
dkms install -m nvidia -v $version

# Proxmox installation
## Hostname management
ip=$(ip a | grep "inet " | grep -v 127.0.0.1 | awk '{print($2)}' | cut -d'/' -f1)
if [[ "$(hostname --ip-address)" != "$ip" ]]; then
    echo "[~] Redefine hostname ip"
    sudo cp /etc/hosts /etc/hosts.bck
    sudo sed -i -e "s/127.0.1.1/$ip/g" /etc/hosts
    if [[ "$(hostname --ip-address)" != "$ip" ]]; then
        echo "[-] Failed to change hostname ip to $ip"
        sudo mv /etc/hosts.bck /etc/hosts
        exit 1
    fi
    sudo rm /etc/hosts.bck
    echo "[+] Hostname ip setted to $ip"
fi

## Add proxmox VE repo
echo "[~] Adding proxmox VE repo"
if [[ ! -f '/etc/apt/sources.list.d/pve-install-repo.list' || ! "$(cat /etc/apt/sources.list.d/pve-install-repo.list | grep 'deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription')" ]]; then
    echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" | sudo tee /etc/apt/sources.list.d/pve-install-repo.list > /dev/null
fi
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -q -O ~/proxmox-release-bookworm.gpg >/dev/null
if [[ "$(sha512sum ~/proxmox-release-bookworm.gpg | awk '{print($1)}')" != "7da6fe34168adc6e479327ba517796d4702fa2f8b4f0a9833f5ea6e6b48f6507a6da403a274fe201595edc86a84463d50383d07f64bdde2e3658108db7d6dc87" ]]; then
    echo "[-] Failed to fetch gpg key for proxmox repo"
    rm ~/proxmox-release-bookworm.gpg >/dev/null 2>/dev/null
    exit 1
fi
sudo mv ~/proxmox-release-bookworm.gpg /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
sudo apt-get update -yq > /dev/null
sudo apt-get upgrade -yq > /dev/null
sudo apt-get full-upgrade -yq > /dev/null
echo "[+] Proxmox VE registered"
echo ""

## Install proxmox
echo "[~] Installing proxmox kernel"
sudo apt-get install proxmox-default-kernel -yq > /dev/null
echo "[~] Installing proxmox ve"
sudo apt-get install proxmox-ve -yq > /dev/null
echo "[~] Installing proxmox dependencies"
sudo apt-get install open-iscsi chrony -yq > /dev/null
### Non-interactive postfix install
sudo debconf-set-selections <<< "postfix postfix/mailname string '$(hostname)'"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Satellite system'"
sudo apt-get install postfix -yq > /dev/null

## Set step 2 on run after reboot - TODO


## Reboot
if [[ -f "/etc/sudoers.d/tmp" ]];then sudo rm /etc/sudoers.d/tmp; fi
if [[ -f "/etc/network/interfaces.new" ]];then sudo rm /etc/network/interfaces.new; fi
sudo systemctl reboot

