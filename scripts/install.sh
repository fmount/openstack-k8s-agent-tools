#!/bin/bash

set -e

# openstack-k8s-operators Operator Tools Installer
# Supports Claude Code (marketplace) and OpenCode (manual install)

PLUGIN_NAME="openstack-k8s-agent-tools"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="0.2.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Skills installation (shared by both platforms) ---

install_skills() {
    local target_dir="$1"

    mkdir -p "$target_dir"

    local count=0
    for skill_dir in "$PLUGIN_DIR/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")

        mkdir -p "$target_dir/$skill_name"
        cp "$skill_dir/SKILL.md" "$target_dir/$skill_name/SKILL.md"
        count=$((count + 1))
    done

    info "Installed $count skills to $target_dir"
}

# --- Agents installation ---

install_agents_claude() {
    # Claude Code: agents live in the plugin's agents/ directory
    # and are discovered automatically via marketplace install.
    # For manual install, copy them alongside skills.
    local target_dir="$1"

    mkdir -p "$target_dir"

    local count=0
    for agent_dir in "$PLUGIN_DIR/agents"/*/; do
        [ -d "$agent_dir" ] || continue
        local agent_name
        agent_name=$(basename "$agent_dir")

        mkdir -p "$target_dir/$agent_name"
        cp "$agent_dir/AGENT.md" "$target_dir/$agent_name/AGENT.md"
        count=$((count + 1))
    done

    info "Installed $count agents to $target_dir"
}

install_agents_opencode() {
    # OpenCode: agents are standalone .md files in agents/ directory
    # Frontmatter needs translation:
    #   - model: inherit -> removed (OpenCode inherits by default)
    #   - add mode: subagent
    #   - translate description
    local target_dir="$1"

    mkdir -p "$target_dir"

    local count=0
    for agent_dir in "$PLUGIN_DIR/agents"/*/; do
        [ -d "$agent_dir" ] || continue
        local agent_name
        agent_name=$(basename "$agent_dir")
        local source_file="$agent_dir/AGENT.md"
        local target_file="$target_dir/$agent_name.md"

        # Read the source AGENT.md and convert frontmatter
        local in_frontmatter=false
        local frontmatter_done=false
        local wrote_mode=false

        {
            while IFS= read -r line; do
                if [ "$frontmatter_done" = false ]; then
                    if [ "$line" = "---" ] && [ "$in_frontmatter" = false ]; then
                        in_frontmatter=true
                        echo "$line"
                        continue
                    fi

                    if [ "$line" = "---" ] && [ "$in_frontmatter" = true ]; then
                        # Add mode: subagent if not already present
                        if [ "$wrote_mode" = false ]; then
                            echo "mode: subagent"
                        fi
                        echo "$line"
                        frontmatter_done=true
                        continue
                    fi

                    if [ "$in_frontmatter" = true ]; then
                        # Skip model: inherit (OpenCode inherits by default)
                        if echo "$line" | grep -q "^model: inherit"; then
                            continue
                        fi
                        # Track if mode was already set
                        if echo "$line" | grep -q "^mode:"; then
                            wrote_mode=true
                        fi
                        echo "$line"
                    fi
                else
                    # Body: replace subagent_type references with @name mentions
                    echo "$line" | sed 's/subagent_type="openstack-k8s-agent-tools:\([^:]*\):\([^"]*\)"/@\2/g'
                fi
            done
        } < "$source_file" > "$target_file"

        count=$((count + 1))
        info "Converted agent: $agent_name"
    done

    info "Installed $count agents to $target_dir"
}

# --- Skills conversion for OpenCode ---

convert_skills_opencode() {
    # OpenCode reads .claude/skills/ natively, but SKILL.md files
    # may contain Claude Code-specific subagent_type references.
    # Convert those to @name mentions for OpenCode.
    local target_dir="$1"

    for skill_dir in "$target_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill_file="$skill_dir/SKILL.md"
        [ -f "$skill_file" ] || continue

        # Replace subagent_type dispatch with @name mentions
        if grep -q "subagent_type" "$skill_file" 2>/dev/null; then
            sed -i.bak 's/subagent_type="openstack-k8s-agent-tools:\([^:]*\):\([^"]*\)"/@\2/g' "$skill_file"
            rm -f "$skill_file.bak"
            info "Converted skill references: $(basename "$skill_dir")"
        fi
    done
}

# --- Platform installers ---

install_claude_code() {
    info "Installing for Claude Code (manual)..."

    if ! command -v claude &> /dev/null; then
        warn "Claude Code CLI not found. Installing files anyway."
    fi

    local skills_dir="$HOME/.claude/skills"
    local agents_dir="$HOME/.claude/agents"

    install_skills "$skills_dir"
    install_agents_claude "$agents_dir"

    info ""
    info "Installed to ~/.claude/"
    info "Skills and agents are now available in all your projects."
    info "Try: /feature, /code-review, /task-executor, /debug-operator"
}

