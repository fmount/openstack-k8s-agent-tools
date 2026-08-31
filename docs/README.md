# openstack-k8s-operators Operator Tools - Documentation

Documentation for openstack-k8s-operators operator development and troubleshooting skills.

## Quick Start

- **[Getting Started](GETTING-STARTED.md)** - Quick reference for all skills
- **[MCP Setup](mcp-setup.md)** - Optional MCP server integrations (Jira)
- **[Development Guide](DEVELOPMENT.md)** - Extending the plugin

## Skills Overview

| Skill | Purpose | Quick Usage |
|-------|---------|-------------|
| **debug-operator** | Development workflow + testing | `/debug-operator` |
| **test-operator** | Testing & quality assurance | `/test-operator quick` |
| **code-style** | Go style enforcement | `/code-style` |
| **analyze-must-gather** | Must-gather archive analysis | `/analyze-must-gather` |
| **explain-flow** | Code flow analysis | `/explain-flow` |
| **onboarding-buddy** | Interactive operator onboarding | `/onboarding-buddy` |
| **feature** | Feature planning with Jira integration | `/feature OSPRH-2345` |
| **bug** | Bug fix planning (alias for feature) | `/bug OSPRH-2345` |
| **task-executor** | Plan execution with checkpointing | `/task-executor` |
| **code-review** | Code review (dev-docs conventions) | `/code-review` |
| **backport-review** | Downstream vs upstream patch comparison | `/backport-review` |
| **jira** | Jira hierarchy validation and integration | `/jira OSPRH-2345` |

## Common Workflows

### Development

```bash
/test-operator quick              # Fast validation
/debug-operator focus-test "..."  # Focused testing
```

### Pre-Commit

```bash
/test-operator standard
/code-style
```

### Pre-PR

```bash
/debug-operator
/test-operator full
/test-operator security
/code-review
```

## Integration

All skills integrate with:

- [openstack-k8s-operators/dev-docs](https://github.com/openstack-k8s-operators/dev-docs)
- [lib-common](https://github.com/openstack-k8s-operators/lib-common)
- Ginkgo testing framework
- Controller-runtime best practices

## Design

Architecture and design decisions behind the plugin:

- **[Feature Planning](design/feature.md)** - How `/feature` works: input routing, cross-repo analysis, strategy evaluation
- **[Memory Architecture](design/memory-docs.md)** - Shared memory, state tracking, worktrees, and dependency resolution

## Troubleshooting

**Skills not showing in Claude Code**: Ensure they are in `.claude/skills/`
and restart Claude Code.

**Skills not showing in Codex**: Run `/skills` or type `$` to check the skill
selector, then restart Codex. If the skills are still absent, invoke
`$skill-installer` again with the repository URL from the installation guide.

**Make targets fail**: Verify in operator directory with Makefile

**Permissions**: `chmod +x scripts/*.sh`

Use the following skills to understand more about the failure:

```bash
/debug-operator
/explain-flow
```

## Additional Resources

- [AGENTS.md](../AGENTS.md) - Project conventions for AI agents
- [README.md](../README.md) - Project overview
