---
name: generate-containerfile
description: Generate Containerfiles for OpenStack service images by analyzing tcib definitions, rdo-packages spec files, and the container images design document. Argument is the service name (e.g., nova, placement, watcher).
user-invocable: true
allowed-tools: ["Bash", "Read", "Write", "Edit", "WebFetch", "AskUserQuestion"]
---

# Generate Containerfile for OpenStack Service

This skill generates container image definitions for OpenStack services
following the patterns in `doc/container-images-design.md`.

The service name is provided as the argument: `$ARGS`. If `$ARGS` is empty,
ask the user which service to generate for before proceeding.

## Workflow

When generating containerfiles for a service, I will systematically:

1. **Read the design document** to understand the build patterns and conventions
2. **Fetch container definitions** from tcib, kolla, or rdo-packages for
   the service's package and dependency information
3. **Fetch the RDO spec file** to extract non-Python deps, config files,
   user/group setup, and file permissions
4. **Fetch upstream requirements** to identify Python dependencies and
   determine extra pip packages needed
5. **Analyze consolidation** — group sub-services by dependency profile
   and propose which share an image vs get separate images
6. **Analyze config files** — classify into upstream source, distgit, and
   excluded categories; map to common vs per-image
7. **Check user/UID** — verify the service user exists in uid_gid_manage
8. **Generate all files** — Containerfiles, dep files (builddeps,
   pythonbuilddeps, bindeps, pythondeps), config files, sources.txt
9. **Create sources.txt** with stream definitions, upper-constraints
   entries, and pinned commit hashes
10. **Ensure directory structure** (src/, config/) exists
11. **Verify** — run the verification checklist against the spec, tcib,
    and generated files to catch missing config, generators, or permissions
12. **Present output** for user review before writing

## Step 1: Read the design document

Fetch and read the container images design document. By default it is at:

```bash
curl -sL https://raw.githubusercontent.com/openstack-k8s-operators/dev-docs/main/container-images-design.md
```

If the user specifies a different location (local file path or URL), use
that instead.

From the design document, understand:
- The Containerfile template pattern (base → service image)
- The kolla interface contract (ENTRYPOINT, CMD, scripts, users, sudoers)
- The four dep files: builddeps.txt, pythonbuilddeps.txt, bindeps.txt, pythondeps.txt
- The consolidation strategy
- The multi-stage build pattern and pip install (`--prefix=/usr`, `--no-deps`)
- The sources.txt format and streams concept
- The source and constraints file locations

## Step 2: Fetch tcib container definitions

Fetch the tcib YAML definitions for the service from `https://github.com/openstack-k8s-operators/tcib` using curl.

First, get the directory listing to find all sub-service definitions:

```bash
curl -sL "https://api.github.com/repos/openstack-k8s-operators/tcib/git/trees/main?recursive=1" | jq -r '.tree[].path' | grep -i "<service>"
```

Then fetch each relevant YAML file via the raw content URL:

```bash
curl -sL https://raw.githubusercontent.com/openstack-k8s-operators/tcib/main/container-images/tcib/base/os/<service>-base/<service>-base.yaml
```

For each sub-service (e.g., `<service>-api`, `<service>-conductor`):

```bash
curl -sL https://raw.githubusercontent.com/openstack-k8s-operators/tcib/main/container-images/tcib/base/os/<service>-base/<sub-service>/<sub-service>.yaml
```

Note: Some services may not follow the `<service>-base/` hierarchy pattern. Check for direct entries under `os/` as well (e.g., `placement-api/` is directly under `os/`, not under a `placement-base/`).

Extract from each YAML:
- `tcib_packages` — RPM packages installed
- `tcib_runs` and `tcib_actions` — build-time commands
- `tcib_user` — runtime user
- Any `tcib_copies`, `tcib_envs`, `tcib_volumes`

## Step 3: Fetch the RDO spec file

Fetch the RPM spec file to cross-reference dependencies:

```bash
# Try the common spec file name patterns
curl -sL https://raw.githubusercontent.com/rdo-packages/<service>-distgit/rpm-master/openstack-<service>.spec

# If that returns 404, try the python- prefix
curl -sL https://raw.githubusercontent.com/rdo-packages/<service>-distgit/rpm-master/python-<service>.spec
```

