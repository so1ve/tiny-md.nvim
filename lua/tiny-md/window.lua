local Renderer = require("tiny-md.renderer")
local RenderMarkdown = require("tiny-md.render-markdown")

local M = {}

local function visual_height(doc, width, max_height)
  local height = 0

  for _, line in ipairs(doc.lines) do
    height = height + math.max(1, math.ceil(vim.api.nvim_strwidth(line) / width))
  end

  return math.max(1, math.min(max_height, height))
end

local function visual_width(doc)
  local width = 0

  for _, line in ipairs(doc.lines) do
    width = math.max(width, vim.api.nvim_strwidth(line))
  end

  return width
end

local function hover_size(doc, opts)
  local columns = vim.o.columns
  local lines = vim.o.lines
  local max_width = opts.max_width or math.min(88, math.max(48, math.floor(columns * 0.58)))
  local max_height = opts.max_height or math.min(28, math.max(8, lines - 8))
  local width = visual_width(doc)

  max_width = math.max(20, math.min(max_width, columns - 6))
  width = math.max(20, math.min(width, max_width))

  return width, visual_height(doc, width, max_height), max_height
end

local function fit_height(win, max_height)
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end

    local text_height = vim.api.nvim_win_text_height(win, {})
    local height = math.max(1, math.min(text_height.all, max_height))

    if height < vim.api.nvim_win_get_height(win) then
      vim.api.nvim_win_set_height(win, height)
    end
  end)
end

function M.open(ctx)
  ctx = ctx or {}

  local text = ctx.text or ""
  local opts = vim.tbl_extend("force", { code_filetype = ctx.code_filetype or vim.bo.filetype }, ctx.config or {})

  local doc = Renderer.render_text(text, opts)
  local width, height, max_height = hover_size(doc, ctx)
  local buf = vim.api.nvim_create_buf(false, true)
  local filetype = ctx.filetype or "markdown_doc"

  local win = vim.api.nvim_open_win(buf, ctx.enter == true, {
    relative = ctx.relative or "cursor",
    row = ctx.row or 1,
    col = ctx.col or 0,
    width = width,
    height = height,
    border = ctx.border or "rounded",
    style = "minimal",
  })

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = true
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].scrolloff = 0
  vim.wo[win].sidescrolloff = 0
  vim.wo[win].conceallevel = 3

  doc = Renderer.render({
    buf = buf,
    win = win,
    doc = doc,
    config = opts,
  })

  vim.bo[buf].filetype = filetype
  RenderMarkdown.refresh(buf, win)
  fit_height(win, max_height)
  vim.bo[buf].modifiable = false

  local close_group

  local function clear_autocmds()
    if close_group then
      vim.api.nvim_del_augroup_by_id(close_group)
      close_group = nil
    end
  end

  local function close()
    clear_autocmds()

    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  if ctx.source_buf then
    close_group = vim.api.nvim_create_augroup(("tiny-md-window-%d"):format(win), { clear = true })

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertCharPre" }, {
      group = close_group,
      buffer = ctx.source_buf,
      callback = function()
        vim.schedule(close)
      end,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
      group = close_group,
      buffer = ctx.source_buf,
      callback = function()
        vim.schedule(function()
          if not close_group then
            return
          end

          local current_buf = vim.api.nvim_get_current_buf()

          if current_buf == buf or current_buf == ctx.source_buf then
            return
          end

          close()
        end)
      end,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
      group = close_group,
      buffer = buf,
      callback = close,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
      group = close_group,
      pattern = tostring(win),
      callback = clear_autocmds,
    })
  end

  vim.keymap.set("n", "q", close, { buffer = buf, silent = true, desc = "Close tiny-md hover window" })

  return {
    buf = buf,
    win = win,
    doc = doc,
    close = close,
  }
end

return M
