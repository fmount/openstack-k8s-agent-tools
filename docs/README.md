# openstack-k8s-operators Operator Tools - Documentation

Documentation for openstack-k8s-operators operator development and troubleshooting skills.

## Quick Start

**[Getting Started](GETTING-STARTED.md)** - Quick reference for all skills

**Skill Details** - See individual SKILL.md files in `../skills/*/SKILL.md`

## Installation

```bash
cd /path/to/openstack-k8s-agent-tools
./scripts/install.sh --claude-code

# For operator projects
cd /path/to/your-operator
cp -r /path/to/openstack-k8s-agent-tools/skills .claude/
cp /path/to/openstack-k8s-agent-tools/CLAUDE.md .
```

## Skills Overview

| Skill | Purpose | Quick Usage |
|-------|---------|-------------|
| **debug-operator** | Development workflow + testing | `/debug-operator` |
| **test-operator** | Testing & quality assurance | `/test-operator quick` |
| **code-style** | Go style enforcement | `/code-style` |
| **analyze-logs** | Log pattern analysis | `/analyze-logs` |
| **explain-flow** | Code flow analysis | `/explain-flow` |
| **plan-feature** | Feature planning | `/plan-feature` |

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
```

## Integration

All skills integrate with:

- [openstack-k8s-operators/dev-docs](https://github.com/openstack-k8s-operators/dev-docs)
- [lib-common](https://github.com/openstack-k8s-operators/lib-common)
- Ginkgo testing framework
- Controller-runtime best practices

## Troubleshooting

**Skills not showing**: Ensure in `.claude/skills/` and restart Claude

**Make targets fail**: Verify in operator directory with Makefile

**Permissions**: `chmod +x skills/**/*.sh scripts/*.sh`

Use the following skills to understand more about the failure:

```bash
/analyze-logs
/explain-flow
```

## Additional Resources

- [CLAUDE.md](../CLAUDE.md) - Development guidelines
- [README.md](../README.md) - Project overview
- [Getting Started](GETTING-STARTED.md) - Quick reference
- [DEVELOPMENT.md](DEVELOPMENT.md) - Plugin development guide
