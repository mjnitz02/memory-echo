# MemoryEcho — task runner.
# CI workflows call these same targets, so `make <x>` behaves identically
# locally and in GitHub Actions. Run `make` (or `make help`) for the list.

PROJECT        := MemoryEcho.xcodeproj
SCHEME         := MemoryEcho
UNIT_TARGET    := MemoryEchoTests
UI_TARGET      := MemoryEchoUITests

# Simulator destination. Override on the CLI or in CI if the runner has a
# different device, e.g. `make test-unit SIMULATOR_NAME="iPhone 16"`.
SIMULATOR_NAME ?= iPhone 17
SIMULATOR_OS   ?= latest
# arch=arm64 pins the native slice (Mac + GitHub runners are Apple Silicon) so
# xcodebuild doesn't warn about matching both the arm64 and x86_64/Rosetta slice
# of the same simulator.
DESTINATION    ?= platform=iOS Simulator,name=$(SIMULATOR_NAME),OS=$(SIMULATOR_OS),arch=arm64

XCODEBUILD     := xcodebuild
# Pretty-print xcodebuild output when xcbeautify is installed; otherwise raw.
FORMATTER      := $(shell command -v xcbeautify >/dev/null 2>&1 && echo "| xcbeautify" || echo "")

.DEFAULT_GOAL := help

## help: list available targets
.PHONY: help
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //' | awk -F': ' '{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

## install-tools: install SwiftLint + SwiftFormat (via Homebrew)
.PHONY: install-tools
install-tools:
	brew install swiftlint swiftformat

## install-hooks: enable the repo's git pre-commit hook
.PHONY: install-hooks
install-hooks:
	git config core.hooksPath .githooks
	@echo "pre-commit hook enabled (lint + format-check)."

## lint: run SwiftLint (strict — warnings fail)
.PHONY: lint
lint:
	swiftlint lint --strict

## format: rewrite sources with SwiftFormat
.PHONY: format
format:
	swiftformat .

## format-check: verify formatting without rewriting (used in CI)
.PHONY: format-check
format-check:
	swiftformat --lint .

## build: build the app + widget for the simulator
.PHONY: build
build:
	set -o pipefail; $(XCODEBUILD) build \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' $(FORMATTER)

## test-unit: run Swift Testing unit tests (the CI gate)
.PHONY: test-unit test
test-unit test:
	set -o pipefail; $(XCODEBUILD) test \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:$(UNIT_TARGET) $(FORMATTER)

## test-ui: run XCUITest UI tests (slower, separate CI job)
.PHONY: test-ui
test-ui:
	set -o pipefail; $(XCODEBUILD) test \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:$(UI_TARGET) $(FORMATTER)

## test-all: run unit + UI tests together
.PHONY: test-all
test-all:
	set -o pipefail; $(XCODEBUILD) test \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' $(FORMATTER)

## clean: remove build artifacts
.PHONY: clean
clean:
	$(XCODEBUILD) clean -project $(PROJECT) -scheme $(SCHEME)
	rm -rf .build MemoryEchoCore/.build
