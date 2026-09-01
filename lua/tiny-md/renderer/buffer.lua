local Code = require("tiny-md.renderer.code")

local M = {}

local function apply_highlights(buf, ns, row, line, opts)
  for pattern, hl_group in pairs(opts.highlights or {}) do
    local from = 1

    while from do
      local to, match

      from, to, match = line:find(pattern, from)

      if match then
        from, to = line:find(match, from)
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

function M.render(buf, ns, doc, opts)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, doc.lines)
  vim.b[buf].tiny_md_links = doc.links
  Code.apply(buf, ns, doc.code_blocks)

  for row, line in ipairs(doc.lines) do
    if doc.prose[row] then
      apply_highlights(buf, ns, row - 1, line, opts)
    end
  end

  for row, links in pairs(doc.links) do
    for _, link in ipairs(links) do
      local from = link.from - 1

      if link.to > from then
        vim.api.nvim_buf_set_extmark(buf, ns, tonumber(row) - 1, from, {
          end_col = link.to,
          hl_group = opts.link_hl,
          priority = 120,
        })
      end
    end
  end
end

return M
