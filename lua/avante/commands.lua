---@mod avante-commands avante commands
---
---@brief [[
---
--- Commands~
---
---                                                     *:AvanteAsk*
--- :AvanteAsk [--position=left|right|top|bottom] [--ask=true|false] [question]
---         Ask AI about your code. Example:
--->
---         :AvanteAsk --position=right Refactor this function
---<
---         Legacy key=value arguments such as `position=right` are still accepted.
---
---                                                     *:AvanteChat*
--- :AvanteChat [args]
---         Start a chat session with AI about your codebase.
---
---                                                     *:AvanteChatNew*
--- :AvanteChatNew [args]
---         Start a new chat session.
---
---                                                     *:AvanteHistory*
--- :AvanteHistory
---         Open a picker for previous chat sessions.
---
---                                                     *:AvanteClear*
--- :AvanteClear [history|cache]
---         Clear the current chat history or Avante cache.
---
---                                                     *:AvanteBuild*
--- :AvanteBuild [--source=true|false]
---         Build dependencies for the project.
---
---                                                     *:AvanteEdit*
--- :[range]AvanteEdit [instruction]
---         Edit the selected code blocks or range.
---
---                                                     *:AvanteFocus*
--- :AvanteFocus
---         Switch focus to or from the sidebar.
---
---                                                     *:AvanteRefresh*
--- :AvanteRefresh
---         Refresh all Avante windows.
---
---                                                     *:AvanteStop*
--- :AvanteStop
---         Stop the current AI request.
---
---                                                     *:AvanteSwitchProvider*
--- :AvanteSwitchProvider
---         Switch AI provider.
---
---                                                     *:AvanteSwitchSelectorProvider*
--- :AvanteSwitchSelectorProvider {provider}
---         Switch selector provider.
---
---                                                     *:AvanteSwitchInputProvider*
--- :AvanteSwitchInputProvider {native|dressing|snacks}
---         Switch input provider.
---
---                                                     *:AvanteShowRepoMap*
--- :AvanteShowRepoMap
---         Show the repository map for the project.
---
---                                                     *:AvanteToggle*
--- :AvanteToggle
---         Toggle the Avante sidebar.
---
---                                                     *:AvanteModels*
--- :AvanteModels
---         Show the model list.
---
---                                                     *:AvanteACPModels*
--- :AvanteACPModels
---         Switch ACP model.
---
---                                                     *:AvanteACPModes*
--- :AvanteACPModes
---         Switch ACP mode.
---
---@brief ]]

local cmdparse = require("mega.cmdparse")
local Config = require("avante.config")
local P = require("avante.path")
local Utils = require("avante.utils")

local M = {}

local POSITION_CHOICES = { "left", "right", "top", "bottom" }
local BOOLEAN_CHOICES = { "true", "false" }
local CLEAR_CHOICES = { "history", "cache" }
local INPUT_PROVIDER_CHOICES = { "native", "dressing", "snacks" }
local SELECTOR_PROVIDER_CHOICES = { "native", "fzf_lua", "mini_pick", "snacks", "telescope" }

local LEGACY_FLAGS = {
  ask = true,
  position = true,
  project_root = true,
  source = true,
}

---@param value any
---@return boolean?
local function to_bool(value)
  if value == nil then return nil end
  if value == true or value == false then return value end
  return value == "true"
end

---@param args string
---@return string
local function normalize_legacy_args(args)
  return (args:gsub("^(%s*)([%w_][%w_]*)=", function(prefix, key)
    if not LEGACY_FLAGS[key] then return prefix .. key .. "=" end
    return prefix .. "--" .. key:gsub("_", "-") .. "="
  end):gsub("(%s+)([%w_][%w_]*)=", function(prefix, key)
    if not LEGACY_FLAGS[key] then return prefix .. key .. "=" end
    return prefix .. "--" .. key:gsub("_", "-") .. "="
  end))
end

---@param parser_creator fun(): mega.cmdparse.ParameterParser
---@return fun(opts: vim.api.keyset.create_user_command.command_args): nil
local function make_legacy_triager(parser_creator)
  local triager = cmdparse.make_parser_triager(parser_creator)
  return function(opts)
    opts.args = normalize_legacy_args(opts.args or "")
    opts.fargs = vim.split(opts.args, "%s+", { trimempty = true })
    triager(opts)
  end
end

---@param parser_creator fun(): mega.cmdparse.ParameterParser
---@return fun(_: any, all_text: string, _: any): string[]?
local function make_legacy_completer(parser_creator)
  local completer = cmdparse.make_parser_completer(parser_creator)
  return function(arg_lead, all_text, pos)
    return completer(arg_lead, normalize_legacy_args(all_text), pos)
  end
end

