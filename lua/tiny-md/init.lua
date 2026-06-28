local Config = require("tiny-md.config")
local RenderMarkdown = require("tiny-md.render-markdown")

local M = {}

function M.setup(opts)
  opts = vim.deepcopy(opts or {})

  local render_markdown = opts.render_markdown
  opts.render_markdown = nil

  Config.setup(opts)
  RenderMarkdown.setup(render_markdown)
end

return M
