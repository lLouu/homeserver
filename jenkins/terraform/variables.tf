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
    os       = string
    disks    = list(object({
      is_ssd   = bool
      size     = string
      storage  = string
      slot     = string
    }))
    network = number
    end_ip   = number
  }))
}

variable "pfsense" {
  type = object({
    ram      = number
    sockets  = number
    cores    = number
    disks    = list(object({
      is_ssd   = bool
      size     = string
      storage  = string
      slot     = string
    }))
  })
}

variable "networks" {
  type = list(number)
}
