variable "proxmox_api_tls_insecure" {
  description = "Ignore TLS when authenticating with Proxmox API"
  type        = bool
  default     = true
}

# TODO: (vadimk): rewrite to be a regex check instead of substring check
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  validation {
    condition     = substr(var.proxmox_api_url, 0, 8) == "https://"
    error_message = "The API url must be a valid HTTPS URL"
  }
}

variable "proxmox_api_token" {
  description = "Proxmox API token, formatted `<Uername@Domain>!<Token Name>=<Token Secret>`"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^\\w+@\\w+!\\w+\\=\\w{8}-\\w{4}-\\w{4}-\\w{4}-\\w{12}$", var.proxmox_api_token))
    error_message = "The API token must be properly formatted `<Uername@Domain>!<Token Name>=<Token Secret>`"
  }
}

variable "proxmox_node" {
  description = "Proxmox node to create VMs on"
  type        = string
}

variable "proxmox_vm_template_id" {
  description = "VM template ID"
  type        = number
}

variable "proxmox_datastore" {
  description = "Datastore name"
  default     = "workloads"
  type        = string
}

variable "vm_count" {
  description = "VM count"
  default     = 3
  type        = number
}

variable "vm_prefix" {
  description = "VM prefix"
  type        = string
}

variable "vm_cores" {
  description = "VM count"
  default     = 24
  type        = number
}

variable "vm_memory" {
  description = "VM count"
  default     = 65536
  type        = number
}

variable "vm_disk_size_gb" {
  description = "VM disk size"
  default     = 200
  type        = number
}

variable "vm_tags" {
  description = "List of tags attached to VM, will be used for Ansible inventory"
  type        = list(string)
}

variable "ip_offset_start" {
  description = "IP offset"
  type        = number
}

variable "vm_ssh_public_key" {
  description = "OpenSSH format of public key to inject to VM"
  type        = string
}
