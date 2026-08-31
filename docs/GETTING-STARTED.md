# Getting Started

## Installation

```bash
# Claude Code (recommended)
claude plugin marketplace add https://github.com/openstack-k8s-operators/devskills
claude plugin install openstack-k8s-agent-tools

# Manual install
make install-claude
```

For Codex, start Codex and use its built-in skill installer:

```text
$skill-installer Install all skills from https://github.com/openstack-k8s-operators/devskills
```

Codex detects newly installed skills automatically. Restart Codex if they do
not appear. Run `/skills` or type `$` to select a skill. For example:

```text
$openstack-k8s-agent-tools:code-review 438
```

The examples below use Claude Code's `/skill-name` notation. In Codex, select
the corresponding `openstack-k8s-agent-tools` skill with `$` instead.

## Skills Quick Reference

| Skill | Usage | Purpose |
|-------|-------|---------|
| `/debug-operator` | `/debug-operator [name] [ns]` | Development workflow + runtime debugging |
| `/test-operator` | `/test-operator quick\|standard\|full` | Testing & QA |
| `/code-style` | `/code-style` | Go style enforcement |
| `/analyze-must-gather` | `/analyze-must-gather` | Must-gather archive analysis |
| `/explain-flow` | `/explain-flow` | Code flow analysis |
| `/onboarding-buddy` | `/onboarding-buddy` | Interactive operator onboarding and repo tour |
| `/feature` | `/feature OSPRH-2345` | Feature planning with Jira |
| `/bug` | `/bug OSPRH-2345` | Bug fix planning |
| `/task-executor` | `/task-executor` | Plan execution with checkpointing |
| `/code-review` | `/code-review 438` | Code review |
| `/backport-review` | `/backport-review` | Downstream vs upstream comparison |
| `/jira` | `/jira OSPRH-2345` | Jira hierarchy validation |

## Feature Planning and Execution

```bash
cd ~/go/src/github.com/openstack-k8s-operators/glance-operator

# Plan from Jira (requires Atlassian MCP)
/feature OSPRH-4567

# Or plan from a local spec file
/feature docs/my-feature-spec.md
```

The skill fetches the ticket, analyzes your codebase and cross-references
lib-common and peer operators, runs an 11-principle planning checklist,
proposes implementation strategies, and produces a task breakdown.
Then execute it:

```bash
/task-executor   # discovers plans for current operator automatically
```

See [design/feature.md](design/feature.md) for a full walkthrough.

## Development Loop

```bash
# Fast feedback while coding
/test-operator quick

# Run focused tests
/test-operator focus "Checks the Topology"

# Check code style
/code-style
```

## Pre-PR Validation

```bash
# Full test suite + linting + security
/test-operator full

# Review a PR by number
/code-review 438

# Review a branch diff against main
/code-review my-feature-branch

# Review specific files
/code-review controllers/glanceapi_controller.go api/v1beta1/glance_types.go
```

When only a number is provided, the skill uses `gh pr diff <number>` to
fetch the PR. If `gh` is not available, it falls back to WebFetch.

## Debugging a Deployed Operator

```bash
# Systematic debugging workflow
/debug-operator glance-operator openstack-operators

# Analyze collected logs
oc logs deployment/glance-operator -n openstack-operators > glance.log
# Then ask /debug-operator to analyze it
```

## Common Workflows

**Feature development**:

```
/feature OSPRH-2345 --> /task-executor --> /test-operator full --> /code-review --> PR
```

**Bug fix**:

```
/debug-operator --> /bug OSPRH-XXX --> /task-executor --> /test-operator full --> PR
```

**Daily development**:

```
write code --> /test-operator quick --> /test-operator focus "..." --> /code-style --> /code-review --> PR
```

## Tips

- Use `quick` for fast feedback during development
- Focused tests speed up iteration: `/test-operator focus "pattern"`
- Auto-fix before manual fixes: `/test-operator fix`
- `/code-style` catches issues before `/code-review` does
