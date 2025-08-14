# General Informations

## The project
Homeserver is an automation script to convert a machine in a self-hosted proxmox server with CI/CD pipe to allow easy and fast deployement for a home lab.

## Installation

### Main installation
```
curl -L -s https://raw.githubusercontent.com/lLouu/homeserver/main/install.sh | bash
```
### Dev installation
```
curl -L -s https://raw.githubusercontent.com/lLouu/homeserver/main/install.sh | bash -s -- -b dev
```
### No-curl installation
```
wget https://raw.githubusercontent.com/lLouu/homeserver/main/install.sh
chmod +x install.sh
./install.sh
```

# Features
## Proxmox installation
Automation of proxmox VE installation from a debian.

## Data management
You'll need to make your partitionning and RAID management before the script is launched. However, the script manage mounting, and use mergerfs to facilitte multi-drives management. You can categorise your partition as followed :
- `vram` will be fully used for swap files, mounted in `/mnt/vram`, thought for NVMe without RAID
- `hot` will be hot storage, mounted in `/mnt/hot`, thought to be SSD with RAID
- `cold` will be cold storage, mounted in `/mnt/cold`, thought to be HDD with RAID
- `temp_hot` (or `thot`) will be hot temp storage, mounted in `/mnt/temp_hot`, thought to be SSD without RAID
- `temp_cold` (or `tcold`) will be cold temp storage, mounted in `/mnt/temp_cold`, thought to be HDD without RAID

Every 3 days, a check of last used is done to move files between hot and cold storages.<br>
Also, hot and cold are merged in `/mnt/storage`, while temp_hot and temp_cold are merged in `/mnt/temp`

## vGPU unlock
> Shoutout to https://github.com/DualCoder/vgpu_unlock

NVIDIA driver is setted up and compiled such as vGPU are unlocked and available for proxmox

## Default API keys
Creating base ressources to allow terraform to interact with proxmox

## ISO library
- alpine-virt-3.21.2-aarch64.iso
- debian-12.9.0-amd64-netinst.iso
- ubuntu-24.04.1-live-server-amd64.iso
- pfSense-CE-2.7.2-RELEASE-amd64.iso