---@param name string
---@param parser_creator fun(): mega.cmdparse.ParameterParser
---@param opts? vim.api.keyset.user_command
local function create_command(name, parser_creator, opts)
  opts = vim.tbl_deep_extend("force", {
    nargs = "*",
    complete = make_legacy_completer(parser_creator),
  }, opts or {})
  if opts.nargs == 0 then opts.complete = nil end
  vim.api.nvim_create_user_command(name, make_legacy_triager(parser_creator), opts)
end

---@return string[]
local function project_root_choices()
  return vim.tbl_map(function(project) return project.root end, P.list_projects())
end

---@return string[]
local function provider_choices()
  local providers = vim.tbl_keys(Config.providers)
  vim.list_extend(providers, vim.tbl_keys(Config.acp_providers))
  table.sort(providers)
  return providers
end

---@param namespace table<string, any>
---@return AskOptions
local function ask_options(namespace)
  local args = {
    question = namespace.question and table.concat(namespace.question, " ") or nil,
    win = {},
  }
  if namespace.position then args.win.position = namespace.position end
  args.ask = to_bool(namespace.ask)
  args.project_root = namespace.project_root
  return args
end

---@param name string
---@param help string
---@param execute fun(namespace: table<string, any>): nil
---@return mega.cmdparse.ParameterParser
local function ask_parser(name, help, execute)
  local parser = cmdparse.ParameterParser.new({ name = name, help = help })
  parser:add_parameter({ name = "question", nargs = "*", required = false, help = "Question or prompt text." })
  parser:add_parameter({ name = "--position", choices = POSITION_CHOICES, help = "Sidebar position." })
  parser:add_parameter({ name = "--project-root", choices = project_root_choices, help = "Project root." })
  parser:add_parameter({ name = "--ask", choices = BOOLEAN_CHOICES, type = to_bool, help = "Enable direct ask mode." })
  parser:set_execute(function(data) execute(data.namespace) end)
  return parser
end

---@param name string
---@param help string
---@param execute fun(namespace: table<string, any>): nil
---@return fun(): mega.cmdparse.ParameterParser
local function make_ask_parser(name, help, execute)
  return function() return ask_parser(name, help, execute) end
end

---@param name string
---@param help string
---@param execute fun(data: mega.cmdparse.NamespaceExecuteArguments): nil
---@return fun(): mega.cmdparse.ParameterParser
local function make_noarg_parser(name, help, execute)
  return function()
    local parser = cmdparse.ParameterParser.new({ name = name, help = help })
    parser:set_execute(execute)
    return parser
  end
end

---@return mega.cmdparse.ParameterParser
local function build_parser()
  local parser = cmdparse.ParameterParser.new({ name = "AvanteBuild", help = "Build dependencies for the project." })
  parser:add_parameter({ name = "--source", choices = BOOLEAN_CHOICES, type = to_bool, help = "Build from source." })
  parser:set_execute(function(data)
    local args = { source = data.namespace.source }
    if args.source == nil then args.source = false end
    require("avante.api").build(args)
  end)
  return parser
end

---@return mega.cmdparse.ParameterParser
local function edit_parser()
  local parser = cmdparse.ParameterParser.new({ name = "AvanteEdit", help = "Edit selected block." })
  parser:add_parameter({ name = "instruction", nargs = "*", required = false, help = "Edit instruction." })
  parser:set_execute(function(data)
    local instruction = data.namespace.instruction and table.concat(data.namespace.instruction, " ") or ""
    require("avante.api").edit(vim.trim(instruction), data.options.line1, data.options.line2)
  end)
  return parser
end

---@return mega.cmdparse.ParameterParser
local function switch_selector_provider_parser()
  local parser = cmdparse.ParameterParser.new({
    name = "AvanteSwitchSelectorProvider",
    help = "Switch selector provider.",
  })
  parser:add_parameter({ name = "provider", choices = SELECTOR_PROVIDER_CHOICES, help = "Selector provider." })
  parser:set_execute(function(data) require("avante.api").switch_selector_provider(data.namespace.provider) end)
  return parser
end

---@return mega.cmdparse.ParameterParser
local function switch_input_provider_parser()
  local parser = cmdparse.ParameterParser.new({ name = "AvanteSwitchInputProvider", help = "Switch input provider." })
  parser:add_parameter({ name = "provider", choices = INPUT_PROVIDER_CHOICES, help = "Input provider." })
  parser:set_execute(function(data) require("avante.api").switch_input_provider(data.namespace.provider) end)
  return parser
end

