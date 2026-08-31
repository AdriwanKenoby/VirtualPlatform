.PHONY: all init plan apply conf

init:
	terraform -chdir=./terraform init
plan:
	terraform -chdir=./terraform plan -out lab.tfplan
apply:
	terraform -chdir=./terraform apply lab.tfplan
control-plane: 
	ansible-playbook -i inventory.yaml ansible/control-plane.yaml
workers:
	ansible-playbook -i inventory.yaml ansible/worker.yaml