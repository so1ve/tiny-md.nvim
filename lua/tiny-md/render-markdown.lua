local Display = require("tiny-md.display")

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

function M.render(buf, win, marks)
  M.setup()

  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  if win and not vim.api.nvim_win_is_valid(win) then
    return
  end

  marks = marks or {}
  local parser = vim.treesitter.get_parser(buf, "markdown")
  parser:parse(true)
  vim.treesitter.stop(buf)
  local state = require("render-markdown.state")
  state.cache[buf] = nil
  local contexts = require("render-markdown.request.context")
  local context = contexts.new(buf, win, state.get(buf, config))
  context.conceal.level = 3
  -- Generated documents are rendered once, including text outside the viewport.
  context.view.ranges = { { 0, vim.api.nvim_buf_line_count(buf) } }

  parser:for_each_tree(function(tree, language_tree)
    local language = language_tree:lang()
    local query = vim.treesitter.query.get(language, "highlights")
    if not query then
      return
    end

    for id, node, metadata, match in query:iter_captures(tree:root(), buf, 0, -1) do
      local capture = query.captures[id]
      local data = metadata[id] or {}
      local range = vim.treesitter.get_range(node, buf, data)
      local conceal = data.conceal or metadata.conceal
      if capture == "noconceal" then
        conceal = false
      end
      local url = data.url
      if type(url) == "number" then
        url = vim.treesitter.get_node_text(assert(match:captures()[url][1]), buf, { metadata = metadata[url] })
      end
      marks[#marks + 1] = {
        start_row = range[1],
        start_col = range[2],
        code = node:type() == "fenced_code_block" or node:type() == "indented_code_block",
        opts = {
          end_row = range[4],
          end_col = range[5],
          hl_group = not capture:find("^_") and ("@" .. capture .. "." .. language) or nil,
          priority = tonumber(data.priority or metadata.priority) or vim.hl.priorities.treesitter,
          conceal = conceal,
          conceal_lines = data.conceal_lines or metadata.conceal_lines,
          url = url,
        },
      }
    end
  end)

  Display.render(context, marks)
  state.cache[buf] = nil
  contexts.cache[buf] = nil
  vim.wo[win].conceallevel = 0
end

return M
