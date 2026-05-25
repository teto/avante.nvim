if vim.fn.has("nvim-0.11") == 0 then
  vim.api.nvim_echo({
    { "Avante requires at least nvim-0.11", "ErrorMsg" },
    { "Please upgrade your neovim version", "WarningMsg" },
    { "Press any key to exit", "ErrorMsg" },
  }, true, {})
  vim.fn.getchar()
  vim.cmd([[quit]])
end

if vim.g.avante_loaded ~= nil then return end

vim.g.avante_loaded = 1

--- NOTE: We will override vim.paste if img-clip.nvim is available to work with avante.nvim internal logic paste
local Clipboard = require("avante.clipboard")
local Config = require("avante.config")

if Config.support_paste_image() then
  vim.paste = (function(overridden)
    ---@param lines string[]
    ---@param phase -1|1|2|3
    return function(lines, phase)
      -- NOTE: require("img-clip.util").verbose = false does NOT silence warnings
      -- because img-clip's warn() reads config.get_opt("verbose"), not util.verbose.
      -- Suppress via api_opts which has highest priority in img-clip's config lookup.
      require("img-clip.config").api_opts = { default = { verbose = false } }

      local bufnr = vim.api.nvim_get_current_buf()
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
      if filetype ~= "AvanteInput" then return overridden(lines, phase) end

      ---@type string
      local line = lines[1]

      -- Only attempt image paste if the line looks like an image path/URL,
      -- or if the clipboard actually contains an image. This avoids the
      -- "Content is not an image" warning when Chinese IME commits text via
      -- vim.paste (which is not a real paste from clipboard).
      local img_clip_util = require("img-clip.util")
      local img_clip_clipboard = require("img-clip.clipboard")
      local is_image_candidate = (line and (img_clip_util.is_image_url(line) or img_clip_util.is_image_path(line)))
        or img_clip_clipboard.content_is_image()
      if not is_image_candidate then return overridden(lines, phase) end

      local ok = Clipboard.paste_image(line)
      if not ok then return overridden(lines, phase) end

      -- After pasting, insert a new line and set cursor to this line
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
      local last_line = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_win_set_cursor(0, { last_line, 0 })
    end
  end)(vim.paste)
end

require("avante.commands").setup()
