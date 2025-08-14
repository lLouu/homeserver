# Proxmox Provider
# ---
# Initial Provider Configuration for Proxmox

terraform {
  required_version = ">= 0.13.0"

  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.proxmox.api.url
  pm_api_token_id = var.proxmox.api.token_id
  pm_api_token_secret = var.proxmox.api.token_secret
  pm_tls_insecure = true
}