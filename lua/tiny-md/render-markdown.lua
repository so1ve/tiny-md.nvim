local M = {}

local applied = false
local doc_filetypes = { "markdown_doc", "blink-cmp-documentation" }
local doc_config = {
  anti_conceal = { enabled = false },
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
  win_options = {
    concealcursor = { rendered = "nvic" },
  },
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

  local state = require("render-markdown.state")

  for _, filetype in ipairs(doc_filetypes) do
    if not vim.tbl_contains(state.file_types, filetype) then
      state.file_types[#state.file_types + 1] = filetype
    end
  end

  applied = true
end

local function reset_buffer_config(buf)
  -- render-markdown caches per-buffer config when FileType fires. Rebuild that
  -- cache so generated-doc options replace the global Markdown configuration.
  require("render-markdown.state").cache[buf] = nil

  local decorator = require("render-markdown.core.ui").cache[buf]

  if decorator then
    decorator.running = false
  end
end

function M.render(buf, win)
  M.setup()

  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  if win and not vim.api.nvim_win_is_valid(win) then
    return
  end

  reset_buffer_config(buf)
  vim.treesitter.start(buf, "markdown")
  require("render-markdown").render({
    buf = buf,
    win = win,
    event = "tiny-md",
    config = config,
  })

  -- If FileType did not attach yet, cache this config before attaching.
  local manager = require("render-markdown.core.manager")

  if not manager.attached(buf) then
    manager.attach(buf)
  end
end

return M
