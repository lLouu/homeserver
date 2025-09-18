#!/bin/sh
# Installation script of jenkins from an alpine os
sudo /usr/bin/wget -O /etc/apk/keys/jenkins-ci.org.key https://pkg.jenkins.io/redhat-stable/jenkins-ci.org.key
if [[ ! "$(cat /etc/apk/repositories | grep http://dl-cdn.alpinelinux.org/alpine/v3.16/community)" ]]; then echo "http://dl-cdn.alpinelinux.org/alpine/v3.16/community" | sudo tee -a /etc/apk/repositories; fi
if [[ ! "$(cat /etc/apk/repositories | grep https://pkg.jenkins.io/redhat-stable)" ]]; then echo "https://pkg.jenkins.io/redhat-stable" | sudo tee -a /etc/apk/repositories; fi
sudo /sbin/apk update 
sudo /sbin/apk add jenkins openjdk21 openjdk21-jre packer terraform python3 py3-pip curl jq git
for py in $(ls /usr/lib/ | grep python3.);do
    if [[ -f /usr/lib/$py/EXTERNALLY-MANAGED ]];then
        sudo /bin/mv /usr/lib/$py/EXTERNALLY-MANAGED /usr/lib/$py/EXTERNALLY-MANAGED.old
    fi
done
sudo /usr/bin/pip install ansible

# Update to last war version
war="/usr/share/webapps/jenkins/jenkins.war"
bck="$war.$(date "+%Y-%m-%d").bck"
if [[ ! -f "$bck" ]]; then sudo /bin/mv $war $bck; else sudo /bin/mv $war $bck.last; fi
sudo /usr/bin/wget https://get.jenkins.io/war-stable/latest/jenkins.war -O $war
sudo /bin/chmod 755 $war
sudo /bin/chown root:root $war

# Define /tmp size
sudo /sbin/rc-service jenkins -s stop
sudo /bin/umount /tmp
sudo /bin/mount -t tmpfs -o size=8G,mode=1777 overflow /tmp

sudo /sbin/rc-service jenkins -S start
sudo /sbin/rc-update add jenkins
