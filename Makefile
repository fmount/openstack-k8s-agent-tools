.PHONY: install-claude install-opencode uninstall-claude uninstall-opencode \
       check test validate help

INSTALL := ./scripts/install.sh

## Installation

install-claude: ## Install globally for Claude Code (~/.claude/)
	@$(INSTALL) --claude-code

install-opencode: ## Install globally for OpenCode (~/.config/opencode/)
	@$(INSTALL) --opencode

## Uninstall

uninstall-claude: ## Remove from Claude Code
	@$(INSTALL) --uninstall-claude

uninstall-opencode: ## Remove from OpenCode
	@$(INSTALL) --uninstall-opencode

## Validation

check: ## Check dependencies
	@$(INSTALL) --check

test: ## Run plugin tests (structure + functional)
	@bash tests/test-plugin.sh all

validate: ## Run structure validation only
	@bash tests/test-plugin.sh structure

## Help

help: ## Show this help
	@echo "openstack-k8s-agent-tools"
	@echo ""
	@echo "Marketplace install (Claude Code, recommended):"
	@echo "  claude plugin marketplace add https://github.com/fmount/openstack-k8s-agent-tools"
	@echo "  claude plugin install openstack-k8s-agent-tools"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'
