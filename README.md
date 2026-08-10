# openstack-k8s-operators Operator Tools

Claude Code plugin for [openstack-k8s-operators](https://github.com/openstack-k8s-operators/) development — debugging, testing, code review, feature planning, and plan execution.

[![asciicast](https://asciinema.org/a/886205.svg)](https://asciinema.org/a/886205)

## Installation

### Claude Code (recommended)

Add the marketplace and install the plugin (two steps):

```bash
claude plugin marketplace add https://github.com/openstack-k8s-operators/devskills
claude plugin install openstack-k8s-agent-tools
```

To update to the latest version:

```bash
claude plugin update openstack-k8s-agent-tools@openstack-k8s-agent-tools
```

### Cursor

Cursor reads Claude Code plugins from `~/.claude/plugins/cache/` automatically.
If you have the Claude Code CLI installed, run the same marketplace commands:

```bash
claude plugin marketplace add https://github.com/openstack-k8s-operators/devskills
claude plugin install openstack-k8s-agent-tools
```

Restart Cursor after installing. Skills will appear in Cursor's agent skill
list and can be invoked from chat.

If you do not have the Claude Code CLI, clone the repo and use the manual
install target instead:

```bash
git clone https://github.com/openstack-k8s-operators/devskills.git
cd openstack-k8s-agent-tools
make install-claude
```

This copies skills to `~/.claude/skills/` and agents to `~/.claude/agents/`,
which Cursor also discovers.

### OpenCode

```bash
git clone https://github.com/openstack-k8s-operators/devskills.git
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
| `/debug-operator` | — | Development workflow + runtime debugging + log analysis |
| `/test-operator` | — | Testing & QA — quick, standard, full, security, coverage |
| `/code-style` | — | Go code style enforcement (gopls modernize, conventions) |
| `/analyze-must-gather` | `support-triage` (optional) | Analyze must-gather archives; dispatches RHOSO triage when OpenStack resources detected |
| `/support-triage` | `support-triage` | RHOSO must-gather triage using omc and Support Enablement diagnostics |
| `/analyze-zuul-ci-logs` | — | Analyze logs downloaded from a Zuul CI job |
| `/explain-flow` | — | Code flow analysis for controllers |
| `/onboarding-buddy` | — | Interactive onboarding — operator fundamentals and repo tour (uses `/explain-flow` for code traces) |
| `/feature` | `feature` | Feature/bug planning with Jira, cross-repo analysis, structured strategies |
| `/bug` | `feature` | Bug fix planning — alias for `/feature` with bug-focused context |
| `/code-review` | `code-review` | Code review against openstack-k8s-operators conventions (PR number, branch diff, or specific files) |
| `/create-dt` | `create-dt` | Scaffold RHOSO Deployment Topologies/Validated Architectures for the architecture repo with existing DT/VA analysis and automation |
| `/task-executor` | `task-executor` | Execute plans task-by-task with checkpointing and resume |
| `/backport-review` | — | Compare downstream backport change requests against upstream Gerrit patches |
| `/jira` | — | Jira integration — ticket inspection, hierarchy validation, outcome posting |
| `/generate-containerfile` | — | Generate Containerfiles for OpenStack service images from tcib/kolla/rdo analysis |

Skills with an agent load an `AGENT.md` file that contains the full domain knowledge and methodology. Skills without an agent are self-contained in their `SKILL.md`.

## Skill Architecture

This plugin uses two patterns for skills. Choosing the right one up front
avoids rework later.

**Self-contained** -- all logic lives in `SKILL.md`. Good for straightforward
workflows that don't need deep domain knowledge (e.g.,
`skills/code-style/SKILL.md`).

**Agent-backed** -- `SKILL.md` handles input routing and orchestration, then
dispatches an `AGENT.md` that holds the domain methodology. Use this when the
skill needs complex evaluation criteria, multi-step analysis, or reusable
expertise that benefits from isolated context (e.g.,
`skills/code-review/SKILL.md` + `agents/code-review/AGENT.md`). Note that the
parent conversation only receives the agent's summary, so detailed
intermediate findings stay in the sub-agent's context. If follow-up
discussion on the full analysis is expected, consider keeping the logic
self-contained. The dispatch looks like:

```
Agent(subagent_type="openstack-k8s-agent-tools:<name>:<name>", ...)
```

> **OpenCode users:** write skills using the Claude Code dispatch syntax above.
> `make install-opencode` automatically converts it to the `@name` mention
> form that OpenCode expects.

When scaffolding an agent-backed skill, run both `make new-skill` and
`make new-agent`, and add `"Agent"` to the skill's `allowed-tools` list.

See the [Development Guide](docs/DEVELOPMENT.md) for the full architecture
walkthrough, flow diagrams, and AGENT.md frontmatter reference.

## Quickstart

### Create a new skill or agent

```bash
# Scaffold a new skill
make new-skill my-skill

# Scaffold a new agent
make new-agent my-agent

# Validate structure
make validate
```

See the [DEVELOPMENT](docs/DEVELOPMENT.md) guide for more details on extending
the plugin.

For usage examples, workflows, and skill reference, see the [GETTING-STARTED](docs/GETTING-STARTED.md) guide.

## Evals

Behavioral testing for skills using [promptfoo](https://promptfoo.dev)
with the `claude-agent-sdk` provider. Each skill has a self-contained
eval directory with prompt templates, Go fixtures, and score-based
Python graders.

```bash
make eval-setup                      # install dependencies (one-time)
make eval EVAL_SKILL=code-review     # run evals for one skill
make eval                            # run all evals
make new-eval my-skill               # scaffold eval for a new skill
```

See the [Evals README](evals/README.md) for framework details, test
tiers, grader conventions, and per-skill documentation.

## Documentation

- **[Getting Started](docs/GETTING-STARTED.md)** — usage examples, workflows, and skill reference
- **[MCP Setup](docs/mcp-setup.md)** — Atlassian MCP configuration for Jira integration
- **[Development Guide](docs/DEVELOPMENT.md)** — extending the plugin with new skills
- **[Feature Planning](docs/design/feature.md)** — detailed walkthrough with use case
- **[Memory and State](docs/design/memory-docs.md)** — shared memory, state tracking, worktrees, dependencies
- **[AGENTS.md](AGENTS.md)** — project conventions for AI agents

## Roadmap

- [x] `install.sh` — manual installation script with platform support (Claude Code, OpenCode)
- [x] Code review accepts PR number, branch, or specific files
- [x] Shared memory (MEMORY.md), state tracking (state.json), worktree isolation, dependency resolution
- [x] `/analyze-must-gather` — must-gather archive analysis
- [x] `/bug` — bug fix planning alias
- [x] `make new-skill` / `make new-agent` — scaffold new skills and agents
- [ ] Guidelines on sandboxing
- [ ] Jira sub-task export from task breakdowns
- [ ] Plan diffing (detect Jira ticket changes after plan creation)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
