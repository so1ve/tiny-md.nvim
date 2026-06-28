local M = {}

function M.split_lines(text)
  return vim.split((text or ""):gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
end

function M.append_lines(target, lines)
  for _, line in ipairs(lines) do
    target[#target + 1] = line
  end

  return target
end

local function marked_string_lines(item)
  if type(item) == "string" then
    return M.split_lines(item)
  end

  if type(item) ~= "table" then
    return {}
  end

  if item.language and item.value then
    local lines = { "```" .. item.language }

    M.append_lines(lines, M.split_lines(item.value))
    lines[#lines + 1] = "```"

    return lines
  end

  if item.value then
    return M.split_lines(item.value)
  end

  return {}
end

function M.lines(markdown)
  if type(markdown) == "string" then
    return M.split_lines(markdown)
  end

  if type(markdown) ~= "table" then
    return {}
  end

  if markdown.kind and markdown.value then
    return M.split_lines(markdown.value)
  end

  if vim.islist(markdown) then
    local lines = {}

    for _, item in ipairs(markdown) do
      if #lines > 0 then
        lines[#lines + 1] = ""
      end

      M.append_lines(lines, marked_string_lines(item))
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
  local detail_lines = { "```" .. filetype }

  M.append_lines(detail_lines, M.split_lines(detail))
  detail_lines[#detail_lines + 1] = "```"

  if M.has_content(lines) then
    detail_lines[#detail_lines + 1] = ""
    M.append_lines(detail_lines, lines)
  end

  return detail_lines
end

return M
