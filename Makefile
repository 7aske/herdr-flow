.PHONY: check lint test install board

check:
	./scripts/check.sh

lint:
	shellcheck -x bin/herdr-flow bin/herdr-flow-tui lib/*.sh

test:
	bats tests/
	$(MAKE) board-test

install: board
	ln -sfn "$(CURDIR)/bin/herdr-flow" "$(HOME)/.local/bin/herdr-flow"
	ln -sfn "$(CURDIR)/bin/herdr-flow-tui" "$(HOME)/.local/bin/herdr-flow-tui"
