# Proxmox Kubernetes Environment

> [!NOTE]
> This repositry is not complete and WIP.

This repository will create virtual machines on Proxmox and will deploy a Kubernetes cluster using [kubespray](https://github.com/kubernetes-sigs/kubespray).

Multiple environments can be managed by providing a unique `PROXMOX_VM_PREFIX` environment variable.

Deployed clusters will fetch `kubeconifg` files to Ansible controller host under `ansible/artifacts/` directory.

Deployed Kubernetes version is `v1.25.15`.

## Caveats

- Proxmox automation is very limited and requires manual input of node and template ID.  
  Currently, there is no mechanism to balance the virtual machines across the Proxmox cluster.
- Requires providing manual IP offset. Virtual machines will start from the offset `192.168.14.XXX`.

## Requirements

- `make` binary
- [OpenTofu](https://opentofu.org) (drop-in replacement for `terraform`)
- `pip3` binary
- _(Optional)_ [mise](https://github.com/jdx/mise) (runtime executor, will auto initialize `tofu` and `python`)

## Usage

Automation scenarios are wrapped around as `make` targets.  
Environment variables are reused for various targets.  
Use `make` or `make help` to view available targets with descriptions.

### Reuirements

- Prepare all Ansible requirements (requires virtual environment):

```bash
make ansible-prepare-requirements
```

- _(optional)_ Generate Ubuntu cloud image:

```bash
PROXMOX_HOST=<IP_ADDRESS> \
PROXMOX_VM_TEMPLATE_ID=9002 \
PROXMOX_USER=root \
PROXMOX_STORAGE_NAME=workloads \
make generate-ubuntu-cloud-image
```

### Virtual Machines

- Create virtual machines on Proxmox:

```bash
PROXMOX_HOST=<IP_ADDRESS> \
PROXMOX_API_TOKEN='root@pam!<TOKEN_KEY>=<TOKEN_SECRET>' \
PROXMOX_VM_TEMPLATE_ID=9002 \
PROXMOX_VM_IP_OFFSET_START=103 \
PROXMOX_NODE=<PROMOX_HOST_NAME> \
PROXMOX_VM_PREFIX="playground" \
make terraform-apply-proxmox-vms
```

- Destroy virtual machines on Proxmox:

```bash
PROXMOX_HOST=<IP_ADDRESS> \
PROXMOX_API_TOKEN='root@pam!<TOKEN_KEY>=<TOKEN_SECRET>' \
PROXMOX_VM_TEMPLATE_ID=9002 \
PROXMOX_VM_IP_OFFSET_START=103 \
PROXMOX_NODE=<PROMOX_HOST_NAME> \
PROXMOX_VM_PREFIX="playground" \
make terraform-destroy-proxmox-vms
```

- View Ansible inventory of `playground` environment:

```bash
PROXMOX_HOST=<IP_ADDRESS> \
PROXMOX_API_TOKEN='root@pam!<TOKEN_KEY>=<TOKEN_SECRET>' \
PROXMOX_VM_PREFIX="playground" \
make ansible-playground-inventory
```

### Kubernetes

#### Deployment

- Deploy a Kubernetes cluster on playground environment:

```bash
PROXMOX_HOST=<IP_ADDRESS> \
PROXMOX_API_TOKEN='root@pam!<TOKEN_KEY>=<TOKEN_SECRET>' \
PROXMOX_VM_PREFIX="playground" \
make ansible-kubespray-bootstrap
```
