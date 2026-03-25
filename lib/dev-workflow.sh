#!/bin/bash

# openstack-k8s-operators Operator Development and Debug Workflow
# Based on openstack-k8s-operators development practices

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if we're in an operator directory
check_operator_directory() {
    if [ ! -f "Makefile" ] || [ ! -f "go.mod" ]; then
        echo -e "${RED}❌ Not in an operator directory${NC}"
        echo "Please run this from an operator root directory (with Makefile and go.mod)"
        return 1
    fi

    local operator_name=$(basename "$(pwd)")
    echo -e "${GREEN}✅ Detected operator: $operator_name${NC}"
    return 0
}

# Run pre-commit checks
run_precommit_checks() {
    echo -e "${BLUE}🔍 Running pre-commit syntax checks${NC}"
    echo "=================================="

    if ! command -v pre-commit &> /dev/null; then
        echo -e "${YELLOW}⚠️  pre-commit not installed, skipping${NC}"
        return 0
    fi

    echo "Running pre-commit on all files..."
    if pre-commit run --all-files; then
        echo -e "${GREEN}✅ Pre-commit checks passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Pre-commit checks failed${NC}"
        echo -e "${YELLOW}💡 Fix syntax issues and run again${NC}"
        return 1
    fi
}

# Generate manifests and code
generate_manifests() {
    echo -e "\n${BLUE}📋 Generating manifests and code${NC}"
    echo "================================="

    echo "Running 'make manifests'..."
    if make manifests; then
        echo -e "${GREEN}✅ Manifests generated successfully${NC}"
    else
        echo -e "${RED}❌ Failed to generate manifests${NC}"
        return 1
    fi

    echo "Running 'make generate'..."
    if make generate; then
        echo -e "${GREEN}✅ Code generated successfully${NC}"
    else
        echo -e "${RED}❌ Failed to generate code${NC}"
        return 1
    fi

    # Check for changes
    if git diff --quiet; then
        echo -e "${GREEN}✅ No changes in generated files${NC}"
    else
        echo -e "${YELLOW}⚠️  Generated files have changes:${NC}"
        git diff --name-only
        echo -e "${YELLOW}💡 Review and commit these changes${NC}"
    fi

    return 0
}

# Run operator tests
run_operator_tests() {
    local focus_pattern="$1"
    local verbose="${2:-false}"

    echo -e "\n${BLUE}🧪 Running operator tests${NC}"
    echo "========================="

    if [ -n "$focus_pattern" ]; then
        echo "Running focused tests: $focus_pattern"
        local ginkgo_args="-v --output-interceptor-mode=none --focus '$focus_pattern'"
        if [ "$verbose" = "true" ]; then
            ginkgo_args="$ginkgo_args --trace"
        fi

        if make test GINKGO_ARGS="$ginkgo_args"; then
            echo -e "${GREEN}✅ Focused tests passed${NC}"
            return 0
        else
            echo -e "${RED}❌ Focused tests failed${NC}"
            return 1
        fi
    else
        echo "Running all tests..."
        if make test; then
            echo -e "${GREEN}✅ All tests passed${NC}"
            return 0
        else
            echo -e "${RED}❌ Tests failed${NC}"
            echo -e "${YELLOW}💡 Use focus_test '<pattern>' to run specific tests${NC}"
            return 1
        fi
    fi
}

# Focus on specific test
focus_test() {
    local pattern="$1"

    if [ -z "$pattern" ]; then
        echo "Usage: focus_test '<test pattern>'"
        echo "Example: focus_test 'Checks the Topology'"
        return 1
    fi

    run_operator_tests "$pattern" true
}

# Check test coverage
check_test_coverage() {
    echo -e "\n${BLUE}📊 Checking test coverage${NC}"
    echo "=========================="

    if make test-coverage 2>/dev/null; then
        echo -e "${GREEN}✅ Coverage report generated${NC}"
        if [ -f "cover.out" ]; then
            echo "Coverage details available in cover.out"
            go tool cover -func=cover.out | tail -1
        fi
    else
        echo -e "${YELLOW}⚠️  Coverage target not available${NC}"
        echo "Running basic test with coverage..."
        go test -coverprofile=cover.out ./... 2>/dev/null || echo "Coverage collection failed"
    fi
}

# Lint code
run_linting() {
    echo -e "\n${BLUE}🔍 Running code linting${NC}"
    echo "======================"

    # Check if golangci-lint is available
    if command -v golangci-lint &> /dev/null; then
        echo "Running golangci-lint..."
        if golangci-lint run; then
            echo -e "${GREEN}✅ Linting passed${NC}"
        else
            echo -e "${YELLOW}⚠️  Linting issues found${NC}"
        fi
    elif make lint 2>/dev/null; then
        echo "Running make lint..."
        echo -e "${GREEN}✅ Linting completed${NC}"
    else
        echo -e "${YELLOW}⚠️  No linting tool available${NC}"
    fi
}

# Check Go modules
check_go_modules() {
    echo -e "\n${BLUE}📦 Checking Go modules${NC}"
    echo "======================"

    echo "Verifying go.mod and go.sum..."
    if go mod verify; then
        echo -e "${GREEN}✅ Go modules verified${NC}"
    else
        echo -e "${RED}❌ Go modules verification failed${NC}"
        return 1
    fi

    echo "Checking for unused dependencies..."
    if go mod tidy; then
        if git diff --quiet go.mod go.sum; then
            echo -e "${GREEN}✅ Dependencies are clean${NC}"
        else
            echo -e "${YELLOW}⚠️  Dependencies need tidying:${NC}"
            git diff go.mod go.sum
        fi
    fi
}

