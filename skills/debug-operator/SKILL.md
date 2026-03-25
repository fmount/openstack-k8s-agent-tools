---
name: debug-operator
description: Debug and develop openstack-k8s-operators operators with comprehensive workflows including make targets, tests, and deployments
user-invocable: true
allowed-tools: ["Bash", "Read", "Grep", "LS", "TodoWrite"]
context: fork
---

# Debug openstack-k8s-operators Operator

This skill provides comprehensive debugging and development workflows for openstack-k8s-operators operators, following openstack-k8s-operators best practices.

## Development Workflow

When debugging or developing an operator, I will:

1. **Development Checks**: Run full development workflow with make targets
2. **Code Quality**: Pre-commit hooks, linting, and syntax validation
3. **Build Verification**: Test compilation and manifest generation
4. **Test Execution**: Run complete test suites or focused tests
5. **Deployment Analysis**: Check running operator pods and resources
6. **Runtime Debugging**: Analyze logs, events, and runtime issues

## Development Commands

The skill includes automated workflows (`dev-workflow.sh`) for:

### Complete Workflow

- `run_full_workflow` - End-to-end development validation
- `run_precommit_checks` - Syntax and style validation
- `generate_manifests` - Run `make manifests && make generate`
- `check_build` - Verify operator compilation

### Testing

- `run_operator_tests` - Execute `make test`
- `focus_test '<pattern>'` - Run specific tests with Ginkgo focus
- `check_test_coverage` - Generate test coverage reports
- `show_tests` - List available test patterns

### Quality Assurance

- `run_linting` - Code style and quality checks
- `check_go_modules` - Validate dependencies with `go mod`
- `validate_crds` - Validate Custom Resource Definitions

## Runtime Debugging

For deployed operators, I will also:

1. **Environment Check**: Verify KUBECONFIG and cluster access
2. **Operator Discovery**: Find operator pods in standard namespaces
3. **Status Analysis**: Check deployment, pod, and replica set status
4. **Log Analysis**: Parse logs for errors, warnings, and patterns
5. **Resource Inspection**: Examine custom resources and their conditions
6. **Event Review**: Check Kubernetes events for issues
7. **RBAC Verification**: Ensure proper permissions are in place

When debugging deployed operators:

```bash
# Debug specific operator
/debug-operator nova-operator openstack

# General cluster debugging
/debug-operator cluster-check
```

## Automated Analysis

I will automatically:

- Detect if we're in an operator development directory
- Run appropriate development workflow based on context
- Search for operators in standard namespaces (openstack, openstack-operators, openstack-k8s-operators)
- Identify error patterns in logs using regex matching
- Check custom resource status and conditions
- Review recent events for warnings and errors
- Verify RBAC configuration

## Helper Scripts

The skill includes helper functions for:

```bash
# Environment verification
check_kubeconfig

# Operator discovery
get_operator_pods

# Deployment analysis
check_operator_deployment <name> [namespace]

# Log pattern analysis
analyze_operator_logs <pod> <namespace> [lines]

# Custom resource inspection
check_custom_resources [pattern]

# RBAC verification
check_operator_rbac <name> [namespace]

# Event analysis
get_operator_events [namespace] [hours]
```

## Usage Examples

### Development Mode

When in an operator directory (with Makefile and go.mod):

```bash
# Run complete development workflow
/debug-operator

# Focus on specific test
/debug-operator focus-test "Checks the Topology"

# Run only tests
/debug-operator test-only
```

## Workflow Detection

I will automatically:

1. **Detect Context**: Check if we're in development or runtime mode
2. **Run Appropriate Workflow**: Development checks vs. runtime debugging
3. **Provide Specific Guidance**: Targeted recommendations based on findings
4. **Create Action Items**: Use TodoWrite for tracking fixes and improvements

## Integration with openstack-k8s-operators Ecosystem

The skill integrates with:

- **openstack-k8s-operators** development practices
- **lib-common** patterns and conventions
- **Ginkgo** testing framework workflows
- **Controller-runtime** debugging patterns

## Common Issues Detected

- Pod crash loops and restart issues
- Image pull failures
- RBAC permission problems
- Custom resource validation errors
- Controller reconciliation failures
- Resource conflicts and dependencies
- Webhook configuration issues

Always start with this skill for any operator debugging to ensure comprehensive analysis.
