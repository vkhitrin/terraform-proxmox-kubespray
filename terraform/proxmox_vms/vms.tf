resource "proxmox_virtual_environment_pool" "vm_pool" {
  pool_id = var.vm_tags[0]
  comment = "Created by vkhitrin/terraform-proxmox-kubespray"
}

resource "proxmox_virtual_environment_vm" "vm" {
  count     = var.vm_count
  name      = "${var.vm_prefix}-${count.index + 1}"
  tags      = var.vm_tags
  node_name = var.proxmox_node
  pool_id   = var.vm_tags[0]

  clone {
    vm_id = var.proxmox_vm_template_id
  }
  agent {
    enabled = true
  }
  machine = "q35"
  cpu {
    type    = "host"
    sockets = 1
    cores   = var.vm_cores
  }
  memory {
    dedicated = var.vm_memory
  }
  boot_order = ["virtio0"]
  disk {
    datastore_id = var.proxmox_datastore
    interface    = "virtio0"
    size         = var.vm_disk_size_gb
  }
  initialization {
    interface = "scsi0"
    ip_config {
      ipv4 {
        address = "192.168.14.${count.index + var.ip_offset_start}/24"
        gateway = "192.168.14.1"
      }
    }
    user_account {
      keys = [
        var.vm_ssh_public_key
      ]
    }
  }
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }
  operating_system {
    type = "l26"
  }
  depends_on = [proxmox_virtual_environment_pool.vm_pool]
}
