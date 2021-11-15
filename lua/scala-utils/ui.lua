local Border = require("plenary.window.border")

-------------------------------------------------------------------------------
-- Some basic wrappers around creating a floating window using plenary borders.
-- We don't directly use the plenary float just to be able to easier return the
-- full border table and change it later on, and also to have more direct
-- control over the height if we don't want a percentage
-------------------------------------------------------------------------------

_Scala_utils_bufs = {}

local function clear(bufnr)
  if _Scala_utils_bufs[bufnr] == nil then
    return
  end

  for _, win_id in ipairs(_Scala_utils_bufs[bufnr]) do
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, true)
    end
  end

  _Scala_utils_bufs[bufnr] = nil
end

local clear_buf_on_leave = function(bufnr)
  vim.cmd(
    string.format(
      "autocmd WinLeave,BufLeave,BufDelete <buffer=%s> ++once ++nested lua require('scala-utils.ui').clear(%s)",
      bufnr,
      bufnr
    )
  )
end

local default_win_opts = {
  relative = "editor",
  row = math.ceil(vim.o.lines / 2),
  col = math.floor(vim.o.columns * 0.25),
  width = math.floor(vim.o.columns / 2),
  height = 1,
  style = "minimal",
}

local bordered_win = function(win_opts, border_opts)
  local bufnr = vim.api.nvim_create_buf(false, true)

  local win_id = vim.api.nvim_open_win(bufnr, true, win_opts)
  vim.api.nvim_win_set_buf(win_id, bufnr)

  local border = Border:new(bufnr, win_id, win_opts, border_opts)

  _Scala_utils_bufs[bufnr] = { win_id, border.win_id }

  clear_buf_on_leave(bufnr)

  vim.cmd("setlocal nocursorcolumn")
  return {
    border = border,
    bufnr = bufnr,
    win_id = win_id,
  }
end

return {
  bordered_win = bordered_win,
  clear = clear,
  default_win_opts = default_win_opts,
}
