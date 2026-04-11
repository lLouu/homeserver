## Init back
stop (){
   if [[ -d $artifacts ]];then sudo rm -R $artifacts; fi
   if [[ -f "/etc/sudoers.d/tmp" ]];then sudo rm /etc/sudoers.d/tmp; fi
   exit 1
}
trap stop INT

usr=$(whoami)
if [[ $usr == "root" ]];then
        echo "[-] Running as root. Please run in rootless mode... Exiting..."
        stop
fi

artifacts="/home/$usr/.artifacts"
log_dir="/home/$usr/.logs"
logs="$log_dir/homeserver.log"
cd $artifacts

# Get sudoer ticket
printf "Defaults\ttimestamp_timeout=-1\n" | sudo tee /etc/sudoers.d/tmp > /dev/null

# Manage options
branch="main"
start=$(date +%s)
nologs=""
nounlock=""
virtu=""
wlan=""
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
    -s|--start)
      start="$2"
      shift # past argument
      shift # past value
      ;;
    -nl|--no-log)
      nologs="1"
      shift
      ;;
    -nu|--no-unlock|--no-vgpu-unlock)
      nounlock="1"
      shift
      ;;
    --wifi|--wlan)
      wlan="1"
      shift
      ;;
    -v|--virtu)
      virtu="1"
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters



#######
## Clean previous step auto-relaunch
export TERM=xterm
sudo rm /etc/systemd/system/getty@tty1.service.d/temp_autologin.conf
sed -i "/step2.sh/c\\" ~/.bash_profile

## Remove Debian Kernel
echo "[~] Removing debian kernel"
sudo apt-get remove linux-image-amd64 'linux-image-6.1*' os-prober -yq > /dev/null
sudo update-grub >/dev/null 2>/dev/null
echo "[+] Debian kernel Removed"

# Remove entreprise proxmox repo
sudo mv /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/pve-enterprise.sources.disabled

# Unlock vGPU
sudo apt-get install python3 python3-pip -yq > /dev/null
for py in $(ls /usr/lib/ | grep python3.);do
    if [[ -f /usr/lib/$py/EXTERNALLY-MANAGED ]];then
        sudo mv /usr/lib/$py/EXTERNALLY-MANAGED /usr/lib/$py/EXTERNALLY-MANAGED.old
    fi
done
if [[ ! "$nounlock" ]];then
echo "[~] Starting vGPU unlock"
echo "[~] Downloading dependencies"
sudo apt-get install dkms git jq build-essential mdevctl -yq > /dev/null
if [[ ! -d $HOME/.cargo ]]; then
   wget https://sh.rustup.rs -O rustup-init.sh -q >/dev/null
   chmod +x rustup-init.sh
   ./rustup-init.sh -y >/dev/null 2>/dev/null
   $HOME/.cargo/bin/rustup default stable >/dev/null 2>/dev/null
fi
pip3 install frida -q >/dev/null 2>/dev/null

if [[ ! -d /lib/vgpu_unlock ]]; then
    echo "[~] Fetching vgpu script"
    git clone https://github.com/DualCoder/vgpu_unlock --quiet >/dev/null 2>/dev/null
    chmod -R +x vgpu_unlock
    sudo mv vgpu_unlock /lib/
fi

if [[ ! -d /lib/vgpu_unlock_rs ]]; then
    echo "[~] Fetching vgpu rust script"
    git clone https://github.com/mbilker/vgpu_unlock-rs --quiet >/dev/null 2>/dev/null
    sudo mv vgpu_unlock-rs /lib/
    cd /lib/vgpu_unlock-rs
    $HOME/.cargo/bin/cargo build --release >/dev/null 2>/dev/null
    cd $artifacts
fi

if [[ ! "$(grep GRUB_CMDLINE_LINUX_DEFAULT=.*iommu=on.*iommu=pt /etc/default/grub)"  ]]; then
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
fi

