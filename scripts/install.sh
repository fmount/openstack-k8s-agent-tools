#!/bin/bash

set -e

# openstack-k8s-operators Operator Tools Installer
# Supports Claude Code and OpenCode platforms

PLUGIN_NAME="openstack-k8s-agent-tools"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="0.1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_dependencies() {
    info "Checking dependencies..."

    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl to use openstack-k8s-operators operator tools."
    fi

    if ! command -v node &> /dev/null; then
        warn "Node.js not found. Some commands may not work."
    fi

    if [ -z "$KUBECONFIG" ]; then
        warn "KUBECONFIG environment variable not set."
        warn "Set it before using commands: export KUBECONFIG=/path/to/kubeconfig"
    else
        info "KUBECONFIG set to: $KUBECONFIG"
    fi

    info "Dependencies check completed."
}

install_claude_code() {
    info "Installing for Claude Code..."

    # Check if Claude Code is installed
    if ! command -v claude &> /dev/null; then
        error "Claude Code not found. Please install Claude Code first."
    fi

    # Get Claude Code plugins directory
    CLAUDE_PLUGINS_DIR="$HOME/.claude/plugins"

    if [ ! -d "$CLAUDE_PLUGINS_DIR" ]; then
        mkdir -p "$CLAUDE_PLUGINS_DIR"
        info "Created Claude plugins directory: $CLAUDE_PLUGINS_DIR"
    fi

    TARGET_DIR="$CLAUDE_PLUGINS_DIR/$PLUGIN_NAME"

    # Remove existing installation
    if [ -d "$TARGET_DIR" ]; then
        warn "Existing installation found. Removing..."
        rm -rf "$TARGET_DIR"
    fi

    # Copy plugin files
    cp -r "$PLUGIN_DIR" "$TARGET_DIR"

    # Ensure .claude-plugin directory exists
    if [ ! -d "$TARGET_DIR/.claude-plugin" ]; then
        cp -r "$PLUGIN_DIR/.claude-plugin" "$TARGET_DIR/"
    fi

    chmod +x "$TARGET_DIR/scripts/install.sh"
    chmod +x "$TARGET_DIR/lib/"*.sh
    chmod +x "$TARGET_DIR/lib/"*.js

    info "Plugin installed to: $TARGET_DIR"
    info "Use '/plugin enable $PLUGIN_NAME' in Claude Code to activate."
}

install_opencode() {
    info "Installing for OpenCode..."

    # OpenCode typically uses a different structure
    OPENCODE_SKILLS_DIR="$HOME/.config/opencode/skills"

    if [ ! -d "$OPENCODE_SKILLS_DIR" ]; then
        mkdir -p "$OPENCODE_SKILLS_DIR"
        info "Created OpenCode skills directory: $OPENCODE_SKILLS_DIR"
    fi

    # Convert Claude skills to OpenCode format
    for skill_dir in "$PLUGIN_DIR/skills"/*; do
        if [ -d "$skill_dir" ]; then
            skill_name=$(basename "$skill_dir")
            target_skill_dir="$OPENCODE_SKILLS_DIR/$skill_name"

            mkdir -p "$target_skill_dir"

            # Convert SKILL.md to OpenCode format (skill.yaml + content.md)
            python3 - << EOF
import yaml
import os
import re

skill_file = "$skill_dir/SKILL.md"
target_dir = "$target_skill_dir"

with open(skill_file, 'r') as f:
    content = f.read()

# Extract YAML frontmatter
yaml_match = re.match(r'^---\n(.*?)\n---\n(.*)', content, re.DOTALL)
if yaml_match:
    yaml_content = yaml.safe_load(yaml_match.group(1))
    md_content = yaml_match.group(2)

    # Write skill.yaml for OpenCode
    with open(os.path.join(target_dir, 'skill.yaml'), 'w') as f:
        yaml.dump(yaml_content, f)

    # Write content.md
    with open(os.path.join(target_dir, 'content.md'), 'w') as f:
        f.write(md_content)
EOF

            info "Converted skill: $skill_name"
        fi
    done

    info "Skills installed for OpenCode in: $OPENCODE_SKILLS_DIR"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --claude-code    Install for Claude Code (default)"
    echo "  --opencode       Install for OpenCode"
    echo "  --check          Check dependencies only"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 # Install for Claude Code"
    echo "  $0 --opencode     # Install for OpenCode"
    echo "  $0 --check        # Check dependencies"
}

main() {
    local platform="claude-code"
    local check_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --claude-code)
                platform="claude-code"
                shift
                ;;
            --opencode)
                platform="opencode"
                shift
                ;;
            --check)
                check_only=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done

    info "openstack-k8s-operators Operator Tools Installer v$VERSION"

    check_dependencies

    if [ "$check_only" = true ]; then
        info "Dependency check completed successfully."
        exit 0
    fi

    case $platform in
        claude-code)
            install_claude_code
            ;;
        opencode)
            install_opencode
            ;;
        *)
            error "Unsupported platform: $platform"
            ;;
    esac

    info "Installation completed successfully!"
    info ""
    info "Next steps:"
    if [ "$platform" = "claude-code" ]; then
        info "1. Run 'claude' to start Claude Code"
        info "2. Use '/plugin enable $PLUGIN_NAME' to activate the plugin"
        info "3. Try '/debug-operator' or '/test-operator quick' to get started"
    else
        info "1. Start OpenCode"
        info "2. Your skills should be automatically available"
        info "3. Check the skills menu for openstack-k8s-operators operator tools"
    fi
}

main "$@"
