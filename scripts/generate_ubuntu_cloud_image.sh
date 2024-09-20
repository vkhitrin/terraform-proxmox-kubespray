#!/usr/bin/env bash

set -eo pipefail

UBUNTU_CLOUD_IMAGE="${UBUNTU_CLOUD_IMAGE}"
REMOTE_TEMPORARY_DIRECTORY="/tmp"
REMOTE_IMAGE_PATH="$REMOTE_TEMPORARY_DIRECTORY/$(basename ${UBUNTU_CLOUD_IMAGE})"
PROXMOX_VM_TEMPLATE_MEMORY_MB=2048
PROXMOX_VM_TEMPLATE_NAME="cloud-ubuntu-22.04-template"
PROXMOX_VM_CLOUD_INIT_FORCE_PACKAGE_UPDATE=0 # false
PROXMOX_VM_TEMPLATE_ID=${PROXMOX_VM_TEMPLATE_ID}
PROXMOX_VM_CLOUD_INIT_USER="${PROXMOX_VM_CLOUD_INIT_USER}"
PROXMOX_VM_CLOUD_INIT_PASSWORD="${PROXMOX_VM_CLOUD_INIT_PASSWORD}"
EXTRA_SNIPPET="""
#cloud-config
runcmd:
    - apt update
    - apt install -y qemu-guest-agent
    - systemctl start qemu-guest-agent
    - reboot"""

# Function which prints an error message and then returns exit code 1
function error_exit {
	echo "$1" >&2
	exit "${2:-1}"
}

# Print padded title based on terminal column size
function print_padded_title {
	termwidth="$(tput cols)"
	padding="$(printf '%0.1s' ={1..500})"
	printf '%*.*s %s %*.*s\n' 0 "$(((termwidth - 2 - ${#1}) / 2))" "$padding" "$1" 0 "$(((termwidth - 1 - ${#1}) / 2))" "$padding"
}

[ -n "$PROXMOX_VM_TEMPLATE_ID" ] || error_exit "Variable PROXMOX_VM_TEMPLATE_ID is undefined"
[ -n "$PROXMOX_VM_CLOUD_INIT_USER" ] || error_exit "Variable PROXMOX_VM_CLOUD_INIT_USER is undefined"
[ -n "$PROXMOX_VM_CLOUD_INIT_PASSWORD" ] || error_exit "Variable PROXMOX_VM_CLOUD_INIT_PASSWORD is undefined"
[ -n "$PROXMOX_HOST" ] || error_exit "Varaible PROXMOX_HOST is undefined"
[ -n "$PROXMOX_USER" ] || error_exit "Varaible PROXMOX_USER is undefined"
[ -n "$PROXMOX_STORAGE_NAME" ] || error_exit "Varaible PROXMOX_STORAGE_NAME is undefined"
[ -n "$REMOTE_SNIPPETS_DIRECTORY" ] || print_padded_title "WARNING: \$REMOTE_SNIPPETS_DIRECTORY is undefined, snippets are useful to extend cloud-init and required for Terraform 'proxmox' provider to recieve response from qemu-guest-agent"

print_padded_title "Check if '$PROXMOX_HOST' Is A Valid Proxmox Host"
ssh $PROXMOX_USER@$PROXMOX_HOST "test -f /etc/pve/datacenter.cfg" || error_exit "Not a valid Proxmox host"

print_padded_title "Check if VM With ID '$PROXMOX_VM_TEMPLATE_ID' Exists"
ssh $PROXMOX_USER@$PROXMOX_HOST "qm wait ${PROXMOX_VM_TEMPLATE_ID} -timeout 1" && error_exit "VM ID ${PROXMOX_VM_TEMPLATE_ID} exists, please delete it"

print_padded_title "Downloading Image '$UBUNTU_CLOUD_IMAGE'"
ssh $PROXMOX_USER@$PROXMOX_HOST "test -f $REMOTE_IMAGE_PATH || wget -qO $REMOTE_IMAGE_PATH $UBUNTU_CLOUD_IMAGE"

print_padded_title "Create Temporary VM '$PROXMOX_VM_TEMPLATE_NAME'"
ssh $PROXMOX_USER@$PROXMOX_HOST "qm create $PROXMOX_VM_TEMPLATE_ID --name $PROXMOX_VM_TEMPLATE_NAME -machine q35 --memory $PROXMOX_VM_TEMPLATE_MEMORY_MB --scsihw virtio-scsi-pci"

print_padded_title "Import Cloud Image To '$PROXMOX_VM_TEMPLATE_NAME'"
ssh $PROXMOX_USER@$PROXMOX_HOST "qm set $PROXMOX_VM_TEMPLATE_ID --virtio0 $PROXMOX_STORAGE_NAME:0,import-from=$REMOTE_IMAGE_PATH"

print_padded_title "Configure Boot For '$PROXMOX_VM_TEMPLATE_NAME'"
ssh $PROXMOX_USER@$PROXMOX_HOST "qm set $PROXMOX_VM_TEMPLATE_ID --boot order=virtio0"

print_padded_title "Attach cloud-init CD-ROM device '$PROXMOX_VM_TEMPLATE_NAME'"
ssh $PROXMOX_USER@$PROXMOX_HOST "qm set $PROXMOX_VM_TEMPLATE_ID --scsi0 $PROXMOX_STORAGE_NAME:cloudinit"

print_padded_title "Set Console/Graphical Devices '$PROXMOX_VM_TEMPLATE_NAME'"
ssh $PROXMOX_USER@$PROXMOX_HOST "qm set $PROXMOX_VM_TEMPLATE_ID --serial0 socket --vga serial0"

print_padded_title "Update cloud-init Information '$PROXMOX_VM_CLOUD_INIT_USER=$' '$PROXMOX_VM_TEMPLATE_NAME'"
ssh $PROXMOX_USER@$PROXMOX_HOST "qm set $PROXMOX_VM_TEMPLATE_ID -ciuser $PROXMOX_VM_CLOUD_INIT_USER -cipassword $PROXMOX_VM_CLOUD_INIT_PASSWORD -ciupgrade $PROXMOX_VM_CLOUD_INIT_FORCE_PACKAGE_UPDATE"
# Conditional if snippets directory is provided
if [ -z "$REMOTE_TEMPORARY_DIRECTORY" ]; then
	print_padded_title "Create Snippet And Inject To Image"
	ssh $PROXMOX_USER@$PROXMOX_HOST "cat > $REMOTE_SNIPPETS_DIRECTORY/qemu-guest-agent.yaml<<EOF $EXTRA_SNIPPET
EOF"
	ssh $PROXMOX_USER@$PROXMOX_HOST "qm set $PROXMOX_VM_TEMPLATE_ID --cicustom vendor=$PROXMOX_STORAGE_NAME:snippets/qemu-guest-agent.yaml"
fi

print_padded_title "Convert To Template '$PROXMOX_VM_TEMPLATE_NAME'"
ssh $PROXMOX_USER@$PROXMOX_HOST "qm template $PROXMOX_VM_TEMPLATE_ID"