If neither works, list the repo contents to find the spec file name:

```bash
curl -sL "https://api.github.com/repos/rdo-packages/<service>-distgit/git/trees/rpm-master" | jq -r '.tree[].path' | grep '\.spec$'
```

From the spec file, extract:
- `Requires:` lines for each subpackage (filtering out `python3-*` packages since those come via pip)
- `%pre` sections for user/group creation (UIDs, GIDs, group memberships)
- Subpackage names to understand the service decomposition
- `%install` section — directory creation (`install -d`) and file copies
  (`install -p -D`). Pay attention to permissions (`-m 755`, `-m 640`, etc.)
- `%files` section for each subpackage — which files belong to which
  subpackage (this determines which files go in which container image)
- `Source` declarations — files shipped in the spec that are NOT from the
  upstream source tree (these must be maintained in the containerfile repo)

## Step 4: Fetch upstream requirements

Fetch the service's requirements.txt:

```bash
curl -sL https://raw.githubusercontent.com/openstack/<service>/master/requirements.txt
```

This confirms what Python dependencies pip will install. Note any that have system-level (C library) dependencies requiring microdnf packages (e.g., `python-memcached` needs nothing, but `PyMySQL` needs `mariadb-connector-c-devel` at build time, `cryptography` needs `openssl-devel`).

## Step 5: Analyze consolidation

Group the sub-services by their non-Python dependency profile:

1. List all sub-services found in tcib and the spec file
2. For each sub-service, list its non-Python RPM dependencies (from tcib YAML `tcib_packages` and spec `Requires:`)
3. Group sub-services with identical or near-identical non-Python deps into the same image
4. **All API service containers** must include `httpd`, `mod_ssl`, and
   `python3-mod_wsgi` in their `bindeps.txt`, and must include the Apache
   httpd setup (disable default listeners, add user to apache group) in
   their Containerfile. This applies even if the upstream kolla container
   doesn't explicitly list these packages.
5. Sub-services with heavy deps (libvirt, qemu, ceph) should be in separate images

Present the consolidation analysis to the user:

```
Proposed image grouping for <service>:

Image: openstack-<service>
  Services: <sub1>, <sub2>
  Non-Python deps: (minimal)

Image: openstack-<service>-api
  Services: <sub3>
  Non-Python deps: httpd, mod_ssl, python3-mod_wsgi

Image: openstack-<service>-<variant>
  Services: <sub4>
  Non-Python deps: <heavy-deps>
```

Ask the user to confirm or adjust the grouping before generating files.

## Step 6: Analyze config files and directories from the spec

Parse the spec file's `%install` and `%files` sections to determine what
directories, config files, and auxiliary files each container image needs.

### 6a. Identify directories to create

Look for `install -d` lines in `%install`. These create directories that
the service expects to exist at runtime. Translate RPM macros to paths:

| RPM macro | Path |
|-----------|------|
| `%{_sysconfdir}` | `/etc` |
| `%{_sharedstatedir}` | `/var/lib` |
| `%{_localstatedir}` | `/var` |
| `%{_bindir}` | `/usr/bin` |
| `%{_datadir}` | `/usr/share` |

For example:
```
install -d -m 755 %{buildroot}%{_sharedstatedir}/nova        → /var/lib/nova (755)
install -d -m 755 %{buildroot}%{_sharedstatedir}/nova/instances → /var/lib/nova/instances (755)
install -d -m 750 %{buildroot}%{_localstatedir}/log/nova      → /var/log/nova (750)
install -d -m 700 %{buildroot}%{_sharedstatedir}/nova/.ssh    → /var/lib/nova/.ssh (700)
install -d -m 755 %{buildroot}%{_sysconfdir}/nova             → /etc/nova (755)
```

Generate `mkdir -p` and `chmod` commands in the Containerfile preserving
the exact permissions from the spec.

### 6b. Classify config files into three categories

**Category 1: Files from upstream source** — These are installed in the spec
with `install -p -D` referencing a path under `etc/` in the source tree:

```
install -p -D -m 640 etc/nova/rootwrap.conf %{buildroot}%{_sysconfdir}/nova/rootwrap.conf
install -p -D -m 640 etc/nova/api-paste.ini %{buildroot}%{_sysconfdir}/nova/api-paste.ini
```

