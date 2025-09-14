#!/bin/sh
# Installation script of jenkins from an alpine os
sudo wget -O /etc/apk/keys/jenkins-ci.org.key https://pkg.jenkins.io/redhat-stable/jenkins-ci.org.key
if [[ ! "$(cat /etc/apk/repositories | grep http://dl-cdn.alpinelinux.org/alpine/v3.16/community)" ]]; then echo "http://dl-cdn.alpinelinux.org/alpine/v3.16/community" | sudo tee -a /etc/apk/repositories; fi
if [[ ! "$(cat /etc/apk/repositories | grep https://pkg.jenkins.io/redhat-stable)" ]]; then echo "https://pkg.jenkins.io/redhat-stable" | sudo tee -a /etc/apk/repositories; fi
sudo apk update 
sudo apk add jenkins openjdk21 openjdk21-jre packer terraform python3 py3-pip curl jq git
for py in $(ls /usr/lib/ | grep python3.);do
    if [[ -f /usr/lib/$py/EXTERNALLY-MANAGED ]];then
        sudo mv /usr/lib/$py/EXTERNALLY-MANAGED /usr/lib/$py/EXTERNALLY-MANAGED.old
    fi
done
sudo pip install ansible

# Update to last war version
wget https://get.jenkins.io/war-stable/latest/jenkins.war -O /tmp/jenkins.war.tmp 
for war in $(sudo find / -name jenkins.war);do
    bck="$war.$(date "+%Y-%m-%d").bck"
    perm="$(ls -la $bck | awk '{print($3)}'):$(ls -la $bck | awk '{print($4)}')"
    sudo mv $war $bck
    sudo cp /tmp/jenkins.war.tmp $war
    sudo chmod 755 $war
    sudo chown $perm $war
done
rm /tmp/jenkins.war.tmp

sudo rc-service jenkins -S start
sudo rc-update add jenkins
