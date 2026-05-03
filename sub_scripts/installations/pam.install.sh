#!/bin/sh
sudo /bin/wget https://cdn.teleport.dev/teleport-v18.7.6-linux-amd64-bin.tar.gz -O /opt/teleport-v18.7.6-linux-amd64-bin.tar.gz
sudo /bin/tar -xzf /opt/teleport-v18.7.6-linux-amd64-bin.tar.gz
sudo /opt/teleport/install
sudo /bin/rm /opt/teleport-v18.7.6-linux-amd64-bin.tar.gz
