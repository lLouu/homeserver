# General Informations

## The project
Homeserver is an automation script to convert a machine in a self-hosted proxmox server with CI/CD pipe to allow easy and fast deployement for a home lab.

## Preparation
On your server, install debian, preferablly without gui. Do the partitionning depending on your drives. Here is some guidelines for it :
- Use a 20G partition for the OS
- Consider using most of your NVMe as swap, if so you don't need to RAID it
- Use NVMe or SSD for a "tmp" partition, still without RAID, that would be used for SSD caching, or for filesystems that do not need backup since it can juste be installed back again
- remaining SSD and NVME can be used with RAID 3 or RAID 5, using HDD as parity if possible. Use that as hot storage.
- For HDD, use them as cold storage with RAID 1, 3 or 5.
- You may also use part of HDD for temp storage with no RAID if you don't care about a slow system, and prefer using SSD for increasing swap capacities.

## Installation

### Main installation
```
bash -c "$(curl -L -s https://raw.githubusercontent.com/lLouu/homeserver/main/install.sh)"
```
### Dev installation
```
bash -c "$(curl -L -s https://raw.githubusercontent.com/lLouu/homeserver/main/install.sh)" -- -b dev
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

## CICD agent
CICD is enabled, allowing to modify allongisde the git repo the structure and configuration of the homeserver.
### Terraform & Packer
Packer creates ansible-ready templates for the different iso, letting it with an ansible user that can connect by ssh only with certificate. The network configuration for them is a single bridge. It is also responsible of initial configuration of the Pfsense.<br>
Terraform then uses these modeles to deploy the architecture of the homeserver.

## ISO library
- alpine-virt-3.21.2-aarch64.iso
- debian-12.9.0-amd64-netinst.iso
- ubuntu-24.04.1-live-server-amd64.iso
- pfSense-CE-2.7.2-RELEASE-amd64.iso
