local has_plenary, Job = pcall(require, "plenary.job")
local F = require("plenary.functional")

if not has_plenary then
  error("You must have plenary installed to use this. 'nvim-lua/plenary.nvim'")
end

local config = require("scala-utils")._config
local msg = require("scala-utils.msg")
local ui = require("scala-utils.ui")

-----------------------------------------------------------
-- Offering the functionality of `cs complete` inside nvim
--  https://get-coursier.io/docs/cli-complete
-----------------------------------------------------------

local ongoing_completion = nil
local ORG_STAGE = "ORG"
local ARTIFACT_STAGE = "ARTIFACT"
local VERSION_STAGE = "VERSION"
local seperator = ":"
local key_mappings = {
  continue_completion = [[<cmd>lua require("scala-utils.coursier").continue_completion()<CR>]],
  copy_to_mill = [[<cmd>lua require("scala-utils.coursier").copy_to("mill")<CR>]],
  copy_to_sbt = [[<cmd>lua require("scala-utils.coursier").copy_to("sbt")<CR>]],
  copy_to_worksheet = [[<cmd>lua require("scala-utils.coursier").copy_to("worksheet")<CR>]],
  copy_version = [[<cmd>lua require("scala-utils.coursier").copy_version()<CR>]],
}

-- @param to_complete (string) The string to pass to complete
local complete = function(to_complete)
  local result
  Job
    :new({
      command = "cs",
      args = { "complete", to_complete },
      on_exit = function(j, return_val)
        if return_val == 0 then
          result = j:result()
        else
          msg.show_error("Something went wrong, unable to get completions")
          msg.show_error(j:stderr_result())
        end
      end,
    })
    :sync()
  return result
end

-- @param bufnr (number) buffer number
-- @param lhs (string) lhs for the mapping
-- @param rhs (string) rhs for the mapping
local function set_keymap(bufnr, lhs, rhs)
  vim.api.nvim_buf_set_keymap(bufnr, "n", lhs, rhs, { nowait = true, silent = true })
end

local Completion = {}
Completion.__index = Completion

Completion.new = function(org, artifact, version, stage)
  local starting_title
  if stage == ORG_STAGE then
    starting_title = org
  elseif stage == ARTIFACT_STAGE then
    starting_title = org .. seperator .. artifact
  elseif stage == VERSION_STAGE then
    starting_title = org .. seperator .. artifact .. seperator
  end
  local completion = setmetatable({
    org = org,
    artifact = artifact,
    version = version,
    completions = {},
    stage = stage,
    title = starting_title,
  }, Completion)
  ongoing_completion = completion
  return completion
end

-- There are three valid states of completion since you always have to start with something
-- 1. ORG where the org is not yet completed
-- 2. ARTIFACT where the artifact is not yet completed
-- 3. VERSION where the version is not yet completed
Completion.increment_stage = function(self)
  if self.stage == ORG_STAGE then
    self.stage = ARTIFACT_STAGE
    self.title = self.org .. seperator
  elseif self.stage == ARTIFACT_STAGE then
    self.stage = VERSION_STAGE
    self.title = self.org .. seperator .. self.artifact .. seperator
  end
  return self
end

-- Looking at the current state, formulate the completion args and call complete.
Completion.complete = function(self)
  local args
  if self.stage == ORG_STAGE then
    args = self.org
  elseif self.stage == ARTIFACT_STAGE then
    args = string.format("%s%s%s", self.org, seperator, self.artifact or "")
  elseif self.stage == VERSION_STAGE then
    args = string.format("%s%s%s%s%s", self.org, seperator, self.artifact, seperator, self.version or "")
  else
    msg.show_error(string.format("Invalid stage: %s", self.stage))
  end
  self.completions = complete(args)
  if self.stage == VERSION_STAGE then
    self:reverse_completions()
  end
  return self
end

