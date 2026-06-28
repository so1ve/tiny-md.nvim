local M = {}

local function line_highlights(line, opts)
  local highlights = {}

  for pattern, hl_group in pairs(opts.highlights or {}) do
    local from = 1

    while from do
      local to, match

      from, to, match = line:find(pattern, from)

      if match then
        from, to = line:find(match, from)
      end

      if from then
        highlights[#highlights + 1] = {
          hl_group = hl_group,
          col = from - 1,
          length = to - from + 1,
        }
      end

      from = to and to + 1 or nil
    end
  end

  return highlights
end

local function highlight_range(buf, ns, row, from, to, hl_group, priority)
  if to <= from then
    return
  end

  vim.api.nvim_buf_set_extmark(buf, ns, row, from, {
    end_col = to,
    hl_group = hl_group,
    priority = priority or 120,
  })
end

local function apply_highlights(buf, ns, row, line, opts)
  for _, highlight in ipairs(line_highlights(line, opts)) do
    highlight_range(buf, ns, row, highlight.col, highlight.col + highlight.length, highlight.hl_group, 120)
  end
end

function M.clear(buf, ns)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.b[buf].tiny_md_links = nil
end

function M.set_lines(buf, lines)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

function M.apply_doc(buf, ns, doc, opts)
  vim.b[buf].tiny_md_links = doc.links

  for row, line in ipairs(doc.lines) do
    if doc.prose[row] then
      apply_highlights(buf, ns, row - 1, line, opts)
    end
  end

  for row, links in pairs(doc.links) do
    for _, link in ipairs(links) do
      highlight_range(buf, ns, tonumber(row) - 1, link.from - 1, link.to, opts.link_hl, 120)
    end
  end
end

return M
