local root = assert(os.getenv("AVANTE_TEST_ROOT"), "AVANTE_TEST_ROOT is required")
local deps = assert(os.getenv("AVANTE_TEST_DEPS_DIR"), "AVANTE_TEST_DEPS_DIR is required")

vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(deps .. "/plenary.nvim")

package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  package.path,
}, ";")
