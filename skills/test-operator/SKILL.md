---
name: test-operator
description: Comprehensive testing, linting, and quality assurance for openstack-k8s-operators operators with Go best practices
user-invocable: true
allowed-tools: ["Bash", "Read", "Grep", "Glob", "TaskCreate", "TaskUpdate"]
context: fork
---

# Test Operator - Quality Assurance & Testing

This skill provides comprehensive testing, linting, and quality assurance workflows for openstack-k8s-operators operators, following Go and Kubernetes operator best practices.

## Testing Workflow

When testing an operator, I will systematically:

1. **Code Formatting**: Ensure consistent code style with `go fmt`
2. **Static Analysis**: Run `go vet` to catch common mistakes
3. **Linting**: Execute golangci-lint with comprehensive checks
4. **Unit Tests**: Run Ginkgo test suites with proper coverage
5. **Security Scanning**: Check for vulnerabilities and security issues
6. **CRD Validation**: Verify Custom Resource Definition schemas
7. **Operator-Specific Checks**: Run operator-lint for controller patterns

## Available Make Targets

Based on the openstack-k8s-operators operator Makefile conventions:

### Core Testing

```bash
make test              # Run full test suite with Ginkgo
make gotest            # Alias for test
make test GINKGO_ARGS="--focus 'pattern'"  # Focused tests
```

### Code Formatting

```bash
make fmt               # Run go fmt
make gofmt             # Run gofmt via CI tools (with checks)
make tidy              # Run go mod tidy
```

### Static Analysis

```bash
make vet               # Run go vet
make govet             # Run govet via CI tools
make operator-lint     # Run operator-specific linting
```

### Linting (Multiple Levels)

```bash
make golangci          # Standard golangci-lint checks
make golangci-lint     # Direct golangci-lint with --fix
make golint            # Additional Go linting
```

### Code Generation & Validation

```bash
make manifests         # Generate CRDs, webhooks, RBAC
make generate          # Generate DeepCopy methods
make crd-schema-check  # Validate CRD schema changes
```

## Comprehensive Quality Check

I will run a complete quality check workflow:

### Level 1: Quick Checks (Fast Feedback)

1. `make fmt` - Format code
2. `make vet` - Static analysis
3. Quick syntax validation

### Level 2: Standard Checks (Pre-commit)

1. `make gofmt` - Format validation
2. `make govet` - Enhanced static analysis
3. `make golangci` - Standard linting
4. `make tidy` - Dependency check

### Level 3: Comprehensive Checks (Pre-PR)

1. `make golangci-lint` - Full linting with auto-fix
2. `make operator-lint` - Operator-specific patterns
3. `make test` - Full test suite
4. `make crd-schema-check` - Schema validation

### Level 4: Security & Advanced (CI/CD)

1. Security scanning (gosec, staticcheck)
2. Vulnerability detection (govulncheck)
3. Code complexity analysis (gocyclo)
4. Test coverage analysis

## Ginkgo Testing Patterns

### Basic Test Execution

```bash
# Run all tests
make test

# Run with specific Ginkgo args
make test GINKGO_ARGS="-v --trace"

# Focus on specific tests
make test GINKGO_ARGS="--focus 'Glance controller'"

# Run tests in parallel
make test GINKGO_ARGS="--procs 4"

# Randomize test order
make test GINKGO_ARGS="--randomize-all"
```

### Advanced Ginkgo Usage

```bash
# Focused testing with pattern
make test GINKGO_ARGS="--focus 'initializes the status fields'"

# Skip specific tests
make test GINKGO_ARGS="--skip 'webhook validation'"

# Dry run (show which tests would run)
make test GINKGO_ARGS="--dry-run --focus 'pattern'"

# Generate test coverage
make test GINKGO_ARGS="--cover --coverprofile=coverage.out"

# Verbose output with trace
make test GINKGO_ARGS="-v --trace --output-interceptor-mode=none"
```

## Golangci-lint Configuration

The skill recognizes common golangci-lint checks:

### Enabled Linters (Recommended)

- **errcheck**: Check for unchecked errors
- **gosimple**: Simplify code
- **govet**: Report suspicious constructs
- **ineffassign**: Detect ineffectual assignments
- **staticcheck**: Static analysis checks
- **unused**: Find unused code
- **typecheck**: Type-checking errors
- **gocritic**: Comprehensive Go linter
- **gofmt**: Check code formatting
- **goimports**: Check import formatting

### Security & Quality Linters

