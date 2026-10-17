# The family's root checkout, where odin-html-builder sits beside this
# repository. The default is the layout `init.sh` makes and CI reproduces;
# override it to build against a builder checked out somewhere else:
#
#   make test ODIN_HTML_ROOT=$HOME/src
ODIN_HTML_ROOT ?= ..

# Odin source collections. Each collection is a repository root, as in the
# odin-rdf family, so an import names the repository and then the package
# inside it: `import "html:html/h"`, `html:html/a` and `html:html/hx` for the
# builder, `import "ui:ui/button"` for a sibling component here. This
# repository is its own `ui:` collection because the components import each
# other (sheet is built on dialog, sidebar on sheet, the pickers on popover),
# and a consumer declares the same two collections pointing at its own
# checkouts. ols.json mirrors both.
COLL := -collection:html=$(ODIN_HTML_ROOT)/odin-html-builder -collection:ui=.

# Every component package, discovered rather than listed: there is one per
# directory under ui/ and about forty of them, and a list that a new
# component forgot to join would leave it silently unchecked -- the failure
# runs toward no verification, which is the wrong direction. `ui/layout` has
# no tests and is vetted all the same.
PKGS := $(patsubst %/,%,$(sort $(dir $(wildcard ui/*/*.odin))))

# The web half: the `oh-*` custom elements, their contract manifests and the
# stylesheet, built by Vite through Bun.
WEB := web

.PHONY: all help test check web-install web-typecheck web-build web clean

all: test check web

# The description of a target is the `##` on its own recipe line, which is what
# help greps for -- prose above a target is for a reader of this file, not the
# listing. A target with no `##` is internal and stays out of it.
help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*## / {printf "%-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# The test runner tracks allocations per test but only warns about leaks and bad
# frees by default, which a passing build hides. Promote them to failures.
TEST_FLAGS := -define:ODIN_TEST_FAIL_ON_BAD_MEMORY=true $(COLL)

# Test binaries go under build/test/ rather than the repository root, where
# `odin test` leaves them by default when a run is interrupted. A contract
# test reads its manifest from web/src/ui by `#directory`, so the suite needs
# the source tree and nothing built: no Bun, no Vite.
test: ## Run every component's tests
	@mkdir -p build/test
	@for pkg in $(PKGS); do \
		echo "-- $$pkg --"; \
		odin test $$pkg $(TEST_FLAGS) -out:build/test/$$(basename $$pkg) || exit 1; \
	done

# The last step is the family's style rule the vet cannot express: Odin binds
# an import to the last component of its path, so `import h "html:html/h"`
# says nothing that `import "html:html/h"` does not. An alias that differs
# from the last component (`import cal "ui:ui/calendar"`) is doing something
# and is not flagged.
check: ## Vet every package
	@for pkg in $(PKGS); do \
		echo "-- $$pkg --"; \
		odin check $$pkg -no-entry-point -vet -strict-style $(COLL) || exit 1; \
	done
	@echo "-- import aliases --"
	@if grep -rnE '^import ([A-Za-z_]+) "([^"]*[:/])?\1"' --include='*.odin' ui; then \
		echo "error: redundant import alias -- Odin already binds the last path component"; exit 1; \
	fi

# --frozen-lockfile so an install never rewrites bun.lock: a dependency moves
# by a deliberate commit of the lockfile, not as a side effect of building.
web-install: ## Install the web dependencies from bun.lock
	@cd $(WEB) && bun install --frozen-lockfile

web-typecheck: ## Typecheck the custom elements and their manifest imports
	@cd $(WEB) && bun run typecheck

web-build: ## Build the stylesheet and bundle into web/dist
	@cd $(WEB) && bun run build

web: web-typecheck web-build ## Typecheck and build the web half

clean: ## Remove build/ and web/dist
	rm -rf build $(WEB)/dist
