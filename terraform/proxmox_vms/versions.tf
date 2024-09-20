terraform {
  backend "local" {}
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.57.1"
    }
  }
}
provider "proxmox" {
  insecure  = var.proxmox_api_tls_insecure
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  ssh {
    agent    = "true"
    username = split("@", var.proxmox_api_token)[0]
  }
}
