.PHONY: init plan apply install refresh destroy

init:
	terraform -chdir=./terraform init
plan:
	terraform -chdir=./terraform plan -out lab.tfplan
apply:
	terraform -chdir=./terraform apply lab.tfplan
install: 
	ansible-playbook -i inventory.yml ansible/install.yml
refresh:
	terraform -chdir=./terraform refresh
destroy:
	terraform -chdir=./terraform destroy