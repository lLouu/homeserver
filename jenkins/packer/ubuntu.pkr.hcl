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


source "proxmox-iso" "alpine-ansible-ready" {

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
    memory      = 4096
    sockets     = 1
    cores       = 2

    # Behaviour
    boot            = "c"
    boot_wait       = "50s"
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
        disk_size         = "25G"
        storage_pool      = "local"
        format            = "qcow2"
    }
    network_adapters {
        model    = "virtio"
        bridge   = "vmbr3"
    }

    # PACKER Boot Commands
    http_directory = "http"
    boot_command = ["<esc><wait>",
        "<enter><wait><enter><wait><up><up><space><down><down><enter><wait><enter><wait><enter><wait><enter><wait>",
        "<down><down><down><down><down><enter><wait><enter><wait><enter><wait><down><enter><wait>",
        "ubuntu<down>ubuntu<down>ubuntu<down>${var.root_pwd}<down>${var.root_pwd}<down><enter><wait>",
        "<enter><wait><space><down><down><enter><wait>",
        "<wait5><wait5><wait5><wait5>",
        "<down><down><enter><wait>",
        "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
        "<enter>ubuntu<enter><wait>${var.root_pwd}<enter><wait5>"

        "sudo adduser --shell /bin/sh ansible --disabled-password --quiet<enter><wait>",
        "${var.root_pwd}<enter><wait>",
        "sudo sed -i 's/ansible:!/ansible:*/' /etc/shadow<enter><wait>",
        "sudo mkdir /home/ansible/.ssh<enter><wait>",
        "sudo wget http://{{ .HTTPIP }}:{{ .HTTPPort }}/ansible.pub -O /home/ansible/.ssh/authorized_keys<enter><wait5>",
        "sudo chmod 700 /home/ansible/.ssh && chmod 600 /home/ansible/.ssh/authorized_keys<enter><wait>",
        "sudo chown ansible:ansible /home/ansible/.ssh /home/ansible/.ssh/authorized_keys<enter><wait>",
        "cat | sudo tee /etc/ssh/sshd_config.d/first_setup.conf >/dev/null <<EOF<enter>Port 22<enter>Protocol 2<enter>PermitRootLogin no<enter>PasswordAuthentication no<enter>PubkeyAuthentication yes<enter>ChallengeResponseAuthentication no<enter>EOF<enter><wait>",
        "sudo systemctl restart sshd.service<enter><wait>",
        
         "sudo apt-get update && sudo apt-get install cloud-init util-linux qemu-guest-agent e2fsprogs-extra<enter><wait>",
         "<wait5><wait5><wait5><wait5><wait5><wait5>",
         "echo 'ansible ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/ansible >/dev/null<enter><wait>",
         "sudo chmod 440 /etc/sudoers.d/ansible && sudo chown root:root /etc/sudoers.d/ansible<enter><wait>",
         "echo 'datasource_list: [ NoCloud, ConfigDrive ]' | sudo tee /etc/cloud/cloud.cfg.d/02-datasource.cfg >/dev/null<enter><wait>",
         "setup-cloud-init<enter><wait>",

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