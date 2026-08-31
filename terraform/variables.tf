variable "base_image" {
  description = "Chemin vers l'image cloud de base"
  type        = object({
    name = string
    path = string
  })
  
  default     = {
    name = "ubuntu-24.04-base.qcow2",
    path = "ubuntu-24.04-server-cloudimg-amd64.img"
  }
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé SSH publique"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Chemin de la clé privée SSH"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "network_info" {
  description = "Réseau libvirt"
  type = object({
    name = string
    address = string
  })

  default     = {
    name = "br0"
    address = "192.168.1.198/24"
  }
}

variable "pool_storage_info" {
  description = "Nom du pool de stockage libvirt"
  type = object({
    name = string
    path = string 
  })

  default     = {
    name = "VMs"
    path = "/var/lib/libvirt/images"
  }
}

variable "vms" {
  description = "Map des VMs à créer"
  type = map(object({
    memory = number
    vcpu   = number
    disk   = number
  }))

  validation {
    condition = alltrue(
      [for vm in keys(var.vms): can(regex("worker", vm)) || can(regex("control", vm))]
    )
    error_message = "The name of the VM must contains either worker or control"
  }

  default = {
    "control-plane-1" = { memory = 1024 * 4, vcpu = 2, disk = 32 }
    "worker01" = { memory = 1024 * 4, vcpu = 2, disk = 32 }
    "worker02" = { memory = 1024 * 4, vcpu = 2, disk = 32 }
  }
}
