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

POSITIONAL_ARGS=()
ORIGINAL_ARGS=$@

while [[ $# -gt 0 ]]; do
  case $1 in
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
sed -i 's/~\/step2.sh//' ~/.bash_profile

## Remove Debian Kernel
echo "[~] Removing debian kernel"
sudo apt-get remove linux-image-amd64 'linux-image-6.1*' os-prober -yq > /dev/null
sudo update-grub >/dev/null 2>/dev/null
echo "[+] Debian kernel Removed"

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

### Groups
echo "group:TerraformProviders:terraform@pve:Terraform Providers:" | sudo tee -a /etc/pve/user.cfg > /dev/null
### Roles
echo "role:terraformDataProvider:Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit:" | sudo tee -a /etc/pve/user.cfg > /dev/null
echo "role:terraformVMProvider:Pool.Allocate,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.Monitor,VM.PowerMgmt,SDN.Use:" | sudo tee -a /etc/pve/user.cfg > /dev/null
echo "role:terraformSysProvider:Sys.Audit,Sys.Console,Sys.Modify:" | sudo tee -a /etc/pve/user.cfg > /dev/null

### /storage acl
echo "acl:1:/:@TerraformProviders:terraformDataProvider" | sudo tee -a /etc/pve/user.cfg > /dev/null
### /vms acl
echo "acl:1:/:@TerraformProviders:terraformVMProvider" | sudo tee -a /etc/pve/user.cfg > /dev/null
### /sys acl
echo "acl:1:/:@TerraformProviders:terraformSysProvider" | sudo tee -a /etc/pve/user.cfg > /dev/null

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

# Download ISO store on /var/lib/vz/template/iso/
echo "[~] Downloading ISO Librarie"
## Alpine
if [[ ! -f "/var/lib/vz/template/iso/alpine-virt-3.21.2-aarch64.iso" || "$(sha256sum /var/lib/vz/template/iso/alpine-virt-3.21.2-aarch64.iso | awk '{print($1)}')" != "8857deccf90f40eada1ab82965819d43d68d10463a09867234ca59f58efe669f" ]]; then
   echo "[~] Downloading Alpine ISO"
   wget https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/aarch64/alpine-virt-3.21.2-aarch64.iso -q > /dev/null
   if [[ "$(sha256sum alpine-virt-3.21.2-aarch64.iso | awk '{print($1)}')" != "8857deccf90f40eada1ab82965819d43d68d10463a09867234ca59f58efe669f" ]]; then
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
   if [[ "$(sha256sum ubuntu-24.04.1-live-server-amd64.iso | awk '{print($1)}')" != "e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9 " ]]; then
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
sudo mv host.fw /etc/pve/nodes/debian/
sudo systemctl restart pve-firewall

# Setting up terraform, Packer & Ansible
echo "[~] Downloading terraform, packer and ansible"
wget -q -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
newdpkg="deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main"
echo "$newdpkg" | sudo tee /etc/apt/sources.list.d/tmp_hashicorp.list >/dev/null
sudo apt update -yq >/dev/null 2>/dev/null && sudo apt install terraform packer -yq >/dev/null 2>/dev/null
sudo pip install ansible -q >/dev/null 2>/dev/null

# Deploying initial state
echo "[~] Fetching for configuration files"
git clone -b $branch https://github.com/llouu/homeserver --quiet >/dev/null 2>/dev/null
cd homeserver/terraform/mainframe
mv ../configs/* ./
mv ../packer/* ./
sed -i "s/===HOSTNAME===/$(cat /etc/hostname)/" proxmox.tfvars.json
sed -i "s/===IP===/$(hostname --ip-address)/" proxmox.tfvars.json
sed -i "s/===ID===/terraform@pve!$TOKEN_ID/" proxmox.tfvars.json
sed -i "s/===SECRET===/$TOKEN_SECRET/" proxmox.tfvars.json

## Create Pfsense packer config, and deploy the firewall
echo "[~] Creating firewall template"
packer init pfsense.pkr.hcl >/dev/null
packer build -var-file="proxmox.tfvars.json" -var "ansible_pub=$ANSIBLE_PUB" -var 'networks=[0,1,2,3,4,5]' pfsense.pkr.hcl >/dev/null

echo "[~] Deploying firewall"
terraform init >/dev/null
echo '[]' | terraform plan --var-file=proxmox.tfvars.json --var-file=pfsense.tfvars.json -out plan >/dev/null
terraform apply "plan"
rm plan

## Create Packer template of alpine and deploy jenkins agent
echo "[~] Creating Alpine template"
packer init alpine.pkr.hcl >/dev/null
packer build -var-file="proxmox.tfvars.json" -var "ansible_pub=$ANSIBLE_PUB" -var "root_pwd=$ROOT_PWD" alpine.pkr.hcl >/dev/null

echo "[~] Deploying Jenkins agent"
terraform init >/dev/null
terraform plan --var-file=proxmox.tfvars.json --var-file=pfsense.tfvars.json --var-file=init.tfvars.json -out plan >/dev/null
terraform apply "plan"
rm plan

## Connect with ansible to setup jenkins for it to handle the other Packer and terraform edits


cd ../../..
sudo rm -r homeserver

# Unsetting terraform & Ansible
sudo apt remove terraform && sudo apt remove packer
sudo rm /usr/share/keyrings/hashicorp-archive-keyring.gpg
sudo rm /etc/apt/sources.list.d/tmp_hashicorp.list

sudo apt autoremove

echo "[*] Script executed in $(date -d@$(($(date +%s)-$start)) -u +%H:%M:%S)"
stop