install_opencode() {
    info "Installing for OpenCode..."

    local skills_dir="$HOME/.config/opencode/skills"
    local agents_dir="$HOME/.config/opencode/agents"

    # Install skills (same SKILL.md format)
    install_skills "$skills_dir"

    # Convert Claude Code-specific references in skills
    convert_skills_opencode "$skills_dir"

    # Install agents (converted to OpenCode format)
    install_agents_opencode "$agents_dir"

    info ""
    info "Installed to ~/.config/opencode/"
    info "Skills: $skills_dir"
    info "Agents: $agents_dir"
    info "Start OpenCode and your skills should be available."
}

install_project() {
    info "Installing to current project..."

    local platform="$1"

    case "$platform" in
        claude)
            local skills_dir=".claude/skills"
            local agents_dir=".claude/agents"
            install_skills "$skills_dir"
            install_agents_claude "$agents_dir"
            info "Installed to .claude/ (project-local, Claude Code)"
            ;;
        opencode)
            local skills_dir=".opencode/skills"
            local agents_dir=".opencode/agents"
            install_skills "$skills_dir"
            convert_skills_opencode "$skills_dir"
            install_agents_opencode "$agents_dir"
            info "Installed to .opencode/ (project-local, OpenCode)"
            ;;
    esac
}

uninstall() {
    local platform="$1"

    case "$platform" in
        claude)
            info "Uninstalling from Claude Code..."
            for skill_dir in "$PLUGIN_DIR/skills"/*/; do
                local name
                name=$(basename "$skill_dir")
                rm -rf "$HOME/.claude/skills/$name"
                rm -rf "$HOME/.claude/agents/$name"
            done
            info "Removed skills and agents from ~/.claude/"
            ;;
        opencode)
            info "Uninstalling from OpenCode..."
            for skill_dir in "$PLUGIN_DIR/skills"/*/; do
                local name
                name=$(basename "$skill_dir")
                rm -rf "$HOME/.config/opencode/skills/$name"
                rm -f "$HOME/.config/opencode/agents/$name.md"
            done
            info "Removed skills and agents from ~/.config/opencode/"
            ;;
    esac
}

check_dependencies() {
    info "Checking dependencies..."

    local has_issues=false

    if command -v go &> /dev/null; then
        info "Go: $(go version | awk '{print $3}')"
    else
        warn "Go toolchain not found (required for operator development)"
        has_issues=true
    fi

    if command -v make &> /dev/null; then
        info "make: available"
    else
        warn "make not found (required for operator builds)"
        has_issues=true
    fi

    if command -v gh &> /dev/null; then
        info "gh: $(gh --version | head -1)"
    else
        warn "GitHub CLI not found (optional, for cross-repo analysis)"
    fi

    if command -v claude &> /dev/null; then
        info "Claude Code: available"
    else
        warn "Claude Code not found"
    fi

    if command -v opencode &> /dev/null; then
        info "OpenCode: available"
    else
        warn "OpenCode not found"
    fi

    if [ "$has_issues" = true ]; then
        warn "Some required dependencies are missing"
    else
        info "All required dependencies found"
    fi
}

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install openstack-k8s-agent-tools for Claude Code or OpenCode.

Options:
  --claude-code        Install globally for Claude Code (~/.claude/)
  --opencode           Install globally for OpenCode (~/.config/opencode/)
  --project-claude     Install to current project (.claude/)
  --project-opencode   Install to current project (.opencode/)
  --uninstall-claude   Remove from Claude Code
  --uninstall-opencode Remove from OpenCode
  --check              Check dependencies only
  --help               Show this help message

Marketplace install (Claude Code only, recommended):
  claude plugin marketplace add https://github.com/fmount/openstack-k8s-agent-tools
  claude plugin install openstack-k8s-agent-tools

Examples:
  $0 --claude-code          # Global install for Claude Code
  $0 --opencode             # Global install for OpenCode
  $0 --project-claude       # Project-local install for Claude Code
  $0 --check                # Check dependencies
EOF
}

main() {
    local action=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --claude-code)       action="claude";           shift ;;
            --opencode)          action="opencode";         shift ;;
            --project-claude)    action="project-claude";   shift ;;
            --project-opencode)  action="project-opencode"; shift ;;
            --uninstall-claude)  action="uninstall-claude"; shift ;;
            --uninstall-opencode) action="uninstall-opencode"; shift ;;
            --check)             action="check";            shift ;;
            --help)              show_usage; exit 0 ;;
            *)                   error "Unknown option: $1" ;;
        esac
    done

    if [ -z "$action" ]; then
        show_usage
        exit 1
    fi

    info "$PLUGIN_NAME installer v$VERSION"

    case "$action" in
        claude)            install_claude_code ;;
        opencode)          install_opencode ;;
        project-claude)    install_project claude ;;
        project-opencode)  install_project opencode ;;
        uninstall-claude)  uninstall claude ;;
        uninstall-opencode) uninstall opencode ;;
        check)             check_dependencies ;;
    esac
}

main "$@"
