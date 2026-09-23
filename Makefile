SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

PROJECT_NAME := routeros_ssl
SOURCE_SCRIPT := src/letsencrypt-routeros.bash
SCRIPT := letsencrypt-routeros.bash
DIST_DIR := dist
DIST_DEV_SCRIPT := $(DIST_DIR)/letsencrypt-routeros.dev.bash
DIST_SCRIPT := $(DIST_DIR)/letsencrypt-routeros.bash
DIST_MIN_SCRIPT := $(DIST_DIR)/letsencrypt-routeros.min.bash
DIST_SCRIPTS := $(DIST_DEV_SCRIPT) $(DIST_SCRIPT) $(DIST_MIN_SCRIPT)
DIST_CHECKSUMS := $(addsuffix .sha256,$(DIST_SCRIPTS))

VENDOR_DIR := vendor
DEPENDENCY_MANIFEST := dependencies.txt
BASHDEPS := $(VENDOR_DIR)/bashdeps.bash
BASHDEPS_VERSION := 0.4.1
BASHDEPS_URL := https://github.com/wesley-dean/bashdeps/releases/download/v$(BASHDEPS_VERSION)/bashdeps.bash
BASHDEPS_SHA256 := 5131ebb6a3a85e1d76624a37146c2442b2e57be6ffd8139b9590d28239876701
ADRCTL := $(VENDOR_DIR)/adrctl.bash
ADR_INDEX_FILE := doc/adr/README.md
ADR_INDEX_MARKER := <!-- adrctl-generated-footer -->
BASH_DOXYGEN := $(VENDOR_DIR)/doxygen-bash.awk
BASHLOG_DEV := $(VENDOR_DIR)/bashlog.dev.bash
BASHLOG_VERSION := 0.0.18
BASH_MINIFIER := $(VENDOR_DIR)/bash-minifier.bash
DOCS_OUTPUT := doc/reference
TEST_DIR := tests
TEST_RESULTS_DIR := test-results

