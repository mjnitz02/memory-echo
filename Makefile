# MemoryEcho — task runner.
# CI workflows call these same targets, so `make <x>` behaves identically
# locally and in GitHub Actions. Run `make` (or `make help`) for the list.

# Per-machine overrides (e.g. DEVICE_ID) live here — gitignored, never committed.
# Copy Makefile.local.example to Makefile.local and fill it in. The `-` makes
# the include silent when the file is absent (CI doesn't need it).
-include Makefile.local

PROJECT        := MemoryEcho.xcodeproj
SCHEME         := MemoryEcho
UNIT_TARGET    := MemoryEchoTests
UI_TARGET      := MemoryEchoUITests

# Simulator destination. Override on the CLI or in CI if the runner has a
# different device, e.g. `make test-unit SIMULATOR_NAME="iPhone 16"`.
SIMULATOR_NAME ?= iPhone 17
# arch=arm64 pins the native slice (Mac + GitHub runners are Apple Silicon) so
# xcodebuild doesn't warn about matching both the arm64 and x86_64/Rosetta slice
# of the same simulator.
DESTINATION    ?= platform=iOS Simulator,name=$(SIMULATOR_NAME),arch=arm64

# On-device deploy (paid Apple Developer Program membership). Profiles are good
# for a year, so `make deploy` is only needed when you want new code on the
# phone — plugged in, or paired over Wi-Fi. DEVICE_ID comes from
# `xcrun devicectl list devices` and is set in Makefile.local (or
# `make deploy DEVICE_ID=...`).
APP_NAME       ?= MemoryEcho
DEVICE_CONFIG  ?= Debug
DEVICE_DERIVED ?= build/device
DEVICE_ID      ?=
DEVICE_APP     := $(DEVICE_DERIVED)/Build/Products/$(DEVICE_CONFIG)-iphoneos/$(APP_NAME).app

# TestFlight distribution. Unlike `deploy` — Debug, development-signed, straight
# to the phone over cable/Wi-Fi — this builds Release, signs for distribution,
# and goes through App Store Connect. Slower loop: uploads take 5-15 minutes to
# process, and TestFlight builds expire after 90 days. `deploy` stays the inner
# loop; this is for cable-free installs and stable checkpoints.
ARCHIVE_CONFIG ?= Release
ARCHIVE_PATH   ?= build/$(APP_NAME).xcarchive
EXPORT_OPTIONS ?= ExportOptions.plist

# App Store Connect refuses a duplicate build number for a given
# MARKETING_VERSION. Deriving it from the commit count keeps it monotonic
# without hand-editing (and churning) the pbxproj on every release.
BUILD_NUMBER   ?= $(shell git rev-list --count HEAD)

# NOTE: `archive` and `testflight` deliberately omit `-allowProvisioningUpdates`.
# That flag lets xcodebuild mint signing assets on the Apple Developer account —
# including distribution certificates, which are capped per account. The cert and
# the App Store profiles are provisioned by hand instead, so this automation can
# only ever *consume* credentials, never create them. The cost is that an expired
# profile fails the build rather than silently renewing: re-download it from the
# portal (or archive once through Xcode) and the CLI path works again.

# App Store Connect API key, set in Makefile.local. The .p8 itself lives outside
# the repo and downloads exactly once — if it's lost, revoke and reissue.
ASC_KEY_ID     ?=
ASC_ISSUER_ID  ?=
ASC_KEY_PATH   ?= $(HOME)/.appstoreconnect/private_keys/AuthKey_$(ASC_KEY_ID).p8

XCODEBUILD     := xcodebuild
# Pretty-print xcodebuild output when xcbeautify is installed; otherwise raw.
FORMATTER      := $(shell command -v xcbeautify >/dev/null 2>&1 && echo "| xcbeautify" || echo "")

# Xcode's App Intents metadata step is unreliable under incremental builds. On
# 2026-08-01 an app built into a long-lived $(DEVICE_DERIVED) shipped WITHOUT
# Metadata.appintents: the step was skipped as up-to-date while its output was
# gone. The build succeeded, the install succeeded, and every App Shortcut
# (Action Button, Siri, Shortcuts app) silently vanished from the phone — the
# widget's copy was still there, which made it look app-specific rather than
# like a build problem. Nothing warns you, so check before shipping a bundle.
# $(1) = path to the built .app
define check_appintents
	@test -d "$(1)/Metadata.appintents" || { \
		echo ""; \
		echo "ERROR: no Metadata.appintents in $(1)"; \
		echo "App Shortcuts would silently disappear from the device."; \
		echo "This is stale incremental build state, not a code problem. Clear it:"; \
		echo "    rm -rf $(DEVICE_DERIVED) && make deploy"; \
		echo ""; \
		exit 1; \
	}
	@echo "Verified Metadata.appintents is present."
