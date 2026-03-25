# openstack-k8s-operators Operator Skills - Quick Reference

## debug-operator

```bash
/debug-operator                           # Auto-run workflow
/debug-operator focus-test "pattern"      # Focused testing

./lib/dev-workflow.sh run_full_workflow
./lib/dev-workflow.sh show_tests
./lib/dev-workflow.sh focus_test "test name"
```

**Runs**: pre-commit -> manifests -> generate -> lint -> build -> test

---

## test-operator

```bash
/test-operator quick           # fmt+vet+tidy (~10s)
/test-operator standard        # +lint+test (~2-5min)
/test-operator full            # +security (~5-10min)
/test-operator focus "pattern" # Focused tests
/test-operator security        # gosec+govulncheck
/test-operator coverage        # Coverage report
/test-operator fix             # Auto-fix issues
```

**Make targets**:

```bash
make fmt vet test golangci operator-lint
make test GINKGO_ARGS="--focus 'pattern'"
```

---

## code-style

```bash
/code-style                    # Analyze code

node ./lib/style-analyzer.js file.go
node ./lib/style-analyzer.js --modernize file.go
```

**Detects**: old syntax, missing error wrapping, controller anti-patterns

---

## analyze-logs

```bash
/analyze-logs                  # Interactive

kubectl logs deployment/op -n ns > op.log
node ./lib/log-analyzer.js op.log
node ./lib/log-analyzer.js --verbose op.log
node ./lib/log-analyzer.js --patterns
```

**Finds**: errors (API/RBAC/runtime), performance issues, OpenStack problems

---

## explain-flow

```bash
/explain-flow                  # Parse current dir

node ./lib/code-parser.js .
node ./lib/code-parser.js controllers/
```

**Extracts**: reconcile functions, flow steps, error handling, CRDs

---

## code-review

```bash
/code-review                   # Review current branch diff
/code-review PR#123            # Review a PR
/code-review file.go           # Review specific file
```

**Checks**: reconciliation, conditions, webhooks, RBAC, testing, API design

---

## plan-feature

```bash
/plan-feature                  # Interactive planning
```

**Provides**: architecture analysis, design suggestions, task breakdown

---

## Common Workflows

**Development loop**:

```bash
/test-operator quick -> /debug-operator focus-test "..." -> iterate
```

**Pre-commit**:

```bash
/test-operator standard && /code-style
```

**Pre-PR**:

```bash
/debug-operator && /test-operator full && /code-review
```

**Debugging**:

```bash
kubectl logs pod > log.txt
/analyze-logs -> /explain-flow -> /debug-operator
```

---

## Installation

```bash
./scripts/install.sh --claude-code
./lib/test-workflow.sh install-tools
```

---

## Tips

- Use `quick` for fast feedback during development
- Focused tests speed up iteration
- Auto-fix before manual fixes
- All lib/ tools support `--json` for automation