-- TODO: Once https://github.com/nvim-lua/plenary.nvim/pull/109 is merged, just
-- use reverse from there.
Completion.reverse_completions = function(self)
  local n = #self.completions
  local i = 1
  while i < n do
    self.completions[i], self.completions[n] = self.completions[n], self.completions[i]
    i = i + 1
    n = n - 1
  end
end

Completion.update_from_choice = function(self, from_choice)
  if self.stage == ORG_STAGE then
    self.org = from_choice
  elseif self.stage == ARTIFACT_STAGE then
    self.artifact = from_choice
  elseif self.stage == VERSION_STAGE then
    self.version = from_choice
  end
  return self
end

Completion.set_display = function(self)
  vim.api.nvim_buf_set_lines(self.win.bufnr, 0, -1, false, self.completions)
  self.win.border:change_title(self.title)

  if self.stage == VERSION_STAGE then
    vim.api.nvim_win_set_cursor(self.win.win_id, { 1, 0 })
  end
  return self
end

Completion.set_keymaps = function(self)
  if self.stage == ORG_STAGE or self.stage == ARTIFACT_STAGE then
    set_keymap(self.win.bufnr, config.coursier.continue_completion_mapping, key_mappings["continue_completion"])
  else
    set_keymap(self.win.bufnr, config.coursier.copy_version_mapping, key_mappings["copy_version"])
    set_keymap(self.win.bufnr, config.coursier.copy_to_sbt_mapping, key_mappings["copy_to_sbt"])
    set_keymap(self.win.bufnr, config.coursier.copy_to_mill_mapping, key_mappings["copy_to_mill"])
    set_keymap(self.win.bufnr, config.coursier.copy_to_worksheet_mapping, key_mappings["copy_to_worksheet"])
  end
  return self
end

Completion.compare_completions = function(self, old_completions)
  if #self.completions ~= #old_completions then
    return false
  else
    return F.all(function(k, v)
      return self.completions[k] == v
    end, old_completions)
  end
end

Completion.create_window = function(self)
  if self.win ~= nil then
    msg.show_error(string.format("Cannot create another completion window, one already exists."))
  else
    local win_opts = ui.default_win_opts
    win_opts.row = math.ceil(vim.o.lines * 0.4)
    win_opts.col = math.floor(vim.o.columns * 0.25)
    win_opts.width = math.floor(vim.o.columns * 0.5)
    win_opts.height = math.ceil(vim.o.lines * 0.2)

    local bordered_win = ui.bordered_win(win_opts, { title = self.title })

    self.win = {
      bufnr = bordered_win.bufnr,
      border = bordered_win.border,
    }
  end
  return self
end

local function get_org_and_artifact_from_line()
  local line = vim.api.nvim_get_current_line()
  local filename = vim.api.nvim_buf_get_name(0)
  if vim.endswith(filename, ".sbt") or vim.endswith(filename, ".scala") then
    return line:match('"(.-)"%s+%%?%%?%%%s+"(.-)"%s+%%.+')
  elseif vim.endswith(filename, ".sc") then
    return line:match('ivy?.["`](.-):?:?:(.+):.+')
  else
    msg.show_warning("Need to be in a valid Scala file to detect Scala dependencies.")
  end
end

local function complete_from_line()
  local org, artifact = get_org_and_artifact_from_line()
  if org and artifact then
    local completion = Completion.new(org, artifact, nil, ARTIFACT_STAGE)
    completion:complete()
    if #completion.completions == 1 then
      completion:increment_stage():complete():create_window():set_display():set_keymaps()
    else
      completion:create_window():set_display():set_keymaps()
    end
  else
    msg.show_warning("Unable to find a dependency on this line.")
  end
end

local continue_completion = function()
  local line_contents = vim.api.nvim_get_current_line()
  local prev_results = ongoing_completion.completions
  ongoing_completion:update_from_choice(line_contents):complete()
  if #ongoing_completion.completions == 1 or ongoing_completion:compare_completions(prev_results) then
    ongoing_completion:increment_stage():complete():set_display():set_keymaps()
  else
    ongoing_completion:set_display():set_keymaps()
  end
