# openstack-k8s-operators Operator Tools

Claude Code plugin for [openstack-k8s-operators](https://github.com/openstack-k8s-operators/) development — debugging, testing, code review, feature planning, and plan execution.

## Installation

### Claude Code (recommended)

Add the marketplace and install the plugin (two steps):

```bash
claude plugin marketplace add https://github.com/fmount/openstack-k8s-agent-tools
claude plugin install openstack-k8s-agent-tools
```

To update to the latest version:

```bash
claude plugin update openstack-k8s-agent-tools
```

### OpenCode

```bash
git clone https://github.com/fmount/openstack-k8s-agent-tools.git
cd openstack-k8s-agent-tools
make install-opencode
```

### Manual install (Claude Code, without marketplace)

```bash
make install-claude
```

## Dependencies

| Dependency | Required | Purpose |
|-----------|----------|---------|
| Go toolchain | Yes | Operator development, tests, linting |
| make | Yes | Build system (make test, make manifests, etc.) |
| gh (GitHub CLI) | Optional | Cross-repo analysis in `/feature` when local checkouts aren't available |
| Atlassian MCP | Optional | Jira integration for `/feature` and `/jira` - see [MCP Setup](docs/mcp-setup.md) |
| golangci-lint | Optional | Enhanced linting in `/test-operator` |
| gosec, govulncheck | Optional | Security scanning in `/test-operator security` |

## Skills

| Skill | Agent | Purpose |
|-------|-------|---------|
| `/debug-operator` | — | Development workflow + runtime debugging |
| `/test-operator` | — | Testing & QA — quick, standard, full, security, coverage |
| `/code-style` | — | Go code style enforcement (gopls modernize, conventions) |
| `/analyze-logs` | — | Log pattern recognition (25+ patterns) |
| `/explain-flow` | — | Code flow analysis for controllers |
| `/feature` | `feature` | Feature/bug planning with Jira, cross-repo analysis, structured strategies |
| `/code-review` | `code-review` | Code review against openstack-k8s-operators conventions (PR number, branch diff, or specific files) |
| `/task-executor` | `task-executor` | Execute plans task-by-task with checkpointing and resume |
| `/jira` | — | Jira integration — ticket inspection, hierarchy validation, outcome posting |

Skills with an agent load an `AGENT.md` file that contains the full domain knowledge and methodology. Skills without an agent are self-contained in their `SKILL.md`.

## Quickstart

### Plan and implement a feature from a Jira ticket

```bash
cd ~/go/src/github.com/openstack-k8s-operators/glance-operator

# Plan from Jira (requires Atlassian MCP)
/feature OSPRH-4567

# Or plan from a local spec file
/feature docs/my-feature-spec.md
```

The skill fetches the ticket, analyzes your codebase and cross-references lib-common and peer operators, runs an 11-principle planning checklist, proposes implementation strategies, and produces a task breakdown. Then execute it:

```bash
/task-executor   # discovers plans for current operator automatically
```

See [docs/feature.md](docs/feature.md) for a full walkthrough.

### Development loop

```bash
# Fast feedback while coding
/test-operator quick

# Run focused tests
/test-operator focus "Checks the Topology"

# Check code style
/code-style
```

### Pre-PR validation

```bash
# Full test suite + linting + security
/test-operator full

# Review a PR by number (uses gh cli on the current repository)
/code-review 438

# Review a branch diff against main
/code-review my-feature-branch

# Review specific files
/code-review controllers/glanceapi_controller.go api/v1beta1/glance_types.go
```

When only a number is provided, the skill uses `gh pr diff <number>` to fetch the PR from the current repository. If `gh` is not available, it falls back to WebFetch. See [docs/feature.md](docs/feature.md) for details.

### Debugging a deployed operator

```bash
# Systematic debugging workflow
/debug-operator nova-operator openstack

# Analyze collected logs
kubectl logs deployment/nova-operator -n openstack > nova.log
/analyze-logs nova.log
```

## Workflows

These are the most common development workflows. Each combines multiple skills to cover the full lifecycle.

### Feature Development

```
/feature OSPRH-2345 --> /task-executor --> /test-operator full --> /code-review --> PR
```

```
+------------------------------------------------------------------------+
|                                                                        |
|  PLANNING & EXECUTION          QUALITY & REVIEW                        |
|                                                                        |
|  /feature ----------+         /test-operator                           |
|  [feature agent]    |           quick | standard | full                |
|       |             |                |                                 |
|       v             |         /code-style                              |
|  ~/.local/share/    |           gopls modernize                        |
|    .../plans/       |                |                                 |
|       |             |         /code-review                             |
|       v             |         [code-review agent]                      |
|  /task-executor     |                                                  |
|  [task-executor] ---+----> uses during execution                       |
|       |                                                                |
|  /jira                       DEBUGGING & ANALYSIS                      |
|    hierarchy rules                                                     |
|    outcome posting           /debug-operator                           |
|    [preloaded into              dev workflow | runtime debug            |
|     feature and                    |                                   |
|     task-executor]           /analyze-logs                             |
|                                 25+ error patterns                     |
|                                                                        |
|                              /explain-flow                             |
|                                 reconciler logic                       |
|                                                                        |
+------------------------------------------------------------------------+
|  AGENTS              | EXTERNAL INTEGRATIONS                           |
|  feature             | [Atlassian MCP] --> /feature, /jira (Jira)      |
|  task-executor       | [GitHub CLI]    --> /feature (repos)             |
|  code-review         | [lib-common]    --> plan + execute (reuse)       |
|                      | [dev-docs]      --> plan + review (conventions)  |
+------------------------------------------------------------------------+
```

See [docs/feature.md](docs/feature.md) for detailed flow diagrams.

### Bug Fix

```
/analyze-logs --> /debug-operator --> /feature OSPRH-XXX --> /task-executor --> /test-operator full --> PR
```

### Daily Development

```
write code --> /test-operator quick --> /test-operator focus "..." --> /code-style --> /code-review --> PR
```

More workflows documented under [docs/](docs/).

## Documentation

- **[Getting Started](docs/GETTING-STARTED.md)** — quick reference for all skills
- **[Feature Planning Guide](docs/feature.md)** — detailed walkthrough with use case
- **[MCP Setup](docs/mcp-setup.md)** — Atlassian MCP configuration for Jira integration
- **[Development Guide](docs/DEVELOPMENT.md)** — extending the plugin with new skills
- **[Memory and State](docs/memory-docs.md)** — shared memory, state tracking, worktrees, dependencies
- **[CLAUDE.md](CLAUDE.md)** — project conventions and skill reference

## Roadmap

- [x] `install.sh` — manual installation script with platform support (Claude Code, OpenCode)
- [ ] Improve code review to take a PR number
- [x] Shared memory (MEMORY.md), state tracking (state.json), worktree isolation, dependency resolution
- [ ] Jira sub-task export from task breakdowns
- [ ] Plan diffing (detect Jira ticket changes after plan creation)
- [ ] Improve docs/ with a section about TOKENS
- [ ] Guidelines on sandboxing

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
