variable "base_image" {
  description = "Chemin vers l'image cloud de base"
  type        = map(string)
  
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
    name = "virbr01"
    address = "192.168.100.0/24"
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
    ip     = string
  }))
  
  default = {
    "control-plane-1" = { memory = 1024 * 4, vcpu = 2, disk = 32, ip = "192.168.100.100/24" }
    "worker01" = { memory = 1024 * 4, vcpu = 2, disk = 32, ip = "192.168.100.101/24" }
    "worker02" = { memory = 1024 * 4, vcpu = 2, disk = 32, ip = "192.168.100.102/24"}
  }
}
