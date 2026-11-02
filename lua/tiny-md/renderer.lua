local Config = require("tiny-md.config")

local M = {}
local ns = vim.api.nvim_create_namespace("tiny-md")

local entities = {
  nbsp = " ",
  lt = "<",
  gt = ">",
  amp = "&",
  quot = '"',
  apos = "'",
  ensp = " ",
  emsp = " ",
}

local rustdoc_attributes = {
  compile_fail = true,
  ignore = true,
  no_run = true,
  should_panic = true,
  standalone_crate = true,
}

local function source(text)
  text = text:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("&(%a+);", entities)

  while text:find("^[ \t]*\n") do
    text = text:gsub("^[ \t]*\n", "", 1)
  end

  return text
end

local function each_line(text)
  return (text .. "\n"):gmatch("([^\n]*)\n")
end

local function opening_fence(line, code_filetype)
  local indent, marker, info = line:match("^(%s*)(`+)(.*)$")

  if not marker then
    indent, marker, info = line:match("^(%s*)(~+)(.*)$")
  end

  if not marker or #marker < 3 then
    return
  end

  info = vim.trim(info)

  local language = type(code_filetype) == "string" and code_filetype:match("^[^%.]+") or nil
  local first = info:match("^([^,%s]+)")
  local rustdoc = first
    and language == "rust"
    and (rustdoc_attributes[first] or first:find("^ignore%-") or first:find("^edition%d+$"))

  if language and (not first or rustdoc) then
    return marker, indent .. marker .. language
  end

  return marker, line
end

local function closes_fence(line, opener)
  local closer = line:match("^%s*([`~]+)%s*$")

  return closer and closer:sub(1, 1) == opener:sub(1, 1) and #closer >= #opener
end

local function is_blank(line)
  return line:find("^%s*$") ~= nil
end

local function is_block_line(line)
  return line:find("^%s*#")
    or line:find("^%s*>")
    or line:find("^%s*<!%-%-")
    or line:find("^%s*%-%->")
    or line:find("^%s*[%-%*+]%s+")
    or line:find("^%s*%d+[.)]%s+")
    or line:find("^%s*|")
    or line:find("|%s*$")
    or line:find("^%s%s%s%s")
    or line:find("^\t")
end

local function paragraph_lines(lines)
  local result = {}
  local current

  for _, line in ipairs(lines) do
    local text = vim.trim(line:gsub("\\%s*$", ""))

    current = current and (current .. " " .. text) or text

    if line:find("\\%s*$") or line:find("  +$") then
      result[#result + 1] = current
      current = nil
    end
  end

  if current then
    result[#result + 1] = current
  end

  return result
end

local function is_reference_definition(line)
  return line:find("^%s*\\?%[.-%]:%s*%S") ~= nil
end

function M.prepare(text, opts)
  opts = Config.get(opts)

  local doc = { lines = {}, prose = {} }
  local code
  local after_code = false
  local paragraph = {}

  local function add_line(line, prose)
    doc.lines[#doc.lines + 1] = line

    if prose then
      doc.prose[#doc.lines] = true
    end
  end

  local function flush_paragraph()
    for _, line in ipairs(paragraph_lines(paragraph)) do
      add_line(line, true)
    end

    paragraph = {}
  end

  for raw in each_line(source(text or "")) do
    if code then
      add_line(raw)

      if closes_fence(raw, code) then
        code = nil
        after_code = true
      end
    else
      local line = raw:gsub("\\|", "|")
      local marker, normalized = opening_fence(line, opts.code_filetype)

      if after_code then
        after_code = false

        if not is_blank(line) then
          add_line("")
        end
      end

      if marker then
        flush_paragraph()
        add_line(normalized)
        code = marker
      elseif is_blank(line) then
        flush_paragraph()
        add_line("")
      elseif is_reference_definition(line) then
        flush_paragraph()
      elseif is_block_line(line) then
        flush_paragraph()
        add_line(line, true)
      else
        paragraph[#paragraph + 1] = line
      end
    end
  end

  flush_paragraph()

  while doc.lines[#doc.lines] and is_blank(doc.lines[#doc.lines]) do
    doc.lines[#doc.lines] = nil
  end

  return doc
end

local function apply_highlights(buf, row, line, highlights)
  for pattern, hl_group in pairs(highlights or {}) do
    local from = 1

    while from do
      local to, match

      from, to, match = line:find(pattern, from)

      if match then
        from, to = line:find(match, from, true)
      end

      if from then
        vim.api.nvim_buf_set_extmark(buf, ns, row, from - 1, {
          end_col = to,
          hl_group = hl_group,
          priority = 120,
        })
      end

      from = to and to + 1 or nil
    end
  end
end

local function contains(from, to, col)
  return from and to and col + 1 >= from and col + 1 <= to
end

local function open_url()
  local urls = vim.ui._get_urls()

  for _, url in ipairs(urls) do
    vim.ui.open(url)
  end

  return #urls > 0
end

local function open_pattern(line, col, hover)
  for pattern, handler in pairs(hover or {}) do
    local from = 1

    while from do
      local to, value

      from, to, value = line:find(pattern, from)

      if contains(from, to, col) then
        handler(value)
        return true
      end

      from = to and to + 1 or nil
    end
  end

  return false
end

local function open_link(opts, lhs)
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  if open_pattern(line, col, opts.hover) or open_url() then
    return
  end

  vim.api.nvim_feedkeys(lhs, "n", false)
end

function M.render(ctx)
  local opts = Config.get(ctx.config)
  local buf = ctx.buf
  local doc = ctx.doc or M.prepare(ctx.text, opts)

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, doc.lines)

  for row, line in ipairs(doc.lines) do
    if doc.prose[row] then
      apply_highlights(buf, row - 1, line, opts.highlights)
    end
  end

  if opts.keys then
    for _, lhs in ipairs({ "gx", "K" }) do
      vim.keymap.set("n", lhs, function()
        open_link(opts, lhs)
      end, { buffer = buf, silent = true })
    end
  end

  return doc
end

return M
