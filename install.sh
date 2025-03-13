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
sudo apt-get install mergerfs -yq > /dev/null

# Mount disks
# TODO : think of temp files
sudo mkdir /mnt/drives /mnt/merged
echo "Here are all partitions :"
lsblk -o NAME,SIZE
part="1"
id="1"
while [[ "$part" ]];do 
    # TODO : check inputs
    read -p "Select partition : " part
    read -p "Type (vram, hot, cold) : " type
    sudo mkdir /mnt/drives/$type$id
    echo "$part /mnt/drives/$type$id ext4 defaults 0 2" | sudo tee -a /etc/fstab > /dev/null
    id=$((id+1))
done
# configure mergerfs
sudo mkdir /mnt/merged/vram /mnt/merged/hot /mnt/merged/cold /mnt/storage
echo "/mnt/drives/vram* /mnt/merged/vram fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/drives/hot* /mnt/merged/hot fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/drives/cold* /mnt/merged/cold fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/merged/hot:/mnt/merged/cold /mnt/storage fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
# mount
sudo mount -a
# configure swap
size=$(df -h /mnt/merged/vram | tail -n1 | awk '{print($4)}')
sudo fallocate -l $size /mnt/merged/vram/swapfile
sudo chmod 600 /mnt/merged/vram/swapfile
sudo mkswap /mnt/merged/vram/swapfile
sudo swapon /mnt/merged/vram/swapfile
echo "/mnt/merged/vram/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
# hot-cold storage management - TODO


# Unlock vGPU
sudo apt-get install python3 python3-pip dkms git jq mdevctl -yq > /dev/null
for py in $(ls /usr/lib/ | grep python3.);do
    if [[ -f /usr/lib/$py/EXTERNALLY-MANAGED ]];then
        sudo mv /usr/lib/$py/EXTERNALLY-MANAGED /usr/lib/$py/EXTERNALLY-MANAGED.old
    fi
done
pip3 install frida

git clone https://github.com/DualCoder/vgpu_unlock
chmod -R +x vgpu_unlock
sudo mv vgpu_unlock /lib/

sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"/' /etc/default/grub
sudo update-grub

echo -e "\nvfio\nvfio_iommu_typel\nvfio_pci\nvfio_virqfd" | sudo tee -a /etc/modules >/dev/null
echo "options vfio_iommu_typel allow_unsafe_interrupts=1" | sudo tee /etc/modprobe.d/iommu_unsafe_interrupts.conf >/dev/null
echo "options kvm ignore_msrs=1" | sudo tee /etc/modprobe.d/kvm_msrs.conf >/dev/null
echo "blacklist nouveau" | sudo tee -a /etc/modprobe.d/blacklist.conf >/dev/null
sudo update-initramfs -u

# https://cloud.google.com/compute/docs/gpus/grid-drivers-table
wget https://storage.googleapis.com/nvidia-drivers-us-public/GRID/vGPU17.5/NVIDIA-Linux-x86_64-550.144.03-grid.run
chmod +x NVIDIA-Linux-x86_64-550.144.03-grid.run
sudo ./NVIDIA-Linux-x86_64-550.144.03-grid.run --dkms

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

