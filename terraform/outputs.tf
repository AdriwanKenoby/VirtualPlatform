output "vms_ips" {
  description = "VM ips associated"
  value = [
    for k, vm in var.vms :
    {
      name = k
      ip = data.libvirt_domain_interface_addresses.ips_addresses["${k}"].interfaces[1].addrs[0].addr
      ssh_command = "ssh ubuntu@${data.libvirt_domain_interface_addresses.ips_addresses["${k}"].interfaces[1].addrs[0].addr}"
    }
  ]
}
