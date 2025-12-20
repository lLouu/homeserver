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
        echo "Script version : V0.10"
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
repository="/llouu/homeserver"

POSITIONAL_ARGS=()
ORIGINAL_ARGS=$@

while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--repository)
      repository="$(echo $2 | sed 's/^\(https\?:\/\/\)\?\(github\.com\)\?\/\?/\//')" | sed 's/\.git$//' # change all form of https://github.com/ with /, or add / if not here, adn remove ending .git some may use
      shift # past argument
      shift # past value
      ;;
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
      echo "[*] -r | --repository <repo> (default: /llouu/homeserver) - Use this repository for reference (eg. use of a fork)"
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
    wget https://raw.githubusercontent.com$repository/$branch/install.sh -q >/dev/null
    chmod +x install.sh
    options="--repository $repository --branch $branch -nc"
    if [[ $nologs ]]; then options="$options -nl"; fi
    ./install.sh $options $POSITIONAL_ARGS
    exit
fi

# Get sudoer ticket
printf "Defaults\ttimestamp_timeout=-1\n" | sudo tee /etc/sudoers.d/tmp > /dev/null

banner

###############

# Add special repositories
## Proxmox repo
if [[ ! -f '/etc/apt/sources.list.d/pve-install-repo.list' || ! "$(cat /etc/apt/sources.list.d/pve-install-repo.list | grep 'deb [arch=amd64] http://download.proxmox.com/debian/pve trixie pve-no-subscription')" ]]; then
   echo "deb [arch=amd64] http://download.proxmox.com/debian/pve trixie pve-no-subscription" | sudo tee /etc/apt/sources.list.d/pve-install-repo.list > /dev/null
fi
if [[ ! -f /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg || "$(sha512sum /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg | awk '{print($1)}')" != "8678f2327c49276615288d7ca11e7d296bc8a2b96946fe565a9c81e533f9b15a5dbbad210a0ad5cd46d361ff1d3c4bac55844bc296beefa4f88b86e44e69fa51" ]]; then
   sudo wget https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg -q -O /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg >/dev/null -q >/dev/null
   if [[ "$(sha512sum /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg | awk '{print($1)}')" != "8678f2327c49276615288d7ca11e7d296bc8a2b96946fe565a9c81e533f9b15a5dbbad210a0ad5cd46d361ff1d3c4bac55844bc296beefa4f88b86e44e69fa51" ]]; then
      sudo rm /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg >/dev/null 2>/dev/null
      exit 1
   fi
fi
## bcache fs repo
if [[ ! -f '/etc/apt/sources.list.d/apt.bcachefs.org.sources' || ! "$(sha512sum /etc/apt/sources.list.d/apt.bcachefs.org.sources | awk '{print($1)}')" != "e7ff64fbbc7f6b6fb426ce4040bbce44739691eba728f7711d079633ef15989c249e12dcd8b51ca2131d8438061c2e767ebd9178dc9ce37b415c29f1a6b44088" ]]; then
   sudo tee /etc/apt/sources.list.d/apt.bcachefs.org.sources > /dev/null <<EOF
Types: deb deb-src
URIs: https://apt.bcachefs.org/trixie/
Suites: bcachefs-tools-release
Components: main
Signed-By: /etc/apt/trusted.gpg.d/apt.bcachefs.org.asc
EOF
fi
if [[ ! -f /etc/apt/trusted.gpg.d/apt.bcachefs.org.asc || "$(sha512sum /etc/apt/trusted.gpg.d/apt.bcachefs.org.asc | awk '{print($1)}')" != "97ae039fed3b22b65840c91e94aef20f0cac3698ef9e9aa4fce7417b2ace94618a87325ad628bd64dfbefc38d5412d1195b0fbb93875df3084b0637ac87a8345" ]]; then
   sudo wget https://apt.bcachefs.org/apt.bcachefs.org.asc -q -O /etc/apt/trusted.gpg.d/apt.bcachefs.org.asc >/dev/null -q >/dev/null
   if [[ "$(sha512sum /etc/apt/trusted.gpg.d/apt.bcachefs.org.asc | awk '{print($1)}')" != "97ae039fed3b22b65840c91e94aef20f0cac3698ef9e9aa4fce7417b2ace94618a87325ad628bd64dfbefc38d5412d1195b0fbb93875df3084b0637ac87a8345" ]]; then
      sudo rm /etc/apt/trusted.gpg.d/apt.bcachefs.org.asc >/dev/null 2>/dev/null
      exit 1
   fi
