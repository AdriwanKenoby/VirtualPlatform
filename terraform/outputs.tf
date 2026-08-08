output "vms" {
  description = "Informations sur les VMs créées"
  value = {
    for i, vm in libvirt_domain.vms  : vm.name => {
      id = vm.id
      ip = var.vms[vm.name].ip
    }
  }
}
