# install_yamls Makefile target reference

## Deploy targets (root Makefile)

### Phase: Prerequisites

| Target | What it does |
|--------|-------------|
| `crc_storage` | Creates local PVs and StorageClass on CRC |
| `input` | Creates secrets/configmaps consumed by OpenStack services |
| `namespace` | Creates the `openstack` namespace (called by other targets) |

### Phase: Operator install

| Target | What it does |
|--------|-------------|
| `openstack` | Installs openstack-operator via OLM; runs `openstack_prep` which pulls in nmstate, NNCP, MetalLB, net-attach-def when network isolation is enabled |
| `openstack_init` | Creates the `OpenStack` CR; waits for sub-operators and webhooks |

### Phase: Service deploy

| Target | What it does |
|--------|-------------|
| `openstack_deploy` | Generates and applies `OpenStackControlPlane` CR via kustomize |
| `openstack_wait_deploy` | Waits for `OpenStackControlPlane` condition=Ready |
| `netconfig_deploy` | Deploys network configuration (called by `openstack_deploy`) |

### Phase: Data plane

| Target | What it does |
|--------|-------------|
| `edpm_deploy` | Applies dataplane manifests (`oc apply`) |
| `edpm_wait_deploy` | `edpm_deploy` + wait for Ready + `edpm_nova_discover_hosts` |
| `edpm_nova_discover_hosts` | Registers compute hosts with Nova cell |

### Phase: Validate

| Target (devsetup/) | What it does |
|---------------------|-------------|
| `edpm_deploy_instance` | Creates Cirros image, network, security group, instance, FIP; pings from `openstackclient` pod |

## Cleanup targets (reverse order)

### Service-level cleanup (keeps operators installed)

| Target | What it removes |
|--------|----------------|
| `edpm_deploy_cleanup` | EDPM dataplane CRs, nodesets, deployments |
| `openstack_deploy_cleanup` | `OpenStackControlPlane` CR + `netconfig_deploy_cleanup` |
| `deploy_cleanup` | All individual service objects (redundant after `openstack_deploy_cleanup`) |
| `input_cleanup` | Secrets and configmaps from `make input` |

### Operator-level cleanup (full wipe)

| Target | What it removes |
|--------|----------------|
| `openstack_cleanup` | OLM subscription, CSV, catalog source, webhooks |
| `cleanup` | All individual operator subscriptions |
| `crc_storage_cleanup` | PVs and StorageClass |
| `namespace_cleanup` | Deletes the `openstack` namespace entirely |

### Correct cleanup order

```
edpm_deploy_cleanup
  → openstack_deploy_cleanup (includes netconfig_deploy_cleanup)
    → input_cleanup
      → openstack_cleanup (operator OLM removal)
        → crc_storage_cleanup
```

## devsetup targets

| Target | What it does |
|--------|-------------|
| `download_tools` | Installs oc, kubectl, kustomize, opm, etc. |
| `crc` | Installs and starts CRC (Code Ready Containers) |
| `crc_attach_default_interface` | Attaches libvirt default network to CRC VM |
| `edpm_compute` | Creates EDPM compute VMs via libvirt |
| `edpm_compute_cleanup` | Destroys EDPM compute VMs |
| `edpm_deploy_instance` | Smoke test: deploy a Nova instance |
| `network_isolation_bridge` | Creates isolated network bridge |

## Key Makefile variables

| Variable | Default | Scope |
|----------|---------|-------|
| `NAMESPACE` | `openstack` | Root |
| `OPERATOR_NAMESPACE` | `openstack-operators` | Root |
| `NETWORK_ISOLATION` | `true` | Root |
| `NETWORK_ISOLATION_USE_DEFAULT_NETWORK` | `true` | Root |
| `DATAPLANE_TOTAL_NODES` | `1` | Root |
| `DATAPLANE_TIMEOUT` | `30m` | Root |
| `DATAPLANE_COMPUTE_IP` | `192.168.122.100` | Root (default network) |
| `TIMEOUT` | `500s` | Root |
| `EDPM_TOTAL_NODES` | `1` | devsetup |
| `OPENSTACK_K8S_BRANCH` | `main` | Root |

`DATAPLANE_TOTAL_NODES` (root) and `EDPM_TOTAL_NODES` (devsetup) must match.
