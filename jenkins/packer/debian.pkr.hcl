# Plugin
packer {
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Variable Definitions
variable "proxmox" {
  type = object({
    node = string
    api  = object({
      url           = string
      token_id      = string
      token_secret  = string
    })
  })
}

variable "root_pwd" {
  type = string
}


source "proxmox-iso" "debian-ansible-ready" {

    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox.api.url}"
    username    = "${var.proxmox.api.token_id}"
    token       = "${var.proxmox.api.token_secret}"
    insecure_skip_tls_verify = true

    # VM General Settings
    node                 = var.proxmox.node
    vm_id                = "303"
    vm_name              = "debian-ansible-ready"

    # Ressources
    memory      = 2048
    sockets     = 1
    cores       = 1

    # Behaviour
    boot            = "c"
    boot_wait       = "5s"
    scsi_controller = "virtio-scsi-pci"
    qemu_agent      = true

    # VM OS Settings
    boot_iso {
        type             = "scsi"
        iso_url          = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.4.0-amd64-netinst.iso"
        unmount          = true
        iso_storage_pool = "local"
        iso_checksum     = "0b813535dd76f2ea96eff908c65e8521512c92a0631fd41c95756ffd7d4896dc"
    }

    # VM System Settings
    disks {
        type              = "scsi"
        disk_size         = "6G"
        storage_pool      = "local"
        format            = "qcow2"
    }
    network_adapters {
        model    = "virtio"
        bridge   = "vmbr3"
    }

    # PACKER Boot Commands
    http_directory = "http"
    boot_command = [
        "<down><wait><enter><wait5><enter><wait><enter><wait><enter><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<enter><wait><enter><wait5>${var.root_pwd}<enter><wait>${var.root_pwd}<enter><wait>debian<enter><wait><enter><wait>${var.root_pwd}<enter><wait>${var.root_pwd}<enter><wait>",
        "<enter><wait5><wait5><enter><wait><enter><wait><enter><wait><enter><wait><left><wait><enter>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<enter><wait><enter><wait><enter><wait><enter><wait>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<enter><wait5><wait5><wait5><enter>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<enter><wait><down><wait><enter><wait>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<enter>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        

        "debian<enter><wait>${var.root_pwd}<enter><wait5>",

        "su -<enter><wait>${var.root_pwd}<enter><wait>",
        "apt-get update && apt-get install sudo<enter><wait5><wait5><wait5><wait5>",
        "echo 'debian ALL=(ALL:ALL) ALL' >> /etc/sudoers.d/debian",
        "exit<enter><wait>",
        "sudo adduser --shell /bin/sh ansible --disabled-password<enter><wait>",
        "${var.root_pwd}<enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait>",
        "sudo sed -i 's/ansible:!/ansible:*/' /etc/shadow<enter><wait>",
        "sudo mkdir /home/ansible/.ssh<enter><wait>",
        "sudo wget http://{{ .HTTPIP }}:{{ .HTTPPort }}/ansible.pub -O /home/ansible/.ssh/authorized_keys<enter><wait5>",
        "sudo chmod 700 /home/ansible/.ssh && sudo chmod 600 /home/ansible/.ssh/authorized_keys<enter><wait>",
        "sudo chown ansible:ansible /home/ansible/.ssh /home/ansible/.ssh/authorized_keys<enter><wait>",
        "cat | sudo tee /etc/ssh/sshd_config.d/first_setup.conf >/dev/null <<EOF<enter>Port 22<enter>Protocol 2<enter>PermitRootLogin no<enter>PasswordAuthentication no<enter>PubkeyAuthentication yes<enter>ChallengeResponseAuthentication no<enter>EOF<enter><wait>",
        "sudo systemctl restart sshd.service<enter><wait5>",
        
        "sudo sed -i '/match/d' /etc/netplan/00-installer-config.yaml<enter><wait>",
        "sudo sed -i '/macaddress/d' /etc/netplan/00-installer-config.yaml<enter><wait>",
        "sudo sed -i '/set-name/d' /etc/netplan/00-installer-config.yaml<enter><wait>",
        "sudo netplan apply<enter><wait>",
        "sudo apt-get update && sudo apt-get install qemu-guest-agent -y<enter><wait>",
        "<wait5><wait5><wait5><wait5><wait5><wait5>",
        "echo 'WantedBy=multi-user.target' | sudo tee -a /usr/lib/systemd/system/qemu-guest-agent.service<enter><wait>",
        "sudo systemctl enable qemu-guest-agent.service<enter><wait>",
        "echo 'ansible ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/ansible >/dev/null<enter><wait>",
        "sudo chmod 440 /etc/sudoers.d/ansible && sudo chown root:root /etc/sudoers.d/ansible<enter><wait>",
        "echo 'datasource_list: [ NoCloud, ConfigDrive ]' | sudo tee /etc/cloud/cloud.cfg.d/02-datasource.cfg >/dev/null<enter><wait>",

        "sudo systemctl poweroff<enter><wait>"
    ]
    
    # VM Cloud-Init Settings
    cloud_init              = true
    cloud_init_storage_pool = "local"
    communicator            = "none"
}

build {
    name    = "debian-ansible-ready"
    sources = ["source.proxmox-iso.debian-ansible-ready"]
}