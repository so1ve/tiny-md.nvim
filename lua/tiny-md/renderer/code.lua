local M = {}
local treesitter_priority = vim.hl.priorities.treesitter

local function highlight(buf, ns, block)
  if not block.language then
    return
  end

  local language = vim.treesitter.language.get_lang(block.language) or block.language
  local source = table.concat(vim.api.nvim_buf_get_lines(buf, block.from - 1, block.to, false), "\n")
  local ok_parser, parser = pcall(vim.treesitter.get_string_parser, source, language)

  if not ok_parser then
    return
  end

  local query = vim.treesitter.query.get(language, "highlights")

  if not query then
    return
  end

  local trees = parser:parse()

  for capture, node, metadata in query:iter_captures(trees[1]:root(), source, 0, -1) do
    local name = query.captures[capture]

    if not name:find("^_") then
      local range = vim.treesitter.get_range(node, source, metadata[capture])
      local start_row, start_col = range[1], range[2]
      local end_row, end_col = range[4], range[5]
      local priority = tonumber(metadata.priority or metadata[capture] and metadata[capture].priority)
        or treesitter_priority

      if priority == treesitter_priority then
        priority = priority + 1
      end

      vim.api.nvim_buf_set_extmark(buf, ns, block.from - 1 + start_row, start_col, {
        end_row = block.from - 1 + end_row,
        end_col = end_col,
        hl_group = "@" .. name .. "." .. language,
        priority = priority,
      })
    end
  end
end

function M.apply(buf, ns, blocks)
  for _, block in ipairs(blocks) do
    for row = block.from - 1, block.to - 1 do
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        end_row = row + 1,
        hl_group = "@markup.raw.block.markdown",
        priority = treesitter_priority,
      })
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        end_row = row + 1,
        hl_eol = true,
        hl_group = "RenderMarkdownCode",
        priority = 140,
      })
    end

    highlight(buf, ns, block)
  end
end

function M.configure_parser(buf, parser, blocks)
  local regions = {}
  local row = 0

  for _, block in ipairs(blocks) do
    local code_start = block.from - 1

    if row < code_start then
      regions[#regions + 1] = { { row, 0, code_start, 0 } }
    end

    row = block.to
  end

  local line_count = vim.api.nvim_buf_line_count(buf)

  if row < line_count then
    regions[#regions + 1] = { { row, 0, line_count, 0 } }
  end

  parser:set_included_regions(regions)
end

return M
