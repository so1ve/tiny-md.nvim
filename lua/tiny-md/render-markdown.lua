local M = {}

local applied = false
local doc_filetypes = { "markdown_doc", "blink-cmp-documentation" }
local user_config = {}
local doc_config = {
  anti_conceal = { enabled = false },
  link = { enabled = false },
  code = { language = false },
  html = {
    tag = {
      code = { scope_highlight = "RenderMarkdownCodeInline" },
    },
  },
  win_options = {
    concealcursor = { rendered = "nvic" },
  },
}

local function watch(buf, win)
  if not win or vim.w[win].tiny_md_render_markdown then
    return
  end

  vim.w[win].tiny_md_render_markdown = true

  local group = vim.api.nvim_create_augroup(("tiny-md-render-markdown-%d"):format(win), { clear = true })
  local view = vim.api.nvim_win_call(win, function()
    return ("%d:%d"):format(vim.fn.line("w0"), vim.fn.line("w$"))
  end)

  local function refresh_scrolled_view()
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
      return
    end

    local next_view = vim.api.nvim_win_call(win, function()
      return ("%d:%d"):format(vim.fn.line("w0"), vim.fn.line("w$"))
    end)

    if next_view ~= view then
      view = next_view
      M.refresh(buf, win)
    end
  end

  vim.api.nvim_create_autocmd("WinScrolled", { group = group, callback = refresh_scrolled_view })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    buffer = buf,
    callback = refresh_scrolled_view,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(win),
    once = true,
    callback = function()
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })
end

function M.setup(opts)
  if opts then
    user_config = vim.deepcopy(opts)
  end

  if applied then
    return
  end

  vim.treesitter.language.register("markdown", doc_filetypes)
  require("render-markdown").setup()

  applied = true
end

local function reset_buffer_config(buf)
  -- render-markdown caches per-buffer config. If it auto-attached on FileType
  -- before tiny-md renders, rebuild the cache so generated-doc options like
  -- anti_conceal=false and concealcursor=nvic actually take effect.
  require("render-markdown.state").cache[buf] = nil

  local decorator = require("render-markdown.core.ui").cache[buf]

  if decorator then
    decorator.running = false
  end
end

function M.refresh(buf, win)
  M.setup()

  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  if win and not vim.api.nvim_win_is_valid(win) then
    return
  end

  vim.treesitter.start(buf, "markdown")
  watch(buf, win)
  reset_buffer_config(buf)

  require("render-markdown").render({
    buf = buf,
    win = win,
    event = "tiny-md",
    config = vim.tbl_deep_extend("force", {}, doc_config, user_config),
  })
end

return M
