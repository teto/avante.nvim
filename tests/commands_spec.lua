local commands = require("avante.commands")

local COMMANDS = {
  "AvanteAsk",
  "AvanteChat",
  "AvanteChatNew",
  "AvanteToggle",
  "AvanteBuild",
  "AvanteEdit",
  "AvanteRefresh",
  "AvanteFocus",
  "AvanteSwitchProvider",
  "AvanteSwitchSelectorProvider",
  "AvanteSwitchInputProvider",
  "AvanteClear",
  "AvanteShowRepoMap",
  "AvanteModels",
  "AvanteACPModels",
  "AvanteACPModes",
  "AvanteHistory",
  "AvanteStop",
}

local function delete_commands()
  for _, name in ipairs(COMMANDS) do
    pcall(vim.api.nvim_del_user_command, name)
  end
end

describe("avante.commands", function()
  local captured
  local original_api

  before_each(function()
    delete_commands()
    captured = {}
    original_api = package.loaded["avante.api"]
    package.loaded["avante.api"] = {
      ask = function(args) captured.ask = args end,
      build = function(args) captured.build = args end,
      edit = function(instruction, line1, line2)
        captured.edit = {
          instruction = instruction,
          line1 = line1,
          line2 = line2,
        }
      end,
    }
    commands.setup()
  end)

  after_each(function()
    delete_commands()
    package.loaded["avante.api"] = original_api
  end)

  it("normalizes legacy key=value arguments", function()
    assert.equals("--position=right refactor", commands._normalize_legacy_args("position=right refactor"))
    assert.equals("question foo=bar", commands._normalize_legacy_args("question foo=bar"))
  end)

  it("parses AvanteAsk legacy arguments and question text", function()
    vim.cmd("AvanteAsk position=right ask=false Refactor this function")

    assert.equals("right", captured.ask.win.position)
    assert.is_false(captured.ask.ask)
    assert.equals("Refactor this function", captured.ask.question)
  end)

  it("parses AvanteAsk cmdparse flags", function()
    vim.cmd("AvanteAsk --position=left --ask=true Explain this")

    assert.equals("left", captured.ask.win.position)
    assert.is_true(captured.ask.ask)
    assert.equals("Explain this", captured.ask.question)
  end)

  it("forces AvanteChat into chat mode", function()
    vim.cmd("AvanteChat --position=bottom Start here")

    assert.equals("bottom", captured.ask.win.position)
    assert.is_false(captured.ask.ask)
    assert.equals("Start here", captured.ask.question)
  end)

  it("sets AvanteChatNew new_chat", function()
    vim.cmd("AvanteChatNew Start fresh")

    assert.is_false(captured.ask.ask)
    assert.is_true(captured.ask.new_chat)
    assert.equals("Start fresh", captured.ask.question)
  end)

  it("parses AvanteBuild source option", function()
    vim.cmd("AvanteBuild source=true")
    assert.is_true(captured.build.source)

    vim.cmd("AvanteBuild --source=false")
    assert.is_false(captured.build.source)
  end)

  it("defaults AvanteBuild source to false", function()
    vim.cmd("AvanteBuild")
    assert.is_false(captured.build.source)
  end)

  it("forwards AvanteEdit instruction and range", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three" })
    vim.api.nvim_set_current_buf(bufnr)

    vim.cmd("2,3AvanteEdit rewrite this")

    assert.equals("rewrite this", captured.edit.instruction)
    assert.equals(2, captured.edit.line1)
    assert.equals(3, captured.edit.line2)
  end)

  it("rejects invalid enum values", function()
    pcall(vim.cmd, "AvanteAsk --position=diagonal Refactor")
    assert.is_nil(captured.ask)
  end)
end)
