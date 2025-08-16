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

variable "networks" {
  type    = list(number)
}
variable "ansible_pub" {
  type = string
}


source "proxmox-iso" "pfsense-ansible-ready" {

    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox.api.url}"
    username    = "${var.proxmox.api.token_id}"
    token       = "${var.proxmox.api.token_secret}"

    # VM General Settings
    node                 = var.proxmox.node
    vm_id                = "300"
    vm_name              = "pfsense-ansible-ready"

    # Ressources
    memory      = 2048
    sockets     = 1
    cores       = 1

    # Behaviour
    boot            = "c"
    boot_wait       = "45s"
    scsi_controller = "virtio-scsi-pci"
    qemu_agent      = true

    # VM OS Settings
    boot_iso {
        type         = "scsi"
        iso_file     = "local:iso/pfSense-CE-2.7.2-RELEASE-amd64.iso"
        unmount      = true
        iso_checksum = "441005f79ea0c155bc4b830a2b4207f8c0804cf7b075d2a6489c0a136cbc5d51"
    }

    # VM System Settings
    disks {
        type              = "virtio"
        disk_size         = "20G"
        storage_pool      = "local"
    }
    dynamic "network_adapter" {
        for_each = var.networks

        content {
        model    = "virtio"
        bridge   = "vmbr${network_adapter.value}"
        firewall = true
        }
    }

    # PACKER Boot Commands
    boot_command = [
         "<enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><spacebar><enter><wait><left><enter><wait5><wait5><wait5><wait5><wait5><wait5><enter><wait>",
         "<wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5><wait5>",
         "1<enter><wait>n<enter><wait>em0<enter><wait>em1<enter><wait>em2<enter><wait>em3<enter><wait>em4<enter><wait>em5<enter><wait>y<enter><wait5><wait5><wait5>",
         "2<enter><wait>2<enter><wait>n<enter><wait>10.1.1.1<enter><wait>24<enter><wait><enter><wait>n<enter><wait><enter><wait>y<enter><wait>10.1.1.10<enter><wait>10.1.1.200<enter><wait>n<enter><wait5><enter><wait>",
         "2<enter><wait>3<enter><wait>n<enter><wait>10.1.2.1<enter><wait>24<enter><wait><enter><wait>n<enter><wait><enter><wait>n<enter><wait>n<enter><wait5><enter><wait>",
         "2<enter><wait>4<enter><wait>n<enter><wait>10.1.3.1<enter><wait>24<enter><wait><enter><wait>n<enter><wait><enter><wait>n<enter><wait>n<enter><wait5><enter><wait>",
         "2<enter><wait>5<enter><wait>n<enter><wait>10.1.4.1<enter><wait>24<enter><wait><enter><wait>n<enter><wait><enter><wait>n<enter><wait>n<enter><wait5><enter><wait>",
         "2<enter><wait>6<enter><wait>n<enter><wait>10.1.5.1<enter><wait>24<enter><wait><enter><wait>n<enter><wait><enter><wait>n<enter><wait>n<enter><wait5><enter><wait>",
         "14<enter><wait>y<enter><wait>",
         
         "8<enter><wait>",
         "adduser<enter><wait>ansible<enter><wait>ansible<enter><wait>",
         "<enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait>",
         "no<enter><wait><enter><wait><enter><wait><enter><wait>",
         "mkdir /home/ansible/.ssh<enter><wait>",
         "echo '${var.ansible_pub}' > /home/ansible/.ssh/authorized_keys<enter><wait>",
         "chmod 700 /home/ansible/.ssh && chmod 600 /home/ansible/.ssh/authorized_keys<enter><wait>",
         "chown ansible:ansible /home/ansible/.ssh /home/ansible/.ssh/authorized_keys<enter><wait>",
         "echo 'Include /etc/ssh/sshd_config.d/*' >> /etc/ssh/sshd_config<enter><wait>",
         "mkdir /etc/ssh/sshd_config.d<enter><wait>",
         "cat > /etc/ssh/sshd_config.d/first_setup.conf <<EOF<enter>Port 22<enter>Protocol 2<enter>PermitRootLogin no<enter>PasswordAuthentication no<enter>PubkeyAuthentication yes<enter>ChallengeResponseAuthentication no<enter>UsePAM yes<enter>EOF<enter><wait>",
         "service sshd restart<enter><wait>",
         
         "echo 'y' | pkg install sudo python3 py3-pip<enter><wait>",
         "echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible<enter><wait>",
         "chmod 440 /etc/sudoers.d/ansible && chown root:root /etc/sudoers.d/ansible<enter><wait>",

    ]
    ssh_username = "ansible"
}

build {
    name    = "pfsense-ansible-ready"
    sources = ["source.proxmox-iso.pfsense-ansible-ready"]
}