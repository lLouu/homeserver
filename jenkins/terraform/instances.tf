# Terraform Proxmox Homeserver Mainframe V0.1

resource "proxmox_vm_qemu" "instances" {
  count = length(var.vms)

  # General
  target_node = var.proxmox.node
  name        = var.vms[count.index].name
  vmid        = var.vms[count.index].id
  clone       = "${var.vms[count.index].os}-ansible-ready"
  full_clone  = true
  os_type     = "cloud-init"

  # Ressources
  memory      = var.vms[count.index].ram
  cpu {
    sockets     = var.vms[count.index].sockets
    cores       = var.vms[count.index].cores
  }

  # Behaviour
  boot                = "order=scsi0"
  scsihw              = "virtio-scsi-pci"
  agent               = 1
  skip_ipv6           = true
  start_at_node_boot  = true
  vm_state            = "running"

  # Storage
  disk {
    type    = "cloudinit"
    storage = "local"
    slot    = "scsi9"
  }

  dynamic "disk" {
    for_each = var.vms[count.index].disks

    content {
      type       = "disk"
      emulatessd = disk.value.is_ssd
      size       = disk.value.size
      storage    = disk.value.storage
      slot       = disk.value.slot
    }
  }

  # Network
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr${var.vms[count.index].network}"
  }
  ipconfig0 = "ip=10.1.${var.vms[count.index].network}.${var.vms[count.index].end_ip}/24,gw=10.1.${var.vms[count.index].network}.1"

  # TODO : PCI
}
