---
name: rhoso-deploy
description: >-
  Deploy, manage, and test RHOSO (Red Hat OpenStack Services on OpenShift) on a
  remote hypervisor using install_yamls Makefile targets over SSH. Use when the
  user asks to deploy OpenStack, deploy RHOSO, sync install_yamls, create EDPM
  VMs, check cluster status, clean up a deployment, or run a smoke test on a
  remote hypervisor.
argument-hint: "<operation> [overrides]"
user-invocable: true
allowed-tools: ["Bash", "Read", "Grep"]
context: fork
---

# RHOSO Remote Deployment

Deploy and manage RHOSO environments on remote hypervisors by running
install_yamls Makefile targets over SSH.

## Prerequisites

The agent needs connection details. Read the config file first:

1. Read `<install_yamls_repo>/.env.deploy` for connection settings.
2. If the file does not exist, ask the user for: **host**, **user**, **remote directory**, and **edpm node count**.

### Config variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEPLOY_HOST` | *(required)* | Remote hypervisor hostname or IP |
| `DEPLOY_USER` | `$USER` | SSH user |
| `DEPLOY_DIR` | `install_yamls` | Remote directory relative to `$HOME` |
| `DEPLOY_SSH_OPTS` | *(empty)* | Extra SSH flags (jump host, key, etc.) |
| `DEPLOY_SKIP_SYNC` | `false` | Skip rsync to remote |
| `DEPLOY_SYNC_DELETE` | `false` | Delete remote files not present locally |
| `DEPLOY_DATAPLANE_NODES` | *(empty, Makefile default=1)* | Number of EDPM/dataplane nodes |
| `DEPLOY_BOOTSTRAP_VMS` | `false` | Create EDPM VMs during full deploy |
| `DEPLOY_CLEANUP_OPERATORS` | `false` | Also remove operators + PVs on cleanup |

## SSH and Make helpers

Build all remote commands from these two patterns. Always use the Shell tool
with `required_permissions: ["all"]` for SSH commands.

**Remote make (root Makefile):**

```bash
ssh ${DEPLOY_SSH_OPTS} ${DEPLOY_USER}@${DEPLOY_HOST} \
  "cd ~/${DEPLOY_DIR} && make <TARGET> <OVERRIDES>"
```

**Remote devsetup make:**

```bash
ssh ${DEPLOY_SSH_OPTS} ${DEPLOY_USER}@${DEPLOY_HOST} \
  "cd ~/${DEPLOY_DIR}/devsetup && make <TARGET> <OVERRIDES>"
```

**Overrides** are Makefile variable assignments, e.g.
`DATAPLANE_TOTAL_NODES=2 NETWORK_ISOLATION=false`. When `DEPLOY_DATAPLANE_NODES`
is set in config, always append `DATAPLANE_TOTAL_NODES=<N> EDPM_TOTAL_NODES=<N>`
unless the user overrides them explicitly.

## Operations

When the user requests a deployment action, match it to one of these
operations and execute the steps **sequentially** (each depends on the
previous one).

### sync — Push local changes to remote

```bash
rsync -avz --exclude='.git' --exclude='out/' --exclude='.env.deploy' \
  -e "ssh ${DEPLOY_SSH_OPTS}" \
  <local_install_yamls>/ \
  ${DEPLOY_USER}@${DEPLOY_HOST}:~/${DEPLOY_DIR}/
```

If `DEPLOY_SYNC_DELETE` is `true`, add `--delete`.
Skip entirely if `DEPLOY_SKIP_SYNC` is `true`.

### bootstrap — Create EDPM compute VMs

1. sync
2. `devsetup make edpm_compute`

### full — Full RHOSO deploy (control plane + EDPM)

1. sync
2. *(if `DEPLOY_BOOTSTRAP_VMS` is true)* `devsetup make edpm_compute`
3. `make crc_storage`
4. `make input`
5. `make openstack`
6. `make openstack_init`
7. `make openstack_deploy`
8. `make openstack_wait_deploy` — **long-running**, background and monitor
9. `make edpm_wait_deploy` — **long-running**, background and monitor

Between steps 8→9, check status to confirm the control plane is Ready
before proceeding. Use `block_until_ms: 0` and monitor for `condition met`
or `error` in the output.

### controlplane — Deploy control plane only

Steps 1–8 from **full** (stop after `openstack_wait_deploy`).

### edpm — Deploy EDPM only

Assumes control plane is already Ready.

1. sync
2. `make edpm_wait_deploy`

### validate — Smoke test

1. `devsetup make edpm_deploy_instance`

No sync needed.

### status — Check cluster state

Run as a single SSH command (fire-and-forget, do not fail on errors):

```bash
ssh ${DEPLOY_SSH_OPTS} ${DEPLOY_USER}@${DEPLOY_HOST} \
  "cd ~/${DEPLOY_DIR} && \
   oc get pods -n openstack 2>/dev/null | head -60; \
   echo '---'; \
   oc get openstackcontrolplane -n openstack 2>/dev/null; \
   echo '---'; \
   oc get openstackdataplanedeployment -n openstack 2>/dev/null; \
   oc get openstackdataplanenodeset -n openstack 2>/dev/null"
```

### cleanup — Remove deployed resources

Run each step, ignoring failures (`|| true`):

1. `make edpm_deploy_cleanup`
2. `make openstack_deploy_cleanup`
3. `make input_cleanup`
4. `make openstack_cleanup` *(only if `DEPLOY_CLEANUP_OPERATORS` is true)*
5. `make crc_storage_cleanup` *(only if `DEPLOY_CLEANUP_OPERATORS` is true)*

### redeploy — Cleanup then full deploy

Shortcut: run **cleanup** then **full** in sequence.

## Execution rules

1. **Always read `.env.deploy` first** before any operation.
2. **Always request `required_permissions: ["all"]`** on SSH/rsync Shell calls.
3. **Run make targets sequentially** — each step depends on the previous.
4. **Long-running targets** (`openstack_wait_deploy`, `edpm_wait_deploy`):
   use `block_until_ms: 0`, monitor output, and poll with Await.
5. **On failure**: stop, show the error output, and ask the user whether to
   retry, skip, or abort. Do not silently continue (except during cleanup).
6. **Status check**: after `full` or `controlplane` completes, automatically
   run a **status** check and show the result.
7. **Locate install_yamls**: search workspace paths for a directory named
   `install_yamls` (check for `Makefile` + `devsetup/` + `scripts/`).

## Quick reference

| User says | Operation |
|-----------|-----------|
| "deploy rhoso" / "deploy openstack" / "full deploy" | full |
| "deploy control plane" / "deploy CP" | controlplane |
| "deploy edpm" / "deploy dataplane" | edpm |
| "sync changes" / "push my changes" | sync |
| "create VMs" / "bootstrap" | bootstrap |
| "check status" / "how's the cluster" | status |
| "clean up" / "tear down" / "remove deployment" | cleanup |
| "redeploy" / "start fresh" | redeploy |
| "test it" / "validate" / "smoke test" | validate |

## Detailed target reference

For a complete list of install_yamls Makefile targets, their dependencies,
and cleanup order, see [reference.md](reference.md).
