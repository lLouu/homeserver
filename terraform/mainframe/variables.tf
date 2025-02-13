# Proxmox configs (to be defined on script)
variable "proxmox" {
  type = list(object({
    node = string
    api  = list(object({
      url           = bool
      token_id      = number
      token_secret  = string
    }))
  }))
}


# VMs
variable "vms" {
  type = list(object({
    name     = string
    id       = number
    ram      = number
    sockets  = number
    cores    = number
    iso      = string
    disks    = list(object({
      is_ssd   = bool
      size     = number
      storage  = string
    }))
    networks = list(string) 
    automation_script = string
  }))
}


# Inets
variable "network_bridge" {
  type = list(string)
  default = ["vmbr1", "vmbr2", "vmbr3", "vmbr4"]
}
