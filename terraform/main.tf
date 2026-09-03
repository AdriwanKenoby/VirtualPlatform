# ============================================================
# Provider libvirt 0.9.x - Configuration complète
# ============================================================

resource "libvirt_network" "virbr" {
  name      = var.network_info.name
  autostart = true
  bridge   = {
    name = var.network_info.name
  }  
  
  forward = {
    mode = "bridge"
  }
}

resource "libvirt_pool" "pool_storage" {
  name = var.pool_storage_info.name
  type = "dir"
  target = {
    path = var.pool_storage_info.path
    permissions = {
      mode = "0711"
    }
  }
}

# 1) Volume de base (image cloud Ubuntu - copie locale)
resource "libvirt_volume" "base" {
  name   = var.base_image.name
  pool   = libvirt_pool.pool_storage.name

  target = {
    format = { type = "qcow2" }
  }

  create = {
    content = {
      url = "${path.module}/${var.base_image.path}"
    }
  }
}

# 2) Volume OS de la VM (overlay CoW sur l'image de base)
resource "libvirt_volume" "os_disk" {
  for_each = var.vms
  name     = "${each.key}.qcow2"
  pool     = libvirt_pool.pool_storage.name
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
    public_key = trimspace(file(pathexpand(var.ssh_key.public_key_path)))
  })

  # meta_data est OBLIGATOIRE en 0.9.x
  meta_data = yamlencode({
    instance-id    = "${each.key}"
    local-hostname = "${each.key}"
  })

  network_config = templatefile("${path.module}/cloud-init/network-config.yaml", {
    gateway = var.network_info.address
  })
}

# 4) Volume pour l'ISO Cloud-Init (upload dans le pool)
resource "libvirt_volume" "cloudinit" {
  for_each = var.vms
  name  = "${each.key}-cloudinit.iso"
  pool = libvirt_pool.pool_storage.name

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
    firmware = "efi"
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
            pool   = libvirt_pool.pool_storage.name
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
            pool   = libvirt_pool.pool_storage.name
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
        wait_for_ip = {
          source = "agent"
          timeout = 60
        }
      }
    ]
    
    channels = [
      {
        source = {
          unix = {
            mode = "bind"
          }
        }
        target = {
          virt_io = {
            name  = "org.qemu.guest_agent.0"
          }
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

# Data source pour récupérer les IPs via DHCP leases
data "libvirt_domain_interface_addresses" "ips_addresses" {
  for_each = var.vms
  domain = libvirt_domain.vms["${each.key}"].name
  source = "agent"  # Utilise le serveur DHCP de libvirt

  depends_on = [libvirt_domain.vms]
}

##--------------- Ansible -------------------

resource "ansible_group" "groups" {
  for_each = toset(flatten([for vm in var.vms : vm.ansible_groups]))
  name = each.key
}

resource "ansible_host" "k8s" {
  for_each = var.vms
  name     = each.key
  groups   = each.value.ansible_groups
  variables = {
    ansible_host                 = data.libvirt_domain_interface_addresses.ips_addresses["${each.key}"].interfaces[1].addrs[0].addr
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = pathexpand(var.ssh_key.private_key_path)
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
  }
}
