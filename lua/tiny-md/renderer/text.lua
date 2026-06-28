local M = {}

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

local function html_entities(text)
  return text:gsub("&(%a+);", entities)
end

local function trim_leading_blank_lines(text)
  while true do
    local next_from = text:match("^[ \t]*\n()")

    if not next_from then
      return text
    end

    text = text:sub(next_from)
  end
end

function M.trim(text)
  return text:gsub("^%s+", ""):gsub("%s+$", "")
end

function M.each_line(text)
  return (text:gsub("\r", "") .. "\n"):gmatch("([^\n]*)\n")
end

function M.source(text)
  return trim_leading_blank_lines(html_entities(text:gsub("\r\n", "\n"):gsub("\r", "\n")))
end

function M.fence_marker(line)
  return line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
end

local rustdoc_attributes = { "compile_fail", "ignore", "no_run", "should_panic", "standalone_crate" }

function M.fence_line(line, code_filetype)
  local indent, marker, info = line:match("^(%s*)(```+)%s*(.-)%s*$")

  if not marker then
    indent, marker, info = line:match("^(%s*)(~~~+)%s*(.-)%s*$")
  end

  if not marker then
    return line, nil
  end

  local language = type(code_filetype) == "string" and code_filetype:match("^[^%.]+") or nil
  local first = info:match("^([^,%s]+)")
  local rustdoc = first
    and language == "rust"
    and (vim.tbl_contains(rustdoc_attributes, first) or first:find("^ignore%-") or first:find("^edition%d+$"))

  if language and (not first or rustdoc) then
    return indent .. marker .. language .. (info ~= "" and "," .. info or ""), marker
  end

  return line, marker
end

function M.closes_fence(line, opener)
  local closer = line:match("^%s*([`~]+)%s*$")

  return closer and closer:sub(1, 1) == opener:sub(1, 1) and #closer >= #opener
end

function M.is_blank(line)
  return line:find("^%s*$") ~= nil
end

function M.is_block_line(line)
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

local function is_hard_break(line)
  return line:find("\\%s*$") or line:find("  +$")
end

local function clean_paragraph_line(line)
  return M.trim(line:gsub("\\%s*$", ""))
end

function M.paragraph_lines(lines)
  local result = {}
  local current

  for _, line in ipairs(lines) do
    local text = clean_paragraph_line(line)

    current = current and (current .. " " .. text) or text

    if is_hard_break(line) then
      result[#result + 1] = current
      current = nil
    end
  end

  if current then
    result[#result + 1] = current
  end

  return result
end

return M
