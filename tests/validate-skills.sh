#!/usr/bin/env bash

# Validate plugin structure, skills, and agents for openstack-k8s-agent-tools
# Usage: ./tests/validate-skills.sh [all|skills|plugin|security|help] [name]
#   all (default): run everything
#   skills [name]: validate skills and agents (optionally just one)
#   plugin: validate plugin metadata, scripts, and docs
#   security: check for hardcoded secrets and file permissions

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}WARN${NC} $1"; WARN=$((WARN + 1)); }

check() {
    local description="$1"
    local command="$2"
    if eval "$command" &>/dev/null; then
        pass "$description"
    else
        fail "$description"
    fi
}

get_frontmatter() {
    local file="$1"
    sed -n '2,/^---$/p' "$file" | sed '$d'
}

has_field() {
    local frontmatter="$1"
    local field="$2"
    echo "$frontmatter" | grep -q "^${field}:"
}

get_field() {
    local frontmatter="$1"
    local field="$2"
    echo "$frontmatter" | grep "^${field}:" | sed "s/^${field}:[[:space:]]*//"
}

# --- Skill and Agent validation ---

validate_skill() {
    local name="$1"
    local dir="${REPO_ROOT}/skills/${name}"
    local file="${dir}/SKILL.md"

    echo -e "\n${BLUE}[skill: ${name}]${NC}"

    if [[ ! -f "$file" ]]; then
        fail "SKILL.md exists"
        return
    fi
    pass "SKILL.md exists"

    local first_line
    first_line=$(head -1 "$file")
    if [[ "$first_line" != "---" ]]; then
        fail "frontmatter starts with ---"
        return
    fi
    pass "frontmatter starts with ---"

    local frontmatter
    frontmatter=$(get_frontmatter "$file")

    for field in name description user-invocable; do
        if has_field "$frontmatter" "$field"; then
            pass "has '${field}' field"
        else
            fail "has '${field}' field"
        fi
    done

    local fm_name
    fm_name=$(get_field "$frontmatter" "name" | tr -d '"' | tr -d "'")
    if [[ "$fm_name" == "$name" ]]; then
        pass "name field matches directory (${name})"
    else
        fail "name field '${fm_name}' does not match directory '${name}'"
    fi

    local lines
    lines=$(wc -l < "$file")
    if [[ "$lines" -gt 10 ]]; then
        pass "has content (${lines} lines)"
    else
        fail "too short (${lines} lines, need >10)"
    fi

    if grep -q "^TODO:" "$file"; then
        warn "contains TODO placeholders"
    fi

    if has_field "$frontmatter" "allowed-tools"; then
        local tools
        tools=$(get_field "$frontmatter" "allowed-tools")
        if echo "$tools" | grep -q '"Agent"'; then
            if grep -q "subagent_type=" "$file"; then
                pass "has agent dispatch block"
                if grep -q "openstack-k8s-agent-tools:" "$file"; then
                    pass "subagent_type uses correct prefix"
                else
                    fail "subagent_type missing 'openstack-k8s-agent-tools:' prefix"
                fi
            elif grep -q "skills/.*/SKILL.md" "$file"; then
                pass "delegates dispatch to another skill"
            elif [[ -d "${REPO_ROOT}/agents/${name}" ]]; then
                warn "has Agent in allowed-tools but no dispatch block (may delegate via another skill)"
            else
                fail "has Agent in allowed-tools but no dispatch block and no matching agent"
            fi
        fi
    fi
}

validate_agent() {
    local name="$1"
    local dir="${REPO_ROOT}/agents/${name}"
    local file="${dir}/AGENT.md"

    echo -e "\n${BLUE}[agent: ${name}]${NC}"

    if [[ ! -f "$file" ]]; then
        fail "AGENT.md exists"
        return
    fi
    pass "AGENT.md exists"

    local first_line
    first_line=$(head -1 "$file")
    if [[ "$first_line" != "---" ]]; then
        fail "frontmatter starts with ---"
        return
    fi
    pass "frontmatter starts with ---"

    local frontmatter
    frontmatter=$(get_frontmatter "$file")

    for field in name description; do
        if has_field "$frontmatter" "$field"; then
            pass "has '${field}' field"
        else
            fail "has '${field}' field"
        fi
    done

    local fm_name
    fm_name=$(get_field "$frontmatter" "name" | tr -d '"' | tr -d "'")
    if [[ "$fm_name" == "$name" ]]; then
        pass "name field matches directory (${name})"
    else
        fail "name field '${fm_name}' does not match directory '${name}'"
    fi

    local lines
    lines=$(wc -l < "$file")
    if [[ "$lines" -gt 10 ]]; then
        pass "has content (${lines} lines)"
    else
        fail "too short (${lines} lines, need >10)"
    fi

    if grep -q "^TODO:" "$file"; then
        warn "contains TODO placeholders"
    fi

    if has_field "$frontmatter" "model"; then
        local model
        model=$(get_field "$frontmatter" "model" | tr -d '"' | tr -d "'")
        if [[ "$model" == "inherit" ]]; then
            pass "model is 'inherit'"
        else
            warn "model is '${model}' (expected 'inherit')"
        fi
    else
        warn "no 'model' field (defaults may vary)"
    fi

    if has_field "$frontmatter" "skills"; then
        local skills_list
        skills_list=$(get_field "$frontmatter" "skills" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed '/^$/d')
        if [[ -n "$skills_list" ]]; then
            while IFS= read -r skill; do
                [[ -z "$skill" ]] && continue
                if [[ -d "${REPO_ROOT}/skills/${skill}" ]]; then
                    pass "referenced skill '${skill}' exists"
                else
                    fail "referenced skill '${skill}' not found"
                fi
            done <<< "$skills_list"
        fi
    fi
}