These should be copied from the source (COPY'd into the build stage)
and carried to the runtime stage via `COPY --from=build /configfiles/ /`.
Preserve the permissions from the spec.

**Category 2: Files from spec Sources** — These are installed referencing
`%{SOURCEnn}` and correspond to files maintained in the distgit repo, not
in the upstream source:

```
install -p -D -m 600 %{SOURCE38} %{buildroot}%{_sysconfdir}/nova/migration/identity
install -p -D -m 644 %{SOURCE39} %{buildroot}%{_sysconfdir}/nova/migration/authorized_keys
install -p -D -m 640 %{SOURCE40} %{buildroot}%{_sysconfdir}/nova/migration/rootwrap.conf
install -p -D -m 640 %{SOURCE41} %{buildroot}%{_sysconfdir}/nova/migration/rootwrap.d/cold_migration.filters
```

These must be **maintained in the containerfile repo** under `config/` in
the appropriate container directory. Fetch the actual file content from the
distgit repo:

```bash
# Find the Source file names (e.g., Source38: nova-migration-rootwrap.conf)
grep '^Source' openstack-nova.spec

# Fetch each file
curl -sL https://raw.githubusercontent.com/rdo-packages/<service>-distgit/rpm-master/<source-filename>
```

Place them in the `config/` directory mirroring the target filesystem path,
and note the permissions for the Containerfile.

**Category 3: Files to exclude** — Skip these entirely:
- Systemd unit files (`%{SOURCE1}` → `openstack-nova-api.service`, etc.)
- Logrotate configs (`%{SOURCE6}` → `openstack-nova.logrotate`)
- SysV init scripts
- Tmpfiles.d configs
- Polkit/dbus configs (unless needed for container operation)

### 6c. Map files to container images

Use the `%files` section of each subpackage to determine which files belong
to which RPM subpackage. Then use the tcib container definitions (from
step 2) to determine which RPM subpackages are installed in each container.
This tells you which files go in which container image.

For example, if:
- `%files compute` lists `/etc/nova/rootwrap.d/compute.filters`
- tcib's `nova-compute.yaml` installs `openstack-nova-compute`

Then `compute.filters` goes in the `nova-compute` container image's
`config/` directory.

Files from subpackages shared by all containers (typically `openstack-<service>-common`)
go in the `common/config/` directory.

### 6d. Handle permissions

Every config file must be listed **explicitly** in the Containerfile with
its full source and destination path. Never use directory-level COPY for
config files (e.g., `COPY common/config/ /`). Instead:

```dockerfile
# Each file explicitly — nothing silently missing, build fails if a file is absent
COPY --from=build /configfiles/etc/<project>/rootwrap.conf /etc/<project>/rootwrap.conf
COPY common/config/etc/<project>/<project>-dist.conf /etc/<project>/<project>-dist.conf
COPY <image>/config/etc/sudoers.d/<project>-rootwrap /etc/sudoers.d/<project>-rootwrap
```

After COPY, set permissions matching the spec's `-m` flags:

```dockerfile
RUN chmod 640 /etc/<project>/rootwrap.conf && \
    chmod 440 /etc/sudoers.d/<project>-rootwrap && \
    chown -R <user>:<user> /etc/<project>
```

If a service has no config files in a category, omit those COPY lines
entirely — do not COPY empty directories.

## Step 7: Check for user/UID requirements

Check if the operator defines a fixed UID for this service. Look in the operator source code (if available) or in the tcib `uid_gid_manage.sh` script. The kolla UID mappings include:

| Service | UID | GID |
|---------|-----|-----|
| nova | 42436 | 42436 |
| placement | 42482 | 42482 |
| cinder | 42407 | 42407 |
| glance | 42415 | 42415 |
| heat | 42418 | 42418 |
| ironic | 42422 | 42422 |
| keystone | 42425 | 42425 |
| neutron | 42435 | 42435 |
| manila | 42429 | 42429 |
| watcher | 42451 | 42451 |
| octavia | 42437 | 42437 |
| barbican | 42403 | 42403 |
| designate | 42411 | 42411 |
| swift | 42445 | 42445 |
| aodh | 42402 | 42402 |

If the service user is not listed in `containers/base/scripts/uid_gid_manage`, note that it needs to be added to the script's mapping table with the correct UID/GID and group memberships.

## Step 8: Generate the files

For each image in the consolidation grouping, generate:

### Containerfile

Follow this exact multi-stage template. The build stage compiles wheels from
source COPY'd into the build stage; the runtime stage installs from those
wheels. See the "Source Management" section in the design doc for details.

The build context is `containers/<project>/` so that `COPY` can reach both
the `common/config/` directory and the image-specific files.

```dockerfile
ARG BASE_IMAGE=localhost/openstack/openstack-base:latest
# Note: the actual base image tag depends on IMAGE_PREFIX and TAG settings

# --- Build stage: compile wheels and collect upstream config ---
FROM ${BASE_IMAGE} AS build

ARG SERVICE_SRC=/src/<project>

# Copy constraints file and source repos into the build stage
# Project-level sources + image-specific sources merged into /src/
ARG CONSTRAINTS_FILE=requirements.lock
COPY ${CONSTRAINTS_FILE} /deps-upper-constraints.txt
COPY src/ /src/
COPY <image>/src/ /src/

COPY <image>/builddeps.txt /tmp/builddeps.txt
RUN pkgs=$(cat /tmp/builddeps.txt | grep -v '^#' | grep -v '^$' | tr '\n' ' ') && \
    if [ -n "${pkgs}" ]; then microdnf -y install ${pkgs} && microdnf clean all; fi

COPY <image>/pythonbuilddeps.txt /tmp/pythonbuilddeps.txt
RUN pkgs=$(cat /tmp/pythonbuilddeps.txt | grep -v '^#' | grep -v '^$' | tr '\n' ' ') && \
    if [ -n "${pkgs}" ]; then pip3 install --no-cache-dir -c /deps-upper-constraints.txt ${pkgs}; fi && \
    rm /tmp/pythonbuilddeps.txt

# Generate a filtered constraints file that excludes packages we build from source.
RUN cp /deps-upper-constraints.txt /tmp/build-constraints.txt && \
    for src_dir in /src/*/ /src/overrides/*/; do \
      if [ -d "${src_dir}" ] && [ -f "${src_dir}/setup.cfg" ]; then \
        pkg_name=$(grep -m1 '^name' "${src_dir}/setup.cfg" | sed 's/.*=\s*//'); \
        sed -i "/^${pkg_name}[=!<>]/Id" /tmp/build-constraints.txt; \
      fi; \
    done

# Build wheels from all source packages and overrides
RUN for pkg in /src/*/ /src/overrides/*/; do \
      if [ -d "${pkg}" ] && [ -f "${pkg}/setup.cfg" -o -f "${pkg}/setup.py" -o -f "${pkg}/pyproject.toml" ]; then \
        pip3 wheel --no-cache-dir --no-build-isolation --no-deps \
          --wheel-dir=/wheels "${pkg}"; \
      fi; \
    done

# Generate build manifest: package-name,commit-hash,version
RUN for src_dir in /src/*/ /src/overrides/*/; do \
      if [ -d "${src_dir}" ] && [ -f "${src_dir}/setup.cfg" ]; then \
        pkg_name=$(grep -m1 '^name' "${src_dir}/setup.cfg" | sed 's/.*=\s*//'); \
        commit=$(git -C "${src_dir}" rev-parse HEAD 2>/dev/null || echo "unknown"); \
        version=$(ls /wheels/${pkg_name//-/_}-*.whl 2>/dev/null | head -1 | sed 's/.*-\([0-9][^-]*\)-.*/\1/' || echo "unknown"); \
        echo "${pkg_name},${commit},${version}"; \
      fi; \
    done > /source-built-packages.txt

# Install wheels temporarily so entry points are available for config generation
RUN pip3 install --no-cache-dir --prefix=/usr \
      -c /tmp/build-constraints.txt \
      /wheels/*.whl

# Generate default config and collect upstream config files
RUN mkdir -p /configfiles/etc/<project> && \
    oslo-config-generator \
      --config-file ${SERVICE_SRC}/<path-to-config-generator.conf> \
      --output-file /configfiles/etc/<project>/<project>.conf && \
    sed -i "/#pybasedir.*/d" /configfiles/etc/<project>/<project>.conf && \
    cp -a ${SERVICE_SRC}/etc/<project>/rootwrap.conf /configfiles/etc/<project>/ 2>/dev/null || true && \
    cp -a ${SERVICE_SRC}/etc/<project>/rootwrap.d /configfiles/etc/<project>/ 2>/dev/null || true && \
    cp -a ${SERVICE_SRC}/etc/<project>/api-paste.ini /configfiles/etc/<project>/ 2>/dev/null || true

# --- Runtime stage: install from wheels ---
FROM ${BASE_IMAGE}

LABEL summary="OpenStack <Service> (<sub-services>)" \
      io.k8s.description="<Service> container built from source with kolla interface"

# Create the service user with fixed UID/GID via uid_gid_manage
RUN uid_gid_manage <user>

# Install non-Python system dependencies
COPY <image>/bindeps.txt /tmp/bindeps.txt
RUN pkgs=$(cat /tmp/bindeps.txt | grep -v '^#' | grep -v '^$' | tr '\n' ' ') && \
    if [ -n "${pkgs}" ]; then microdnf -y install ${pkgs} && microdnf clean all; fi && rm /tmp/bindeps.txt

# Install source-built wheels + deps from PyPI + extra Python deps
COPY --from=build /wheels /wheels
COPY --from=build /tmp/build-constraints.txt /deps-upper-constraints.txt
COPY --from=build /source-built-packages.txt /source-built-packages.txt
COPY <image>/pythondeps.txt /tmp/pythondeps.txt
RUN extrapkgs=$(cat /tmp/pythondeps.txt | grep -v '^#' | grep -v '^$' | tr '\n' ' ') && \
    pip3 install --no-cache-dir --prefix=/usr \
      -c /deps-upper-constraints.txt \
      /wheels/*.whl ${extrapkgs} && \
    rm -rf /wheels /tmp/pythondeps.txt

# Create required directories
RUN mkdir -p /etc/<project> /var/log/<project> /var/lib/<project> && \
    chown -R <user>:<user> /etc/<project> /var/log/<project> /var/lib/<project>

# Install config files — each file listed explicitly
COPY --from=build /configfiles/etc/<project>/<project>.conf /etc/<project>/<project>.conf
COPY --from=build /configfiles/etc/<project>/rootwrap.conf /etc/<project>/rootwrap.conf
COPY --from=build /configfiles/etc/<project>/api-paste.ini /etc/<project>/api-paste.ini
COPY common/config/etc/<project>/<project>-dist.conf /etc/<project>/<project>-dist.conf
COPY <image>/config/etc/sudoers.d/<project>-rootwrap /etc/sudoers.d/<project>-rootwrap

# Set config file permissions
RUN chmod 640 /etc/<project>/<project>.conf /etc/<project>/rootwrap.conf /etc/<project>/api-paste.ini && \
    chmod 440 /etc/sudoers.d/<project>-rootwrap && \
    chown -R <user>:<user> /etc/<project>

USER <user>
```

For WSGI-based services (those needing httpd), add before `USER <user>`:

```dockerfile
# Apache httpd setup for WSGI
RUN sed -i -r 's,^(Listen 80),#\1,' /etc/httpd/conf/httpd.conf && \
    sed -i -r 's,^(Listen 443),#\1,' /etc/httpd/conf.d/ssl.conf 2>/dev/null || true && \
    usermod --append --groups apache <user>
```

### builddeps.txt

Build-time system packages for the build stage. These are needed to compile
Python C extensions and are discarded from the final image. This file is
typically the same across all services:

```
git-core
gcc
gcc-c++
python3-devel
python3-setuptools
python3-wheel
libffi-devel
openssl-devel
```

If the service has Python dependencies with unusual C library requirements
(e.g., `libxml2-devel` for lxml), add them here.

### pythonbuilddeps.txt

Python packages installed via pip in the build stage before building the
service wheel. Typically just `pbr` for version detection:

```
pbr
```

### bindeps.txt

List the runtime system packages (installed via microdnf in the final image), one
per line, with comments explaining each:

```
# <category>
<package-name>
```

Use the tcib YAML `tcib_packages` and the spec file `Requires:` as sources.
Filter out:
- `python3-*` packages (these go in pythondeps.txt or come via pip)
- `openstack-<service>-*` packages (replaced by pip install from source)
- Packages already in the base image (dumb-init, sudo, python3, pip, etc.)

Exception: system-level Python bindings that can only be installed via microdnf
(e.g., `python3-libvirt`, `python3-mod_wsgi`) belong in bindeps.txt, not
pythondeps.txt.

### pythondeps.txt

List additional Python packages installed via pip after the main service.
These are typically database drivers, caching backends, or optional features
not in the service's `requirements.txt`:

```
# Database driver (mysql extra for oslo.db)
oslo.db[mysql]
# Caching backend (dogpile extra for oslo.cache)
oslo.cache[dogpile]
```

To populate this, check:
- If the service depends on `oslo.db`, add `oslo.db[mysql]` for the MySQL driver
- If the service depends on `oslo.cache`, add `oslo.cache[dogpile]` for the caching backend
- The spec file's `Requires: python3-*` lines for packages not in the
  service's `requirements.txt`
- The tcib YAML for any extra pip installs

## Step 9: Create sources.txt and directory structure

### 9a. Determine streams

Check if the user specified which streams to include in the initial
request (e.g., `/generate-containerfile watcher streams=master,hibiscus`).

If not specified, ask the user:
- Which streams should be defined? (e.g., master, hibiscus, stable)
- For each stream, which branch should the service follow?
  (e.g., master → master, hibiscus → stable/2024.2)

Also ask which branch the upper-constraints (requirements repo) should
follow for each stream.

### 9b. Resolve pinned hashes

For each stream, resolve the current commit hash for the branch-to-follow.
Try as a branch first, then as a tag:

```bash
# Try as a branch
git ls-remote https://opendev.org/openstack/<project>.git refs/heads/<branch> | cut -f1

# If empty, try as a tag (dereference annotated tags)
git ls-remote https://opendev.org/openstack/<project>.git "refs/tags/<branch>^{}" | cut -f1
```

If the branch-to-follow is a commit hash, use it directly.

Alternatively, you can leave the pinned-hash field empty and let the user
run `build.sh update-sources` to fill it in.

### 9c. Generate sources.txt

Create `containers/<project>/sources.txt` with entries for each stream.

**Every stream MUST include an `upper-constraints` entry.** This is
required for the build to work — without it, build.sh cannot fetch the
constraints file and the build will fail.

The `upper-constraints` entry should follow the same branch as the main
service for that stream (e.g., if watcher follows `master`, then
upper-constraints also follows `master`; if watcher follows `stable/2024.2`,
then upper-constraints follows `stable/2024.2`).

```
# <stream> <name> <repo-url> <branch-to-follow> <pinned-hash>
master upper-constraints https://opendev.org/openstack/requirements.git master abc123...
master <project> https://opendev.org/openstack/<project>.git master def456...
hibiscus upper-constraints https://opendev.org/openstack/requirements.git stable/2024.2 789abc...
hibiscus <project> https://opendev.org/openstack/<project>.git stable/2024.2 012def...
```

If the image needs additional packages (from the consolidation analysis
in step 5), add their entries too.

### 9d. Create directory structure

Create empty `src/` directories with `.gitkeep` at both levels:
- `containers/<project>/src/.gitkeep`
- `containers/<project>/<image>/src/.gitkeep`

These must exist even if empty — the Containerfile `COPY src/ /src/`
and `COPY <image>/src/ /src/` will fail if the directory is missing.

## Step 10: Present output

Present all generated files to the user for review. For each file, show:
1. The file path
2. The full file content
3. A brief explanation of design choices made

Ask the user to confirm before writing the files.

## Step 11: Verification Checklist

After generating all files, run through this checklist **before presenting
output to the user**. Each item must be explicitly verified — do not skip
items or assume they are satisfied without checking.

### Config files and build-stage generators

- [ ] **Every `install -p -D` line in `%install`** is accounted for:
  - Mapped to a `COPY --from=build` in the Containerfile (upstream source files), OR
  - Mapped to a `COPY` from `config/` directory (distgit Source files), OR
  - Explicitly excluded with a reason (systemd units, logrotate, tmpfiles.d)
- [ ] **Every generator command in `%install`** (oslo-config-generator,
  oslo-policy-generator, config-generate, etc.) is reproduced in the
  build stage. Check for patterns like:
  - `oslo-config-generator --config-file ...`
  - `oslo-policy-generator --config-file ...`
  - Any `python` or script invocations that produce config files
- [ ] **Generated config files** are collected into `/configfiles/` in the
  build stage and COPY'd explicitly into the runtime stage
- [ ] **The `sed` or cleanup commands** applied to generated files in the
  spec are also applied in the build stage (e.g., `sed -i "/#pybasedir.*/d"`)

### Directories and permissions

- [ ] **Every `install -d` and `mkdir` in `%install`** has a corresponding
  `mkdir -p` in the Containerfile
- [ ] **Directory permissions** from the spec (`-m 750`, `-m 700`, etc.)
  are preserved in the Containerfile via `chmod`
- [ ] **Config file permissions** from `install -p -D -m NNN` and
  `%config ... %attr(...)` are set in the Containerfile after COPY
- [ ] **Ownership** matches the spec (`chown user:group`)

### User and group

- [ ] **`%pre` section** user/group creation matches the `uid_gid_manage`
  call (same username, same group memberships)
- [ ] **UID/GID** matches the kolla standard table

### Dependencies

- [ ] **All four dep files** exist for every image (even if empty):
  builddeps.txt, pythonbuilddeps.txt, bindeps.txt, pythondeps.txt
- [ ] **builddeps.txt** includes headers needed by Python deps with C
  extensions (check requirements.txt for lxml→libxml2-devel,
  cryptography→openssl-devel, etc.)
- [ ] **bindeps.txt** includes all non-Python `Requires:` from the spec,
  minus packages already in base image and minus `openstack-*` RPMs
- [ ] **pythondeps.txt** includes extras for oslo libraries used by the
  service (oslo.db→`oslo.db[mysql]`, oslo.cache→`oslo.cache[dogpile]`)
- [ ] **API images** include httpd, mod_ssl, python3-mod_wsgi in bindeps.txt
  and the Apache httpd setup block in the Containerfile

### Structure and sources

- [ ] **src/.gitkeep** exists at both project level and each image level
- [ ] **sources.txt** has an `upper-constraints` entry for every stream
- [ ] **No `git clone`** appears in any Containerfile
- [ ] **`--prefix=/usr`** is used on `pip3 install` in the runtime stage
- [ ] **Dep file installs** are conditional (handle empty files gracefully)

### Cross-reference with tcib

- [ ] **Every `tcib_actions` command** that is not a simple `microdnf install`
  is reproduced in the Containerfile (e.g., sed commands for httpd,
  usermod for group membership)
- [ ] **`tcib_user`** matches the USER directive at the end of the
  Containerfile

### Final sanity check

Present a summary table to the user showing what was found and how it
was handled:

| Source | Item | Action |
|--------|------|--------|
| spec %install | `oslo-config-generator ...` | Generated in build stage |
| spec %install | `install ... watcher.conf` | COPY --from=build |
| spec Source10 | `openstack-watcher-api.service` | Excluded (systemd) |
| tcib watcher-api | `sed ... httpd.conf` | Reproduced in Containerfile |
| ... | ... | ... |

## Important Notes

- Always use `--prefix=/usr` for pip install so binaries land at `/usr/bin/`
- Source is COPY'd from `src/` (project-level) and `<image>/src/`
  (image-level) into the build stage — the Containerfile must NOT contain
  `git clone`
- Two COPY commands merge project and image sources: `COPY src/ /src/`
  then `COPY <image>/src/ /src/`
- Both `src/` directories must exist (even if empty with just `.gitkeep`)
  or the COPY will fail
- All dep file installs must be conditional (handle empty files gracefully)
- All four dep files (builddeps, pythonbuilddeps, bindeps, pythondeps)
  must always be present in the generated output, even if empty
- All API service containers must include httpd, mod_ssl, python3-mod_wsgi
  in bindeps.txt
- Do not duplicate packages already in the base image
- The `upper-constraints` entry in sources.txt is special — it is NOT
  cloned into src/. build.sh fetches just the upper-constraints.txt file
  and places it in the project build context.
- Constraints are per-project — each project's sources.txt defines its
  own upper-constraints entry, allowing different projects to track
  different OpenStack releases
- All remote fetches use `curl` against raw.githubusercontent.com — no
  `gh` CLI or authentication needed for public repos
- If `curl` fails (404), try alternative file name patterns or use
  `WebFetch` as a fallback
