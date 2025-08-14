resource "proxmox_vm_qemu" "network_bridges" {
  count = length(var.network_bridge)

  name        = "net-${var.network_bridge[count.index]}"
  target_node = var.proxmox.node
  memory      = 256
  sockets     = 1
  cores       = 1
  vmid        = 200 + count.index

  network {
    model  = "virtio"
    id     = var.network_bridge[count.index].id
    bridge = var.network_bridge[count.index].bridge
  }
}
