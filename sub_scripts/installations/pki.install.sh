#!/bin/sh
sudo /sbin/apk add --update --virtual .deps --no-cache gnupg
sudo /bin/mkdir /opt/vault
sudo /bin/wget https://releases.hashicorp.com/vault/2.0.0/vault_2.0.0_linux_amd64.zip -O /opt/vault/vault_2.0.0_linux_amd64.zip
sudo /usr/bin/unzip /opt/vault/vault_2.0.0_linux_amd64.zip -d /opt/vault
sudo /bin/mv /opt/vault/vault /usr/local/bin/vault
sudo /bin/rm -R /opt/vault
sudo /sbin/apk del .deps

sudo /usr/sbin/adduser -D -h /var/lib/vault -s /sbin/nologin vault
sudo /bin/mkdir -p /var/lib/vault
sudo /usr/bin/tee /etc/conf.d/vault.hcl <<EOF
storage "file" {
  path = "/var/lib/vault"
}

listener "tcp" {
  address = "10.1.5.5:8200"
  tls_disable = 1
}

ui = true
api_addr = "https://10.1.5.5:8200"
disable_mlock = true
EOF
sudo /sbin/chown -R vault:vault /etc/conf.d/vault.hcl /var/lib/vault
sudo /sbin/chmod 750 /etc/vault /etc/conf.d/vault.hcl /var/lib/vault

sudo /usr/bin/tee /etc/init.d/vault <<EOF
#!/sbin/openrc-run

name="Vault"
description="HashiCorp Vault Server"

command="/usr/local/bin/vault"
command_args="server -config=/etc/conf.d/vault.hcl"
command_user="vault:vault"
pidfile="/run/vault.pid"

depend() {
  need net
}

start_pre() {
    checkpath --directory --owner vault:vault /run
}
EOF
sudo /bin/chmod +x /etc/init.d/vault
sudo /sbin/rc-update add vault default
sudo /sbin/rc-service vault start

init=$(VAULT_ADDR=http://10.1.5.5:8200 vault operator init | sudo /usr/bin/tee /root/.keys)


echo "$init" | grep 'Unseal Key 1' | awk '{print($4)}' | VAULT_ADDR=http://10.1.5.5:8200 vault operator unseal
echo "$init" | grep 'Unseal Key 2' | awk '{print($4)}' | VAULT_ADDR=http://10.1.5.5:8200 vault operator unseal
echo "$init" | grep 'Unseal Key 3' | awk '{print($4)}' | VAULT_ADDR=http://10.1.5.5:8200 vault operator unseal
