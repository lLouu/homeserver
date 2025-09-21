#! /bin/bash

# Configure proxmox repo
if [[ ! -f '/etc/apt/sources.list.d/pve-install-repo.list' || ! "$(cat /etc/apt/sources.list.d/pve-install-repo.list | grep 'deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription')" ]]; then
   echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" | sudo tee /etc/apt/sources.list.d/pve-install-repo.list > /dev/null
fi
if [[ ! -f /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg || "$(sha512sum /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg | awk '{print($1)}')" != "7da6fe34168adc6e479327ba517796d4702fa2f8b4f0a9833f5ea6e6b48f6507a6da403a274fe201595edc86a84463d50383d07f64bdde2e3658108db7d6dc87" ]]; then
   sudo wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -q -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg >/dev/null -q >/dev/null
   if [[ "$(sha512sum /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg | awk '{print($1)}')" != "7da6fe34168adc6e479327ba517796d4702fa2f8b4f0a9833f5ea6e6b48f6507a6da403a274fe201595edc86a84463d50383d07f64bdde2e3658108db7d6dc87" ]]; then
      sudo rm /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg >/dev/null 2>/dev/null
      exit 1
   fi
fi

# Package installations
sudo apt-get update > /dev/null
sudo apt-get upgrade -yq > /dev/null
sudo apt-get full-upgrade -yq > /dev/null
sudo apt-get install mergerfs python3 python3-pip dkms git jq mdevctl megatools open-iscsi chrony -yq > /dev/null
sudo debconf-set-selections <<< "postfix postfix/mailname string '$(hostname)'"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Satellite system'"
sudo apt-get install postfix -yq > /dev/null
sudo apt-get install proxmox-default-kernel proxmox-ve -yq > /dev/null
sudo apt-get remove linux-image-amd64 'linux-image-6.1*' os-prober -yq > /dev/null
sudo apt-get autoremove -yq > /dev/null
sudo update-grub >/dev/null 2>/dev/null

# Python management
for py in $(ls /usr/lib/ | grep python3.);do
    if [[ -f /usr/lib/$py/EXTERNALLY-MANAGED ]];then
        sudo mv /usr/lib/$py/EXTERNALLY-MANAGED /usr/lib/$py/EXTERNALLY-MANAGED.old
    fi
done
pip3 install frida -q >/dev/null 2>/dev/null

# hot-cold storage management
wget https://raw.githubusercontent.com/llouu/homeserver/$branch/sub_scripts/storage_manager.sh -q >/dev/null
chmod +x storage_manager.sh
sudo mkdir -p /opt/homeserver
sudo mv storage_manager.sh /opt/homeserver/storage_manager
(crontab -l 2>/dev/null | grep -v "/opt/homeserver/storage_manager" ; echo "0 0 */3 * * /opt/homeserver/storage_manager") | crontab -


# Unlock vGPU
if [[ ! -f /home/ansible/.vgpu_unlocked ]]; then
   mkdir work; cd work
   git clone https://github.com/DualCoder/vgpu_unlock --quiet >/dev/null 2>/dev/null
   chmod -R +x vgpu_unlock
   sudo mv vgpu_unlock /lib/

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
   dkms remove -m nvidia -v $version --all >/dev/null 2>/dev/null
   dkms install -m nvidia -v $version >/dev/null 2>/dev/null

   touch /home/ansible/.vgpu_unlocked
   cd ..
   rm -R work -f
fi

