#!/bin/sh
# Installation script of jenkins from an alpine os
sudo wget -O /etc/apk/keys/jenkins-ci.org.key https://pkg.jenkins.io/redhat-stable/jenkins-ci.org.key
if [[ ! "$(cat /etc/apk/repositories | grep http://dl-cdn.alpinelinux.org/alpine/v3.16/community)" ]]; then echo "http://dl-cdn.alpinelinux.org/alpine/v3.16/community" | sudo tee -a /etc/apk/repositories; fi
if [[ ! "$(cat /etc/apk/repositories | grep https://pkg.jenkins.io/redhat-stable)" ]]; then echo "https://pkg.jenkins.io/redhat-stable" | sudo tee -a /etc/apk/repositories; fi
sudo apk update && sudo apk add jenkins openjdk21 openjdk21-jre packer terraform python3 py3-pip curl jq
sudo pip install ansible

sudo rc-service jenkins -S start
sudo rc-update add jenkins
