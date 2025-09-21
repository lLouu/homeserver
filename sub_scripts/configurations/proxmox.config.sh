#! /bin/bash

# Mounting configuration
sudo mkdir -p /mnt/vram /mnt/hot /mnt/cold /mnt/temp_hot /mnt/temp_cold /mnt/storage /mnt/temp
options="fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs 0 0"
declare -A mounts=(
  ["/mnt/vram"]="/mnt/.vram*"
  ["/mnt/hot"]="/mnt/.hot*"
  ["/mnt/cold"]="/mnt/.cold*"
  ["/mnt/storage"]="/mnt/hot:/mnt/cold"
  ["/mnt/temp_cold"]="/mnt/.temp_cold*:/mnt/.tcold*"
  ["/mnt/temp_hot"]="/mnt/.temp_hot*:/mnt/.thot*"
  ["/mnt/temp"]="/mnt/temp_hot:/mnt/temp_cold"
)

for target in "${!mounts[@]}"; do
   src="${mounts[$target]}"
   newline="$src $target $options"
   if grep -qE "^[^#].*\s+$target\s+" /etc/fstab; then
      sudo sed -i "s|^[^#].*\s\+$target\s\+.*|$newline|" /etc/fstab
   else
      echo "$newline" | sudo tee -a /etc/fstab > /dev/null
   fi
done
# Swap configuration
for vram_drive in $(ls -a /mnt | grep .vram);do
   size=$(df -h /mnt/$vram_drive | tail -n1 | awk '{print($4)}')
   swapfile="/mnt/$vram_drive/$vram_drive.swap"
   sudo fallocate -l $size $swapfile 2>/dev/null
   sudo chmod 600 $swapfile 2>/dev/null
   sudo mkswap $swapfile >/dev/null 2>/dev/null
   sudo swapon $swapfile 2>/dev/null
   if ! grep -qE "$swapfile none swap sw 0 0" /etc/fstab; then
      echo "$swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
   fi
done

sudo mount -a 2>/dev/null

## Hostname management
ip="10.1.3.10"
if [[ "$(hostname --ip-address)" != "$ip" ]]; then
    sudo cp /etc/hosts /etc/hosts.bck
    sudo sed -i -e "s/127.0.1.1/$ip/g" /etc/hosts
    if [[ "$(hostname --ip-address)" != "$ip" ]]; then
        sudo mv /etc/hosts.bck /etc/hosts
        exit 1
    fi
    sudo rm /etc/hosts.bck
fi

## Config perms terraform on proxmox
lines=(
  "group:TerraformProviders:terraform@pve:Terraform Providers:"
  "role:terraformDataProvider:Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit:"
  "role:terraformVMProvider:Pool.Allocate,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.Monitor,VM.PowerMgmt,SDN.Use:"
  "role:terraformSysProvider:Sys.Audit,Sys.Console,Sys.Modify:"
  "acl:1:/:@TerraformProviders:terraformDataProvider"
  "acl:1:/:@TerraformProviders:terraformVMProvider"
  "acl:1:/:@TerraformProviders:terraformSysProvider"
)

for line in "${lines[@]}"; do
   if ! grep -qxF "$line" "$file"; then
      echo "$line" | sudo tee -a /etc/pve/user.cfg > /dev/null
   fi
done

## Do not expose host services on other places than vmbr4
cat > host.fw <<EOF
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -i vmbr0 -p icmp
IN ACCEPT -i vmbr4 -p tcp --dport 22
IN ACCEPT -i vmbr4 -p tcp --dport 8006
EOF
chmod 640 host.fw
sudo chown root:www-data host.fw
sudo mv host.fw /etc/pve/nodes/debian/
sudo systemctl restart pve-firewall

## Alpine
if [[ ! -f "/var/lib/vz/template/iso/alpine-virt-3.21.2-aarch64.iso" || "$(sha256sum /var/lib/vz/template/iso/alpine-virt-3.21.2-aarch64.iso | awk '{print($1)}')" != "42918974513750a6923393f3074c3bb226badfce4a0d0f35f90377fd789fda1f" ]]; then
   echo "[~] Downloading Alpine ISO"
   wget https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.1-x86_64.iso -q > /dev/null
   if [[ "$(sha256sum alpine-virt-3.21.2-aarch64.iso | awk '{print($1)}')" != "42918974513750a6923393f3074c3bb226badfce4a0d0f35f90377fd789fda1f" ]]; then
      echo "[!] Could not download Alpine ISO"
      rm alpine-virt-3.21.2-aarch64.iso
   else
      sudo mv alpine-virt-3.21.2-aarch64.iso /var/lib/vz/template/iso/alpine-virt-3.21.2-aarch64.iso
      echo "[+] Alpine ISO added to ISO local library"
   fi
