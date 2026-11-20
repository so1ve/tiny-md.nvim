local Display = require("tiny-md.display")
local Treesitter = require("tiny-md.treesitter")

local M = {}

local applied = false
local doc_filetypes = { "markdown_doc", "blink-cmp-documentation" }
local doc_config = {
  code = {
    border = "hide",
    language = false,
  },
  html = {
    tag = {
      code = { scope_highlight = "RenderMarkdownCodeInline" },
      kbd = { scope_highlight = "RenderMarkdownCodeInline" },
      samp = { scope_highlight = "RenderMarkdownCodeInline" },
      var = { scope_highlight = "@variable" },
      strong = { scope_highlight = "@markup.strong" },
      em = { scope_highlight = "@markup.italic" },
    },
  },
  link = { enabled = true },
}
local config = vim.deepcopy(doc_config)

function M.setup(opts)
  if opts then
    config = vim.tbl_deep_extend("force", vim.deepcopy(doc_config), opts)
  end

  if applied then
    return
  end

  vim.treesitter.language.register("markdown", doc_filetypes)
  require("render-markdown").setup()

  applied = true
end

function M.render(buf, win, marks, opts)
  M.setup()

  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  if win and not vim.api.nvim_win_is_valid(win) then
    return
  end

  local collected = Treesitter.collect(buf, marks, opts)
  local state = require("render-markdown.state")
  state.cache[buf] = nil
  local contexts = require("render-markdown.request.context")
  local context = contexts.new(buf, win, state.get(buf, config))
  context.conceal.level = 3
  -- Generated documents are rendered once, including text outside the viewport.
  context.view.ranges = { { 0, vim.api.nvim_buf_line_count(buf) } }

  Display.render(context, collected)
  state.cache[buf] = nil
  contexts.cache[buf] = nil
  vim.wo[win].conceallevel = 0
end

return M
