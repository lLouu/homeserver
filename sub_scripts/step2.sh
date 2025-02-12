
#######
## Remove Debian Kernel
echo "[~] Removing debian kernel"
sudo apt-get remove linux-image-amd64 'linux-image-6.1*' os-prober -y > /dev/null
sudo update-grub > /dev/null
echo "[+] Debian kernel Removed"

# Setup init terraform
## Generate hash & Token
echo "[~] Generating terraform credentials"
sudo apt-get install python3-bcrypt -y > /dev/null
NEW_PASS=$(openssl rand -base64 64)
HASHED_PASS=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$NEW_PASS', bcrypt.gensalt()).decode())")
ETOKEN_ID=-$(openssl rand -hex 12)
ETOKEN_SECRET="$(openssl rand -hex 8)-$(openssl rand -hex 4)-$(openssl rand -hex 4)-$(openssl rand -hex 4)-$(openssl rand -hex 12)"
RTOKEN_ID=-$(openssl rand -hex 12)
RTOKEN_SECRET="$(openssl rand -hex 8)-$(openssl rand -hex 4)-$(openssl rand -hex 4)-$(openssl rand -hex 4)-$(openssl rand -hex 12)"


## Add terraform user
echo "[~] Setting up proxmox API"
echo "user:terraform@pve:1:0:::::::" | sudo tee /etc/pve/user.cfg > /dev/null
echo "token:terraform@pve!$ETOKEN_ID:0:0:extended terraform token:" | sudo tee /etc/pve/user.cfg > /dev/null
echo "token:terraform@pve!$RTOKEN_ID:0:1:restricted terraform token:" | sudo tee /etc/pve/user.cfg > /dev/null

### Groups
echo "group:InfraAdmin:terraform@pve:Infra Admin:" | sudo tee /etc/pve/user.cfg > /dev/null
echo "group:InfraUser:terraform@pve:Infra User:" | sudo tee /etc/pve/user.cfg > /dev/null
echo "group:VMAdmin:terraform@pve,terraform@pve!$RTOKEN_ID:VM Admin:" | sudo tee /etc/pve/user.cfg > /dev/null
### /mapping acl
echo "acl:1:/mapping:@InfraAdmin:PVEMappingAdmin" | sudo tee /etc/pve/user.cfg > /dev/null
echo "acl:1:/mapping:@InfraUser:PVEMappingUser" | sudo tee /etc/pve/user.cfg > /dev/null
### /sdn/zones acl
echo "acl:1:/sdn/zones:@InfraAdmin:PVESDNAdmin" | sudo tee /etc/pve/user.cfg > /dev/null
echo "acl:1:/sdn/zones:@InfraUser:PVESDNUser" | sudo tee /etc/pve/user.cfg > /dev/null
### /storage acl
echo "acl:1:/storage:@InfraAdmin:PVEDatastoreAdmin" | sudo tee /etc/pve/user.cfg > /dev/null
echo "acl:1:/storage:@InfraUser:PVEDatastoreUser" | sudo tee /etc/pve/user.cfg > /dev/null
### /vms acl
echo "acl:1:/vms:@VMAdmin:PVEVMAdmin" | sudo tee /etc/pve/user.cfg > /dev/null

### store secrets
echo "terraform:$HASHED_PASS:" | sudo tee /etc/pve/priv/shadow.cfg > /dev/null
echo "terraform@pve!$ETOKEN_ID $ETOKEN_SECRET" | sudo tee /etc/pve/priv/token.cfg > /dev/null
echo "terraform@pve!$RTOKEN_ID $RTOKEN_SECRET" | sudo tee /etc/pve/priv/token.cfg > /dev/null


# user:uname@<pam|pve>:1(enabled):<expiration_ts|0>:first_name:last_name:email:comment:<x if totp enabled>:
# group:gname:user1,user2,...,userN:<comment>:
# role:role_name:perm1,perm2,...,permN:
# acl:<propagate>:<path>:<user@pve|user@pve!tid|@group>:<role>:
# token:uname@<pam|pve>!<tokenid>:<expiration_ts|0>:<unlinked_permission>:<comment>:
# uname@<pam|pve>!<tokenid> (b16){8}-(b16){4}-(b16){4}-(b16){4}-(b16){12}


echo "[+] API setted up"
echo "[>] The terraform user password is '$NEW_PASS'"
echo "[>] The extended API token is '$ETOKEN_SECRET'"
echo "[>] The restricted API token is '$RTOKEN_SECRET'"