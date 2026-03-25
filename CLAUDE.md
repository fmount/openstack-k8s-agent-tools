# openstack-k8s-operators Operator Tools - Claude Development Guide

This is a specialized Claude Code plugin for openstack-k8s-operators operators development and troubleshooting.

## Reference Documentation

For comprehensive openstack-k8s-operators operator development guidance, always refer to:
- **[openstack-k8s-operators/dev-docs](https://github.com/openstack-k8s-operators/dev-docs)** - Official development documentation
- **[lib-common](https://github.com/openstack-k8s-operators/lib-common)** - Shared libraries and patterns
- **[Operator development practices](https://github.com/openstack-k8s-operators/dev-docs/blob/main/developing.md)** - Development workflow guidelines

## Project Structure

```
openstack-k8s-agent-tools/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata and configuration
├── skills/                  # Skill definitions (SKILL.md only)
│   ├── debug-operator/      # Operator debugging workflows
│   ├── explain-flow/        # Code flow analysis
│   ├── plan-feature/        # Feature planning
│   ├── analyze-logs/        # Log analysis patterns
│   ├── code-style/          # Go code style enforcement
│   ├── test-operator/       # Testing and quality assurance
│   ├── code-review/         # Code review agent (skill entry point)
│   └── task-executor/       # Plan execution with checkpointing
├── agents/                  # Agent definitions
│   ├── code-review/         # openstack-k8s-operators code reviewer
│   ├── plan-feature/        # Feature planning methodology
│   └── task-executor/       # Plan execution guidelines
├── lib/                     # Shared helper scripts and tools
│   ├── dev-workflow.sh      # Development workflow automation
│   ├── test-workflow.sh     # Testing workflow automation
│   ├── debug-helpers.sh     # Debug utility functions
│   ├── style-analyzer.js    # Go code style analysis
│   ├── code-parser.js       # Operator code flow parser
│   ├── log-analyzer.js      # Log pattern analysis
│   └── log-patterns.json    # Log pattern definitions
└── scripts/                 # Utility scripts
    └── install.sh           # Cross-platform installer
```

## Available Skills

### `/debug-operator`
Systematic operator debugging workflow:
- Pod status verification
- Log analysis for errors
- Custom resource inspection
- Event timeline review

### `/explain-flow`
Code flow analysis for operators:
- Controller reconciliation logic
- Decision tree mapping
- State transition diagrams
- Error handling paths

### `/plan-feature`
Feature and bug fix planning with Jira integration:
- Fetch Jira tickets via Atlassian MCP (or use local spec files)
- Cross-repo analysis (lib-common, peer operators, dev-docs)
- Structured planning checklist (API, webhooks, conditions, tests, RBAC, etc.)
- 2-3 implementation strategies with trade-offs and recommendation
- Task breakdown grouped by functional area
- Plan files saved to `~/.local/share/openstack-k8s-agent-tools/plans/` per operator

### `/analyze-logs`
Intelligent log analysis:
- Error pattern recognition
- Performance issue detection
- Reconciliation behavior analysis
- Resource state tracking

### `/code-style`
Go code style enforcement:
- gopls modernize patterns
- openstack-k8s-operators operator conventions
- Controller-runtime best practices
- lib-common integration patterns

### `/test-operator`
Comprehensive testing and quality assurance:
- Multi-level testing workflows (quick/standard/full)
- Ginkgo focused testing support
- golangci-lint and operator-lint integration
- Security scanning (gosec, govulncheck)
- Test coverage analysis and reporting
- Auto-fix common issues

### `/code-review`
Code review agent for openstack-k8s-operators:
- Reconciliation patterns (finalizers, deferred status, return-after-update)
- Status conditions (severity/reason rules, ObservedGeneration)
- Webhook conventions (Spec-level Default/Validate, field paths)
- API design (override patterns, probes, topology/affinity)
- Testing (EnvTest, TestVector pattern, simulated dependencies)
- RBAC marker verification
- Structured review output with severity and verdict

### `/task-executor`
Execute implementation plans task-by-task:
- Load and resume plan files from `~/.local/share/openstack-k8s-agent-tools/plans/`
- Sequential task execution with checkpointing
- Code quality enforcement (gopls modernize, lib-common, conventions)
- Test-first for new reconciliation paths
- Group boundary review gates

## MCP Integrations

### Atlassian MCP (Optional)
The `/plan-feature` skill integrates with Atlassian MCP for Jira ticket reading. When configured, you can invoke `/plan-feature OSPRH-2345` to fetch and plan from a Jira ticket directly. Without it, the skill works with local spec files or pasted content.

Configure the Atlassian MCP server in your Claude Code settings to enable this integration.

## Development Guidelines

### When working with openstack-k8s-operators operators:

1. **Always start with systematic diagnosis** using `/debug-operator`
2. **Use TodoWrite** for complex tasks to track progress
3. **Follow development workflow** with make targets and testing
4. **Analyze logs methodically** with `/analyze-logs` for patterns
5. **Document code flow** when explaining complex controller logic
6. **Plan features carefully** using `/plan-feature` for new implementations
7. **Enforce code style** using `/code-style` for consistency and best practices

### Testing Commands

```bash
# Check dependencies and KUBECONFIG
./scripts/install.sh --check

# Test development workflow (in operator directory)
cd /path/to/operator
./lib/dev-workflow.sh run_full_workflow
./lib/dev-workflow.sh focus_test "Checks the Topology"

# Test code style analysis
node ./lib/style-analyzer.js controllers/controller.go

# Test in Claude Code
claude
/debug-operator
/code-style

# Run tests (if available)
npm test

# Lint and format
npm run lint
npm run format

# Build plugin
npm run build
```

### Installation Commands

```bash
# Install locally
./scripts/install.sh

# Install for Claude Code
/plugin install openstack-k8s-agent-tools

# Install for OpenCode (when available)
./scripts/install.sh --opencode
```

## Best Practices

1. **Always verify pod status first** before diving into logs
2. **Use grep patterns** to focus on relevant log entries
3. **Check custom resource conditions** for operator state
4. **Review Kubernetes events** for cluster-level issues
5. **Follow reconciliation patterns** when analyzing controller logic
6. **Document complex flows** with diagrams and step-by-step explanations

## Plugin Development

To extend this plugin with new skills, see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for:
- Creating new skills with SKILL.md format
- Helper script patterns
- Testing and integration
- Contributing guidelines
