format:
	stylua lua/ tests/*.lua

format-check:
	stylua --check lua/ tests/*.lua

lint:
	luacheck lua/ tests/*.lua

test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal.vim' }"

