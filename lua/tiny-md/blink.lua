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

  if not Markdown.has_content(lines) then
    Renderer.clear({ buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
    return
  end

  Renderer.render({
    buf = bufnr,
    win = window:get_win(),
    text = table.concat(lines, "\n"),
    config = { code_filetype = filetype },
  })

  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  vim.schedule(function()
    local win = window:get_win()

    if win then
      RenderMarkdown.refresh(bufnr, win)
    end
  end)
end

return M