VERSION ?= 0.0.0-dev
BUILD_COMMIT ?= $(shell git rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')
BUILD_DATE ?= $(shell git show -s --format=%cI HEAD 2>/dev/null || printf 'unknown')
COMPAT_VERSION := 0.0.0-dev
COMPAT_BUILD_DATE := unknown
COMPAT_BUILD_COMMIT := unknown

.PHONY: adr-index all build check clean deps deps-check distclean docs docs-clean FORCE test verify-bashdeps

all: deps
	$(MAKE) --no-print-directory build

FORCE:

$(BASHDEPS): FORCE
	@mkdir -p "$(VENDOR_DIR)"
	@verify_hash() { \
		path=$$1; \
		if command -v sha256sum >/dev/null 2>&1; then \
			printf '%s  %s\n' "$(BASHDEPS_SHA256)" "$$path" | sha256sum -c - >/dev/null 2>&1; \
		elif command -v shasum >/dev/null 2>&1; then \
			read -r actual _ < <(shasum -a 256 "$$path"); \
			[[ "$$actual" == "$(BASHDEPS_SHA256)" ]]; \
		else \
			return 2; \
		fi; \
	}; \
	if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then \
		printf '%s\n' 'No SHA-256 verification command is available for bashdeps.bash' >&2; \
		exit 1; \
	fi; \
	if [[ -f "$@" ]] && verify_hash "$@"; then \
		chmod 0755 "$@"; \
		exit 0; \
	fi; \
	tmp="$@.tmp"; \
	trap 'rm -f "$$tmp"' EXIT; \
	if command -v curl >/dev/null 2>&1; then \
		curl -fsSL "$(BASHDEPS_URL)" -o "$$tmp"; \
	elif command -v wget >/dev/null 2>&1; then \
		wget -qO "$$tmp" "$(BASHDEPS_URL)"; \
	else \
		printf '%s\n' 'curl or wget is required to bootstrap bashdeps.bash' >&2; \
		exit 1; \
	fi; \
	verify_hash "$$tmp" || { \
		printf '%s\n' 'Downloaded bashdeps.bash does not match the committed SHA-256 digest' >&2; \
		exit 1; \
	}; \
	chmod 0755 "$$tmp"; \
	mv "$$tmp" "$@"; \
	trap - EXIT

verify-bashdeps:
	@test -x "$(BASHDEPS)" || { \
		printf '%s\n' 'Missing or non-executable bashdeps bootstrap; run make deps' >&2; \
		exit 1; \
	}
	@if command -v sha256sum >/dev/null 2>&1; then \
		printf '%s  %s\n' "$(BASHDEPS_SHA256)" "$(BASHDEPS)" | sha256sum -c - >/dev/null 2>&1 || { \
			printf '%s\n' 'bashdeps.bash does not match the committed SHA-256 digest; run make deps' >&2; \
			exit 1; \
		}; \
	elif command -v shasum >/dev/null 2>&1; then \
		read -r actual _ < <(shasum -a 256 "$(BASHDEPS)"); \
		[[ "$$actual" == "$(BASHDEPS_SHA256)" ]] || { \
			printf '%s\n' 'bashdeps.bash digest mismatch; run make deps' >&2; \
			exit 1; \
		}; \
	else \
		printf '%s\n' 'No SHA-256 verification command is available for bashdeps.bash' >&2; \
		exit 1; \
	fi

deps: $(BASHDEPS) $(DEPENDENCY_MANIFEST)
	$(MAKE) --no-print-directory verify-bashdeps
	"$(BASHDEPS)" sync "$(DEPENDENCY_MANIFEST)"

deps-check: verify-bashdeps $(DEPENDENCY_MANIFEST)
	"$(BASHDEPS)" verify "$(DEPENDENCY_MANIFEST)"

adr-index:
	@test -r "$(ADRCTL)" || { \
		printf '%s\n' 'Missing documentation dependency vendor/adrctl.bash; run make deps' >&2; \
		exit 1; \
	}
	@marker='$(ADR_INDEX_MARKER)'; \
	count=0; \
	while IFS= read -r line || [[ -n "$$line" ]]; do \
		if [[ "$$line" == "$$marker" ]]; then ((count += 1)); fi; \
	done <"$(ADR_INDEX_FILE)"; \
	[[ "$$count" == 1 ]] || { \
		printf 'Expected exactly one ADR inventory marker in %s; found %s\n' "$(ADR_INDEX_FILE)" "$$count" >&2; \
		exit 1; \
	}; \
	prefix_tmp="$(ADR_INDEX_FILE).prefix.tmp"; \
	toc_tmp="$(ADR_INDEX_FILE).toc.tmp"; \
	candidate_tmp="$(ADR_INDEX_FILE).tmp"; \
	trap 'rm -f "$$prefix_tmp" "$$toc_tmp" "$$candidate_tmp"' EXIT; \
	: >"$$prefix_tmp"; \
	while IFS= read -r line || [[ -n "$$line" ]]; do \
		printf '%s\n' "$$line" >>"$$prefix_tmp"; \
		[[ "$$line" == "$$marker" ]] && break; \
	done <"$(ADR_INDEX_FILE)"; \
	bash "$(ADRCTL)" generate toc >"$$toc_tmp"; \
	IFS= read -r heading <"$$toc_tmp"; \
	[[ "$$heading" == '# Architecture Decision Records' ]] || { \
		printf 'Unexpected adrctl TOC heading: %s\n' "$$heading" >&2; \
		exit 1; \
	}; \
	{ \
		while IFS= read -r line || [[ -n "$$line" ]]; do printf '%s\n' "$$line"; done <"$$prefix_tmp"; \
		printf '\n'; \
		first=true; \
		while IFS= read -r line || [[ -n "$$line" ]]; do \
			if $$first; then line='## Architecture Decision Records'; first=false; fi; \
			printf '%s\n' "$$line"; \
		done <"$$toc_tmp"; \
	} >"$$candidate_tmp"; \
	if ! cmp -s "$$candidate_tmp" "$(ADR_INDEX_FILE)"; then mv "$$candidate_tmp" "$(ADR_INDEX_FILE)"; fi; \
	trap - EXIT; \
	rm -f "$$prefix_tmp" "$$toc_tmp" "$$candidate_tmp"

docs:
	@test -r "$(BASH_DOXYGEN)" || { \
		printf '%s\n' 'Missing documentation dependency vendor/doxygen-bash.awk; run make deps' >&2; \
		exit 1; \
	}
	@command -v doxygen >/dev/null 2>&1 || { \
		printf '%s\n' 'doxygen is required to generate reference documentation' >&2; \
		exit 1; \
	}
	awk -f "$(BASH_DOXYGEN)" -- --strict "$(SOURCE_SCRIPT)" >/dev/null
	rm -rf "$(DOCS_OUTPUT)"
	doxygen Doxyfile
	@test -f "$(DOCS_OUTPUT)/index.html" || { \
		printf '%s\n' 'Doxygen did not generate doc/reference/index.html' >&2; \
		exit 1; \
	}

docs-clean:
	rm -rf "$(DOCS_OUTPUT)"

build: $(DIST_SCRIPTS) $(DIST_CHECKSUMS) $(SCRIPT)

$(DIST_DEV_SCRIPT): FORCE $(SOURCE_SCRIPT) $(BASHLOG_DEV)
	@mkdir -p "$(DIST_DIR)"
	@tmp="$@.tmp"; \
	trap 'rm -f "$$tmp"' EXIT; \
	{ \
		printf '%s\n' '#!/usr/bin/env bash'; \
		printf '%s\n' '#'; \
		printf '%s\n' '# Generated by make build. Do not edit directly.'; \
		printf '%s\n' '# Project: $(PROJECT_NAME)'; \
		printf '%s\n' '# Version: $(VERSION)'; \
		printf '%s\n' '# Build date: $(BUILD_DATE)'; \
		printf '%s\n' '# Build commit: $(BUILD_COMMIT)'; \
		printf '%s\n' '# Maintained source: $(SOURCE_SCRIPT)'; \
		printf '%s\n' '# Embedded dependency: bashlog.dev.bash v$(BASHLOG_VERSION)'; \
		printf '\n'; \
		printf 'ROUTEROS_SSL_PROJECT_NAME=%q\n' "$(PROJECT_NAME)"; \
		printf 'ROUTEROS_SSL_VERSION=%q\n' "$(VERSION)"; \
		printf 'ROUTEROS_SSL_BUILD_DATE=%q\n' "$(BUILD_DATE)"; \
		printf 'ROUTEROS_SSL_BUILD_COMMIT=%q\n' "$(BUILD_COMMIT)"; \
		printf '\n'; \
		{ IFS= read -r _; while IFS= read -r line || [[ -n "$$line" ]]; do printf '%s\n' "$$line"; done; } <"$(BASHLOG_DEV)"; \
		printf '\n'; \
		{ IFS= read -r _; while IFS= read -r line || [[ -n "$$line" ]]; do printf '%s\n' "$$line"; done; } <"$(SOURCE_SCRIPT)"; \
	} >"$$tmp"; \
	chmod 0755 "$$tmp"; \
	bash -n "$$tmp"; \
	mv "$$tmp" "$@"; \
	trap - EXIT

$(DIST_SCRIPT): $(DIST_DEV_SCRIPT)
	@tmp="$@.tmp"; \
	trap 'rm -f "$$tmp"' EXIT; \
	first=true; \
	while IFS= read -r line || [[ -n "$$line" ]]; do \
		if $$first; then \
			printf '%s\n' "$$line"; \
			first=false; \
			continue; \
		fi; \
		if [[ "$$line" =~ ^[[:space:]]*# ]]; then \
			continue; \
		fi; \
		printf '%s\n' "$$line"; \
	done <"$<" >"$$tmp"; \
	chmod 0755 "$$tmp"; \
	bash -n "$$tmp"; \
	mv "$$tmp" "$@"; \
	trap - EXIT

$(DIST_MIN_SCRIPT): $(DIST_SCRIPT) $(BASH_MINIFIER)
	@tmp="$@.tmp"; \
	trap 'rm -f "$$tmp"' EXIT; \
	bash "$(BASH_MINIFIER)" -F <"$(DIST_SCRIPT)" >"$$tmp"; \
	chmod 0755 "$$tmp"; \
	bash -n "$$tmp"; \
	mv "$$tmp" "$@"; \
	trap - EXIT

$(DIST_DIR)/%.bash.sha256: $(DIST_DIR)/%.bash
	@digest=''; \
	if command -v sha256sum >/dev/null 2>&1; then \
		read -r digest _ < <(sha256sum "$<"); \
	elif command -v shasum >/dev/null 2>&1; then \
		read -r digest _ < <(shasum -a 256 "$<"); \
	else \
		printf '%s\n' 'No SHA-256 command is available for build checksums' >&2; \
		exit 1; \
	fi; \
	printf '%s  %s\n' "$$digest" "$(notdir $<)" >"$@.tmp"; \
	mv "$@.tmp" "$@"

$(SCRIPT): $(DIST_SCRIPT)
	@tmp="$@.tmp"; \
	trap 'rm -f "$$tmp"' EXIT; \
	while IFS= read -r line || [[ -n "$$line" ]]; do \
		case "$$line" in \
			ROUTEROS_SSL_VERSION=*) printf 'ROUTEROS_SSL_VERSION=%q\n' "$(COMPAT_VERSION)" ;; \
			ROUTEROS_SSL_BUILD_DATE=*) printf 'ROUTEROS_SSL_BUILD_DATE=%q\n' "$(COMPAT_BUILD_DATE)" ;; \
			ROUTEROS_SSL_BUILD_COMMIT=*) printf 'ROUTEROS_SSL_BUILD_COMMIT=%q\n' "$(COMPAT_BUILD_COMMIT)" ;; \
			*) printf '%s\n' "$$line" ;; \
		esac; \
	done <"$(DIST_SCRIPT)" >"$$tmp"; \
	chmod 0755 "$$tmp"; \
	bash -n "$$tmp"; \
	mv "$$tmp" "$@"; \
	trap - EXIT

