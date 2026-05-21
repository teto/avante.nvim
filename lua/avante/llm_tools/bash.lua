---@mod avante-tools-bash Avante bash
---@brief
---Runs bash. Tries to avoid running the 'banned_commands'
local Base = require("avante.llm_tools.base")

---@class AvanteLLMTool
---Gives access to bash
local M = setmetatable({}, Base)

M.name = "bash"

M.get_description = function()
    return [[Executes a given bash command in a persistent shell session with optional timeout, ensuring proper handling and security measures. Do not use bash command to read or modify files, or you will be fired!]]
end

---@type AvanteLLMToolParam
M.param = {
  type = "table",
  fields = {
    {
      name = "path",
      description = "Relative path to the project directory, as cwd",
      type = "string",
    },
    {
      name = "command",
      description = "Command to run",
      type = "string",
    },
  },
  usage = {
    path = "Relative path to the project directory, as cwd",
    command = "Command to run",
  },
}

---@type AvanteLLMToolReturn[]
M.returns = {
  {
    name = "stdout",
    description = "Output of the command",
    type = "string",
  },
  {
    name = "error",
    description = "Error message if the command was not run successfully",
    type = "string",
    optional = true,
  },
}

---@type AvanteLLMToolFunc<{ path: string, command: string }>
function M.func(input, opts)
  local is_streaming = opts.streaming or false
  local Helpers = require("avante.llm_tools.helpers")
  local Path = require("plenary.path")
  local Utils = require("avante.utils")

  if is_streaming then
    -- wait for stream completion as command may not be complete yet
    return
  end

  local abs_path = Helpers.get_abs_path(input.path)
  if not Helpers.has_permission_to_access(abs_path) then return false, "No permission to access path: " .. abs_path end
  if not Path:new(abs_path):exists() then return false, "Path not found: " .. abs_path end
  if not input.command then return false, "Command is required" end
  if opts.on_log then opts.on_log("command: " .. input.command) end

  ---change cwd to abs_path
  ---@param output string
  ---@param exit_code integer
  ---@return string | boolean | nil result
  ---@return string | nil error
  local function handle_result(output, exit_code)
    if exit_code ~= 0 then
      if output then return false, "Error: " .. output .. "; Error code: " .. tostring(exit_code) end
      return false, "Error code: " .. tostring(exit_code)
    end
    return output, nil
  end
  if not opts.on_complete then return false, "on_complete not provided" end
  Helpers.confirm(
    "Are you sure you want to run the command: `" .. input.command .. "` in the directory: " .. abs_path,
    function(ok, reason)
      if not ok then
        opts.on_complete(false, "User declined, reason: " .. (reason and reason or "unknown"))
        return
      end
      Utils.shell_run_async(input.command, "bash -c", function(output, exit_code)
        local result, err = handle_result(output, exit_code)
        opts.on_complete(result, err)
      end, abs_path, 1000 * 60 * 2)
    end,
    { focus = true },
    opts.session_ctx,
    M.name -- Pass the tool name for permission checking
  )
end

return M
