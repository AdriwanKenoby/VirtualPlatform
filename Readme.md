# K8s Virtual Platform
## Prerequisite

### Clone repository
If ssh key is set
```
git clone git@github.com:AdriwanKenoby/VirtualPlatform.git
```
or with https protocol
```
git clone https://github.com/AdriwanKenoby/VirtualPlatform.git
```
### Get an ubuntu 24.04 cloud image
Download ubuntu 24.04 cloud image in the project directory

```
cd VirtualPlatform
sudo wget -O ./ubuntu-24.04-server-cloudimg-amd64.img https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```
### Create bridged interface with your network 
Create bridge for KVM network with nmcli
For example, supposed that your physical interface is enp4s0 :

```
nmcli con show --active
nmcli connection add ifname br0 type bridge con-name br0
nmcli connection add type bridge-slave ifname enp4s0 master br0
nmcli co down <wired-connection>
nmcli co up br0
```
In this way you can use dhcp provided by your router (box)

### Install dependencies

Install [terraform](https://developer.hashicorp.com/terraform/install)

Use the package manager [pip](https://pip.pypa.io/en/stable/) to install [ansible](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html) in a virtual environment.

Supposed the directory of your python virtual environment is named venv
```
source .venv/bin/activate
```

### Install needed ansible collection
```
ansible-galaxy collection install cloud.terraform
```

### Configure ansible.cfg to use terraform plugin inventory

Edit file ansible.cfg add path to terraform inventory plugin in ```inventory_plugins``` parameter and cloud.terraform.terraform_provider to ```enable_plugins``` parameter

## Usage

### Create VMs provided by terraform.tfvars (default values are quit excessives 64Go RAM needed )
```
cd terraform
terraform init
terraform plan -out lab.tfplan
terraform apply lab.tfplan
```

### Run ansible playbook on provided VMs
```
cd ../ansible
ansible-playbook -i inventory.yaml control-plane.yaml
```