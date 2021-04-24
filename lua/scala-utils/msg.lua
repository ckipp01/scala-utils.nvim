-- Some very basic functions to just show info to the user. We could also use
-- Plenary.log, but we don't need nearly everything that offers. Mainly I just
-- want a nice way to show messges to the user with various levels of
-- importance. For now, this seems to be fine.

local function show_info(msg)
  print(string.format("[scala-utils] - %s", msg))
end

local function show_warning(msg)
  vim.cmd("echohl WarningMsg")
  vim.cmd(string.format("echom '[scala-utils] - %s'", msg))
  vim.cmd("echohl NONE")
end

local function show_error(msg)
  vim.cmd("echohl ErrorMsg")
  vim.cmd(string.format("echom '[scala-utils] - %s'", msg))
  vim.cmd("echohl NONE")
end

return {
  show_info = show_info,
  show_warning = show_warning,
  show_error = show_error,
}
