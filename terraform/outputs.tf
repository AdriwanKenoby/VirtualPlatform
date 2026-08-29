output "vms" {
  description = "Informations sur les VMs créées"
  value = data.libvirt_domain_interface_addresses.ips_addresses
}
