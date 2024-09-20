SHELL   := /usr/bin/env bash
.DEFAULT: help

# Proxmox variables
UBUNTU_CLOUD_IMAGE                            ?= https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img 
PROXMOX_VM_TEMPLATE_ID             ?= 9000
PROXMOX_VM_CLOUD_INIT_USER         ?= ubuntu
PROXMOX_VM_CLOUD_INIT_PASSWORD     ?= 12345678
PROXMOX_VM_COUNT                   ?= 3
PROXMOX_DATASTORE                  ?= workloads
PROXMOX_VM_CORES                   ?= 26
PROXMOX_VM_MEMORY                  ?= 65536
PROXMOX_VM_DISK_SIZE_GB            ?= 200

# Kubernetes variables
KUBECONFIG                         ?= ./ansible/artifacts/${PROXMOX_VM_PREFIX}.conf

.PHONY: help
help:
	@fgrep -h "##" $(MAKEFILE_LIST) | sed -e 's/\(\:.*\#\#\)/\:\ /' | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

.PHONY: VAR
var-%: VAR
	@if [ -z '${${*}}' ]; then echo 'Environment variable $* not set.' && exit 1; fi

.PHONY: check-if-running-venv
check-if-running-venv: #Hacky way to check if we are running from virtual evnironment.
	@if [ ! -d "${VIRTUAL_ENV}" ]; then echo "Probably not running in a Python Virtual Environment, please use one." && exit 1; fi

.PHONY: terraform-init
terraform-init: var-PROXMOX_VM_PREFIX #Initialize terraform if required
	if [ ! -d terraform/proxmox_vms/.${PROXMOX_VM_PREFIX}.terraform ]; then tofu -chdir=terraform/proxmox_vms init -backend-config="path=.${PROXMOX_VM_PREFIX}.terraform"; fi

.PHONY: ansible-prepare-requirements
ansible-prepare-requirements: check-if-running-venv ##Prepare ansible requirements
	@${VIRTUAL_ENV}/bin/pip3 install -qqq --upgrade pip
	@${VIRTUAL_ENV}/bin/pip3 install -qqqr ansible/requirements.txt
	@${VIRTUAL_ENV}/bin/ansible-galaxy collection install -r ansible/requirements.yaml

.PHONY: generate-ubuntu-cloud-image
generate-ubuntu-cloud-image: var-PROXMOX_VM_TEMPLATE_ID var-PROXMOX_VM_CLOUD_INIT_USER var-PROXMOX_VM_CLOUD_INIT_PASSWORD var-PROXMOX_HOST var-PROXMOX_USER var-PROXMOX_STORAGE_NAME var-UBUNTU_CLOUD_IMAGE ##Generates Ubuntu cloud-init compatible image 
	@./scripts/generate_ubuntu_cloud_image.sh

# NOTE: (vadimk) consider migrationg from `-var` to `TF_VAR_` convention
.PHONY: terraform-apply-proxmox-vms
terraform-apply-proxmox-vms: var-PROXMOX_HOST var-PROXMOX_API_TOKEN var-PROXMOX_VM_TEMPLATE_ID var-PROXMOX_VM_IP_OFFSET_START var-PROXMOX_NODE var-PROXMOX_VM_PREFIX var-PROXMOX_VM_COUNT var-PROXMOX_DATASTORE var-PROXMOX_VM_CORES var-PROXMOX_VM_MEMORY var-PROXMOX_VM_DISK_SIZE_GB terraform-init ##Create Proxmox virtual machines
	@tofu -chdir=terraform/proxmox_vms apply \
	-var proxmox_api_url="https://${PROXMOX_HOST}:8006" \
	-var proxmox_api_token="${PROXMOX_API_TOKEN}" \
	-var proxmox_vm_template_id="${PROXMOX_VM_TEMPLATE_ID}" \
	-var proxmox_datastore="${PROXMOX_DATASTORE}" \
	-var vm_count="${PROXMOX_VM_COUNT}" \
	-var vm_cores="${PROXMOX_VM_CORES}" \
	-var vm_memory="${PROXMOX_VM_MEMORY}" \
	-var vm_disk_size_gb="${PROXMOX_VM_DISK_SIZE_GB}" \
	-var ip_offset_start="${PROXMOX_VM_IP_OFFSET_START}" \
	-var proxmox_node="${PROXMOX_NODE}" \
	-var vm_prefix="${PROXMOX_VM_PREFIX}" \
	-var vm_tags="[\"${PROXMOX_VM_PREFIX}\"]" \
	-auto-approve

.PHONY: terraform-destroy-proxmox-vms
terraform-destroy-proxmox-vms: var-PROXMOX_HOST var-PROXMOX_API_TOKEN var-PROXMOX_VM_TEMPLATE_ID var-PROXMOX_VM_IP_OFFSET_START var-PROXMOX_NODE var-PROXMOX_VM_PREFIX var-PROXMOX_VM_COUNT var-PROXMOX_DATASTORE var-PROXMOX_VM_CORES var-PROXMOX_VM_MEMORY var-PROXMOX_VM_DISK_SIZE_GB terraform-init ##Create Proxmox virtual machines
	@tofu -chdir=terraform/proxmox_vms destroy \
	-var proxmox_api_url="https://${PROXMOX_HOST}:8006" \
	-var proxmox_api_token="${PROXMOX_API_TOKEN}" \
	-var proxmox_vm_template_id="${PROXMOX_VM_TEMPLATE_ID}" \
	-var proxmox_datastore="${PROXMOX_DATASTORE}" \
	-var vm_count="${PROXMOX_VM_COUNT}" \
	-var vm_cores="${PROXMOX_VM_CORES}" \
	-var vm_memory="${PROXMOX_VM_MEMORY}" \
	-var vm_disk_size_gb="${PROXMOX_VM_DISK_SIZE_GB}" \
	-var ip_offset_start="${PROXMOX_VM_IP_OFFSET_START}" \
	-var proxmox_node="${PROXMOX_NODE}" \
	-var vm_prefix="${PROXMOX_VM_PREFIX}" \
	-var vm_tags="[\"${PROXMOX_VM_PREFIX}\"]" \
	-var vm_ssh_public_key="doesnt_matter_when_deleting" \
	-auto-approve

.PHONY: ansible-show-inventory 
ansible-show-inventory: check-if-running-venv var-PROXMOX_HOST var-PROXMOX_API_TOKEN var-PROXMOX_VM_PREFIX ##View ansible inventory
	@${VIRTUAL_ENV}/bin/ansible-inventory -i ansible/inventory.proxmox.yaml --graph

.PHONY: ansible-kubespray-bootstrap
ansible-kubespray-bootstrap: check-if-running-venv var-PROXMOX_HOST var-PROXMOX_API_TOKEN var-PROXMOX_VM_PREFIX ##Bootstrap Kubernetes cluster using kubespray
	ANSIBLE_CONFIG="./ansible/ansible.cfg" ${VIRTUAL_ENV}/bin/ansible-playbook ansible/bootstrap-cluster.yaml
