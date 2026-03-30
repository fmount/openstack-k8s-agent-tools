# /feature — Feature Planning Guide

Plan features and bug fixes for openstack-k8s-operators operators with Jira integration, cross-repo analysis, and structured implementation strategies.

## Quickstart

```bash
# From a Jira ticket (requires Atlassian MCP configured)
/feature OSPRH-2345

# From a local spec file
/feature docs/my-feature-spec.md

# Interactive — the skill asks what you have
/feature
```

## How It Works

```
 Jira ticket (OSPRH-2345)        Spec file (.md)        Interactive
      |                               |                      |
      +--- Atlassian MCP              +--- Read tool          +--- ask user
      |                               |                      |
      +-------------------------------+----------------------+
                                      |
                              /feature
                              [agent: feature]
                                      |
              +-----------+-----------+-----------+
              |           |           |           |
           Context    Cross-repo   Planning   Strategies
           Summary    Analysis     Checklist  (2-3 options)
              |           |           |           |
              |    +------+------+    |     user picks
              |    |      |      |    |        one
              |  lib-   peer   dev-   |           |
              | common  ops   docs    |           |
              +---+------+------+----+-----------+
                                      |
                          ~/.local/share/openstack-k8s-agent-tools/plans/<operator>/<plan>.md
                                      |
                              /task-executor
                              [agent: task-executor]
                                      |
              +-----------+-----------+-----------+
              |           |           |           |
           Group 1     Group 2     Group 3      ...
          API changes  Controller  Testing
              |           |           |
              +----each task----------+
              |  write -> test -> checkpoint
              |  pause at group boundaries
              |
              +---> /test-operator full
              +---> /code-review [agent: code-review]
              +---> submit PR
```

### Planning Phase (detail)

```
+---------------------------------------------------------------+
|                     /feature                                   |
|                     [agent: feature]                           |
+---------------------------------------------------------------+
|                                                                |
|  1. INPUT NORMALIZATION                                        |
|     Jira (MCP) or spec file --> Context Summary                |
|                                                                |
|  2. CROSS-REPO ANALYSIS                                        |
|     +------------------+------------------+-----------------+  |
|     | Current operator | lib-common       | Peer operators  |  |
|     | controllers/     | modules/common/* | nova, cinder,   |  |
|     | api/             | (local or gh)    | manila, ...     |  |
|     | config/          |                  | (local or gh)   |  |
|     | test/            | dev-docs         |                 |  |
|     +------------------+ conventions      +-----------------+  |
|                        +------------------+                    |
|                                                                |
|  3. PLANNING CHECKLIST (11 principles)                         |
|     +-------------+---------------+---------------------------+|
|     | Principle    | Assessment    | Notes                     ||
|     |-------------|---------------|---------------------------||
|     | API Changes | Yes/No/N/A    | struct changes, markers   ||
|     | lib-common  | Yes/No/N/A    | existing helpers, new?    ||
|     | Duplication | Yes/No/N/A    | peer operator patterns    ||
|     | Code Style  | Yes/No/N/A    | gopls, imports, wrapping  ||
|     | Webhooks    | Yes/No/N/A    | Spec.Default(), paths     ||
|     | Conditions  | Yes/No/N/A    | severity, generation      ||
|     | EnvTest     | Yes/No/N/A    | new reconcile paths       ||
|     | Kuttl       | Yes/No/N/A    | integration scenarios     ||
|     | RBAC        | Yes/No/N/A    | markers, verbs            ||
|     | Evidence    | Yes/No/N/A    | logs, repro (bugs only)   ||
|     | Docs        | Yes/No/N/A    | dev-docs, inline          ||
|     +-------------+---------------+---------------------------+|
|                                                                |
|  4. STRATEGIES (2-3 options)                                   |
|     Strategy A: <approach> -- pros/cons/risk                   |
|     Strategy B: <approach> -- pros/cons/risk                   |
|     Recommendation: Strategy A because <reasoning>             |
|     --> user approves                                          |
|                                                                |
|  5. TASK BREAKDOWN (grouped by functional area)                |
|     Group 1: API  --> Task 1.1, 1.2, 1.3                      |
|     Group 2: Ctrl --> Task 2.1, 2.2                            |
|     Group 3: Test --> Task 3.1, 3.2                            |
|     --> writes ~/.local/share/openstack-k8s-agent-tools/plans/<operator>/<plan>.md                            |
|                                                                |
+---------------------------------------------------------------+
```

### Execution Phase (detail)

