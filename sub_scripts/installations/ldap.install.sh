#!/bin/sh
sudo /sbin/apk add openldap openldap-back-mdb openldap-clients
sudo /usr/bin/install -m 755 -o ldap -g ldap -d /etc/openldap/slapd.d
sudo /bin/sed -i 's/cfgfile=.*$/cfgdir=slapd.d/' /etc/conf.d/slapd
sudo /bin/rm /etc/openldap/slapd.conf

sudo /bin/sed -i 's/^olcSuffix:.*$/olcSuffix: dc=home,dc=lab/' /etc/openldap/slapd.ldif
sudo /bin/sed -i 's/^olcRootDN:.*$/olcRootDN: cn=Manager,dc=home,dc=lab/' /etc/openldap/slapd.ldif
sudo /bin/sed -i "s/^olcRootPW:.*$/olcRootPW: $(slappasswd -s $(openssl rand -base64 48))/" /etc/openldap/slapd.ldif

sudo /usr/sbin/slapadd -n 0 -F /etc/openldap/slapd.d -l /etc/openldap/slapd.ldif


sudo /usr/bin/install -m 755 -o ldap -g ldap -d /var/lib/openldap/run
sudo /sbin/rc-service slapd start
sudo /sbin/rc-update add slapd

