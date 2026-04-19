# edict Makefile — Convenience targets for system management
#
# Usage:
#   make pull       — Update Guix channels
#   make system     — Reconfigure the operating system (requires sudo)
#   make home       — Reconfigure the home environment
#   make deploy     — Reconfigure both system and home
#   make gc         — Run garbage collection
#   make check      — Lint and validate configuration
#   make repl       — Start a Guile REPL with modules loaded
#   make channels   — Deploy channels.scm to ~/.config/guix/

GUIX_CONFIG_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
MODULES_DIR := $(GUIX_CONFIG_DIR)/modules

# Number of parallel build jobs
CORES := $(shell nproc)

# Dynamic host detection — maps hostnames to config names.
# Add new machines here:  HOST_MAP_<hostname> := <config-name>
HOST_MAP_vessel := vessel
HOSTNAME := $(shell hostname)
HOST ?= $(or $(HOST_MAP_$(HOSTNAME)),$(HOSTNAME))

# Substitute URLs read from substitute-urls.txt (one per line, # comments ok).
# Edit that file to add/remove mirrors — takes effect on the very next make target.
SUBSTITUTE_URLS := $(shell sed -e 's/\#.*$$//' -e '/^[[:space:]]*$$/d' $(GUIX_CONFIG_DIR)/substitute-urls.txt | tr '\n' ' ')
SUB_FLAG := --substitute-urls="$(SUBSTITUTE_URLS)"

# Extra arguments for guix commands — e.g., make system ARGS="--dry-run"
ARGS ?=

export GUIX_PACKAGE_PATH := $(MODULES_DIR)

.PHONY: pull system home deploy gc check repl channels \
        quickshell-upstream-fetch quickshell-upstream-log \
        quickshell-upstream-diff quickshell-upstream-show \
        quickshell-upstream-bump

## Pull latest channel updates
pull:
	guix pull -C $(GUIX_CONFIG_DIR)/channels.scm --cores=$(CORES) $(SUB_FLAG) $(ARGS)

## Reconfigure the operating system
system:
	sudo -E guix system reconfigure \
		$(SUB_FLAG) \
		--cores=$(CORES) \
		--fallback \
		-L $(MODULES_DIR) \
		$(MODULES_DIR)/edict/systems/$(HOST).scm $(ARGS)

## Reconfigure the home environment
home:
	guix home reconfigure \
		$(SUB_FLAG) \
		--cores=$(CORES) \
		--fallback \
		-L $(MODULES_DIR) \
		$(MODULES_DIR)/edict/home/$(HOST).scm $(ARGS)

## Reconfigure both system and home
deploy: system home

## Garbage collect old generations
gc:
	guix gc --delete-generations=30d

## Lint custom packages and validate system config
check:
	@echo "═══ Validating system config (dry-run) ═══"
	guix system build \
		$(SUB_FLAG) \
		-L $(MODULES_DIR) \
		--dry-run \
		$(MODULES_DIR)/edict/systems/$(HOST).scm $(ARGS)
	@echo ""
	@echo "═══ Validating home config (dry-run) ═══"
	guix home build \
		$(SUB_FLAG) \
		-L $(MODULES_DIR) \
		--dry-run \
		$(MODULES_DIR)/edict/home/$(HOST).scm $(ARGS)
	@echo ""
	@echo "Done — no errors found."

## Start a Guile REPL with modules loaded
repl:
	guile -L $(MODULES_DIR)

## Deploy channels.scm to ~/.config/guix/
channels:
	@mkdir -p $(HOME)/.config/guix
	@ln -sf $(GUIX_CONFIG_DIR)/channels.scm $(HOME)/.config/guix/channels.scm
	@echo "Symlinked channels.scm → ~/.config/guix/channels.scm"


# ═══════════════════════════════════════════════════════════════════
# Quickshell upstream tracking
# ═══════════════════════════════════════════════════════════════════
#
# files/quickshell/ is a vendored copy of caelestia-dots/shell. The SHA
# we diverged from lives in files/quickshell/.upstream-base. These targets
# fetch upstream into a local cache and show what's changed since that pin
# so you can decide what to port.

QUICKSHELL_UPSTREAM_URL  := https://github.com/caelestia-dots/shell.git
QUICKSHELL_UPSTREAM_DIR  := $(GUIX_CONFIG_DIR)/files/quickshell
QUICKSHELL_UPSTREAM_BASE := $(shell cat $(QUICKSHELL_UPSTREAM_DIR)/.upstream-base 2>/dev/null || echo "HEAD~10")
QUICKSHELL_CACHE         := $(GUIX_CONFIG_DIR)/.cache/caelestia-shell.git

$(QUICKSHELL_CACHE):
	mkdir -p $(dir $(QUICKSHELL_CACHE))
	git clone --bare $(QUICKSHELL_UPSTREAM_URL) $(QUICKSHELL_CACHE)

## Fetch latest upstream quickshell/caelestia changes
quickshell-upstream-fetch: $(QUICKSHELL_CACHE)
	git -C $(QUICKSHELL_CACHE) fetch --quiet origin '+refs/heads/*:refs/heads/*'
	@echo "upstream HEAD: $$(git -C $(QUICKSHELL_CACHE) rev-parse --short main)"
	@echo "pinned base:   $$(echo $(QUICKSHELL_UPSTREAM_BASE) | cut -c1-12)"

## List upstream commits since the pinned base
quickshell-upstream-log: quickshell-upstream-fetch
	@git -C $(QUICKSHELL_CACHE) log --oneline $(QUICKSHELL_UPSTREAM_BASE)..main

## Full diff of upstream changes since the pinned base
quickshell-upstream-diff: quickshell-upstream-fetch
	@git -C $(QUICKSHELL_CACHE) diff $(QUICKSHELL_UPSTREAM_BASE)..main

## Show one upstream commit by SHA: make quickshell-upstream-show SHA=abc123
quickshell-upstream-show: quickshell-upstream-fetch
	@test -n "$(SHA)" || { echo "usage: make quickshell-upstream-show SHA=<sha>"; exit 1; }
	@git -C $(QUICKSHELL_CACHE) show $(SHA)

## Bump the pin to current upstream main (run AFTER porting changes)
quickshell-upstream-bump: quickshell-upstream-fetch
	@new=$$(git -C $(QUICKSHELL_CACHE) rev-parse main); \
	echo $$new > $(QUICKSHELL_UPSTREAM_DIR)/.upstream-base; \
	echo "bumped pin to $$new"
