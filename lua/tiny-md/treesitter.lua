local Config = require("tiny-md.config")

local M = {}

local indented_code_query

local function get_indented_code_query()
  if not indented_code_query then
    indented_code_query = vim.treesitter.query.parse("markdown", "(indented_code_block) @block")
  end

  return indented_code_query
end

local function resolve_indented_language(option, code_filetype)
  if not option or type(code_filetype) ~= "string" then
    return nil
  end

  local filetype = code_filetype:match("^[^%.]+")
  if not filetype or filetype == "" then
    return nil
  end

  local default_lang = vim.treesitter.language.get_lang(filetype) or filetype

  if option == true then
    return default_lang
  end

  if type(option) ~= "table" then
    return nil
  end

  local configured = option[code_filetype]
  if configured == nil then
    configured = option[filetype]
  end
  if configured == nil and default_lang ~= filetype then
    configured = option[default_lang]
  end

  if configured ~= nil then
    if configured == true then
      return default_lang
    end
    if type(configured) == "string" and configured ~= "" then
      return vim.treesitter.language.get_lang(configured) or configured
    end
    return nil
  end

  for _, entry in ipairs(option) do
    if entry == code_filetype or entry == filetype or entry == default_lang then
      return default_lang
    end
  end

  return nil
end

local function strip_code_indent(line, start_col)
  local col = 0
  local index = start_col + 1

  while index <= #line and col < 4 do
    local byte = line:byte(index)
    if byte == 32 then
      col = col + 1
      index = index + 1
    elseif byte == 9 then
      col = col + (4 - (col % 4))
      index = index + 1
    else
      break
    end
  end

  return index - 1
end

local function indented_block_lines(buf, node)
  local sr, sc, er, ec = node:range()
  local last_row = ec == 0 and er - 1 or er
  if last_row < sr then
    return nil
  end

  local continuations = {}
  for child in node:iter_children() do
    if child:type() == "block_continuation" then
      local csr, _, _, cec = child:range()
      continuations[csr] = cec
    end
  end

  local raw_lines = vim.api.nvim_buf_get_lines(buf, sr, last_row + 1, false)
  local code_lines = {}
  local offsets = {}
  local prev_empty = false

  for index, line in ipairs(raw_lines) do
    local row = sr + index - 1
    local cont_end = continuations[row]
    local offset

    if row == sr then
      offset = strip_code_indent(line, sc)
    elseif cont_end and not prev_empty then
      offset = cont_end
    else
      offset = strip_code_indent(line, cont_end or 0)
    end

    local code_line = line:sub(offset + 1)
    code_lines[index] = code_line
    offsets[index] = offset
    prev_empty = #code_line == 0
  end

  return {
    start_row = sr,
    lines = code_lines,
    offsets = offsets,
  }
end

local function collect_indented_blocks(buf, parser)
  local query = get_indented_code_query()
  local blocks = {}
  local row_offsets = {}

  for _, tree in ipairs(parser:trees()) do
    for _, node in query:iter_captures(tree:root(), buf, 0, -1) do
      local block = indented_block_lines(buf, node)
      if block then
        blocks[#blocks + 1] = block
        for index, offset in ipairs(block.offsets) do
          row_offsets[block.start_row + index - 1] = offset
        end
      end
    end
  end

  return blocks, row_offsets
end

local function filter_marks(marks, row_offsets)
  if not next(row_offsets) then
    return vim.list_slice(marks or {})
  end

  local filtered = {}
  for _, mark in ipairs(marks or {}) do
    local offset = row_offsets[mark.start_row]
    if not offset or mark.start_col < offset then
      filtered[#filtered + 1] = mark
    end
  end

  return filtered
end

local function add_indented_code_highlights(marks, block, language)
  local source = table.concat(block.lines, "\n")
  if not source:find("%S") then
    return
  end

  local ok, sub_parser = pcall(vim.treesitter.get_string_parser, source, language)
  if not ok or not sub_parser then
    return
  end

  sub_parser:parse(true)
  sub_parser:for_each_tree(function(tree, language_tree)
    local sub_language = language_tree:lang()
    local query = vim.treesitter.query.get(sub_language, "highlights")
    if not query then
      return
    end

    for id, node, metadata in query:iter_captures(tree:root(), source, 0, -1) do
      local capture = query.captures[id]
      if not capture:find("^_") then
        local data = metadata[id] or {}
        local range = vim.treesitter.get_range(node, source, data)
        local r1, c1, r2, c2 = range[1], range[2], range[4], range[5]
        local hl_group = "@" .. capture .. "." .. sub_language
        local priority = tonumber(data.priority or metadata.priority) or vim.hl.priorities.treesitter

        for row = r1, math.min(r2, #block.lines - 1) do
          local offset = block.offsets[row + 1]
          local line_len = #block.lines[row + 1]
          local from = math.max(0, row == r1 and c1 or 0)
          local to = math.min(line_len, row == r2 and c2 or line_len)

          if to > from then
            marks[#marks + 1] = {
              start_row = block.start_row + row,
              start_col = offset + from,
              opts = {
                end_row = block.start_row + row,
                end_col = offset + to,
                hl_group = hl_group,
                priority = priority,
              },
            }
          end
        end
      end
    end
  end)
end

function M.collect(buf, marks, opts)
  local render_opts = Config.get(opts)
  local indented_language = resolve_indented_language(render_opts.indented_code_highlight, render_opts.code_filetype)

  local parser = vim.treesitter.get_parser(buf, "markdown")
  parser:parse(true)
  vim.treesitter.stop(buf)

  local indented_blocks, indented_offsets = collect_indented_blocks(buf, parser)
  local collected = filter_marks(marks, indented_offsets)

  parser:for_each_tree(function(tree, language_tree)
    local language = language_tree:lang()
    local query = vim.treesitter.query.get(language, "highlights")
    if not query then
      return
    end

    for id, node, metadata, match in query:iter_captures(tree:root(), buf, 0, -1) do
      local capture = query.captures[id]
      local data = metadata[id] or {}
      local range = vim.treesitter.get_range(node, buf, data)
      local conceal = data.conceal or metadata.conceal
      if capture == "noconceal" then
        conceal = false
      end
      local url = data.url
      if type(url) == "number" then
        url = vim.treesitter.get_node_text(assert(match:captures()[url][1]), buf, { metadata = metadata[url] })
      end
      local priority = tonumber(data.priority or metadata.priority) or vim.hl.priorities.treesitter
      if indented_language and node:type() == "indented_code_block" then
        priority = math.min(priority, 90)
      end
      collected[#collected + 1] = {
        start_row = range[1],
        start_col = range[2],
        code = node:type() == "fenced_code_block" or node:type() == "indented_code_block",
        opts = {
          end_row = range[4],
          end_col = range[5],
          hl_group = not capture:find("^_") and ("@" .. capture .. "." .. language) or nil,
          priority = priority,
          conceal = conceal,
          conceal_lines = data.conceal_lines or metadata.conceal_lines,
          url = url,
        },
      }
    end
  end)

  if indented_language then
    for _, block in ipairs(indented_blocks) do
      add_indented_code_highlights(collected, block, indented_language)
    end
  end

  return collected
end

return M
