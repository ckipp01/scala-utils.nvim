local has_plenary, Job = pcall(require, "plenary.job")
local F = require("plenary.functional")
local Float = require("plenary.window.float")

if not has_plenary then
  error("You must have plenary installed to use this. 'nvim-lua/plenary.nvim'")
end

local msg = require("scala-utils.msg")

-- Offering the functionality of `cs complete` inside nvim
-- https://get-coursier.io/docs/cli-complete

local ongoing_completion = nil
local ORG_STAGE = "ORG"
local ARTIFACT_STAGE = "ARTIFACT"
local VERSION_STAGE = "VERSION"
local key_mappings = {
  continue_completion = "<cmd>lua require('scala-utils.coursier').continue_completion()<CR>",
  copy_version = "<cmd>lua require('scala-utils.coursier').copy_version()<CR>",
}

-- @param to_complete (string) The string to pass to complete
local complete = function(to_complete)
  local result
  Job:new({
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
  }):sync()
  return result
end

local Completion = {}
Completion.__index = Completion

Completion.new = function(org, artifact, version, stage)
  return setmetatable(
      { org = org, artifact = artifact, version = version, completions = {}, stage = stage },
      Completion
    )
end

-- There are three valid states of completion since you always have to start with something
-- 1. ORG where the org is not yet completed
-- 2. ARTIFACT where the artifact is not yet completed
-- 3. VERSION where the version is not yet completed
Completion.increment_stage = function(self)
  if self.stage == ORG_STAGE then
    self.stage = ARTIFACT_STAGE
  elseif self.stage == ARTIFACT_STAGE then
    self.stage = VERSION_STAGE
  else
    msg.show_error(string.format("Invalid, stage cannot increment further than %s.", VERSION_STAGE))
  end
  return self
end

-- Looking at the current state, formulate the completion args and call complete.
Completion.complete = function(self)
  local seperator = ":"
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
  return self
end

Completion.set_keymap = function(self)
  if self.stage == ORG_STAGE or self.stage == ARTIFACT_STAGE then
    vim.api.nvim_buf_set_keymap(
      self.win.bufnr,
      "n",
      "<CR>",
      key_mappings["continue_completion"],
      { nowait = true, silent = true }
    )
  else
    -- TODO add 3 different keymappings
    -- 1. copy out to sbt format "org" % "artifact" % version
    --  - choose if it's %, %%, or js %%%
    -- 2. copy out to ivy $ivy.`org::artifact:version`
    vim.api.nvim_buf_set_keymap(self.win.bufnr, "n", "<CR>", key_mappings["copy_version"], { nowait = true, silent = true })
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
    local win = Float.percentage_range_window(0.5, 0.2, { winblend = 0 })
    self.win = win
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
    print("Need to be in a valid Scala file to detect Scala dependencies.")
  end
end

local function complete_from_line()
  local org, artifact = get_org_and_artifact_from_line()
  if org and artifact then
    local completion = Completion.new(org, artifact, nil, ARTIFACT_STAGE)
    completion:complete()
    if #completion.completions == 1 then
      completion:increment_stage():complete():create_window():set_display():set_keymap()
    else
      completion:create_window():set_display():set_keymap()
    end
    ongoing_completion = completion
  else
    msg.show_warning("Unable to find a dependency on this line.")
  end
end

local continue_completion = function()
  local line_contents = vim.api.nvim_get_current_line()
  local prev_results = ongoing_completion.completions
  ongoing_completion:update_from_choice(line_contents):complete()
  if #ongoing_completion.completions == 1 or ongoing_completion:compare_completions(prev_results) then
    ongoing_completion:increment_stage():complete():set_display():set_keymap()
  else
    ongoing_completion:set_display():set_keymap()
  end
end

local copy_version = function()
  local line_contents = vim.api.nvim_get_current_line()
  vim.fn.setreg("+", line_contents)
  msg.show_info("Copied version")
  vim.api.nvim_win_close(ongoing_completion.win.win, true)
end

local function stage_from_input(org, artifact, version)
  local stage = nil
  if org and org ~= "" then
    stage = ORG_STAGE
    if artifact and artifact ~= "" then
      stage = ARTIFACT_STAGE
      if version and version ~= "" then
        stage = VERSION_STAGE
      end
    end
  end
  return stage
end

local complete_from_input = function()
  -- TODO: this can probably just be smaller a single line (look into how Telescope does this)
  local win = Float.percentage_range_window(0.5, 0.1, { winblend = 0 })
  vim.api.nvim_buf_set_option(win.bufnr, "buftype", "prompt")
  vim.fn.prompt_setprompt(win.bufnr, (vim.g["scala_utils_prompt"] or "❯") .. " ")

  vim.fn.prompt_setcallback(win.bufnr, function(text)
    vim.api.nvim_win_close(win.win_id, true)
    vim.api.nvim_buf_delete(win.bufnr, { force = true })
    local org, artifact, version = text:match("([%w%-%._]+):?([%w%-%._]*):?(.*)")
    local stage = stage_from_input(org, artifact, version)

    if stage then
      local completion = Completion.new(org, artifact, version, stage)
      completion:complete():create_window():set_display():set_keymap()
      ongoing_completion = completion
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
  copy_version = copy_version,
}
