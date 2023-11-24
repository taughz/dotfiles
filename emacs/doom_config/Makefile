# doom_config/Makefile

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -o errexit -o nounset -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
ifeq ($(origin .RECIPEPREFIX), undefined)
  $(error Please use a version of Make supporting .RECIPEPREFIX)
endif
.RECIPEPREFIX = >

DOOM_SRCS := $(wildcard *.el)
DOOM_INSTALL_DIR := $(HOME)/.doom.d

.PHONY: all
all: install

.PHONY: install
install: $(DOOM_SRCS) | $(DOOM_INSTALL_DIR)
> cp -f -t $(DOOM_INSTALL_DIR) $^
> doom sync -e

$(DOOM_INSTALL_DIR):
> mkdir -p $@
