PLENARY ?= tests/plenary.nvim

test:
	nvim --headless -c "lua require('plenary.test_harness').test_directory('tests/', {minimal_init = 'tests/minimal_init.vim'})"

format:
	stylua lua/ tests/

check-format:
	stylua --check lua/ tests/

lint:
	luacheck lua/ tests/

.PHONY: test format check-format lint