end

local copy_version = function()
  local line_contents = vim.api.nvim_get_current_line()
  vim.fn.setreg("+", line_contents)
  msg.show_info("Copied version")
  vim.api.nvim_win_close(ongoing_completion.win.win, true)
end

-- Create an output to copy out from the current completions org, artifact, and version.
-- @param format (string) Enum of possible output values: sbt, mill, worksheet
local function copy_to(format)
  local line_contents = vim.api.nvim_get_current_line()
  ongoing_completion.version = line_contents
  local java_or_scala, artifact, format_string
  local start, end_point = ongoing_completion.artifact:find("_")
  if start and end_point then
    artifact = ongoing_completion.artifact:sub(0, start - 1)
    if format == "sbt" then
      java_or_scala = "%%"
    else
      java_or_scala = "::"
    end
  else
    artifact = ongoing_completion.artifact
    if format == "sbt" then
      java_or_scala = "%"
    else
      java_or_scala = ":"
    end
  end

  if format == "sbt" then
    format_string = [["%s" %s "%s" %% "%s"]]
  elseif format == "mill" then
    format_string = [[ivy"%s%s%s:%s"]]
  elseif format == "worksheet" then
    format_string = [[$dep.`%s%s%s:%s`]]
  else
    msg.show_error(string.format("Unknown output format: %s", format))
  end

  local output_string = string.format(
    format_string,
    ongoing_completion.org,
    java_or_scala,
    artifact,
    ongoing_completion.version
  )

  vim.fn.setreg("+", output_string)
  msg.show_info(string.format("Copied %s dependency", format))
  vim.api.nvim_win_close(ongoing_completion.win.win, true)
end

local function stage_from_input(org, artifact, version, colon_count)
  local stage = nil
  if org and org ~= "" then
    stage = ORG_STAGE
    if artifact and artifact ~= "" then
      if colon_count == 1 then
        stage = ARTIFACT_STAGE
      else
        stage = VERSION_STAGE
      end
      if version and version ~= "" then
        stage = VERSION_STAGE
      end
    end
  end
  return stage
end

local complete_from_input = function()
  local win_opts = ui.default_win_opts
  win_opts.height = 1

  local bordered_win = ui.bordered_win(win_opts, { title = "complete" })

  vim.api.nvim_buf_set_option(bordered_win.bufnr, "buftype", "prompt")
  vim.fn.prompt_setprompt(bordered_win.bufnr, config.prompt .. " ")

  vim.fn.prompt_setcallback(bordered_win.bufnr, function(text)
    vim.api.nvim_win_close(bordered_win.win_id, true)
    vim.api.nvim_buf_delete(bordered_win.bufnr, { force = true })

    local org, artifact, version = text:match("([%w%-%._]+):?([%w%-%._]*):?(.*)")
    -- So this isn't ideal to do again, and it may be possible to just capture
    -- this somehow with the above match, but I'm unsure how and this is way
    -- easier atm. We need to capture is since in the scenario
    -- `org.scalameta:metals_2.12:` we actually want to be at the version
    -- stage, but it's currently registered at the artifact because the `:`
    -- isn't taken into account, so here we grab it to correctly be able to set
    -- the stage. However, we don't fully rely on it since we still want to
    -- ensure it's in valid format.
    local _, colon_count = text:gsub(":", "")
    local stage = stage_from_input(org, artifact, version, colon_count)

    if stage then
      local completion = Completion.new(org, artifact, version, stage)
      completion:complete():create_window():set_display():set_keymaps()
    else
      msg.show_warning("Must pass in valid input.")
    end
  end)

  vim.cmd("startinsert")
end

return {
  complete = complete,
  complete_from_input = complete_from_input,
  complete_from_line = complete_from_line,
  continue_completion = continue_completion,
  copy_to = copy_to,
  copy_version = copy_version,
}
