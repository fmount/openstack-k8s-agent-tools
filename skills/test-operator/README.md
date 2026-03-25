# Test Operator Skill

Comprehensive testing, linting, and quality assurance for openstack-k8s-operators operators.

## Quick Start

```bash
# Quick tests (fast feedback loop)
./test-workflow.sh quick

# Standard tests (pre-commit)
./test-workflow.sh standard

# Full test suite (pre-PR)
./test-workflow.sh full

# Focused testing
./test-workflow.sh focus "Glance controller"

# Security scanning
./test-workflow.sh security

# Coverage analysis
./test-workflow.sh coverage
```

## Features

### Multi-Level Testing

- **Quick**: `make fmt + vet + tidy` (~10 seconds)
- **Standard**: Quick + `golangci + test` (~2-5 minutes)
- **Full**: Standard + `operator-lint + crd-schema-check` (~5-10 minutes)

### Ginkgo Integration

- Focused testing with patterns
- Parallel execution support
- Randomized test ordering
- Coverage generation

### Linting Levels

- `make fmt` - Code formatting
- `make vet` - Static analysis
- `make golangci` - Standard linting
- `make golangci-lint` - Full linting with auto-fix
- `make operator-lint` - Operator-specific checks

### Security Scanning

- `gosec` - Security vulnerability detection
- `govulncheck` - Known vulnerability scanning
- `staticcheck` - Advanced static analysis

### Auto-Fix

Automatically fixes common issues:

- Code formatting
- Import organization
- Dependency tidying
- Linting violations (where possible)

## Make Targets Reference

Based on openstack-k8s-operators operator Makefile conventions:

```makefile
# Testing
make test                                    # Full test suite
make test GINKGO_ARGS="--focus 'pattern'"  # Focused tests
make gotest                                  # Alias for test

# Formatting
make fmt                                     # go fmt
make gofmt                                   # Format check
make tidy                                    # go mod tidy

# Analysis
make vet                                     # go vet
make govet                                   # Enhanced vet
make operator-lint                           # Operator checks

# Linting
make golangci                                # Standard lint
make golangci-lint                           # Full lint + fix
make golint                                  # Additional lint

# Generation
make manifests                               # Generate CRDs
make generate                                # Generate code
make crd-schema-check                        # Validate schemas
```

## Usage in Claude Code

Invoke the skill:

```
/test-operator quick
/test-operator standard
/test-operator full
/test-operator focus "test pattern"
/test-operator lint
/test-operator security
/test-operator fix
```

## Workflow Integration

### Development Loop

1. Make changes
2. `./test-workflow.sh quick` (fast feedback)
3. Fix issues
4. Repeat

### Pre-Commit

1. `./test-workflow.sh standard`
2. Fix any failures
3. Commit changes

### Pre-PR

1. `./test-workflow.sh full`
2. `./test-workflow.sh security`
3. `./test-workflow.sh coverage`
4. Create pull request

## Tool Installation

Install recommended tools:

```bash
./test-workflow.sh install-tools
```

This installs:

- gosec
- govulncheck
- staticcheck
- goimports
- golangci-lint

## Examples

### Quick Development Feedback

```bash
# Fast iteration cycle
./test-workflow.sh quick
# Output shows: fmt ✓ vet ✓ tidy ✓
```

### Focused Test Development

```bash
# Work on specific test
./test-workflow.sh focus "initializes the status fields"
# Runs only matching tests with verbose output
```

### Pre-PR Validation

```bash
# Complete validation
./test-workflow.sh full
./test-workflow.sh security
./test-workflow.sh coverage

# Check coverage
go tool cover -html=coverage.out
```

### Auto-Fix Issues

```bash
# Apply automatic fixes
./test-workflow.sh fix

# Review changes
git diff
```

## Tips

1. **Use quick tests during development** for fast feedback
2. **Run standard tests before committing** to catch issues early
3. **Run full tests before creating PRs** to ensure quality
4. **Use focused tests** when working on specific features
5. **Check coverage regularly** to maintain >80%
6. **Fix linting issues** before they accumulate
7. **Run security scans** periodically

## Common Issues

### Test Failures

- Check `make test` output for specific failures
- Use focused tests to debug: `./test-workflow.sh focus "failing test"`
- Ensure test environment is clean

### Linting Errors

- Run `./test-workflow.sh fix` to auto-fix simple issues
- Check `.golangci.yaml` for configuration
- Review operator-lint output for pattern violations

### Coverage Too Low

- Identify uncovered code: `go tool cover -func=coverage.out`
- Add tests for uncovered paths
- Focus on critical code paths first

## Integration

Works with other openstack-k8s-operators operator tools:

- **debug-operator**: Use test failures to guide debugging
- **code-style**: Enforce style before testing
- **analyze-logs**: Parse test output for patterns
- **plan-feature**: Include tests in planning

## References

- [openstack-k8s-operators Development Docs](https://github.com/openstack-k8s-operators/dev-docs)
- [Ginkgo Testing Framework](https://onsi.github.io/ginkgo/)
- [golangci-lint](https://golangci-lint.run/)
- [Operator Best Practices](https://sdk.operatorframework.io/docs/best-practices/)
