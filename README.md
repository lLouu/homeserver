# General Informations

## The project
Homeserver is an automation script to convert a machine in a self-hosted proxmox server with CI/CD pipe to allow easy and fast deployement for a home lab.

## Preparation
On your server, install debian, preferablly without gui. Do the partitionning depending on your drives. Here is some guidelines for it :
- Use a 50G partition for the OS (min 35G)
- NVMe should be used for the swap, and for SSD caching before real SSDs if needed. It may also be used as hot storage, with SSD or HDD as cold storage behind
- SSD should be mostly used for hot storage. Swap may be also be considered if you have no NVMe
- HDD should be used mostly for parity, and for cold storage
> We advise pairing HDDs with SSDs, and as such using part of HDD for the snapraid parity. For xTb of SSD and yTb of HDD, make a HDD partition of (x+y)/2 for parity. For 4Tb SSD and 16Tb HDD, that makes (4+16)/2 Tb = 10 Tb HDD partition for parity, leaving 6 Tb for cold storage. This allows redundancy of SSD using cheaper and more durable HDD storage. Also, in case of HDD fails where you miss a parity to restore old data, it may be possible to retrieve the hard disk parity partition by dismounting one of the failed drive.
> This makes even the single-pair viable, but we advice to consider using this system with at least 2 pairs.

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
## Drives management
> Schematics will be added in near future for explaination

## Proxmox installation
Automation of proxmox VE installation from a debian.

## vGPU unlock
> Shoutout to https://github.com/DualCoder/vgpu_unlock

NVIDIA driver is setted up and compiled such as vGPU are unlocked and available for proxmox

## CICD agent
CICD is enabled, allowing to modify allongisde the git repo the structure and configuration of the homeserver.
### Terraform & Packer
Packer creates ansible-ready templates for the different iso, letting it with an ansible user that can connect by ssh only with certificate. The network configuration for them is a single bridge. It is also responsible of initial configuration of the Pfsense.<br>
Terraform then uses these modeles to deploy the architecture of the homeserver.
### Ansible
Ansible is responsible for software configuration. Once a server is up and running, it connects to it, installs the software, and once installed limits its rights to be able only to manage the configurations.
### Initial deployment
Before Jenkins gets deployed, the host proxmox node takes the role of the CICD agent, deploying the initial configuration of the pfsense + the jenkins agent. It forward then the ansible private key to jenkins before destroying CICD related stuff. Starting there, Jenkins takes the hand to deploy the dynamic architcture

## ISO library
- alpine-virt-3.21.2-aarch64.iso
- debian-13.2.0-amd64-netinst.iso
- ubuntu-24.04.1-live-server-amd64.iso
- pfSense-CE-2.7.2-RELEASE-amd64.iso
