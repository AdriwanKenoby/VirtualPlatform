variable "vm_name" {
  description = "Nom de la VM"
  type        = string
  default     = "vm-k8s-01"
}

variable "base_image_path" {
  description = "Chemin vers l'image cloud de base"
  type        = string
  default     = "/var/lib/libvirt/images/base/ubuntu-24.04-server-cloudimg-amd64.img"
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
  type        = object({
    name = string
    address = string
    netmask = string
  })

  default     = {
    name = "virbr01"
    address = "192.168.100.1"
    netmask = "255.255.255.0"
  }
}

variable "pool_name" {
  description = "Nom du pool de stockage libvirt"
  type        = string
  default     = "VMs"
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
    "k8s-control-plane-1" = { memory = 1024 * 4, vcpu = 2, disk = 32, ip = "192.168.100.100" },
    "k8s-worker01" = { memory = 1024 * 4, vcpu = 2, disk = 32, ip = "192.168.100.101" },
    "k8s-worker02" = { memory = 1024 * 4, vcpu = 2, disk = 32, ip = "192.168.100.102" }
  }
}