#! /bin/bash

# TODO : logs
start=$(date +%s)

banner (){
        echo '______  __                     ________                               ';
        echo '___  / / /____________ __________  ___/______________   ______________';
        echo '__  /_/ /_  __ \_  __ `__ \  _ \____ \_  _ \_  ___/_ | / /  _ \_  ___/';
        echo '_  __  / / /_/ /  / / / / /  __/___/ //  __/  /   __ |/ //  __/  /    ';
        echo '/_/ /_/  \____//_/ /_/ /_/\___//____/ \___//_/    _____/ \___//_/     ';
        echo ""
        echo "Author : lLou_"
        echo "Script version : V0.8"
        echo ""
        echo ""
}

# Get current user
usr=$(whoami)
if [[ $usr == "root" ]];then
        echo "[-] Running as root. Please run in rootless mode... Exiting..."
        exit 1
fi

# Set a working & log dir
artifacts="/home/$usr/.artifacts"
log_dir="/home/$usr/.logs"
logs="$log_dir/homeserver.log"
mkdir -p $artifacts $log_dir
cd $artifacts

stop (){
   if [[ -d $artifacts ]];then sudo rm -R $artifacts; fi
   if [[ -f "/etc/sudoers.d/tmp" ]];then sudo rm /etc/sudoers.d/tmp; fi
   exit 1
}
trap stop INT

# Manage options
branch="main"
check="1"
nologs=""

POSITIONAL_ARGS=()
ORIGINAL_ARGS=$@

while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--branch)
      branch="$2"
      shift # past argument
      shift # past value
      ;;
    -nc|--no-check)
      check=""
      shift
      ;;
    -nl|--no-log)
      nologs="1"
      shift
      ;;
    -h|--help)
      echo "[~] Github options"
      echo "[*] -b | --branch <main|dev> (default: main) - Use this branch version of the github"
      echo "[*] -nc | --no-check - Disable the check of the branch on github"
      echo ""
      echo "[~] Misc options"
      echo "[*] -nl | --no-log - Disable logging"
      echo "[*] -h | --help - Get help"
      stop
      ;;
    -*|--*)
      echo "[-] Unknown option $1... Exiting"
      stop
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# match the branch
if [[ $check ]];then
    wget https://raw.githubusercontent.com/llouu/homeserver/$branch/install.sh -q >/dev/null
    chmod +x install.sh
    ./install.sh --branch $branch -nc
    exit
fi

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
echo "[*] Please ensure to have done your partitionning before the script execution. CTRL+C if that has not be done yet"
echo "[#] Here are all partitions :"
lsblk -o NAME,SIZE
inputed_part="1"
id="1"
while [[ "$inputed_part" ]];do
    part=""
    while [[ $inputed_part && ! $part ]];do
        echo "[*] Select partition :"
        read -p "[>] " inputed_part
        part="$(ls /dev | grep ^$inputed_part$)"
        if [[ $inputed_part && ! $part ]];then
            echo "[!] Invalid partition"
        fi
    done
    if [[ $inputed_part ]];then
        type=""
        while [[ ! $type ]];do
            echo "[*] Type (vram, hot, cold, temp_hot, temp_cold):"
            read -p "[>] " inputed_type
            type=$(echo -e "vram\nhot\ncold\ntemp_hot\ntemp_cold\nthot\ntcold" | grep ^$inputed_type)
            if [[ ! $type || $(echo $type) != $(echo "$type") ]];then
                echo "[!] Invalid type"
            fi
        done

        sudo mkdir -p /mnt/.$type$id
        echo "/dev/$part /mnt/.$type$id ext4 defaults 0 2" | sudo tee -a /etc/fstab > /dev/null
        id=$((id+1))
    fi
done
# configure mergerfs
## /mnt/vram is used for vram, /mnt/storage is under RAID, /mnt/temp is not, hot is for caching (SSD), cold for archivage (HDD)
echo "[~] Configuring mergerfs"
sudo mkdir -p /mnt/vram /mnt/hot /mnt/cold /mnt/temp_hot /mnt/temp_cold /mnt/storage /mnt/temp
echo "/mnt/.vram* /mnt/vram fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/.hot* /mnt/hot fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/.cold* /mnt/cold fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/hot:/mnt/cold /mnt/storage fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/.temp_cold*:/mnt/.tcold* /mnt/temp_cold fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/.temp_hot*:/mnt/.thot* /mnt/temp_hot fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
echo "/mnt/temp_hot:/mnt/temp_cold /mnt/temp fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0" | sudo tee -a /etc/fstab > /dev/null
# mount
sudo mount -a 2>/dev/null
# configure swap
echo "[~] Configuring swap"
for vram_drive in $(ls -a /mnt | grep .vram);do
    size=$(df -h /mnt/$vram_drive | tail -n1 | awk '{print($4)}')
    swapfile="/mnt/$vram_drive/$vram_drive.swap"
    sudo fallocate -l $size $swapfile 2>/dev/null
    sudo chmod 600 $swapfile 2>/dev/null
    sudo mkswap $swapfile >/dev/null 2>/dev/null
    sudo swapon $swapfile 2>/dev/null
    echo "$swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
