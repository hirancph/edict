# edict Makefile — Convenience targets for system management
#
# Usage:
#   make pull       — Update Guix channels
#   make system     — Reconfigure the operating system (requires sudo)
#   make home       — Reconfigure the home environment
#   make gc         — Run garbage collection
#   make check      — Lint and validate configuration

GUIX_CONFIG_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
MODULES_DIR := $(GUIX_CONFIG_DIR)/modules

# Default host system config — change this or override with: make system HOST=laptop
HOST ?= vessel

export GUIX_PACKAGE_PATH := $(MODULES_DIR)

.PHONY: pull system home deploy gc check repl

## Pull latest channel updates
pull:
	guix pull -C $(GUIX_CONFIG_DIR)/channels.scm

## Reconfigure the operating system
system:
	sudo -E guix system reconfigure \
		-L $(MODULES_DIR) \
		$(MODULES_DIR)/edict/systems/$(HOST).scm

## Reconfigure the home environment
home:
	guix home reconfigure \
		-L $(MODULES_DIR) \
		$(MODULES_DIR)/edict/home/$(HOST).scm

## Reconfigure both system and home
deploy: system home

## Garbage collect old generations
gc:
	guix gc --delete-generations=30d

## Lint custom packages
check:
	@echo "Linting custom packages..."
	@for f in $(MODULES_DIR)/edict/packages/*.scm; do \
		echo "  $$f"; \
	done
	@echo "Done. (Add guix lint commands as packages are created)"

## Start a Guile REPL with modules loaded
repl:
	guile -L $(MODULES_DIR)
