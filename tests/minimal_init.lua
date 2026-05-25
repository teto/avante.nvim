local repo = vim.fn.getcwd()
local deps = repo .. "/target/tests/deps"

vim.opt.runtimepath:append(repo)
vim.opt.runtimepath:append(deps .. "/plenary.nvim")
vim.opt.runtimepath:append(deps .. "/mega.logging")
vim.opt.runtimepath:append(deps .. "/mega.cmdparse")
