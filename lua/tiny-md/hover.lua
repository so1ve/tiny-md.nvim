local Markdown = require("tiny-md.markdown")
local Window = require("tiny-md.window")

local M = {}

local hover_method = vim.lsp.protocol.Methods.textDocument_hover
local active
local request_id = 0

local function cursor_equal(left, right)
  return left and right and left[1] == right[1] and left[2] == right[2]
end

local function active_hover()
  if active and active.handle and active.handle.win and vim.api.nvim_win_is_valid(active.handle.win) then
    return active
  end

  active = nil
end

local function close_active()
  local hover = active_hover()
  active = nil

  if hover then
    hover.handle.close()
  end
end

local function focus_active(bufnr, cursor, changedtick)
  local hover = active_hover()

  if
    not (
      hover
      and hover.source_buf == bufnr
      and hover.changedtick == changedtick
      and cursor_equal(hover.cursor, cursor)
    )
  then
    return false
  end

  request_id = request_id + 1
  vim.api.nvim_set_current_win(hover.handle.win)
  vim.cmd.stopinsert()

  return true
end

local function notify(message, level, opts)
  if not opts.silent then
    vim.notify(message, level or vim.log.levels.INFO)
  end
end

local function add_client(clients, seen, client)
  if client and not seen[client.id] then
    seen[client.id] = true
    clients[#clients + 1] = client
  end
end

local function hover_clients(bufnr, providers)
  local clients = {}
  local seen = {}

  if type(providers) == "table" then
    for _, provider in ipairs(providers) do
      add_client(clients, seen, vim.lsp.get_clients({ bufnr = bufnr, method = hover_method, name = provider })[1])
    end
  elseif type(providers) == "string" then
    add_client(clients, seen, vim.lsp.get_clients({ bufnr = bufnr, method = hover_method, name = providers })[1])
  else
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = hover_method })) do
      add_client(clients, seen, client)
    end
  end

  return clients
end

local function entries_text(entries, count)
  local lines = {}

  for index = 1, count do
    local entry = entries[index]

    if entry then
      if #lines > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "---"
        lines[#lines + 1] = ""
      end

      Markdown.append_lines(lines, entry.lines)
    end
  end

  return table.concat(lines, "\n")
end

local function valid_source(bufnr, win, cursor, changedtick)
  if not (vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_win_is_valid(win)) then
    return false
  end

  if vim.b[bufnr].changedtick ~= changedtick then
    return false
  end

  local current = vim.api.nvim_win_get_cursor(win)

  return current[1] == cursor[1] and current[2] == cursor[2]
end

function M.hover(ctx)
  ctx = ctx or {}

  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  local win = ctx.win or vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local changedtick = vim.b[bufnr].changedtick

  if focus_active(bufnr, cursor, changedtick) then
    return
  end

  close_active()

  request_id = request_id + 1

  local current_request = request_id
  local clients = hover_clients(bufnr, ctx.providers)

  if #clients == 0 then
    notify("No LSP client supports hover", vim.log.levels.INFO, ctx)
    return
  end

  local entries = {}
  local pending = #clients
  local response_count = 0
  local shown_count = 0

  local function render(force)
    if current_request ~= request_id then
      return
    end

    if response_count == 0 or response_count == shown_count then
      return
    end

    if not force and shown_count > 0 then
      return
    end

    close_active()
    local preview = vim.tbl_deep_extend("force", ctx.preview or {}, {
      code_filetype = vim.bo[bufnr].filetype,
      text = entries_text(entries, #clients),
      source_buf = bufnr,
    })

    active = {
      changedtick = changedtick,
      cursor = { cursor[1], cursor[2] },
      handle = Window.open(preview),
      source_buf = bufnr,
    }
    shown_count = response_count
  end

  local function finish()
    pending = pending - 1

    if pending == 0 then
      if response_count == 0 then
        notify("No information available", vim.log.levels.INFO, ctx)
      else
        render(true)
      end
    end
  end

  for index, client in ipairs(clients) do
    local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
    local ok = client:request(hover_method, params, function(err, result)
      if current_request ~= request_id then
        return
      end

      if not valid_source(bufnr, win, cursor, changedtick) then
        finish()
        return
      end

      if err then
        vim.lsp.log.error(err.code, err.message)
        finish()
        return
      end

      local lines = result and result.contents and Markdown.lines(result.contents) or {}

      if Markdown.has_content(lines) then
        response_count = response_count + 1
        entries[index] = { lines = lines }
        render(false)
      end

      finish()
    end, bufnr)

    if not ok then
      finish()
    end
  end
end

return M
