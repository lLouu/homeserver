source "proxmox-iso" "alpine-ansible-ready" {

    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox.api.url}"
    username    = "${var.proxmox.api.token_id}"
    token       = "${var.proxmox.api.token_secret}"

    # VM General Settings
    node                 = var.proxmox.node
    vm_id                = "301"
    vm_name              = "alpine-ansible-ready"

    # Ressources
    memory      = 2048
    sockets     = 1
    cores       = 1

    # Behaviour
    boot        = "c"
    boot_wait   = "5s"
    scsihw      = "virtio-scsi-pci"
    qemu_agent  = true

    # VM OS Settings
    boot_iso {
        type         = "scsi"
        iso_file     = "local:iso/alpine-virt-3.21.2-aarch64.iso"
        unmount      = true
        iso_checksum = "8857deccf90f40eada1ab82965819d43d68d10463a09867234ca59f58efe669f"
    }

    # VM System Settings
    disks {
        type              = "scsi"
        disk_size         = "20G"
        storage_pool      = "local"
    }
    network_adapters {
        model    = "virtio"
        bridge   = "vmbr1"
    }

    # PACKER Boot Commands
    boot_command = [
        "root<enter><wait>",
        "ifconfig eth0 up && udhcpc -i eth0<enter><wait5>",
        "setup-alpine<enter><wait>",
        "us<enter><wait>us<enter><wait>",
        "alpine<enter><wait>",
        "<enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait>",
        "${var.root_pwd}<enter><wait>${var.root_pwd}<enter><wait>",
        "<enter><wait><enter><wait><enter><wait><enter><wait><enter><wait><enter><wait>",
        "no<enter><wait>",
        "sda<enter><wait>sys<enter><wait>y<enter><wait5>",

        "adduser -s /bin/sh ansible -D<enter><wait>",
        "mkdir /home/ansible/.ssh<enter><wait>",
        "echo '${var.ansible_pub}' > /home/ansible/.ssh/authorized_keys<enter><wait>",
        "chmod 700 /home/ansible/.ssh && chmod 600 /home/ansible/.ssh/authorized_keys<enter><wait>",
        "chown ansible:ansible /home/ansible/.ssh /home/ansible/.ssh/authorized_keys<enter><wait>",
        "cat > /etc/ssh/sshd_config.d/first_setup.conf <<EOF<enter>Port 22<enter>Protocol 2<enter>PermitRootLogin no<enter>PasswordAuthentication no<enter>PubkeyAuthentication yes<enter>ChallengeResponseAuthentication no<enter>UsePAM yes<enter>EOF<enter><wait>",
        "service sshd restart<enter><wait>",
        
        "sed -i 's/^#//' /etc/apk/repositories<enter><wait>",
        "apk update && apk add --no-cache sudo python3 py3-pip cloud-init<enter><wait>",
        "echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible<enter><wait>",
        "chmod 440 /etc/sudoers.d/ansible && chown root:root /etc/sudoers.d/ansible<enter><wait>",

        "poweroff<enter>"
    ]
    
    # VM Cloud-Init Settings
    cloud_init              = true
    cloud_init_storage_pool = "local"
}

build {
    name    = "alpine-ansible-ready"
    sources = ["source.proxmox.alpine-ansible-ready"]
}