check: build
	bash -n "$(SOURCE_SCRIPT)"
	bash -n "$(SCRIPT)"
	@for artifact in $(DIST_SCRIPTS); do bash -n "$$artifact"; done
	bash -n "$(TEST_DIR)/test_helper.bash"

test: build
	@rm -rf "$(TEST_RESULTS_DIR)"
	@mkdir -p "$(TEST_RESULTS_DIR)"
	@run_tests() { \
		name=$$1; \
		artifact=$$2; \
		report_dir="$(TEST_RESULTS_DIR)/$$name"; \
		mkdir -p "$$report_dir"; \
		printf 'Testing %s\n' "$$artifact"; \
		if ! ROUTEROS_SSL_UNDER_TEST="$(CURDIR)/$$artifact" \
			bats \
				--formatter tap \
				--report-formatter junit \
				--output "$$report_dir" \
				"$(TEST_DIR)"; then \
			return 1; \
		fi; \
	}; \
	status=0; \
	if ! run_tests root "$(SCRIPT)"; then status=1; fi; \
	if ! run_tests development "$(DIST_DEV_SCRIPT)"; then status=1; fi; \
	if ! run_tests ordinary "$(DIST_SCRIPT)"; then status=1; fi; \
	if ! run_tests minified "$(DIST_MIN_SCRIPT)"; then status=1; fi; \
	exit "$$status"
clean: docs-clean
	rm -rf "$(DIST_DIR)" "$(TEST_RESULTS_DIR)"

distclean: clean
	rm -rf "$(VENDOR_DIR)"
