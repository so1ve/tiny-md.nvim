local M = {}

local function split_lines(text)
  return vim.split((text or ""):gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
end

local function fenced_lines(language, text)
  local lines = { "```" .. language }

  vim.list_extend(lines, split_lines(text))
  lines[#lines + 1] = "```"

  return lines
end

local function marked_string_lines(item)
  if type(item) == "string" then
    return split_lines(item)
  end

  if type(item) ~= "table" or not item.value then
    return {}
  end

  if item.language then
    return fenced_lines(item.language, item.value)
  end

  return split_lines(item.value)
end

function M.lines(markdown)
  if type(markdown) == "string" then
    return split_lines(markdown)
  end

  if type(markdown) ~= "table" then
    return {}
  end

  if vim.islist(markdown) then
    local lines = {}

    for _, item in ipairs(markdown) do
      if #lines > 0 then
        lines[#lines + 1] = ""
      end

      vim.list_extend(lines, marked_string_lines(item))
    end

    return lines
  end

  return marked_string_lines(markdown)
end

function M.has_content(lines)
  for _, line in ipairs(lines or {}) do
    if type(line) == "string" and line:find("%S") then
      return true
    end
  end

  return false
end

function M.with_detail(opts)
  opts = opts or {}

  local lines = M.lines(opts.documentation)
  local detail = type(opts.detail) == "string" and vim.trim(opts.detail) or ""

  if detail == "" or table.concat(lines, "\n"):find(detail, 1, true) then
    return lines
  end

  local filetype = type(opts.filetype) == "string" and opts.filetype:match("^[^%.]+") or ""
  local detail_lines = fenced_lines(filetype, detail)

  if M.has_content(lines) then
    detail_lines[#detail_lines + 1] = ""
    vim.list_extend(detail_lines, lines)
  end

  return detail_lines
end

return M
