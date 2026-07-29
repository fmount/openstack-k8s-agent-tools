---
name: analyze-must-gather
description: Produce an analysis of observed problems in a must-gather report from OpenStack Services on OpenShift
argument-hint: "<path>"
user-invocable: true
allowed-tools: ["Bash", "Read", "Grep", "Agent"]
context: fork
---

# Analyze must-gather

## General rules

- If something prevents you from taking meaningful steps forward, stop and report the problem to the user.

- Consider the must-gather report read-only. Do not edit anything in it.

- Even if you have tools like `oc` or `ssh` available, don't do direct cluster examination during the analysis. Stick to just analyzing the files in the must-gather report. If you find that it would be useful to have some more information, which is missing from the report but could be obtained by directly inspecting OpenShift or OpenStack or the underlying servers, highlight that in your analysis.

- You MUST NOT use any command whose purpose is to communicate over network.

- If you have a TODO-like tool available, use it to keep track of steps to do.

- The analysis you produce should include paths to relevant files so that the analysis can be independently verified or continued further from where you left off.

## Must-gather report structure hints

- The must-gather report can come already extracted as a directory, or as a .tar.xz that you should extract.

- Pod logs for OpenStack services and their Operators tend to be useful. These are by default under `namespaces/openstack` and `namespaces/openstack-operators` respectively, but the naming may be customized.

- There may be "sos reports" (logs and troubleshooting command outputs) from OpenStack data plane nodes (e.g. compute nodes) and OCP nodes under `sos-reports/_all_nodes` directory. You may need to extract them from .tar.xz files. The compute node sos reports tend to be useful when investigating problems affecting OpenStack virtual machines and services on the data plane.

- There can be short transient error states -- this is often ok and expected for convergence-oriented deployment/update processes where many things happen in parallel. If an error happens for a short while and then stops happening (service recovers and progresses further) then it's quite likely it's not a symptom of a problem.

## Analysis workflow

1. Locate the must-gather report. If it's tarballed, extract it. Do not do too many `ls` calls to understand the structure of the report yet, it is big with many subdirectories.

2. Scan the report for signs of problems with tools like `grep` or `ripgrep`. The words to look for include but may not be limited to "error", "fail", "failure", "fatal", "restart".

3. Try to find the root cause of the main problem, not just symptoms. If that doesn't seem possible, gathering more clues is still helpful.

4. Output a structured analysis of the observed problems and ideally also their causes. Focus primarily on the most severe issues. Don't forget to cite relevant file paths in your analysis.

## RHOSO-Specialized Triage (optional)

After producing the generic analysis, check whether the must-gather contains RHOSO (Red Hat OpenStack Services on OpenShift) resources:

```bash
# Check for RHOSO namespace directories
find <must-gather-root> -maxdepth 2 -type d \( -name "openstack" -o -name "openstack-operators" \)

# Check for RHOSO CRDs
find <must-gather-root> -path "*/cluster-scoped-resources/openstack.org" -type d

# Check for OpenStackControlPlane resources
find <must-gather-root> -path "*openstackcontrolplane*" -type f | head -5
```

If RHOSO resources are detected:

1. **Inform the user**: "This must-gather contains RHOSO (Red Hat OpenStack Services on OpenShift) resources. A specialized RHOSO triage is available that uses `omc` to perform deeper diagnostics including operator installation validation, networking alignment checks, storage class analysis, and control/data plane status."

2. **Ask**: "Would you like to run RHOSO-specialized triage? (Requires `omc` to be installed.)"

3. **If the user confirms**, check for `omc`:
   - Run `which omc`. If not found, provide install instructions and continue with just the generic analysis.
   - If found, locate the must-gather root (find the directory containing `cluster-scoped-resources/`), run `omc use <path>`, and detect the OpenStack namespaces (`openstack`, `openstack-operators`).

4. **Dispatch the support-triage agent** with the generic findings as context:

   ```
   Agent(
     subagent_type="openstack-k8s-agent-tools:support-triage:support-triage",
     description="RHOSO-specialized triage after generic analysis",
     prompt="Must-gather path: <path>
   Namespaces: openstack=<ns>, openstack-operators=<ns-ops>
   Selected categories: all

   ## Prior Generic Analysis Findings
   <insert the structured analysis you just produced>

   RHOSO-specific resources detected. The generic analysis above identified surface-level
   issues. Focus on RHOSO-specific diagnostics: correlate generic findings with RHOSO root
   causes, check configurations the generic scan cannot evaluate (OperatorGroup
   targetNamespace, NAD/NNCP alignment, StorageClass alignment, webhook namespace selectors),
   and avoid duplicating already-reported issues unless adding RHOSO-specific context."
   )
   ```

5. **Present the combined output**: the generic analysis followed by the RHOSO-specialized triage report.

If RHOSO resources are NOT detected, skip this section entirely and present only the generic analysis.