done
# hot-cold storage management
wget https://raw.githubusercontent.com/llouu/homeserver/$branch/sub_scripts/storage_manager.sh -q >/dev/null
chmod +x storage_manager.sh
sudo mkdir -p /opt/homeserver
sudo mv storage_manager.sh /opt/homeserver/storage_manager
(crontab -l 2>/dev/null; echo "0 0 */3 * * /opt/homeserver/storage_manager") | crontab -

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
pip3 install frida -q >/dev/null 2>/dev/null

echo "[~] Fetching script"
git clone https://github.com/DualCoder/vgpu_unlock --quiet >/dev/null 2>/dev/null
chmod -R +x vgpu_unlock
sudo mv vgpu_unlock /lib/

echo "[~] Setting up iommu"
vendor_id=$(cat /proc/cpuinfo | grep vendor_id | awk 'NR==1{print $3}')
if [[ "$vendor_id" = "AuthenticAMD" ]];then
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"/' /etc/default/grub
else
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"/' /etc/default/grub
fi
sudo update-grub >/dev/null 2>/dev/null

echo -e "\nvfio\nvfio_iommu_typel\nvfio_pci\nvfio_virqfd\n" | sudo tee -a /etc/modules >/dev/null
echo "options vfio_iommu_typel allow_unsafe_interrupts=1" | sudo tee /etc/modprobe.d/iommu_unsafe_interrupts.conf >/dev/null
echo "options kvm ignore_msrs=1" | sudo tee /etc/modprobe.d/kvm_msrs.conf >/dev/null
echo "blacklist nouveau" | sudo tee -a /etc/modprobe.d/blacklist.conf >/dev/null
sudo update-initramfs -u >/dev/null 2>/dev/null

echo "[~] Fetching Drivers"
# https://github.com/wvthoog/proxmox-vgpu-installer/blob/main/proxmox-installer.sh
version="550.54.10"
megadl https://mega.nz/file/JjtyXRiC#cTIIvOIxu8vf-RdhaJMGZAwSgYmqcVEKNNnRRJTwDFI >/dev/null 2>/dev/null
chmod +x NVIDIA-Linux-x86_64-$version-vgpu-kvm.run
sudo ./NVIDIA-Linux-x86_64-$version-vgpu-kvm.run --dkms -m=kernel -s >/dev/null 2>/dev/null
sudo sed -i 's/ExecStart=/ExecStart=\/lib\/vgpu_unlock\/vgpu_unlock /' /lib/systemd/system/nvidia-vgpud.service
sudo sed -i 's/ExecStart=/ExecStart=\/lib\/vgpu_unlock\/vgpu_unlock /' /lib/systemd/system/nvidia-vgpu-mgr.service
sudo systemctl daemon-reload
sudo sed -i 's/cpuset.h>/cpuset.h>\n#include "\/lib\/vgpu_unlock\/vgpu_unlock_hooks.c"/' /usr/src/nvidia-$version/nvidia/os-interface.c
echo "ldflags-y += -T /lib/vgpu_unlock/kern.ld" | sudo tee -a /usr/src/nvidia-$version/nvidia/nvidia.Kbuild >/dev/null
echo "[~] Building driver"
dkms remove -m nvidia -v $version --all >/dev/null 2>/dev/null
dkms install -m nvidia -v $version >/dev/null 2>/dev/null

# Proxmox installation
## Hostname management
ip="10.1.3.10"
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
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -q -O ~/proxmox-release-bookworm.gpg >/dev/null -q >/dev/null
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

## Set step 2 on run after reboot
wget https://raw.githubusercontent.com/llouu/homeserver/$branch/sub_scripts/step2.sh -q >/dev/null
chmod +x step2.sh
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin $(whoami) --noclear %I \\\$TERM" | sudo tee /etc/systemd/system/getty@tty1.service.d/temp_autologin.conf >/dev/null
options="--start $start --branch $branch"
if [[ $nologs ]];then options="$options -nl";fi
echo "$artifacts/step2.sh $options" > ~/.bash_profile


## Reboot
if [[ -f "/etc/sudoers.d/tmp" ]];then sudo rm /etc/sudoers.d/tmp; fi
if [[ -f "/etc/network/interfaces.new" ]];then sudo rm /etc/network/interfaces.new; fi
sudo systemctl reboot