```
+---------------------------------------------------------------+
|                     /task-executor                              |
|                     [agent: task-executor]                      |
+---------------------------------------------------------------+
|                                                                |
|  LOAD          READ ~/.local/share/openstack-k8s-agent-tools/plans/<operator>/<plan>.md                       |
|  VALIDATE      check 5 sections present                        |
|  DETECT        find first uncompleted task                     |
|  REPORT        "3/8 tasks done. Next: Task 2.1"               |
|                                                                |
|  EXECUTE LOOP:                                                 |
|                                                                |
|    +---> pick next [ ] task                                    |
|    |          |                                                |
|    |     check dependencies met?                               |
|    |     no --> stop, report                                   |
|    |     yes                                                   |
|    |          |                                                |
|    |     test-first? (new reconcile path)                      |
|    |     yes --> write test, verify fail, implement, verify pass|
|    |     no  --> implement directly                            |
|    |          |                                                |
|    |     checkpoint: [ ] --> [x] in plan file                  |
|    |          |                                                |
|    |     last task in group?                                   |
|    |     yes --> run make fmt/vet                              |
|    |            "Group N complete. Review?"                    |
|    |             wait for user approval                        |
|    |     no                                                    |
|    +----<-+                                                    |
|                                                                |
|  ON ERROR:                                                     |
|    task failure   --> stop, report, keep [ ], ask user         |
|    codebase drift --> detect, ask adapt or regenerate          |
|    corrupt plan   --> report, ask fix or /feature again        |
|                                                                |
|  ON QUIT:                                                      |
|    plan file has current progress --> /task-executor to resume  |
|                                                                |
+---------------------------------------------------------------+
```

## Prerequisites

- **Atlassian MCP** (optional): configure in Claude Code settings for Jira integration. Without it, use spec files or paste content directly.
- **GitHub CLI** (optional): `gh` for browsing lib-common and peer operators when local checkouts aren't available.

## Use Case: Adding Topology Support to an Operator

You're working on `glance-operator` and need to add topology/affinity support (Jira: `OSPRH-4567`).

### Step 1: Invoke the skill

```bash
cd ~/go/src/github.com/openstack-k8s-operators/glance-operator
/feature OSPRH-4567
```

### Step 2: The skill fetches and normalizes the ticket

```
## Context Summary

**Source:** OSPRH-4567 (Jira)
**Type:** Story
**Priority:** Major

### Problem Statement
Glance operator does not support topology spread constraints or pod affinity.
Deployers need control over pod placement for HA configurations.

### Requirements
1. Add topology/affinity fields to GlanceAPI and GlanceInternal specs
2. Follow the lib-common topology CR pattern
3. Propagate topology constraints to generated pods

### Acceptance Criteria
- [ ] GlanceAPI and GlanceInternal specs accept topology overrides
- [ ] Pods are scheduled respecting topology constraints
- [ ] EnvTest coverage for topology reconciliation
```

### Step 3: Cross-repo analysis

The skill checks your local checkouts (or GitHub) and reports:

```
## Impact Analysis

**Affected controllers:** GlanceAPI, GlanceInternal
**Affected API types:** GlanceAPISpec, GlanceInternalSpec

**lib-common:** common/affinity and common/topology modules already provide
TopologySpreadConstraints helpers — use these, do not reimplement.

**Prior art:** nova-operator and cinder-operator both implemented topology
support. nova-operator's approach (PR #423) is the closest match.

**dev-docs:** No specific topology convention doc, but the topology CR
pattern is established in lib-common.
```

### Step 4: Planning checklist

| Principle | Assessment |
|-----------|-----------|
| API Changes | **Yes** — add `TopologyRef` field to GlanceAPISpec and GlanceInternalSpec |
| lib-common Reuse | **Yes** — use `common/topology` module |
| Code Duplication | **Yes** — nova-operator has the same pattern, follow it |
| Webhook Changes | **Yes** — add defaulting for topology fields |
| Status Conditions | **No** — no new conditions needed |
| EnvTest Tests | **Yes** — test topology propagation to pods |
| Kuttl Tests | **N/A** — EnvTest is sufficient |
| RBAC | **Yes** — need watch on Topology CR |

### Step 5: Implementation strategies

The skill proposes approaches (e.g., "follow nova-operator exactly" vs "simplified version without TopologyRef") with trade-offs. You pick one.

### Step 6: Task breakdown

```
## Group 1: API Changes
- [ ] Task 1.1: Add TopologyRef to GlanceAPISpec and GlanceInternalSpec
- [ ] Task 1.2: Run make manifests generate
- [ ] Task 1.3: Add webhook defaulting for topology fields

## Group 2: Controller Logic
- [ ] Task 2.1: Reconcile topology constraints into pod specs
- [ ] Task 2.2: Add RBAC markers for Topology CR

## Group 3: Testing
- [ ] Task 3.1: Add EnvTest cases for topology propagation
```

### Step 7: Execute the plan

```bash
/task-executor ~/.local/share/openstack-k8s-agent-tools/plans/<operator>/2026-03-25-OSPRH-4567-plan.md
```

The task-executor picks up the plan file, shows progress, and executes tasks one by one with checkpointing. You can quit and resume anytime.

## Related Skills

- **`/task-executor`** — executes plans produced by `/feature`
- **`/code-review`** — reviews code against the same conventions the planner checks
- **`/debug-operator`** — useful when the ticket is a bug and you need runtime analysis first
- **`/test-operator`** — run tests during or after plan execution

## Reference

- [Design spec](specs/2026-03-25-plan-feature-enhancement-design.md)
- [agents/feature/AGENT.md](../agents/feature/AGENT.md) — full planning methodology
- [agents/task-executor/AGENT.md](../agents/task-executor/AGENT.md) — execution principles