- **gosec**: Security issues detection
- **revive**: Fast, extensible linter
- **stylecheck**: Style consistency
- **unconvert**: Remove unnecessary type conversions
- **misspell**: Spelling errors
- **dupl**: Code duplication detection
- **gocyclo**: Cyclomatic complexity

### Operator-Specific Checks

- **operator-lint**: Kubernetes operator patterns
- Custom rules for controller-runtime
- Finalizer usage validation
- Status condition patterns

## Security Scanning

I will run security-focused tools:

```bash
# Install and run gosec
go install github.com/securego/gosec/v2/cmd/gosec@latest
gosec -fmt=json -out=results.json ./...

# Run govulncheck for vulnerability detection
go install golang.org/x/vuln/cmd/govulncheck@latest
govulncheck ./...

# Check for known CVEs in dependencies
go list -json -m all | nancy sleuth
```

## Test Coverage Analysis

Generate and analyze test coverage:

```bash
# Generate coverage
make test GINKGO_ARGS="--cover --coverprofile=coverage.out"

# View coverage in browser
go tool cover -html=coverage.out

# Coverage summary
go tool cover -func=coverage.out

# Coverage by package
go test -coverprofile=coverage.out -covermode=atomic ./...
go tool cover -func=coverage.out | grep total
```

## CI/CD Integration Checks

For continuous integration workflows:

```bash
# Pre-commit hook simulation
make fmt && make vet && make golangci

# Pre-PR validation
make manifests && make generate && git diff --exit-code

# Full CI pipeline
make fmt vet golangci test crd-schema-check

# Ensure no generated file changes
git diff --exit-code api/ config/
```

## Automated Test Workflows

### Quick Test Loop (Development)

1. Make code changes
2. `make fmt` - Format
3. `make vet` - Quick validation
4. `make test GINKGO_ARGS="--focus 'MyTest'"` - Focused test
5. Iterate

### Pre-Commit Workflow

1. `make fmt` - Format code
2. `make tidy` - Clean dependencies
3. `make vet` - Static analysis
4. `make golangci` - Linting
5. `make test` - Run tests
6. Stage and commit changes

### Pre-PR Workflow

1. `make manifests generate` - Regenerate code
2. Check for uncommitted changes
3. `make golangci-lint` - Full lint with fixes
4. `make operator-lint` - Operator checks
5. `make test` - Full test suite
6. `make crd-schema-check` - Schema validation
7. Generate coverage report

## Common Issues Detected

### Code Quality

- Unchecked errors
- Unused variables and imports
- Inefficient code patterns
- Type conversion issues
- Code duplication

### Operator-Specific

- Missing finalizer handling
- Incorrect status condition usage
- Improper error wrapping
- Missing owner references
- Webhook validation issues

### Security

- SQL injection vulnerabilities
- Hardcoded credentials
- Insecure random number generation
- Path traversal risks
- Known CVE dependencies

### Testing

- Failing test cases
- Flaky tests (randomization issues)
- Missing test coverage
- Slow test execution
- Race conditions

## Usage Examples

### Quick Test Mode

```bash
/test-operator quick
# Runs: fmt + vet + focused tests
```

### Standard Test Mode

```bash
/test-operator standard
# Runs: fmt + vet + golangci + test
```

### Full Test Mode

```bash
/test-operator full
# Runs: All checks + security + coverage
```

### Focused Test

```bash
/test-operator focus "initializes the status fields"
# Runs specific test pattern with Ginkgo
```

### Lint Only

```bash
/test-operator lint
# Runs: golangci-lint + operator-lint
```

### Security Scan

```bash
/test-operator security
# Runs: gosec + govulncheck + dependency check
```

## Integration with Other Skills

- **debug-operator**: Use test failures to guide debugging
- **code-style**: Enforce style before testing
- **plan-feature**: Include tests in feature planning
- **analyze-logs**: Parse test output for patterns

## Best Practices

1. **Run tests frequently** during development
2. **Fix linting issues** before committing
3. **Maintain test coverage** above 80%
4. **Use focused tests** for rapid iteration
5. **Run full suite** before creating PRs
6. **Keep dependencies updated** and secure
7. **Follow operator-lint** recommendations
8. **Validate CRD changes** with schema checker

## Reporting

I will provide:

- Test execution summary
- Failing test details with line numbers
- Linting issues categorized by severity
- Security vulnerabilities found
- Coverage statistics
- Actionable recommendations

Simply invoke `/test-operator` to run comprehensive testing and quality checks with detailed reporting and recommendations.
