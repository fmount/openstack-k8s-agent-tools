#!/bin/bash

# openstack-k8s-operators Operator Tools Plugin Test Suite
# Validates plugin functionality and components

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
run_test() {
    local test_name="$1"
    local test_command="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${BLUE}[TEST $TESTS_RUN] $test_name${NC}"

    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}  ✅ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}  ❌ FAILED${NC}"
        echo -e "${YELLOW}     Command: $test_command${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# File existence tests
test_file_exists() {
    local file="$1"
    local description="$2"

    run_test "$description" "[ -f '$file' ]"
}

test_executable() {
    local file="$1"
    local description="$2"

    run_test "$description" "[ -x '$file' ]"
}

# JSON validation tests
test_json_valid() {
    local file="$1"
    local description="$2"

    run_test "$description" "jq . '$file' >/dev/null 2>&1"
}

# Node.js script tests
test_node_script() {
    local script="$1"
    local description="$2"

    run_test "$description" "node '$script' --help >/dev/null 2>&1"
}

# Main test suite
run_plugin_tests() {
    echo -e "${BLUE}🧪 openstack-k8s-operators Operator Tools Plugin Test Suite${NC}"
    echo "=========================================="
    echo

    # Test plugin structure
    echo -e "${YELLOW}📂 Testing Plugin Structure${NC}"
    test_file_exists ".claude-plugin/plugin.json" "Plugin metadata exists"
    test_json_valid ".claude-plugin/plugin.json" "Plugin metadata is valid JSON"

    # Test skills
    echo -e "\n${YELLOW}🎯 Testing Skills${NC}"
    test_file_exists "skills/debug-operator/SKILL.md" "Debug operator skill exists"
    test_file_exists "skills/explain-flow/SKILL.md" "Explain flow skill exists"
    test_file_exists "skills/plan-feature/SKILL.md" "Plan feature skill exists"
    test_file_exists "skills/analyze-logs/SKILL.md" "Analyze logs skill exists"
    test_file_exists "skills/code-style/SKILL.md" "Code style skill exists"
    test_file_exists "skills/test-operator/SKILL.md" "Test operator skill exists"
    test_file_exists "skills/code-review/SKILL.md" "Code review skill exists"
    test_file_exists "skills/task-executor/SKILL.md" "Task executor skill exists"

    # Test agents
    echo -e "\n${YELLOW}🤖 Testing Agents${NC}"
    test_file_exists "agents/code-review/AGENT.md" "Code review agent exists"
    test_file_exists "agents/plan-feature/AGENT.md" "Plan feature agent exists"
    test_file_exists "agents/task-executor/AGENT.md" "Task executor agent exists"

    # Test lib helpers
    echo -e "\n${YELLOW}📦 Testing Lib${NC}"
    test_file_exists "lib/debug-helpers.sh" "Debug helpers exist"
    test_executable "lib/debug-helpers.sh" "Debug helpers are executable"
    test_file_exists "lib/dev-workflow.sh" "Dev workflow exists"
    test_executable "lib/dev-workflow.sh" "Dev workflow is executable"
    test_file_exists "lib/test-workflow.sh" "Test workflow exists"
    test_executable "lib/test-workflow.sh" "Test workflow is executable"
    test_file_exists "lib/code-parser.js" "Code parser exists"
    test_node_script "lib/code-parser.js" "Code parser runs"
    test_file_exists "lib/log-analyzer.js" "Log analyzer exists"
    test_node_script "lib/log-analyzer.js" "Log analyzer runs"
    test_file_exists "lib/style-analyzer.js" "Style analyzer exists"
    test_file_exists "lib/log-patterns.json" "Log patterns exist"
    test_json_valid "lib/log-patterns.json" "Log patterns are valid JSON"

    # Test scripts
    echo -e "\n${YELLOW}📜 Testing Scripts${NC}"
    test_file_exists "scripts/install.sh" "Install script exists"
    test_executable "scripts/install.sh" "Install script is executable"

    # Test documentation
    echo -e "\n${YELLOW}📚 Testing Documentation${NC}"
    test_file_exists "README.md" "README exists"
    test_file_exists "CLAUDE.md" "Claude development guide exists"
    test_file_exists "LICENSE" "License exists"
    test_file_exists "package.json" "Package.json exists"
    test_json_valid "package.json" "Package.json is valid JSON"
}

# Functional tests
run_functional_tests() {
    echo -e "\n${YELLOW}⚙️  Testing Functionality${NC}"

    # Test script help
    run_test "Install script help" "./scripts/install.sh --help >/dev/null 2>&1"

    # Test lib tools
    run_test "Log analyzer patterns" "node lib/log-analyzer.js --patterns >/dev/null 2>&1"
    run_test "Code parser help" "node lib/code-parser.js --help >/dev/null 2>&1"
    run_test "Dev workflow help" "./lib/dev-workflow.sh help >/dev/null 2>&1"
    run_test "Test workflow help" "./lib/test-workflow.sh help >/dev/null 2>&1"
}