com_version="19.3"
version="580.105.06"
if [[ ! "$(sudo dkms status | grep nvidia/$version)" ]]; then
    echo "[~] Fetching Drivers"
    # https://github.com/wvthoog/proxmox-vgpu-installer/blob/main/proxmox-installer.sh
    # megadl https://mega.nz/file/JjtyXRiC#cTIIvOIxu8vf-RdhaJMGZAwSgYmqcVEKNNnRRJTwDFI >/dev/null 2>/dev/null
    # https://www.reddit.com/r/Proxmox/comments/1b9ssk8/anyone_willing_to_share_nvidia_enterprise_drivers/
    wget https://alist.homelabproject.cc/p/foxipan/vGPU/$com_version/NVIDIA-Linux-x86_64-$version-vgpu-kvm-patch.run -q >/dev/null
    chmod +x NVIDIA-Linux-x86_64-$version-vgpu-kvm-patch.run
    sudo ./NVIDIA-Linux-x86_64-$version-vgpu-kvm-patch.run --dkms -m=kernel -s >/dev/null 2>/dev/null
   #  sudo sed -i 's/ExecStart=/ExecStart=\/lib\/vgpu_unlock\/vgpu_unlock /' /lib/systemd/system/nvidia-vgpud.service
   #  sudo sed -i 's/ExecStart=/ExecStart=\/lib\/vgpu_unlock\/vgpu_unlock /' /lib/systemd/system/nvidia-vgpu-mgr.service
    sudo mkdir -p /etc/systemd/system/nvidia-vgpud.service.d /etc/systemd/system/nvidia-vgpu-mgr.service.d
    echo -e "[Service]\nEnvironment=LD_PRELOAD=/lib/vgpu_unlock_rs/target/release/libvgpu_unlock_rs.so" | sudo tee /etc/systemd/system/nvidia-vgpud.service.d/vgpu_unlock.conf | sudo tee /etc/systemd/system/nvidia-vgpu-mgr.service.d/vgpu_unlock.conf >/dev/null
    sudo systemctl daemon-reload
    sudo sed -i 's/cpuset.h>/cpuset.h>\n#include "\/lib\/vgpu_unlock\/vgpu_unlock_hooks.c"/' /usr/src/nvidia-$version/nvidia/os-interface.c
    echo "ldflags-y += -T /lib/vgpu_unlock/kern.ld" | sudo tee -a /usr/src/nvidia-$version/nvidia/nvidia.Kbuild >/dev/null
    echo "[~] Building driver"
    sudo dkms remove -m nvidia -v $version --all >/dev/null 2>/dev/null
    sudo dkms install -m nvidia -v $version >/dev/null 2>/dev/null
fi
fi

if [[ ! "$virtu" ]]; then
## Create network bridges and network configuration
WAN=$(sudo cat /etc/network/interfaces | grep 'dhcp' | awk '{print($2)}')
cat > bridges <<EOF
# guest network 10.1.1.0/24
auto vmbr1
iface vmbr1 inet static
    bridge_ports none
    bridge_stp off
    bridge_fd 0

# inet 10.1.2.0/24
auto vmbr2
iface vmbr2 inet static
    bridge_ports none
    bridge_stp off
    bridge_fd 0

# secnet 10.1.3.0/24
auto vmbr3
iface vmbr3 inet static
    address 10.1.3.10/24
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    up ip route add 10.1.0.0/16 via 10.1.3.1 dev vmbr3

# worknet 10.1.4.0/24
auto vmbr4
iface vmbr4 inet static
    bridge_ports none
    bridge_stp off
    bridge_fd 0

# datanet 10.1.5.0/24
auto vmbr5
iface vmbr5 inet static
    bridge_ports none
    bridge_stp off
    bridge_fd 0
EOF
if [[ ! "$wlan" ]]; then 
cat >> bridges <<EOF
# WAN
auto vmbr0
iface vmbr0 inet dhcp
    bridge_ports WAN
    bridge_stp off
    bridge_fd 0
EOF
else
sudo apt-get install iptables dnsmasq -yq > /dev/null
cat >> dnsmasq.conf <<EOF
interface=vmbr0
bind-interfaces

dhcp-range=10.255.255.10,10.255.255.200,12h
dhcp-option=3,10.255.255.1
dhcp-option=6,8.8.8.8
EOF
sudo mv dnsmasq.conf /etc/dnsmasq.conf
sudo systemctl restart dnsmasq.service
cat >> bridges <<EOF
# WAN
auto vmbr0
iface vmbr0 inet static
    address 10.255.255.1/24
    bridge_ports none
    bridge_stp off
    bridge_fd 0
   
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s '10.255.255.0/24' -o WAN -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '10.255.255.0/24' -o WAN -j MASQUERADE
EOF
fi
sed -i "s/WAN/$WAN/" bridges
chmod 644 bridges
sudo chown root:root bridges
sudo mv bridges /etc/network/interfaces.d/
sudo systemctl restart networking
fi

# Setup init terraform
## Generate hash & Token
echo "[~] Generating terraform credentials"
sudo apt-get install python3-bcrypt -yq > /dev/null
NEW_PASS=$(openssl rand -base64 48)
HASHED_PASS=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$NEW_PASS', bcrypt.gensalt()).decode())")
TOKEN_ID=e$(openssl rand -hex 12)
TOKEN_SECRET="$(openssl rand -hex 8)-$(openssl rand -hex 4)-$(openssl rand -hex 4)-$(openssl rand -hex 4)-$(openssl rand -hex 12)"

