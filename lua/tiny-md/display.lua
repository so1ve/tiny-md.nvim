local Format = require("render-markdown.lib.display")
local Highlights = require("render-markdown.request.highlights")
local Inline = require("render-markdown.request.inline")
local Line = require("render-markdown.lib.line")
local Str = require("render-markdown.lib.str")

local M = {}
local ns = vim.api.nvim_create_namespace("tiny-md-display")

local function groups(highlight)
  return type(highlight) == "table" and highlight or { highlight }
end

local function linked_inline(context, links)
  local inline = Inline.new()

  -- Preserve a link's target on inserted icons, including before table wrapping.
  function inline:add(row, value)
    local tags = {}

    for _, range in ipairs(context.highlights:line(row).groups) do
      if links[range.highlight] and value.col >= range[1] and value.col < range[2] then
        tags[#tags + 1] = range.highlight
      end
    end

    local chunks = {}

    for _, chunk in ipairs(value.line) do
      local highlights = vim.list_slice(tags)

      vim.list_extend(highlights, groups(chunk[2]))
      chunks[#chunks + 1] = { chunk[1], highlights }
    end

    Inline.add(self, row, { col = value.col, line = chunks })
  end

  return inline
end

local function collect(context, lines, marks, links)
  context.highlights = Highlights.new(context.buf, context.view)
  context.inline = linked_inline(context, links)

  local rows = {}

  for _ in ipairs(lines) do
    rows[#rows + 1] = { before = {}, after = {}, overlays = {}, eol = {} }
  end

  for id, mark in ipairs(marks) do
    local opts = mark.opts
    local first, last = mark.start_row, opts.end_row or mark.start_row

    for row = first, math.min(#lines - 1, last) do
      local from = row == first and mark.start_col or 0
      local to = row == last and (opts.end_col or from) or #lines[row + 1]
      local covered = row < last or to > from
      local target = rows[row + 1]

      if mark.code and covered then
        target.code = true
      end

      if opts.conceal_lines and (covered or first == last) then
        target.hidden = true
      end

      if opts.hl_eol and covered then
        vim.list_extend(target.eol, groups(opts.hl_group))
      end

      if opts.conceal then
        context.highlights:add(row, {
          conceal = { from, to, replacement = "", blocks = 1 },
        })
      end

      for _, group in ipairs(groups(opts.hl_group)) do
        context.highlights:add(row, {
          group = { from, to, priority = opts.priority or 4096, highlight = group },
        })
      end

      if opts.url then
        -- Wrapped table chunks carry highlight names, but no URL field.
        local tag = "TinyMdLink" .. id

        links[tag] = opts.url
        context.highlights:add(row, {
          group = { from, to, priority = 10000, highlight = tag },
        })
      end
    end

    local row = rows[first + 1]

    if row then
      vim.list_extend(row.before, mark.replace or {})

      local virtual_lines = opts.virt_lines_above and row.before or row.after

      vim.list_extend(virtual_lines, opts.virt_lines or {})

      if opts.virt_text_pos == "inline" then
        context.inline:add(first, { col = mark.start_col, line = opts.virt_text })
      elseif opts.virt_text then
        row.overlays[#row.overlays + 1] = mark
      end
    end
  end

  return rows
end

local function render_rows(context, lines, rows)
  local output = {}

  -- Ordinary text inherits the documentation window's Normal highlight.
  -- The table formatter's padding highlight is only for its generated cells.
  local source = {
    highlights = context.highlights,
    inline = context.inline,
    conceal = context.conceal,
    config = {
      padding = {},
      line = function()
        return Line.new()
      end,
    },
  }
  local width = vim.api.nvim_win_get_width(context.win)

  for index, text in ipairs(lines) do
    local row = rows[index]

    vim.list_extend(output, row.before)

    if not row.hidden then
      local body = { start_row = index - 1, start_col = 0, end_col = #text, text = text }
      local line = Line.new():extend(Format.line(source, body))

      for _, mark in ipairs(row.overlays) do
        local opts = mark.opts
        local replacement = Line.new():extend(opts.virt_text)

        body.end_col = mark.start_col

        local column = opts.virt_text_win_col or Str.line_width(Format.line(source, body))

        if opts.virt_text_pos == "right_align" or opts.virt_text_pos == "eol_right_align" then
          column = math.max(0, width - replacement:width())
        elseif opts.virt_text_pos == "eol" then
          column = line:width() + 1
        end

        if column < width then
          replacement = replacement:sub(1, width - column)

          local before = line:sub(1, column)
          local after = line:sub(column + replacement:width() + 1, line:width())

          before:pad(column - line:width(), {})
          line = before:extend(replacement):extend(after)
        end
      end

      local chunks = line:get()

      chunks.code = row.code
      chunks.eol = row.eol
      output[#output + 1] = chunks
    end

    vim.list_extend(output, row.after)
  end

  return output
end

local function write(buf, rows, links)
  local lines = {}
  local compacted = {}
  local previous_blank = false

  for _, chunks in ipairs(rows) do
    local parts = {}

    for _, chunk in ipairs(chunks) do
      parts[#parts + 1] = chunk[1]
    end

    local line = table.concat(parts)
    local blank = not chunks.code and not line:find("%S")

    if not (blank and previous_blank) then
      lines[#lines + 1] = line
      compacted[#compacted + 1] = chunks
    end

    previous_blank = blank
  end

  local modifiable = vim.bo[buf].modifiable

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  for row, chunks in ipairs(compacted) do
    local column = 0

    for _, chunk in ipairs(chunks) do
      for priority, group in ipairs(groups(chunk[2])) do
        local opts = { end_col = column + #chunk[1], priority = priority }

        if links[group] then
          opts.url = links[group]
        else
          opts.hl_group = group
        end

        vim.api.nvim_buf_set_extmark(buf, ns, row - 1, column, opts)
      end

      column = column + #chunk[1]
    end

    for _, group in ipairs(chunks.eol or {}) do
      vim.api.nvim_buf_set_extmark(buf, ns, row - 1, column, {
        end_row = row,
        end_col = 0,
        hl_group = group,
        hl_eol = true,
      })
    end
  end

  vim.bo[buf].modifiable = modifiable
  vim.bo[buf].modified = false
end

function M.render(context, marks)
  local lines = vim.api.nvim_buf_get_lines(context.buf, 0, -1, false)
  local links = {}

  -- Tables and ordinary text must see the same syntax and custom highlights.
  collect(context, lines, marks, links)

  local parser = vim.treesitter.get_parser(context.buf)
  local decorations = require("render-markdown.core.handlers").run(context, parser)

  vim.list_extend(marks, decorations)

  local rows = collect(context, lines, marks, links)

  write(context.buf, render_rows(context, lines, rows), links)
end

return M
