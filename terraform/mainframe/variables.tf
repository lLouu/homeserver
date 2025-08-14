# Proxmox configs (to be defined on script)
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
      size     = string
      storage  = string
      slot     = string
    }))
    networks = list(object({
      id = number
      bridge = string
    })) 
    automation_script = string
  }))
}


# Inets
variable "network_bridge" {
  type = list(object({
      id = number
      bridge = string
  }))
}