## Add terraform user
echo "[~] Setting up proxmox API"
echo "user:terraform@pve:1:0:::::::" | sudo tee -a /etc/pve/user.cfg > /dev/null
echo "token:terraform@pve!$TOKEN_ID:0:0:extended terraform token:" | sudo tee -a /etc/pve/user.cfg > /dev/null

lines=(
  "group:TerraformProviders:terraform@pve:Terraform Providers:"
  "role:terraformDataProvider:Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit:"
  "role:terraformVMProvider:Pool.Allocate,Pool.Audit,VM.Allocate,VM.Audit,VM.Clone,VM.Console,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.PowerMgmt,VM.GuestAgent.Audit,VM.GuestAgent.Unrestricted,SDN.Use:"
  "role:terraformSysProvider:Sys.Audit,Sys.Console,Sys.Modify:"
  "acl:1:/:@TerraformProviders:terraformDataProvider"
  "acl:1:/:@TerraformProviders:terraformVMProvider"
  "acl:1:/:@TerraformProviders:terraformSysProvider"
)

for line in "${lines[@]}"; do
   if [[ ! "$(sudo grep "$line" /etc/pve/user.cfg)" ]]; then
      echo "$line" | sudo tee -a /etc/pve/user.cfg > /dev/null
   fi
done

### store secrets
echo "terraform:$HASHED_PASS:" | sudo tee -a /etc/pve/priv/shadow.cfg > /dev/null
echo "terraform@pve!$TOKEN_ID $TOKEN_SECRET" | sudo tee -a /etc/pve/priv/token.cfg > /dev/null


# user:uname@<pam|pve>:1(enabled):<expiration_ts|0>:first_name:last_name:email:comment:<x if totp enabled>:
# group:gname:user1,user2,...,userN:<comment>:
# role:role_name:perm1,perm2,...,permN:
# acl:<propagate>:<path>:<user@pve|user@pve!tid|@group>:<role>:
# token:uname@<pam|pve>!<tokenid>:<expiration_ts|0>:<unlinked_permission>:<comment>:
# uname@<pam|pve>!<tokenid> (b16){8}-(b16){4}-(b16){4}-(b16){4}-(b16){12}


echo "[+] API setted up"
echo "[>] The terraform user password is '$NEW_PASS'"

if [[ ! "$virtu" ]]; then
   # Download ISO store on /var/lib/vz/template/iso/
   echo "[~] Downloading ISO Librarie"
   ## Alpine
   if [[ ! -f "/var/lib/vz/template/iso/alpine-virt-3.22.1-x86_64.iso" || "$(sha256sum /var/lib/vz/template/iso/alpine-virt-3.22.1-x86_64.iso | awk '{print($1)}')" != "42918974513750a6923393f3074c3bb226badfce4a0d0f35f90377fd789fda1f" ]]; then
      echo "[~] Downloading Alpine ISO"
      wget https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.1-x86_64.iso -q > /dev/null
      if [[ "$(sha256sum alpine-virt-3.22.1-x86_64.iso | awk '{print($1)}')" != "42918974513750a6923393f3074c3bb226badfce4a0d0f35f90377fd789fda1f" ]]; then
         echo "[!] Could not download Alpine ISO"
         rm alpine-virt-3.22.1-x86_64.iso
      else
         sudo mv alpine-virt-3.22.1-x86_64.iso /var/lib/vz/template/iso/alpine-virt-3.22.1-x86_64.iso
         echo "[+] Alpine ISO added to ISO local library"
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
fi

## Do not expose host services on other places than vmbr4
echo "[~] Avoiding access to host through outside"
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
sudo mv host.fw /etc/pve/nodes/$(hostname)/
sudo systemctl restart pve-firewall

# Setting up terraform, Packer & Ansible
echo "[~] Downloading terraform, packer and ansible"
wget -q -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
newdpkg="deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main"
echo "$newdpkg" | sudo tee /etc/apt/sources.list.d/tmp_hashicorp.list >/dev/null
sudo apt-get update -yq >/dev/null 2>/dev/null
sudo apt-get install terraform packer -yq >/dev/null 2>/dev/null
sudo pip install ansible -q >/dev/null 2>/dev/null