---@return mega.cmdparse.ParameterParser
local function clear_parser()
  local parser = cmdparse.ParameterParser.new({ name = "AvanteClear", help = "Clear history or cache." })
  parser:add_parameter({
    name = "target",
    choices = CLEAR_CHOICES,
    required = false,
    help = "What to clear. Defaults to history.",
  })
  parser:set_execute(function(data)
    local arg = data.namespace.target or "history"
    if arg == "history" then
      local sidebar = require("avante").get()
      if not sidebar then
        Utils.error("No sidebar found")
        return
      end
      sidebar:clear_history()
    elseif arg == "cache" then
      local history_path = vim.fs.abspath(tostring(P.history_path))
      local cache_path = vim.fs.abspath(tostring(P.cache_path))
      local prompt = string.format("Recursively delete %s and %s?", history_path, cache_path)
      if vim.fn.confirm(prompt, "&Yes\n&No", 2) == 1 then P.clear() end
    end
  end)
  return parser
end

function M.setup()
  create_command(
    "AvanteAsk",
    make_ask_parser(
      "AvanteAsk",
      "Ask AI for code suggestions.",
      function(namespace) require("avante.api").ask(ask_options(namespace)) end
    ),
    { desc = "avante: ask AI for code suggestions" }
  )

  create_command(
    "AvanteChat",
    make_ask_parser("AvanteChat", "Chat with the codebase.", function(namespace)
      local args = ask_options(namespace)
      args.ask = false
      require("avante.api").ask(args)
    end),
    { desc = "avante: chat with the codebase" }
  )

  create_command(
    "AvanteChatNew",
    make_ask_parser("AvanteChatNew", "Create a new chat.", function(namespace)
      local args = ask_options(namespace)
      args.ask = false
      args.new_chat = true
      require("avante.api").ask(args)
    end),
    { desc = "avante: create new chat" }
  )

  create_command(
    "AvanteToggle",
    make_noarg_parser("AvanteToggle", "Toggle AI panel.", function() require("avante").toggle() end),
    { desc = "avante: toggle AI panel", nargs = 0 }
  )
  create_command("AvanteBuild", build_parser, { desc = "avante: build dependencies" })
  create_command("AvanteEdit", edit_parser, { desc = "avante: edit selected block", range = 2 })
  create_command(
    "AvanteRefresh",
    make_noarg_parser("AvanteRefresh", "Refresh windows.", function() require("avante.api").refresh() end),
    { desc = "avante: refresh windows", nargs = 0 }
  )
  create_command(
    "AvanteFocus",
    make_noarg_parser("AvanteFocus", "Switch focus windows.", function() require("avante.api").focus() end),
    { desc = "avante: switch focus windows", nargs = 0 }
  )
  create_command(
    "AvanteSwitchProvider",
    make_noarg_parser("AvanteSwitchProvider", "Switch provider.", function()
      vim.ui.select(provider_choices(), { prompt = "Provider> " }, function(choice, idx)
        if idx ~= nil then require("avante.api").switch_provider(vim.trim(choice)) end
      end)
    end),
    { desc = "avante: switch provider", nargs = 0 }
  )
  create_command(
    "AvanteSwitchSelectorProvider",
    switch_selector_provider_parser,
    { desc = "avante: switch selector provider" }
  )
  create_command(
    "AvanteSwitchInputProvider",
    switch_input_provider_parser,
    { desc = "avante: switch input provider" }
  )
  create_command("AvanteClear", clear_parser, { desc = "avante: clear history or cache" })
  create_command(
    "AvanteShowRepoMap",
    make_noarg_parser("AvanteShowRepoMap", "Show repo map.", function() require("avante.repo_map").show() end),
    { desc = "avante: show repo map", nargs = 0 }
  )
  create_command(
    "AvanteModels",
    make_noarg_parser("AvanteModels", "Show models.", function() require("avante.model_selector").open() end),
    { desc = "avante: show models", nargs = 0 }
  )
  create_command(
    "AvanteACPModels",
    make_noarg_parser("AvanteACPModels", "Switch ACP model.", function() require("avante.api").select_acp_model() end),
    { desc = "avante: switch ACP model", nargs = 0 }
  )
  create_command(
    "AvanteACPModes",
    make_noarg_parser("AvanteACPModes", "Switch ACP mode.", function() require("avante.api").select_acp_mode() end),
    { desc = "avante: switch ACP mode", nargs = 0 }
  )
  create_command(
    "AvanteHistory",
    make_noarg_parser("AvanteHistory", "Show histories.", function() require("avante.api").select_history() end),
    { desc = "avante: show histories", nargs = 0 }
  )
  create_command(
    "AvanteStop",
    make_noarg_parser("AvanteStop", "Stop current AI request.", function() require("avante.api").stop() end),
    { desc = "avante: stop current AI request", nargs = 0 }
  )
end

M._normalize_legacy_args = normalize_legacy_args
M._to_bool = to_bool

return M
