# Makefile — canonical entrypoint for the dotfiles repo.
# Works identically on macOS and Ubuntu.

.DEFAULT_GOAL := help

SHELL := /bin/bash

.PHONY: help
help: ## Print the available targets
	@echo "dotfiles — available targets:"
	@echo
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo

.PHONY: install
install: ## Install dotfiles and packages for the current platform
	@./install.sh

.PHONY: install-configs
install-configs: ## Install config files only, skipping package managers
	@DOTFILES_SKIP_PACKAGES=1 ./install.sh

.PHONY: submodules
submodules: ## Fetch/update the vendored oh-my-zsh and zsh plugins
	@git submodule update --init --recursive

.PHONY: packages
packages: ## Install packages only, using this platform's manifest
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		./scripts/packages_macos.sh; \
	else \
		./scripts/packages_ubuntu.sh; \
	fi

.PHONY: test
test: ## Run the full test suite
	@./tests/run_all.sh

.PHONY: lint
lint: ## Syntax-check every shell script and zsh config
	@status=0; \
	for f in install.sh lib/*.sh scripts/*.sh tests/*.sh; do \
		bash -n "$$f" || status=1; \
	done; \
	if command -v zsh >/dev/null 2>&1; then \
		for f in .zshrc .aliases; do \
			zsh -n "$$f" || status=1; \
		done; \
	else \
		echo "zsh not installed; skipping zsh syntax checks"; \
	fi; \
	if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x install.sh lib/*.sh scripts/*.sh || status=1; \
	else \
		echo "shellcheck not installed; skipping (brew install shellcheck / apt install shellcheck)"; \
	fi; \
	exit $$status

.PHONY: clean
clean: ## Remove the staged package manifests from ~/.local/env
	@rm -rf "$(HOME)/.local/env/Brewfile" "$(HOME)/.local/env/Aptfile"
	@echo "cleaned staged manifests"
