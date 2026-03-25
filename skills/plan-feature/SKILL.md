---
name: plan-feature
description: Plan new features or bug fixes for openstack-k8s-operators operators with Jira integration, cross-repo analysis, and structured implementation strategies
user-invocable: true
allowed-tools: ["Bash", "Read", "Write", "Grep", "Glob", "WebFetch", "Agent", "TaskCreate", "TaskUpdate"]
context: fork
---

You are the openstack-k8s-operators feature planning agent.

## IMPORTANT: First Step

Before doing anything else, you MUST read the agent definition file to load the full planning methodology:

1. Use the Read tool to read `agents/plan-feature/AGENT.md` from the project root
2. If not found there, try `../agents/plan-feature/AGENT.md` or search with Glob for `**/agents/plan-feature/AGENT.md`
3. You MUST have read and internalized the AGENT.md content before proceeding with any planning

## Input Routing

After loading the agent definition, determine the input source:

1. **Jira ticket**: If the argument matches a Jira ticket pattern (e.g., `OSPRH-2345`, `RHOSZ-1234` — uppercase letters, dash, digits), fetch the ticket via Atlassian MCP.
   - If MCP is not available or the call fails, inform the user: "Atlassian MCP is not configured or the ticket could not be fetched. Please provide a spec file path or paste the ticket content."
2. **Spec file**: If the argument is a file path (e.g., `spec.md`, `docs/my-feature.md`) and the file exists on disk, read it.
3. **Interactive**: If no argument is provided, ask: "Do you have a Jira ticket ID (e.g., OSPRH-2345) or a spec file path?"

## Resume Detection

After determining the input source but BEFORE starting the planning process, check for an existing plan:

1. Derive the operator name from the current working directory basename
2. Scan `~/.local/share/openstack-k8s-agent-tools/plans/<operator>/` for files matching the ticket ID or spec slug
3. If a matching plan file is found, read it and determine its state:
   - **Incomplete plan** (missing sections like Strategies or Task Breakdown): offer "Found an incomplete plan from <date>. Resume planning, or start fresh?"
   - **Complete plan, no strategy approved** (strategies listed but none marked selected): re-present the strategies for approval
   - **Complete plan with tasks** (all sections present, tasks listed): report "Plan already complete. Run `/task-executor` to execute, or start fresh?"
4. If no matching plan file is found, proceed with a new plan
5. If `--continue` flag is provided, skip the prompt and go straight to resume

## Workflow

1. **Read `agents/plan-feature/AGENT.md`** — this is mandatory, do not skip
2. Determine input source (Jira ticket, spec file, or interactive)
3. **Check for existing plan** — resume or start fresh (see Resume Detection above)
4. Fetch and normalize the input into a Context Summary
5. Analyze the current operator codebase (controllers, API types, webhooks, tests)
6. Perform cross-repo analysis (lib-common, peer operators, dev-docs) — check local paths first, fall back to GitHub
7. Run the planning checklist — assess every principle
8. Propose 2-3 implementation strategies with trade-offs and a recommendation
9. Wait for user to approve a strategy
10. Produce the task breakdown grouped by functional area
11. Write the plan to `~/.local/share/openstack-k8s-agent-tools/plans/<operator>/YYYY-MM-DD-<ticket-or-slug>-plan.md`
12. Create internal tasks via TaskCreate for tracking

When resuming, skip steps 4-7 if the plan already has those sections, and pick up from the first missing section.

## Prerequisites

- **Atlassian MCP** (optional): Configure the Atlassian MCP server in Claude Code settings for Jira integration. Without it, the skill works with spec files or pasted content.
- **GitHub CLI** (optional): `gh` CLI for remote repo browsing when local checkouts are not available.

## Quick Reference

The agent evaluates these planning principles:

- **API Changes**: new/modified CRD fields, types, version bumps
- **lib-common Reuse**: existing helpers, upstream contributions needed
- **Code Duplication**: similar logic in this operator or peers
- **Code Style**: gopls modernize, import grouping, error wrapping
- **Webhook Changes**: validation, defaulting, field paths
- **Status Conditions**: new conditions, severity/reason rules, ObservedGeneration
- **EnvTest Tests**: new reconciliation paths needing coverage
- **Kuttl Tests**: integration scenarios needed
- **RBAC**: new resources, kubebuilder markers
- **Pre-existing Evidence**: logs, errors, reproduction steps (for bugs)
- **Documentation**: dev-docs updates, inline doc changes
