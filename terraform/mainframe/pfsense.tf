# Terraform Proxmox Homeserver Mainframe V0.1

resource "proxmox_vm_qemu" "pfsense" {
  # General
  target_node = var.proxmox.node
  name        = "pfSense"
  vmid        = 500
  clone       = "pfsense-ansible-ready"

  # Ressources
  memory      = var.pfsense.ram
  sockets     = var.pfsense.sockets
  cores       = var.pfsense.cores

  # Behaviour
  boot        = "order=scsi0"
  scsihw      = "virtio-scsi-pci"
  agent       = 1
  onboot      = true
  vm_state    = "running"

  # Storage
  dynamic "disk" {
    for_each = var.pfsense.disks

    content {
      type       = "disk"
      emulatessd = disk.value.is_ssd
      size       = disk.value.size
      storage    = disk.value.storage
      slot       = disk.value.slot
    }
  }

  # Network
  dynamic "network" {
    for_each = var.networks

    content {
      id       = network.value
      model    = "virtio"
      bridge   = "vmbr${network.value}"
      firewall = true
    }
  }
}
