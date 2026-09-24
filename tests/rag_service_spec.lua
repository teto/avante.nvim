local mock = require("luassert.mock")
local stub = require("luassert.stub")

describe("RagService", function()
  local RagService
  local Config_mock
  local stubs

  local function replace(target, key, implementation)
    local value = stub(target, key, implementation)
    table.insert(stubs, value)
    return value
  end

  before_each(function()
    stubs = {}
    -- Load the module before each test
    RagService = require("avante.rag_service")

    -- Setup common mocks
    Config_mock = mock(require("avante.config"), true)
    Config_mock.rag_service = { host_mount = "/home/user" }
  end)

  after_each(function()
    for i = #stubs, 1, -1 do
      stubs[i]:revert()
    end
    -- Clean up after each test
    package.loaded["avante.rag_service"] = nil
    mock.revert(Config_mock)
  end)

  describe("URI conversion functions", function()
    it("should convert URIs between host and container formats", function()
      -- Test both directions of conversion
      local host_uri = "file:///home/user/project/file.txt"
      local container_uri = "file:///host/project/file.txt"

      -- Host to container
      local result1 = RagService.to_container_uri(host_uri)
      assert.equals(container_uri, result1)

      -- Container to host
      local result2 = RagService.to_local_uri(container_uri)
      assert.equals(host_uri, result2)
    end)
  end)

  describe("built-in runners", function()
    local errors
    before_each(function()
      Config_mock.rag_service = {
        runner = "nix",
        llm = { provider = "openai", endpoint = "https://llm", api_key = "", model = "llm-model" },
        embed = { provider = "ollama", endpoint = "http://embed", api_key = "", model = "embed-model" },
      }
      local utils = require("avante.utils")
      replace(utils, "info", function() end)
      replace(utils, "debug", function() end)
      errors = replace(utils, "error", function() end)
    end)

    it("dispatches through the exported starter functions", function()
      for _, runner in ipairs({ "docker", "nix" }) do
        Config_mock.rag_service.runner = runner
        local start = replace(RagService, "start_" .. runner, function() end)
        RagService.launch_rag_service()
        assert.stub(start).was_called_with(Config_mock.rag_service)
      end
    end)

    it("accepts Docker options separately without modifying the config", function()
      local config = Config_mock.rag_service
      config.host_mount = "/legacy"
      config.docker_extra_args = "--legacy-argument"
      local original = vim.deepcopy(config)
      replace(RagService, "get_data_path", function() return "/data-path" end)
      replace(RagService, "stop_rag_service", function() end)
      replace(vim, "system", function()
        return { wait = function() return { code = 0, stdout = "" } end }
      end)
      local commands = {}
      replace(vim.fn, "jobstart", function(cmd)
        table.insert(commands, cmd)
        return 1
      end)
      RagService.start_docker(config, { host_mount = "/explicit", docker_extra_args = "--network=host" })
      assert.is_truthy(commands[1]:find("-v /explicit:/host:ro", 1, true))
      assert.is_truthy(commands[1]:find("--network=host", 1, true))
      assert.is_nil(commands[1]:find("--legacy-argument", 1, true))
      RagService.start_docker(config, { docker_extra_args = "" })
      assert.is_truthy(commands[2]:find("-v /legacy:/host:ro", 1, true))
      assert.is_nil(commands[2]:find("--legacy-argument", 1, true))
      assert.same(original, config)
    end)

    it("dispatches Nix with provider arguments and resolved credentials without mutating config", function()
      local config = Config_mock.rag_service
      config.llm.api_key = "LLM_KEY"
      config.embed.api_key = "EMBED_KEY"
      config.llm.extra = { temperature = 0.5 }
      config.embed.extra = { size = 10 }
      local original = vim.deepcopy(config)
      replace(os, "getenv", function(key) return key .. "-value" end)
      local system = replace(vim, "system", function(args, opts, on_exit)
        assert.same({
          "avante-rag-service",
          "/tmp/avante-rag-service",
          "--port",
          20250,
          "--embed-provider",
          "ollama",
          "--embed-extra",
          string.format("%q", vim.json.encode(config.embed.extra)),
          "--llm-provider",
          "openai",
          "--llm-model",
          "llm-model",
        }, args)
        assert.same({
          detach = true,
          env = {
            DATA_DIR = "/tmp/avante-rag-service",
            RAG_EMBED_ENDPOINT = "http://embed",
            RAG_EMBED_API_KEY = "EMBED_KEY-value",
            RAG_EMBED_MODEL = "embed-model",
            RAG_LLM_ENDPOINT = "https://llm",
            RAG_LLM_API_KEY = "LLM_KEY-value",
            RAG_LLM_EXTRA = string.format("%q", vim.json.encode(config.llm.extra)),
          },
        }, opts)
        on_exit({ code = 0 })
      end)
      RagService.launch_rag_service()
      assert.stub(system).was_called(1)
      assert.stub(errors).was_not_called()
      assert.same(original, config)
    end)

    it("reports Nix spawn and process failures", function()
      local system = replace(vim, "system", function() error("executable missing") end)
      RagService.launch_rag_service()
      assert.stub(errors).was_called(1)
      system:revert()
      replace(vim, "system", function(_, _, on_exit) on_exit({ code = 7 }) end)
      RagService.launch_rag_service()
      assert.stub(errors).was_called_with("service avante-rag-service failed to start, exit code: 7")
    end)

    for _, runner in ipairs({ "docker", "nix" }) do
      for _, model in ipairs({ "llm", "embed" }) do
        it("rejects missing " .. model .. " credentials for " .. runner, function()
          Config_mock.rag_service.runner = runner
          Config_mock.rag_service[model].api_key = "MISSING_KEY"
          replace(os, "getenv", function() return nil end)
          local system = replace(vim, "system", function() end)
          assert.has_error(
            function() RagService.launch_rag_service() end,
            "cannot launch avante rag service, MISSING_KEY is not set"
          )
          assert.stub(system).was_not_called()
        end)
      end
    end

    it("rejects unsupported runners", function()
      Config_mock.rag_service.runner = "unknown"
      assert.has_error(function() RagService.launch_rag_service() end, "Unsupported RAG service runner: unknown")
    end)

    it("dispatches Docker with legacy options and reports launch errors", function()
      local config = Config_mock.rag_service
      config.runner = "docker"
      config.host_mount = "/legacy"
      config.image = "legacy-image"
      config.docker_extra_args = "--network=host"
      replace(RagService, "get_data_path", function() return "/data-path" end)
      replace(RagService, "stop_rag_service", function() end)
      replace(vim, "system", function()
        return { wait = function() return { code = 0, stdout = "" } end }
      end)
      local job = replace(vim.fn, "jobstart", function(cmd, opts)
        assert.is_truthy(cmd:find("docker run --platform=linux/amd64 -d -p 0.0.0.0:20250:20250", 1, true))
        assert.is_truthy(cmd:find("-v /data-path:/data -v /legacy:/host:ro", 1, true))
        assert.is_truthy(cmd:find("RAG_EMBED_PROVIDER=ollama", 1, true))
        assert.is_truthy(cmd:find("RAG_LLM_PROVIDER=openai", 1, true))
        assert.is_truthy(cmd:find("--network=host legacy-image", 1, true))
        assert.is_true(opts.detach)
        opts.on_exit(1, 9)
        return 1
      end)
      RagService.launch_rag_service()
      assert.stub(job).was_called(1)
      assert.stub(errors).was_called_with("container avante-rag-service failed to start, exit code: 9")
    end)

    it("does not restart a Docker container already running the configured image", function()
      Config_mock.rag_service.runner = "docker"
      replace(RagService, "get_data_path", function() return "/data-path" end)
      replace(vim, "system", function(cmd)
        return {
          wait = function()
            return {
              code = 0,
              stdout = cmd[4] == "{{.State.Status}}" and "running" or "quay.io/yetoneful/avante-rag-service:0.0.11",
            }
          end,
        }
      end)
      local job = replace(vim.fn, "jobstart", function() end)
      RagService.launch_rag_service()
      assert.stub(job).was_not_called()
    end)
  end)
end)