endef

.DEFAULT_GOAL := help

## help: list available targets
.PHONY: help
help:
	@grep -hE '^## ' $(MAKEFILE_LIST) | sed 's/## //' | awk -F': ' '{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

## install-tools: install SwiftLint + SwiftFormat (via Homebrew)
# Homebrew always installs current stable, so this can drift ahead of the
# versions CI pins in .github/workflows/lint.yml. If a lint/format error only
# reproduces in one place, compare versions there first.
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

## deploy: build + install to the iPhone over cable/Wi-Fi
.PHONY: deploy
deploy:
	@test -n "$(DEVICE_ID)" || { echo "DEVICE_ID is unset. Set it in Makefile.local (copy Makefile.local.example) or pass DEVICE_ID=... — find it via 'xcrun devicectl list devices'."; exit 1; }
	set -o pipefail; $(XCODEBUILD) build \
		-project $(PROJECT) -scheme $(SCHEME) \
		-configuration $(DEVICE_CONFIG) \
		-destination 'generic/platform=iOS' \
		-allowProvisioningUpdates \
		-derivedDataPath $(DEVICE_DERIVED) $(FORMATTER)
	$(call check_appintents,$(DEVICE_APP))
	xcrun devicectl device install app --device $(DEVICE_ID) "$(DEVICE_APP)"
	@echo "Installed $(APP_NAME)."

## ipa: package an unsigned .ipa for SideStore/AltStore (which auto-refreshes)
.PHONY: ipa
ipa:
	set -o pipefail; $(XCODEBUILD) build \
		-project $(PROJECT) -scheme $(SCHEME) \
		-configuration $(DEVICE_CONFIG) \
		-destination 'generic/platform=iOS' \
		CODE_SIGNING_ALLOWED=NO \
		-derivedDataPath $(DEVICE_DERIVED) $(FORMATTER)
	rm -rf build/ipa && mkdir -p build/ipa/Payload
	cp -R "$(DEVICE_APP)" build/ipa/Payload/
	cd build/ipa && zip -qry ../$(APP_NAME).ipa Payload
	@echo "Wrote build/$(APP_NAME).ipa — import it into SideStore/AltStore once."

## archive: build a Release .xcarchive (upload with `make testflight`)
.PHONY: archive
archive:
	set -o pipefail; $(XCODEBUILD) archive \
		-project $(PROJECT) -scheme $(SCHEME) \
		-configuration $(ARCHIVE_CONFIG) \
		-destination 'generic/platform=iOS' \
		-archivePath $(ARCHIVE_PATH) \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) $(FORMATTER)
	$(call check_appintents,$(ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app)
	@echo "Archived build $(BUILD_NUMBER) -> $(ARCHIVE_PATH)"

## testflight: archive + upload to App Store Connect for internal testing
.PHONY: testflight
testflight: archive
	@test -n "$(ASC_KEY_ID)" || { echo "ASC_KEY_ID is unset. Set it in Makefile.local — it's the 10-character code in the key filename (AuthKey_XXXXXXXXXX.p8)."; exit 1; }
	@test -n "$(ASC_ISSUER_ID)" || { echo "ASC_ISSUER_ID is unset. Set it in Makefile.local — find it at the top of App Store Connect > Users and Access > Integrations > App Store Connect API."; exit 1; }
	@test -f "$(ASC_KEY_PATH)" || { echo "No API key at $(ASC_KEY_PATH). The .p8 downloads only once; if it's gone, revoke the key in App Store Connect and issue a new one."; exit 1; }
	set -o pipefail; $(XCODEBUILD) -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportOptionsPlist $(EXPORT_OPTIONS) \
		-exportPath build/export \
		-authenticationKeyPath $(ASC_KEY_PATH) \
		-authenticationKeyID $(ASC_KEY_ID) \
		-authenticationKeyIssuerID $(ASC_ISSUER_ID) $(FORMATTER)
	@echo "Uploaded build $(BUILD_NUMBER). Processing takes 5-15 min, then it appears for the Personal group in TestFlight."

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
	rm -rf .build MemoryEchoCore/.build build