fi

# Update system
echo "[~] Updating system"
sudo apt-get update > /dev/null
echo "[~] Updating done, upgrading system"
sudo apt-get upgrade -yq > /dev/null
sudo apt-get full-upgrade -yq > /dev/null
sudo apt-get autoremove -yq > /dev/null
echo "[+] Updating and upgrading done"
echo ""

# Manage data 
echo "[~] Mounting drives"
sudo apt-get install pve-headers bcachefs-tools bcachefs-kernel-dkms snapraid mergerfs -yq > /dev/null

# Mount disks
echo "[*] Please ensure to have done your partitionning before the script execution. CTRL+C if that has not be done yet"
echo "[#] Here are all partitions :"
lsblk -o NAME,SIZE
# Swap
inputed_part="1"
swapDrives=""
while [[ "$inputed_part" ]];do
    part=""
    while [[ $inputed_part && ! $part ]];do
        echo "[*] Select swap partition (empty to stop) :"
        read -p "[>] " inputed_part
        part="$(ls /dev | grep ^$inputed_part$)"
        if [[ $inputed_part && ! $part ]];then
            echo "[!] Invalid partition"
        fi
    done
    swapDrives="$part $swapDrives"
done

# Swap optimisation
echo "[~] Configuring swap"
## config lz4
echo "lz4" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
echo "lz4_compress" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
sudo update-initramfs -u > /dev/null
## zram
sudo apt-get install zram-tools -yq > /dev/null
echo -e "ALGO=lz4\nPERCENT=60\nPRIORITY=100" | sudo tee -a /etc/default/zramswap > /dev/null
sudo service zramswap reload
## zswap
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash zswap.enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=20 zswap.zpool=z3fold/' /etc/default/grub
sudo update-grub >/dev/null 2>/dev/null
## vram
for vram_drive in "$swapDrives";do
   sudo mkswap /dev/$vram_drive >/dev/null 2>/dev/null
   if ! grep -qE "/dev/$vram_drive none swap sw,pri=10 0 0" /etc/fstab; then
      echo "/dev/$vram_drive none swap sw,pri=10 0 0" | sudo tee -a /etc/fstab > /dev/null
   fi
done
sudo swapon -a 2>/dev/null
## nohang
sudo apt-get install make fakeroot git -yq > /dev/null
git clone https://github.com/hakavlad/nohang.git --quiet >/dev/null 2>/dev/null && cd nohang
./deb/build.sh >/dev/null 2>/dev/null
sudo apt-get install ./deb/package.deb -yq > /dev/null
sudo systemctl enable --now nohang-desktop.service 2>/dev/null
cd ..
sudo rm -R nohang
sudo mount -a 2>/dev/null

