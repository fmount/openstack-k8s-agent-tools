# openstack-k8s-operators Operator Tools

Claude Code plugin for [openstack-k8s-operators](https://github.com/openstack-k8s-operators/) development — debugging, testing, code review, feature planning, and plan execution.

## Installation

### Claude Code (recommended)

Install via the plugin marketplace:

```bash
/plugin install openstack-k8s-agent-tools
```

Or clone and install manually:

```bash
git clone https://github.com/openstack-k8s-operators/operator-tools.git
cd operator-tools
./scripts/install.sh --claude-code
```

### OpenCode

```bash
./scripts/install.sh --opencode
```

### Check dependencies

```bash
./scripts/install.sh --check
```

## Dependencies

| Dependency | Required | Purpose |
|-----------|----------|---------|
| Go toolchain | Yes | Operator development, tests, linting |
| make | Yes | Build system (make test, make manifests, etc.) |
| gh (GitHub CLI) | Optional | Cross-repo analysis in `/plan-feature` when local checkouts aren't available |
| Atlassian MCP | Optional | Jira ticket reading in `/plan-feature` — configure in Claude Code settings |
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
| `/plan-feature` | `plan-feature` | Feature/bug planning with Jira, cross-repo analysis, structured strategies |
| `/code-review` | `code-review` | Code review against openstack-k8s-operators conventions |
| `/task-executor` | `task-executor` | Execute plans task-by-task with checkpointing and resume |

Skills with an agent load an `AGENT.md` file that contains the full domain knowledge and methodology. Skills without an agent are self-contained in their `SKILL.md`.

## Quickstart

### Plan and implement a feature from a Jira ticket

```bash
cd ~/go/src/github.com/openstack-k8s-operators/heat-operator

# Plan from Jira (requires Atlassian MCP)
/plan-feature OSPRH-4567

# Or plan from a local spec file
/plan-feature docs/my-feature-spec.md
```

The skill fetches the ticket, analyzes your codebase and cross-references lib-common and peer operators, runs an 11-principle planning checklist, proposes implementation strategies, and produces a task breakdown. Then execute it:

```bash
/task-executor docs/plans/2026-03-25-OSPRH-4567-plan.md
```

See [docs/plan-feature.md](docs/plan-feature.md) for a full walkthrough.

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

# Review your changes
/code-review
```

### Debugging a deployed operator

```bash
# Systematic debugging workflow
/debug-operator nova-operator openstack

# Analyze collected logs
kubectl logs deployment/nova-operator -n openstack > nova.log
/analyze-logs nova.log
```

## Workflows

### Feature Development

```
 Jira ticket                  Spec file (.md)
      |                            |
      +----------+   +-------------+
                 |   |
            /plan-feature
            [agent: plan-feature]
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
          docs/plans/<plan>.md
                 |
            /task-executor
            [agent: task-executor]
                 |
     +-----------+-----------+
     |           |           |
   Group 1    Group 2    Group 3
  API changes Controller  Testing
     |           |           |
     +---each task-----------+
     |   write -> test -> checkpoint
     |   pause at group boundaries
     |
     +---> /test-operator full
     +---> /code-review [agent: code-review]
     +---> submit PR
```

### Bug Fix

```
  logs / error report
         |
    /analyze-logs ---------> pattern report
         |                   (25+ patterns)
    /debug-operator -------> diagnosis
         |                   (pods, events,
         |                    RBAC, conditions)
    /plan-feature OSPRH-XXX
    [agent: plan-feature]
         |
     +---+---+
     |       |
  root    regression
  cause   test plan
  hypothesis  |
     |        |
     +---+----+
         |
    docs/plans/<plan>.md
         |
    /task-executor --------> fix + tests
    [agent: task-executor]
         |
    /test-operator full ---> validate
         |
    /code-review ----------> review
    [agent: code-review]
         |
      submit PR
```

### Daily Development

```
                    +------------------+
                    |   write code     |<----------+
                    +--------+---------+           |
                             |                     |
                    /test-operator quick            |
                       fmt + vet + tidy             |
                             |                     |
                       pass? |                     |
                     +---yes-+--no--+              |
                     |              |              |
            /test-operator     fix issues ---------+
            focus "pattern"
                     |
                pass? |
              +--yes--+--no--+
              |              |
         /code-style    fix + iterate ----+
              |                           |
         /test-operator standard          |
           lint + full tests              |
              |                           |
         /code-review                     |
         [agent: code-review]             |
              |                           |
         verdict?                         |
      +--approve--+--changes--+-----------+
      |
   submit PR
```

### Skill Interaction Map

```
+-------------------------------------------------------------------+
|                        SKILLS & AGENTS                            |
+-------------------------------------------------------------------+
|                                                                   |
|  PLANNING & EXECUTION          QUALITY & REVIEW                   |
|  ~~~~~~~~~~~~~~~~~~~~          ~~~~~~~~~~~~~~~~                   |
|                                                                   |
|  /plan-feature -----+         /test-operator                      |
|  [plan-feature]     |           quick | standard | full           |
|       |              |              |                              |
|       v              |         /code-style                        |
|  docs/plans/         |           gopls modernize                  |
|       |              |              |                              |
|       v              |         /code-review                       |
|  /task-executor      |         [code-review]                      |
|  [task-executor]     |           10 review criteria               |
|       |              |                                            |
|       +--------------+----> uses during execution                 |
|                                                                   |
|  DEBUGGING & ANALYSIS          CODE UNDERSTANDING                 |
|  ~~~~~~~~~~~~~~~~~~~~          ~~~~~~~~~~~~~~~~~~                 |
|                                                                   |
|  /debug-operator               /explain-flow                      |
|    dev workflow                  reconciler logic                  |
|    runtime debug                 state transitions                |
|       |                          decision trees                   |
|       v                                                           |
|  /analyze-logs                                                    |
|    25+ patterns                                                   |
|    performance                                                    |
|    OpenStack-specific                                             |
|                                                                   |
+-------------------------------------------------------------------+
|                        AGENTS                                     |
+-------------------------------------------------------------------+
|                                                                   |
|  plan-feature     task-executor     code-review                   |
|  agents/          agents/           agents/                       |
|  plan-feature/    task-executor/    code-review/                  |
|  AGENT.md         AGENT.md          AGENT.md                     |
|                                                                   |
|  - input norm     - sequential      - reconciliation              |
|  - cross-repo       execution       - conditions                  |
|    analysis       - code quality     - webhooks                   |
|  - 11-principle     standards       - API design                  |
|    checklist      - test-first      - RBAC                        |
|  - strategies     - checkpoint      - testing                     |
|  - task breakdown - group review    - code style                  |
|                                                                   |
+-------------------------------------------------------------------+

  External integrations:
  ~~~~~~~~~~~~~~~~~~~~~~
  [Atlassian MCP] ---> /plan-feature (Jira tickets)
  [GitHub CLI]    ---> /plan-feature (cross-repo fallback)
  [lib-common]    ---> /plan-feature, /task-executor (pattern reuse)
  [dev-docs]      ---> /plan-feature, /code-review (conventions)
```

## Documentation

- **[Getting Started](docs/GETTING-STARTED.md)** — quick reference for all skills
- **[Plan Feature Guide](docs/plan-feature.md)** — detailed walkthrough with use case
- **[Development Guide](docs/DEVELOPMENT.md)** — extending the plugin with new skills
- **[CLAUDE.md](CLAUDE.md)** — project conventions and skill reference

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add skills following existing patterns (see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md))
4. Test with real openstack-k8s-operators operators
5. Submit a pull request

## License

MIT — see [LICENSE](LICENSE).
