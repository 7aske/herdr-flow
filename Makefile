.PHONY: check lint test install board

check:
	./scripts/check.sh

lint:
	shellcheck -x bin/herdr-flow bin/herdr-flow-tui lib/*.sh

test:
	bats tests/
	$(MAKE) board-test

board:
	cd board && go build -o herdr-flow-board .

board-test:
	cd board && go test ./...

install: board
	ln -sfn "$(CURDIR)/bin/herdr-flow" "$(HOME)/.local/bin/herdr-flow"
	ln -sfn "$(CURDIR)/bin/herdr-flow-tui" "$(HOME)/.local/bin/herdr-flow-tui"
	ln -sfn "$(CURDIR)/board/herdr-flow-board" "$(HOME)/.local/bin/herdr-flow-board"