# Plugin validation tests
run_plugin_validation() {
    echo -e "\n${YELLOW}✅ Testing Plugin Validation${NC}"

    # Check plugin.json structure
    if [ -f ".claude-plugin/plugin.json" ]; then
        local has_name=$(jq '.name' .claude-plugin/plugin.json 2>/dev/null)
        local has_version=$(jq '.version' .claude-plugin/plugin.json 2>/dev/null)
        local has_skills=$(jq '.skills' .claude-plugin/plugin.json 2>/dev/null)

        run_test "Plugin has name field" "[ '$has_name' != 'null' ]"
        run_test "Plugin has version field" "[ '$has_version' != 'null' ]"
        run_test "Plugin has skills field" "[ '$has_skills' != 'null' ]"
    fi

    # Check skill references
    if command -v jq >/dev/null 2>&1; then
        local skills=$(jq -r '.skills | keys[]' .claude-plugin/plugin.json 2>/dev/null)
        for skill in $skills; do
            local skill_file=$(jq -r ".skills[\"$skill\"]" .claude-plugin/plugin.json 2>/dev/null)
            run_test "Skill '$skill' file exists" "[ -f '$skill_file' ]"
        done
    fi
}

# Performance tests
run_performance_tests() {
    echo -e "\n${YELLOW}⚡ Testing Performance${NC}"

    # Test script execution time
    local start_time=$(date +%s.%N)
    ./lib/dev-workflow.sh help >/dev/null 2>&1
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")

    run_test "Dev workflow runs quickly (<2s)" "[ $(echo '$duration < 2' | bc -l 2>/dev/null || echo 0) -eq 1 ]"

    # Test log analyzer with small input
    echo "test error message" | timeout 5s node lib/log-analyzer.js - >/dev/null 2>&1
    local exit_code=$?
    run_test "Log analyzer handles input quickly" "[ $exit_code -eq 0 ]"
}

# Security tests
run_security_tests() {
    echo -e "\n${YELLOW}🔒 Testing Security${NC}"

    # Check for hardcoded secrets
    run_test "No hardcoded passwords" "! grep -r -i 'password.*=' . --include='*.js' --include='*.sh' --include='*.md'"
    run_test "No hardcoded tokens" "! grep -r -i 'token.*=' . --include='*.js' --include='*.sh' --include='*.md'"
    run_test "No hardcoded API keys" "! grep -r -i 'apikey.*=' . --include='*.js' --include='*.sh' --include='*.md'"

    # Check file permissions
    run_test "Scripts have safe permissions" "find scripts/ -name '*.sh' -exec test '{}' -perm /o+w \\; -print | wc -l | grep -q '^0$'"
}

# Integration tests
run_integration_tests() {
    echo -e "\n${YELLOW}🔗 Testing Integration${NC}"

    # Test install script check mode
    run_test "Install script check mode" "./scripts/install.sh --check >/dev/null 2>&1"

    # Test plugin installation
    if [ -d "$HOME/.claude/plugins" ]; then
        run_test "Plugin can be installed" "./scripts/install.sh --claude-code >/dev/null 2>&1"
    fi
}

# Summary report
show_summary() {
    echo
    echo -e "${BLUE}📊 Test Summary${NC}"
    echo "==============="
    echo -e "Total tests:  ${TESTS_RUN}"
    echo -e "Passed:       ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed:       ${RED}${TESTS_FAILED}${NC}"
    echo -e "Success rate: $(( TESTS_PASSED * 100 / TESTS_RUN ))%"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed. Please review and fix issues.${NC}"
        exit 1
    fi
}

# Main execution
main() {
    local test_type="${1:-all}"

    case "$test_type" in
        "structure")
            run_plugin_tests
            ;;
        "functional")
            run_functional_tests
            ;;
        "validation")
            run_plugin_validation
            ;;
        "performance")
            run_performance_tests
            ;;
        "security")
            run_security_tests
            ;;
        "integration")
            run_integration_tests
            ;;
        "all")
            run_plugin_tests
            run_functional_tests
            run_plugin_validation
            run_performance_tests
            run_security_tests
            run_integration_tests
            ;;
        "help")
            echo "Usage: $0 [test-type]"
            echo "Test types: structure, functional, validation, performance, security, integration, all"
            exit 0
            ;;
        *)
            echo "Unknown test type: $test_type"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac

    show_summary
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
