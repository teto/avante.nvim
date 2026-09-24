local stub = require("luassert.stub")

describe("RAG service URL port", function()
  local service = require("avante.rag_service")
  local url

  after_each(function() url:revert() end)

  for _, case in ipairs({
    { "http://localhost:20250", 20250 },
    { "http://localhost:20250/", 20250 },
    { "https://rag.example:8443/base/", 8443 },
    { "http://rag.example:8080?next=:9000#section", 8080 },
    { "http://rag.example", 80 },
    { "https://rag.example/base:9000", 443 },
    { "http://[::1]:9090/", 9090 },
    { "https://[::1]/", 443 },
  }) do
    it("extracts the port from " .. case[1], function()
      url = stub(service, "get_rag_service_url", function() return case[1] end)
      assert.equals(case[2], service.get_rag_service_port())
    end)
  end

  for _, value in ipairs({
    "localhost:20250",
    "ftp://host:21",
    "http://host:bad",
    "http://host:0",
    "http://host:65536",
  }) do
    it("rejects " .. value, function()
      url = stub(service, "get_rag_service_url", function() return value end)
      assert.has_error(function() service.get_rag_service_port() end)
    end)
  end
end)
