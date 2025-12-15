.PHONY: help build build-release test test-parallel check format lint clean package package-release stop

help: ## Display available make targets
	@awk 'BEGIN {FS=":.*##"; printf "\nUsage: make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_\-]+:.*##/ {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## Build targets

build: ## Build the project (debug)
	@if [ -n "$$VERBOSE" ]; then \
		swift build; \
	else \
		. ./hack/run_silent.sh && run_silent "Build (debug)" "swift build"; \
	fi

build-release: ## Build the project (release)
	@if [ -n "$$VERBOSE" ]; then \
		swift build -c release; \
	else \
		. ./hack/run_silent.sh && run_silent "Build (release)" "swift build -c release"; \
	fi

## Test targets

test: ## Run unit tests (quiet output)
	@if [ -n "$$VERBOSE" ]; then \
		swift test; \
	else \
		$(MAKE) test-quiet; \
	fi

test-quiet:
	@. ./hack/run_silent.sh && print_main_header "Running Tests"
	@. ./hack/run_silent.sh && print_header "OptimusClip" "Unit tests"
	@. ./hack/run_silent.sh && run_silent_with_test_count "Unit tests passed" "swift test" "swift"

test-parallel: ## Run tests in parallel (quiet output)
	@if [ -n "$$VERBOSE" ]; then \
		swift test --parallel; \
	else \
		. ./hack/run_silent.sh && print_main_header "Running Tests (Parallel)" && \
		print_header "OptimusClip" "Unit tests" && \
		run_silent_with_test_count "Unit tests passed" "swift test --parallel" "swift"; \
	fi

## Check targets (formatting and linting)

check: ## Run format check and lint (quiet output)
	@if [ -n "$$VERBOSE" ]; then \
		swiftformat . --lint && swiftlint lint --strict; \
	else \
		$(MAKE) check-quiet; \
	fi

check-quiet:
	@. ./hack/run_silent.sh && print_main_header "Running Checks"
	@. ./hack/run_silent.sh && print_header "OptimusClip" "Format check"
	@. ./hack/run_silent.sh && run_with_quiet "Format" "swiftformat . --lint"
	@. ./hack/run_silent.sh && print_header "OptimusClip" "Lint"
	@. ./hack/run_silent.sh && run_with_quiet "Lint" "swiftlint lint --strict"

format: ## Auto-format code with swiftformat
	@if [ -n "$$VERBOSE" ]; then \
		swiftformat .; \
	else \
		. ./hack/run_silent.sh && run_silent "Formatting code" "swiftformat ."; \
	fi

lint: ## Run swiftlint with auto-fix and strict mode
	@if [ -n "$$VERBOSE" ]; then \
		swiftlint lint --fix --strict; \
	else \
		. ./hack/run_silent.sh && run_silent "Linting code" "swiftlint lint --fix --strict"; \
	fi

lint-strict: ## Run swiftlint in strict mode
	@if [ -n "$$VERBOSE" ]; then \
		swiftlint lint --strict; \
	else \
		. ./hack/run_silent.sh && run_silent "Lint (strict)" "swiftlint lint --strict"; \
	fi

## Combined targets

check-test: ## Run all checks and tests
	@$(MAKE) check
	@$(MAKE) test

all: ## Run format, lint, and tests
	@$(MAKE) format
	@$(MAKE) lint
	@$(MAKE) test

## Package targets

package: ## Package app (debug build)
	@if [ -n "$$VERBOSE" ]; then \
		./Scripts/package_app.sh debug; \
	else \
		. ./hack/run_silent.sh && run_silent "Package app (debug)" "./Scripts/package_app.sh debug"; \
	fi

package-release: ## Package app (release build)
	@if [ -n "$$VERBOSE" ]; then \
		./Scripts/package_app.sh release; \
	else \
		. ./hack/run_silent.sh && run_silent "Package app (release)" "./Scripts/package_app.sh release"; \
	fi

## Other targets

start: ## Compile and run the app
	@./Scripts/compile_and_run.sh

stop: ## Stop running app instances
	@./Scripts/kill_optimusclip.sh || true

clean: ## Remove build artifacts
	@if [ -n "$$VERBOSE" ]; then \
		swift package clean && rm -rf .build OptimusClip.app; \
	else \
		. ./hack/run_silent.sh && run_silent "Cleaning" "swift package clean && rm -rf .build OptimusClip.app"; \
	fi
