local msg = require("scala-utils.msg")
local _config = {
  prompt = "❯",
  coursier = {
    continue_completion_mapping = "<CR>",
    copy_to_mill_mapping = "m",
    copy_to_sbt_mapping = "s",
    copy_to_worksheet_mapping = "w",
    copy_version_mapping = "v",
  },
}

local function setup(config)
  config = config or {}
  if type(config) ~= "table" then
    msg.show_eror("setup given must be a table.")
    return
  end
  for key, value in pairs(config) do
    if _config[key] == nil then
      msg.show_error(string.format("Key %s not a valid config option", key))
      return
    end
    if type(_config[key]) == "table" then
      for k, v in pairs(value) do
        if _config[key][k] == nil then
          msg.show_error(string.format("%s.%s is not a valid config option", key, v))
          return
        end
        _config[key][k] = v
      end
    else
      _config[key] = value
    end
  end
end

return {
  _config = _config,
  setup = setup,
}
