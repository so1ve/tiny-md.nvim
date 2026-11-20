local Markdown = require("tiny-md.markdown")
local Renderer = require("tiny-md.renderer")
local RenderMarkdown = require("tiny-md.render-markdown")

local M = {}

function M.draw(opts)
  local item = opts.item or {}
  local window = opts.window
  local bufnr = window:get_buf()
  local source_buf = opts.context and opts.context.bufnr
  local filetype = source_buf and vim.bo[source_buf].filetype or vim.bo.filetype
  local lines = Markdown.with_detail({
    documentation = item.documentation,
    detail = item.detail,
    filetype = filetype,
  })

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

  local render_opts = { code_filetype = filetype }
  local marks = Renderer.render({
    buf = bufnr,
    text = table.concat(lines, "\n"),
    config = render_opts,
  })

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false

  local changedtick = vim.b[bufnr].changedtick
  vim.schedule(function()
    local win = window:get_win()

    if win and vim.api.nvim_buf_is_valid(bufnr) and vim.b[bufnr].changedtick == changedtick then
      RenderMarkdown.render(bufnr, win, marks, render_opts)
    end
  end)
end

return M