# Check operator build
check_build() {
    echo -e "\n${BLUE}🔨 Checking operator build${NC}"
    echo "=========================="

    echo "Building operator binary..."
    if make build 2>/dev/null || go build -o bin/manager cmd/main.go; then
        echo -e "${GREEN}✅ Operator builds successfully${NC}"
    else
        echo -e "${RED}❌ Build failed${NC}"
        return 1
    fi

    # Check docker build if available
    if [ -f "Dockerfile" ]; then
        echo "Checking Dockerfile..."
        if make docker-build IMG=test:latest 2>/dev/null; then
            echo -e "${GREEN}✅ Docker image builds successfully${NC}"
        else
            echo -e "${YELLOW}⚠️  Docker build issues (may be expected)${NC}"
        fi
    fi
}

# Validate CRDs
validate_crds() {
    echo -e "\n${BLUE}📜 Validating CRDs${NC}"
    echo "=================="

    local crd_dir="config/crd/bases"
    if [ -d "$crd_dir" ]; then
        echo "Checking CRD files in $crd_dir..."
        local crd_count=$(find "$crd_dir" -name "*.yaml" | wc -l)
        echo "Found $crd_count CRD files"

        # Validate YAML syntax
        for crd_file in "$crd_dir"/*.yaml; do
            if [ -f "$crd_file" ]; then
                if yq eval '.' "$crd_file" >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ $(basename "$crd_file") is valid${NC}"
                else
                    echo -e "${RED}❌ $(basename "$crd_file") has YAML errors${NC}"
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠️  No CRD directory found at $crd_dir${NC}"
    fi
}

# Run full development workflow
run_full_workflow() {
    echo -e "${BLUE}🔄 Running full openstack-k8s-operators development workflow${NC}"
    echo "==========================================="

    check_operator_directory || return 1

    local failed_steps=()

    # Step 1: Pre-commit checks
    if ! run_precommit_checks; then
        failed_steps+=("pre-commit")
    fi

    # Step 2: Generate manifests and code
    if ! generate_manifests; then
        failed_steps+=("generate")
    fi

    # Step 3: Check Go modules
    if ! check_go_modules; then
        failed_steps+=("modules")
    fi

    # Step 4: Linting
    run_linting  # Don't fail on linting issues

    # Step 5: Build check
    if ! check_build; then
        failed_steps+=("build")
    fi

    # Step 6: CRD validation
    validate_crds

    # Step 7: Run tests
    if ! run_operator_tests; then
        failed_steps+=("tests")
    fi

    # Step 8: Coverage check
    check_test_coverage

    # Summary
    echo -e "\n${BLUE}📋 Workflow Summary${NC}"
    echo "==================="

    if [ ${#failed_steps[@]} -eq 0 ]; then
        echo -e "${GREEN}🎉 All development workflow steps passed!${NC}"
        echo -e "${GREEN}✅ Operator is ready for development/deployment${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed steps: ${failed_steps[*]}${NC}"
        echo -e "${YELLOW}💡 Fix the failed steps and run again${NC}"
        return 1
    fi
}

# Show available tests
show_tests() {
    echo -e "${BLUE}🧪 Available Tests${NC}"
    echo "=================="

    # Look for test files and extract test names
    echo "Scanning for test files..."
    find . -name "*_test.go" -exec grep -l "Describe\|Context\|It(" {} \; | while read -r file; do
        echo -e "\n${YELLOW}📄 $file:${NC}"
        grep -E "(Describe|Context|It)\(" "$file" | sed 's/.*[[:space:]]*\(Describe\|Context\|It\)("/  - /' | sed 's/",.*$//' | head -10
    done

    echo -e "\n${BLUE}💡 Usage:${NC}"
    echo "  focus_test 'partial test name'     - Run specific test"
    echo "  run_operator_tests                 - Run all tests"
}

# Help function
show_dev_help() {
    echo -e "${BLUE}🛠️  openstack-k8s-operators Development Workflow Commands${NC}"
    echo "======================================="
    echo
    echo "Development workflow:"
    echo "  run_full_workflow           - Complete development workflow"
    echo "  run_precommit_checks        - Syntax and style checks"
    echo "  generate_manifests          - Generate CRDs and code"
    echo "  run_operator_tests          - Run all tests"
    echo "  focus_test '<pattern>'      - Run specific tests"
    echo "  check_test_coverage         - Generate coverage report"
    echo
    echo "Quality checks:"
    echo "  run_linting                 - Code linting"
    echo "  check_go_modules            - Verify dependencies"
    echo "  check_build                 - Test compilation"
    echo "  validate_crds               - Validate CRD files"
    echo
    echo "Utilities:"
    echo "  show_tests                  - List available tests"
    echo
    echo "Examples:"
    echo "  ./dev-workflow.sh run_full_workflow"
    echo "  ./dev-workflow.sh focus_test 'Checks the Topology'"
    echo "  ./dev-workflow.sh show_tests"
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        "run_full_workflow")
            run_full_workflow
            ;;
        "run_precommit_checks"|"precommit")
            run_precommit_checks
            ;;
        "generate_manifests"|"generate")
            generate_manifests
            ;;
        "run_operator_tests"|"test")
            run_operator_tests "$2" "$3"
            ;;
        "focus_test")
            focus_test "$2"
            ;;
        "check_test_coverage"|"coverage")
            check_test_coverage
            ;;
        "run_linting"|"lint")
            run_linting
            ;;
        "check_go_modules"|"modules")
            check_go_modules
            ;;
        "check_build"|"build")
            check_build
            ;;
        "validate_crds"|"crds")
            validate_crds
            ;;
        "show_tests"|"tests")
            show_tests
            ;;
        "help"|*)
            show_dev_help
            ;;
    esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