run_skills_validation() {
    local target="${1:-}"

    echo -e "\n${YELLOW}Skills & Agents${NC}"

    if [[ -n "$target" ]]; then
        if [[ -d "${REPO_ROOT}/skills/${target}" ]]; then
            validate_skill "$target"
        fi
        if [[ -d "${REPO_ROOT}/agents/${target}" ]]; then
            validate_agent "$target"
        fi
        if [[ ! -d "${REPO_ROOT}/skills/${target}" && ! -d "${REPO_ROOT}/agents/${target}" ]]; then
            echo -e "${RED}No skill or agent named '${target}' found${NC}"
            exit 1
        fi
    else
        for skill_dir in "${REPO_ROOT}"/skills/*/; do
            [[ -d "$skill_dir" ]] || continue
            validate_skill "$(basename "$skill_dir")"
        done

        for agent_dir in "${REPO_ROOT}"/agents/*/; do
            [[ -d "$agent_dir" ]] || continue
            validate_agent "$(basename "$agent_dir")"
        done
    fi
}

# --- Plugin metadata, scripts, and docs ---

run_plugin_validation() {
    echo -e "\n${YELLOW}Plugin Metadata${NC}"
    check "plugin.json exists" "[ -f '${REPO_ROOT}/.claude-plugin/plugin.json' ]"
    check "plugin.json is valid JSON" "jq . '${REPO_ROOT}/.claude-plugin/plugin.json'"

    if [[ -f "${REPO_ROOT}/.claude-plugin/plugin.json" ]]; then
        local has_name has_version
        has_name=$(jq '.name' "${REPO_ROOT}/.claude-plugin/plugin.json" 2>/dev/null)
        has_version=$(jq '.version' "${REPO_ROOT}/.claude-plugin/plugin.json" 2>/dev/null)
        check "plugin.json has name" "[ '$has_name' != 'null' ]"
        check "plugin.json has version" "[ '$has_version' != 'null' ]"
    fi

    local skill_count
    skill_count=$(find "${REPO_ROOT}/skills/" -name "SKILL.md" 2>/dev/null | wc -l)
    check "skills discovered (${skill_count} found)" "[ $skill_count -gt 0 ]"

    echo -e "\n${YELLOW}Scripts${NC}"
    for f in "${REPO_ROOT}"/scripts/*.sh; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f")
        check "script '${name}' is executable" "[ -x '$f' ]"
    done
    check "install.sh --help" "${REPO_ROOT}/scripts/install.sh --help"
    check "install.sh --check" "${REPO_ROOT}/scripts/install.sh --check"
    check "install.sh parses without error" "bash -n '${REPO_ROOT}/scripts/install.sh'"

    echo -e "\n${YELLOW}Documentation${NC}"
    check "README.md exists" "[ -f '${REPO_ROOT}/README.md' ]"
    check "AGENTS.md exists" "[ -f '${REPO_ROOT}/AGENTS.md' ]"
    check "LICENSE exists" "[ -f '${REPO_ROOT}/LICENSE' ]"
    check "package.json exists" "[ -f '${REPO_ROOT}/package.json' ]"
    check "package.json is valid JSON" "jq . '${REPO_ROOT}/package.json'"
}

# --- Security checks ---

run_security_validation() {
    echo -e "\n${YELLOW}Security${NC}"
    check "no hardcoded passwords" \
        "! grep -r -i 'password.*=' --include='*.sh' --exclude-dir=tests --exclude-dir=.git '${REPO_ROOT}'"
    check "no hardcoded tokens" \
        "! grep -r -i 'token.*=' --include='*.sh' --exclude-dir=tests --exclude-dir=.git '${REPO_ROOT}'"
    check "no hardcoded API keys" \
        "! grep -r -i 'apikey.*=' --include='*.sh' --exclude-dir=tests --exclude-dir=.git '${REPO_ROOT}'"
    check "scripts have safe permissions" \
        "find '${REPO_ROOT}/scripts/' -name '*.sh' -perm /o+w -print | wc -l | grep -q '^0$'"
}

# --- Summary ---

show_summary() {
    echo
    echo "=================================================="
    echo -e "${BLUE}Validation Summary${NC}"
    echo "=================================================="
    local total=$((PASS + FAIL + WARN))
    echo -e "Total:    $total"
    echo -e "Passed:   ${GREEN}${PASS}${NC}"
    echo -e "Failed:   ${RED}${FAIL}${NC}"
    echo -e "Warnings: ${YELLOW}${WARN}${NC}"
    echo

    if [[ "$FAIL" -eq 0 ]]; then
        echo -e "${GREEN}All validations passed!${NC}"
        exit 0
    else
        echo -e "${RED}${FAIL} validation(s) failed${NC}"
        exit 1
    fi
}

# --- Main ---

echo -e "${BLUE}openstack-k8s-agent-tools Validator${NC}"
echo "=================================================="

case "${1:-all}" in
    all)
        run_skills_validation
        run_plugin_validation
        run_security_validation
        ;;
    skills)
        run_skills_validation "${2:-}"
        ;;
    plugin)
        run_plugin_validation
        ;;
    security)
        run_security_validation
        ;;
    help)
        echo "Usage: $(basename "$0") [all|skills|plugin|security|help] [name]"
        echo "  all (default)   Run all validations"
        echo "  skills [name]   Validate skills and agents (optionally one)"
        echo "  plugin          Validate plugin metadata, scripts, docs"
        echo "  security        Check for hardcoded secrets and permissions"
        exit 0
        ;;
    *)
        # Treat as a skill/agent name for backwards compatibility
        run_skills_validation "$1"
        ;;
esac

show_summary
