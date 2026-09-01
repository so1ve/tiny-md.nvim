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
  text = text:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("&(%a+);", entities)

  return trim_leading_blank_lines(text)
end

local rustdoc_attributes = {
  compile_fail = true,
  ignore = true,
  no_run = true,
  should_panic = true,
  standalone_crate = true,
}

function M.fence_marker(line)
  local marker, info = line:match("^%s*(```+)%s*(.-)%s*$")

  if not marker then
    marker, info = line:match("^%s*(~~~+)%s*(.-)%s*$")
  end

  if not marker then
    return
  end

  return marker, info
end

function M.fence(line, code_filetype)
  local marker, info = M.fence_marker(line)

  if not marker then
    return
  end

  local language = type(code_filetype) == "string" and code_filetype:match("^[^%.]+") or nil
  local first = info:match("^([^,%s]+)")
  local rustdoc = first
    and language == "rust"
    and (rustdoc_attributes[first] or first:find("^ignore%-") or first:find("^edition%d+$"))

  if language and (not first or rustdoc) then
    first = language
  end

  return marker, first
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

function M.paragraph_lines(lines)
  local result = {}
  local current

  for _, line in ipairs(lines) do
    local text = M.trim(line:gsub("\\%s*$", ""))

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

return M
