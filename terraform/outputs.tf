# Data source pour récupérer les IPs via DHCP leases
data "libvirt_domain_interface_addresses" "ips_addresses" {
  for_each = var.vms
  domain = libvirt_domain.vms["${each.key}"].name
  source = "lease"  # Utilise le serveur DHCP de libvirt

  depends_on = [libvirt_domain.vms]
}

output "vms" {
  description = "Informations sur les VMs créées"
  value = data.libvirt_domain_interface_addresses.ips_addresses
}
