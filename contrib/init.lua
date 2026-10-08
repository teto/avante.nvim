vim.g.avante = {
  log_level = vim.log_level.DEBUG,
  rag_service = { enabled = false, runner = "native" },
  file_selector = { provider = "fzf_lua" },
  ui = { border = 'single', background_color = '#FF0000' },
  selector = {
      provider = 'fzf_lua',
  },
}
require("avante").setup()
