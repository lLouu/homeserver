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


source "proxmox-iso" "ubuntu-ansible-ready" {

    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox.api.url}"
    username    = "${var.proxmox.api.token_id}"
    token       = "${var.proxmox.api.token_secret}"
    insecure_skip_tls_verify = true

    # VM General Settings
    node                 = var.proxmox.node
    vm_id                = "302"
    vm_name              = "ubuntu-ansible-ready"

    # Ressources
    memory      = 6144
    sockets     = 2
    cores       = 2

    # Behaviour
    boot            = "c"
    boot_wait       = "5s"
    scsi_controller = "virtio-scsi-pci"
    qemu_agent      = true

    # VM OS Settings
    boot_iso {
        type             = "scsi"
        iso_url          = "https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
        unmount          = true
        iso_storage_pool = "local"
        iso_checksum     = "dec49008a71f6098d0bcfc822021f4d042d5f2db279e4d75bdd981304f1ca5d9"
    }

    # VM System Settings
    disks {
        type              = "scsi"
        disk_size         = "10G"
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
        "<enter><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<enter><wait><enter><wait><up><wait><up><wait><enter><wait><down><wait><down><wait><enter><wait5>",
        "<enter><wait><enter><wait5><wait5><enter><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<down><wait><down><wait><enter><wait><down><wait><down><wait><enter><wait><enter><wait><down><wait><enter><wait>",
        "ubuntu<down><wait>ubuntu<down><wait>ubuntu<down><wait>${var.root_pwd}<down><wait>${var.root_pwd}<down><wait><enter><wait>",
        "<enter><wait><enter><wait><down><wait><down><wait><enter><wait>",
        "<down><wait><down><wait><down><wait><down><wait><down><wait><down><wait><down><wait><down><wait>",
        "<down><wait><down><wait><down><wait><down><wait><down><wait><down><wait><down><wait><down><wait>",
        "<enter><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<down><wait><down><wait><enter><wait><down><wait><down><wait><enter><wait5><wait5><enter><wait>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<enter><wait>ubuntu<enter><wait>${var.root_pwd}<enter><wait5>",

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
    name    = "ubuntu-ansible-ready"
    sources = ["source.proxmox-iso.ubuntu-ansible-ready"]
}