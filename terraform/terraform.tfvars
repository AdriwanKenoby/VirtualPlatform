base_image = {
  name = "ubuntu-24.04-base.qcow2"
  path = "ubuntu-24.04-server-cloudimg-amd64.img"
}

ssh_key = {
  public_key_path  = "~/.ssh/id_ed25519.pub"
  private_key_path = "~/.ssh/id_ed25519"
}

network_info = {
  name    = "br0"
  address = "192.168.1.198/24"
}

pool_storage_info = {
  name = "VMs"
  path = "/var/lib/libvirt/images"
}

vms = {
  "control-plane-1" = { memory = 1024 * 4, vcpu = 2, disk = 32, ansible_groups = ["controls"] }
  "worker01" = { memory = 1024 * 4, vcpu = 2, disk = 32, ansible_groups = ["workers"] }
  "worker02" = { memory = 1024 * 4, vcpu = 2, disk = 32, ansible_groups = ["workers"] }
}