# Deploying initial state
echo "[~] Fetching for configuration files"
git clone -b $branch https://github.com$repository --quiet >/dev/null 2>/dev/null
cd homeserver/jenkins/terraform
mv ../configs/* ./
mv ../packer/* ./
mv ../ansible/* ./
sed -i "s/===HOSTNAME===/$(cat /etc/hostname)/" proxmox.tfvars.json
sed -i "s/===IP===/$(hostname --ip-address)/" proxmox.tfvars.json
sed -i "s/===ID===/terraform@pve!$TOKEN_ID/" proxmox.tfvars.json
sed -i "s/===SECRET===/$TOKEN_SECRET/" proxmox.tfvars.json

## Create Ansible rsa id
if [[ ! "$virtu" ]]; then
   ssh-keygen -f ansible -N "" -t rsa -b 8192 -q
   sed -i "s/$(whoami)/ansible/" ansible.pub
else
   wget https://raw.githubusercontent.com$repository/$branch/virtu/ansible -q >/dev/null
   wget https://raw.githubusercontent.com$repository/$branch/virtu/ansible.pub -q >/dev/null
   chmod 600 ansible
fi
ROOT_PWD=$(openssl rand -base64 64)
echo $ROOT_PWD | sudo tee /root/.virt_roots.pwd >/dev/null && sudo chmod 400 /root/.virt_roots.pwd && sudo chown root:root /root/.virt_roots.pwd

## Create Pfsense packer config, and deploy the firewall
echo "[~] Creating firewall template"
packer init pfsense.pkr.hcl >/dev/null
if [[ ! "$virtu" ]]; then
   ansible_pub_var="$(cat ansible.pub | fold -w 150 | awk '{printf "\"%s\"\", $0}' | sed 's/,$//')"
   packer build -var-file="proxmox.tfvars.json" -var "ansible_pub=[$ansible_pub_var]" -var "ansible_key_file=$(pwd)/ansible" -var 'networks=[0,1,2,3,4,5]' pfsense.pkr.hcl >/dev/null
fi

echo "[~] Deploying firewall"
terraform init >/dev/null
echo '[]' | terraform plan --var-file=proxmox.tfvars.json --var-file=pfsense.tfvars.json -out plan >/dev/null
if [[ ! "$virtu" ]]; then terraform apply "plan" >/dev/null; fi
rm plan

## Create Packer template of alpine and deploy jenkins agent
echo "[~] Creating Alpine template"
packer init alpine.pkr.hcl >/dev/null
if [[ ! "$virtu" ]]; then
   packer build -var-file="proxmox.tfvars.json" -var "ansible_pub=$(cat ansible.pub)" -var "ansible_key_file=$(pwd)/ansible" -var "root_pwd=$ROOT_PWD" alpine.pkr.hcl >/dev/null
fi

echo "[~] Deploying Jenkins agent"
terraform init >/dev/null
terraform plan --var-file=proxmox.tfvars.json --var-file=pfsense.tfvars.json --var-file=init.tfvars.json -out plan >/dev/null
if [[ ! "$virtu" ]]; then terraform apply "plan" >/dev/null; fi
rm plan

## Create remote ansible user
sudo apt-get install ssh -yq >/dev/null
sudo adduser ansible --disabled-password --gecos "" --quiet >/dev/null 2>/dev/null
sudo sed -i 's/ansible:!/ansible:*/' /etc/shadow
sudo mkdir -p /home/ansible/.ssh
sudo cp ansible.pub /home/ansible/.ssh/authorized_keys
sudo chmod 700 /home/ansible/.ssh && sudo chmod 600 /home/ansible/.ssh/authorized_keys
sudo chown ansible:ansible /home/ansible/.ssh /home/ansible/.ssh/authorized_keys
cat > first_setup.conf <<EOF
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
EOF
sudo mv first_setup.conf /etc/ssh/sshd_config.d/
sudo service sshd restart
echo 'ansible ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/ansible >/dev/null

## Connect with ansible to setup jenkins for it to handle the other Packer and terraform edits
ansible-playbook -i hosts.yml -u ansible --key-file ansible preinstall.yml -e "branch='$branch' repository='$repository' ssh_priv='$(cat ansible)' ssh_pub='$(cat ansible.pub)' proxmox_config='$(cat proxmox.tfvars.json)' root_pwd='$ROOT_PWD'"

cd $artifacts
sudo rm -r homeserver

# Unsetting terraform & Ansible
sudo apt-get -yq remove terraform packer >/dev/null 2>/dev/null
sudo pip uninstall ansible -yq >/dev/null 2>/dev/null
sudo rm /usr/share/keyrings/hashicorp-archive-keyring.gpg
sudo rm /etc/apt/sources.list.d/tmp_hashicorp.list

sudo apt-get -yq autoremove >/dev/null 2>/dev/null

echo "[*] Script executed in $(date -d@$(($(date +%s)-$start)) -u +%H:%M:%S)"
stop
