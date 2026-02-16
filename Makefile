SHELL := /bin/bash

.DEFAULT_GOAL := help

SWIFT ?= swift
SWIFT_ENV = SWIFTPM_MODULECACHE_OVERRIDE="$(CURDIR)/.build/modulecache" CLANG_MODULE_CACHE_PATH="$(CURDIR)/.build/clang-module-cache"
SWIFT_SANDBOX_FLAG ?= --disable-sandbox

APP_PRODUCT ?= VitalBarApp
VERSION ?= 0.1.0
DIST_DIR ?= dist
COVERAGE_THRESHOLD ?= 80
ICON_OUTPUT_DIR ?= Assets/IconCandidates
ICON_SOURCE ?= Assets/IconCandidates/vitalbar-icon-pulse-grid.png
ICON_ICNS ?= Assets/AppIcon.icns

.PHONY: help build run test test-coverage coverage-check coverage bundle app icon icon-candidates ci clean

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*##"; print "Available targets:"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build app in debug mode
	$(SWIFT_ENV) $(SWIFT) build $(SWIFT_SANDBOX_FLAG)

run: ## Run VitalBar menu bar app
	$(SWIFT_ENV) $(SWIFT) run $(SWIFT_SANDBOX_FLAG) $(APP_PRODUCT)

test: ## Run all tests
	$(SWIFT_ENV) $(SWIFT) test $(SWIFT_SANDBOX_FLAG)

test-coverage: ## Run tests with code coverage
	$(SWIFT_ENV) $(SWIFT) test $(SWIFT_SANDBOX_FLAG) --enable-code-coverage

coverage-check: ## Enforce VitalBarCore line coverage threshold (default: 80)
	./Scripts/check-core-coverage.sh $(COVERAGE_THRESHOLD)

coverage: test-coverage coverage-check ## Run coverage flow end-to-end

bundle: ## Build .app bundle into dist directory (VERSION=0.1.0 DIST_DIR=dist)
	./Scripts/build-app-bundle.sh $(VERSION) $(DIST_DIR)

app: bundle ## Alias of bundle

icon: ## Build AppIcon.icns from ICON_SOURCE (default: pulse-grid)
	./Scripts/build-app-icon.sh $(ICON_SOURCE) $(ICON_ICNS)

icon-candidates: ## Generate app icon PNG candidates into ICON_OUTPUT_DIR
	$(SWIFT_ENV) $(SWIFT) Scripts/generate-icon-candidates.swift $(ICON_OUTPUT_DIR)

ci: build test-coverage coverage-check ## Run local CI-equivalent checks

clean: ## Remove build outputs and generated artifacts
	rm -rf .build $(DIST_DIR) coverage-summary.json coverage-summary.txt
