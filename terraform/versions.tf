terraform {
  required_version = ">= 1.11.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.0"  # Version 2025+ avec breaking changes
    }

    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3"
    }
  }
}

provider "libvirt" {
  # Connexion au démon libvirt système (pas session utilisateur)
  uri = "qemu:///system"
  alias = "qemu_system"
}