# Main storage
creating="1"
id="1"
while [[ "$creating" ]];do
    echo "[+] Creating a tiered drive"
    inputed_part="1"
    part=""
    while [[ $inputed_part && ! $part ]];do
        echo "[*] Select cold storage (empty to none) :"
        read -p "[>] " inputed_part
        part="$(ls /dev | grep ^$inputed_part$)"
        if [[ $inputed_part && ! $part ]];then
            echo "[!] Invalid partition"
        fi
    done
    coldStorage="$part"

    inputed_part="1"
    part=""
    while [[ $inputed_part && ! $part ]];do
        echo "[*] Select hot storage (empty to none) :"
        read -p "[>] " inputed_part
        part="$(ls /dev | grep ^$inputed_part$)"
        if [[ $inputed_part && ! $part ]];then
            echo "[!] Invalid partition"
        fi
    done
    hotStorage="$part"

    inputed_part="1"
    part=""
    while [[ $inputed_part && ! $part ]];do
        echo "[*] Select ssd caching (empty to none) :"
        read -p "[>] " inputed_part
        part="$(ls /dev | grep ^$inputed_part$)"
        if [[ $inputed_part && ! $part ]];then
            echo "[!] Invalid partition"
        fi
    done
    ssdCaching="$part"

    if [[ ! "$coldStorage$hotStorage" ]]; then echo "[!] Cannot create empty LV"; else
        options="-f --replicas=1 --compression=lz4"
        meta=""
        if [[ "$ssdCaching" ]]; then
            options="$options --label='caching' /dev/$ssdCaching --promote_target=/dev/$ssdCaching"
            if [[ ! "$meta" ]]; then meta="$ssdCaching"; fi
        fi
        if [[ "$hotStorage" ]]; then
            options="$options --label='hot' /dev/$hotStorage --foreground_target=/dev/$hotStorage"
            if [[ ! "$meta" ]]; then meta="$hotStorage"; fi
        fi
        if [[ "$coldStorage" ]]; then
            options="$options --label='cold' /dev/$coldStorage --background_target=/dev/$coldStorage"
            if [[ ! "$meta" ]]; then meta="$coldStorage"; fi
        fi
        options="$options --metadata_target=/dev/$meta"
        uuid="$(sudo bcachefs format $options | grep 'External UUID' | awk '{print($3)}')"
        sudo mkdir -p /mnt/.tieredDrive$id
        echo "UUID=$uuid /mnt/.tieredDrive$id bcachefs defaults 0 0" | sudo tee -a /etc/fstab > /dev/null
    fi

    read -p "[?] Continue Creating tiered drives ? (empty to stop) :" creating
    id=$(($id+1))
done
sudo mount -a 2>/dev/null

## Manage Snap raid & Parity
inputed_part="1"
parityDrives=""
while [[ "$inputed_part" ]];do
    part=""
    while [[ $inputed_part && ! $part ]];do
        echo "[*] Select parity partition (empty to stop) :"
        read -p "[>] " inputed_part
        part="$(ls /dev | grep ^$inputed_part$)"
        if [[ $inputed_part && ! $part ]];then
            echo "[!] Invalid partition"
        fi
    done
    parityDrives="$part $parityDrives"
done

sudo touch /etc/snapraid.conf
for drive in "$parityDrives"; do echo "parity /dev/$drive" | sudo tee -a /etc/snapraid.conf >/dev/null; done
for data in "$(ls -a /mnt | grep .tieredDrive)"; do
    sudo touch /mnt/$data/snapraid.content
    echo "content /mnt/$data/snapraid.content" | sudo tee -a /etc/snapraid.conf >/dev/null
    echo "data $data /mnt/$data" | sudo tee -a /etc/snapraid.conf >/dev/null
done

## Merge with mergerfs
options="fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0"
echo "/mnt/.tieredDrive* /mnt/content $options" | sudo tee -a /etc/fstab > /dev/null

# Manage snapraid routine
wget https://raw.githubusercontent.com/llouu/homeserver/$branch/sub_scripts/storage_manager.sh -q >/dev/null
chmod +x storage_manager.sh
sudo mkdir -p /opt/homeserver
sudo mv storage_manager.sh /opt/homeserver/storage_manager
(crontab -l 2>/dev/null | grep -v "/opt/homeserver/storage_manager" ; echo "0 0 */3 * * /opt/homeserver/storage_manager") | crontab -

echo "[+] Mounting done"

# Unlock vGPU
if [[ ! -f /home/ansible/.vgpu_unlocked ]]; then
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
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt/' /etc/default/grub
    else
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt/' /etc/default/grub
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

    touch /home/ansible/.vgpu_unlocked
fi

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
options="--start $start --branch $branch --repository $repository"
if [[ $nologs ]];then options="$options -nl";fi
echo "$artifacts/step2.sh $options" >> ~/.bash_profile
if [[ ! "$(grep -qE 'export TERM=xterm')" ~/.bash_profile ]]; then echo 'export TERM=xterm' >> ~/.bash_profile; fi
if [[ ! "$(grep -qE 'export TERM=xterm')" ~/.profile ]]; then echo 'export TERM=xterm' >> ~/.profile; fi


## Reboot
if [[ -f "/etc/sudoers.d/tmp" ]];then sudo rm /etc/sudoers.d/tmp; fi
if [[ -f "/etc/network/interfaces.new" ]];then sudo rm /etc/network/interfaces.new; fi
sudo systemctl reboot

