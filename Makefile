PLENARY ?= tests/plenary.nvim

test:
	@for f in tests/*_spec.lua; do \
		nvim --headless -u tests/minimal_init.vim -c "lua require('plenary.test_harness').test_file('$$f')" || exit 1; \
	done

format:
	stylua lua/ tests/

check-format:
	stylua --check lua/ tests/

lint:
	luacheck lua/ tests/*_spec.lua

.PHONY: test format check-format lint