fi

## Debian
if [[ ! -f "/var/lib/vz/template/iso/debian-12.9.0-amd64-netinst.iso" || "$(sha512sum /var/lib/vz/template/iso/debian-12.9.0-amd64-netinst.iso | awk '{print($1)}')" != "9ebe405c3404a005ce926e483bc6c6841b405c4d85e0c8a7b1707a7fe4957c617ae44bd807a57ec3e5c2d3e99f2101dfb26ef36b3720896906bdc3aaeec4cd80" ]]; then
   echo "[~] Downloading Debian ISO"
   wget https://cdimage.debian.org/cdimage/archive/12.9.0/amd64/iso-cd/debian-12.9.0-amd64-netinst.iso -q > /dev/null
   if [[ "$(sha512sum debian-12.9.0-amd64-netinst.iso | awk '{print($1)}')" != "9ebe405c3404a005ce926e483bc6c6841b405c4d85e0c8a7b1707a7fe4957c617ae44bd807a57ec3e5c2d3e99f2101dfb26ef36b3720896906bdc3aaeec4cd80" ]]; then
      echo "[!] Could not download Debian ISO"
      rm debian-12.9.0-amd64-netinst.iso
   else
      sudo mv debian-12.9.0-amd64-netinst.iso /var/lib/vz/template/iso/debian-12.9.0-amd64-netinst.iso
      echo "[+] Debian ISO added to ISO local library"
   fi
fi

## Ubuntu
if [[ ! -f "/var/lib/vz/template/iso/ubuntu-24.04.1-live-server-amd64.iso" || "$(sha256sum /var/lib/vz/template/iso/ubuntu-24.04.1-live-server-amd64.iso | awk '{print($1)}')" != "e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9" ]]; then
   echo "[~] Downloading Ubuntu Server ISO"
   wget https://old-releases.ubuntu.com/releases/noble/ubuntu-24.04.1-live-server-amd64.iso -q > /dev/null
   sleep 3
   if [[ "$(sha256sum ubuntu-24.04.1-live-server-amd64.iso | awk '{print($1)}')" != "e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9" ]]; then
      echo "[!] Could not download Ubuntu Server ISO"
      rm ubuntu-24.04.1-live-server-amd64.iso
   else
      sudo mv ubuntu-24.04.1-live-server-amd64.iso /var/lib/vz/template/iso/ubuntu-24.04.1-live-server-amd64.iso
      echo "[+] Ubuntu Server ISO added to ISO local library"
   fi
fi

## Pfsense
if [[ ! -f "/var/lib/vz/template/iso/pfSense-CE-2.7.2-RELEASE-amd64.iso" || "$(sha256sum /var/lib/vz/template/iso/pfSense-CE-2.7.2-RELEASE-amd64.iso | awk '{print($1)}')" != "441005f79ea0c155bc4b830a2b4207f8c0804cf7b075d2a6489c0a136cbc5d51" ]]; then
   echo "[~] Downloading Pfsense ISO"
   wget https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz -q > /dev/null
   gunzip pfSense-CE-2.7.2-RELEASE-amd64.iso.gz > /dev/null
   if [[ "$(sha256sum pfSense-CE-2.7.2-RELEASE-amd64.iso | awk '{print($1)}')" != "441005f79ea0c155bc4b830a2b4207f8c0804cf7b075d2a6489c0a136cbc5d51" ]]; then
      echo "[!] Could not download Pfsense ISO"
      rm pfSense-CE-2.7.2-RELEASE-amd64.iso
   else
      sudo mv pfSense-CE-2.7.2-RELEASE-amd64.iso /var/lib/vz/template/iso/pfSense-CE-2.7.2-RELEASE-amd64.iso
      echo "[+] Pfsense ISO added to ISO local library"
   fi
fi