NVIM ?= nvim
STYLUA ?= stylua
LUACHECK ?= luacheck

.PHONY: check test lint format

check: lint test

test:
	NVIM_LOG_FILE=/tmp/notes.nvim-test.log $(NVIM) --headless -u tests/minimal_init.lua -i NONE -c "lua dofile('tests/test_notes.lua')" -c "qa!"

lint:
	$(STYLUA) --check lua plugin tests
	$(LUACHECK) lua plugin tests

format:
	$(STYLUA) lua plugin tests
