# Terraform Proxmox Homeserver Mainframe V0.1

resource "proxmox_vm_qemu" "instances" {
  count = length(var.vms)

  # General
  target_node = var.proxmox.node
  name        = var.vms[count.index].name
  vmid        = var.vms[count.index].id
  clone       = "${var.vms[count.index].os}-ansible-ready"

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
  network {
    id     = var.vms[count.index].network
    model  = "virtio"
    bridge = "vmbr${var.vms[count.index].network}"
  }
  ipconfig0 = "10.1.${var.vms[count.index].network}.${var.vms[count.index].end_ip}/24,gw=10.1.${var.vms[count.index].network}.1"

  # TODO : PCI
}
