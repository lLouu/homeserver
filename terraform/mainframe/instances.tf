# Terraform Proxmox Homeserver Mainframe V0.1

resource "proxmox_vm_qemu" "instances" {
  count = length(var.vms)

  # General
  target_node = var.proxmox_node
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
  }
  dynamic "disk" {
    for_each = var.vms[count.index].disks
    iterator = disk

    content {
      type       = "scsi"
      emulatessd = disk.value.is_ssd
      size       = disk.value.size
      storage    = disk.value.storage
    }
  }

  # Network
  dynamic "network" {
    for_each =  var.vms[count.index].networks
    iterator = inet.value

    content {
      model  = "virtio"
      bridge = inet.value
    }
  }

  # TODO : PCI

  # Remote automation
  user_data = file("${path.module}/automation/${var.vms[count.index].automation_script}")
}
