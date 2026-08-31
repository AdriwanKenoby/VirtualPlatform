.PHONY: all init plan apply conf

init:
	terraform -chdir=./terraform init
plan:
	terraform -chdir=./terraform plan -out lab.tfplan
apply:
	terraform -chdir=./terraform apply lab.tfplan
conf: 
	ansible-playbook -i inventory.yaml ansible/control-plane.yaml
