# Terraform Proxmox Homeserver Mainframe V0.1

resource "proxmox_vm_qemu" "instances" {
  count = length(var.vms)

  # General
  target_node = var.proxmox.node
  name        = var.vms[count.index].name
  vmid        = var.vms[count.index].id

  # Ressources
  memory      = var.vms[count.index].ram
  sockets     = var.vms[count.index].sockets
  cores       = var.vms[count.index].cores

  # Behaviour
  boot        = "order=scsi0"
  scsihw      = "virtio-scsi-pci"
  agent       = 1
  onboot      = true
  vm_state    = "running"

  # Storage
  disk {
    type     = "ide"
    storage  = "local"
    iso      = var.vms[count.index].iso
    slot     = "virtio0"
  }
  dynamic "disk" {
    for_each = var.vms[count.index].disks

    content {
      type       = "scsi"
      emulatessd = disk.value.is_ssd
      size       = disk.value.size
      storage    = disk.value.storage
      slot       = disk.value.slot
    }
  }

  # Network
  dynamic "network" {
    for_each = var.vms[count.index].networks

    content {
      model  = "virtio"
      bridge = network.value.bridge
      id     = network.value.id
    }
  }

  # TODO : PCI

  # Remote automation
  # user_data = file("${path.module}/automation/${var.vms[count.index].automation_script}")
}
