# ============================================================
# Provider libvirt 0.9.x - Configuration complète
# ============================================================

resource "libvirt_network" "virbr" {
  name      = var.network_info.name
  autostart = true
  bridge   = {
    name = var.network_info.name
  }

  ips = [{
    address = var.network_info.address
    netmask = var.network_info.netmask
    dhcp    =  {
      enabled = false
    }
    family  = "ipv4"
  }]
}



# 1) Volume de base (image cloud Ubuntu - copie locale)
resource "libvirt_volume" "base" {
  name   = "ubuntu-24.04-base.qcow2"
  pool   = var.pool_name

  target = {
    format = { type = "qcow2" }
  }

  create = {
    content = {
      url = var.base_image_path
    }
  }
}

# 2) Volume OS de la VM (overlay CoW sur l'image de base)
resource "libvirt_volume" "os_disk" {
  for_each = var.vms
  name     = "${each.key}.qcow2"
  pool     = var.pool_name
  capacity = "${each.value.disk}" * 1024 * 1024 * 1024  # Conversion en bytes

  target = {
    format = { type = "qcow2" }
  }

  # Utilise l'image de base comme backing store (Copy-on-Write)
  backing_store = {
    path   = libvirt_volume.base.path
    format = { type = "qcow2" }
  }
}

# 3) Cloud-Init : génération de l'ISO de configuration
resource "libvirt_cloudinit_disk" "init" {
  for_each = var.vms
  name  = "${each.key}-cloudinit"

  user_data = templatefile("${path.module}/cloud-init/user-data.yaml", {
    hostname   = "${each.key}"
    public_key = file(pathexpand(var.ssh_public_key_path))
  })

  # meta_data est OBLIGATOIRE en 0.9.x
  meta_data = yamlencode({
    instance-id    = "${each.key}"
    local-hostname = "${each.key}"
  })

  network_config = templatefile("${path.module}/cloud-init/network-config.yaml", {
    ip = var.vms["${each.key}"].ip
    gateway = var.network_info.address
  })
}

# 4) Volume pour l'ISO Cloud-Init (upload dans le pool)
resource "libvirt_volume" "cloudinit" {
  for_each = var.vms
  name  = "${each.key}-cloudinit.iso"
  pool = var.pool_name

  create = {
    content = {
      url = libvirt_cloudinit_disk.init[each.key].path
    }
  }
}

# 5) Domaine (VM) - Syntaxe 0.9.x avec bloc devices
resource "libvirt_domain" "vms" {
  for_each    = var.vms
  name        = "${each.key}"
  type        = "kvm"                     # Type obligatoire en 0.9.x
  memory      = each.value.memory
  memory_unit = "MiB"                # OBLIGATOIRE : l'unité par défaut du provider est KiB
  vcpu        = each.value.vcpu

  # CPU host-passthrough : expose tous les flags CPU de l'hôte (AES-NI,
  # SSE4.x, AVX...). Sans ça, libvirt utilise mode=custom model=qemu64
  # qui n'expose que des instructions x86_64 minimales, et les kernels
  # récents (RHEL/AlmaLinux 10, Fedora ≥ 40) bloquent au chargement
  # des modules crypto.
  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_machine = "q35"
    firmware     = "efi"
    # Désactive Secure Boot : libvirt 10+ enrôle par défaut les clés
    # Microsoft (OVMF_CODE_4M.ms.fd) qui rejettent les kernels non
    # signés MS. Les images cloud Linux démarrent puis se bloquent à
    # /init faute de modules virtio chargés.
    # Ordre alphabétique des features OBLIGATOIRE : le provider 0.9.x
    # retourne les features triées et compare strictement avec ce
    # qu'on lui donne (sinon "Provider produced inconsistent result").
    firmware_info = {
      features = [
        { enabled = "no", name = "enrolled-keys" },
        { enabled = "no", name = "secure-boot" },
      ]
    }
  }

  features = {
    acpi = true
  }

  # Bloc devices : structure obligatoire en 0.9.x
  devices = {
    # Disque OS
    disks = [
      {
        # Driver explicite obligatoire pour qcow2 !
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          volume = {
            pool   = var.pool_name
            volume = libvirt_volume.os_disk[each.key].name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      # Disque Cloud-Init (CDROM)
      {
        device = "cdrom"
        driver = {
          name = "qemu"
          type = "raw"
        }
        source = {
          volume = {
            pool   = var.pool_name
            volume = libvirt_volume.cloudinit["${each.key}"].name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

    # Interface réseau
    interfaces = [
      {
        type  = "network"
        model = { type = "virtio" }
        source = {
          network = { network = libvirt_network.virbr.name }
        }
      }
    ]

    # Console série (indispensable pour debug)
    serials = [
      {
        type = "pty"
        target = {
          port = 0
          type = "isa-serial"
        }
      }
    ]

    # Support graphique (optionnel, pour virt-manager)
    graphics = [
      {
        spice = {
          autoport = "yes"
        }
      }
    ]
  }

  running = true
}

##--------------- Ansible -------------------

resource "ansible_group" "k8s_control_plane" {
  name = "control-plane"
}

resource "ansible_group" "k8s_workers" {
  name = "workers"
}

resource "ansible_host" "k8s-control-plane-1" {
  name     = "k8s-control-plane-1"
  groups   = [ansible_group.k8s_control_plane.name]
  variables = {
    ansible_host                 = var.vms["k8s-control-plane-1"].ip
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = pathexpand(var.ssh_private_key_path)
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
  }
}

resource "ansible_host" "k8s-worker01" {
  name     = "k8s-worker01"
  groups   = [ansible_group.k8s_workers.name]
  variables = {
    ansible_host                 = var.vms["k8s-worker01"].ip
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = pathexpand(var.ssh_private_key_path)
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
  }
}

resource "ansible_host" "k8s-worker02" {
  name     = "k8s-worker02"
  groups   = [ansible_group.k8s_workers.name]
  variables = {
    ansible_host                 = var.vms["k8s-worker02"].ip
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = pathexpand(var.ssh_private_key_path)
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
  }
}

