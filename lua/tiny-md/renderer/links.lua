local Text = require("tiny-md.renderer.text")

local M = {}

local reference_links = {
  collapsed_reference_link = true,
  full_reference_link = true,
  shortcut_link = true,
}

local function node_range(node)
  local _, start_col, _, end_col = node:range()

  return start_col + 1, end_col
end

local function node_text(source, node)
  local from, to = node_range(node)

  return source:sub(from, to)
end

local function child(node, node_type)
  for child_node in node:iter_children() do
    if child_node:type() == node_type then
      return child_node
    end
  end
end

local function label_node(node)
  return child(node, node:type() == "image" and "image_description" or "link_text")
end

local function normalize_label(label)
  return Text.trim(label):gsub("`([^`]*)`", "%1"):gsub("`", ""):gsub("%s+", " "):lower()
end

local function normalize_url(url)
  return url and (Text.trim(url):match("^<(.+)>") or Text.trim(url)) or nil
end

function M.reference_definition(line)
  local label, url = line:match("^%s*\\?%[(.-)%]:%s*<([^>]+)>")

  if label then
    return label, url
  end

  return line:match("^%s*\\?%[(.-)%]:%s*(%S+)")
end

function M.references_from(text)
  local references = {}
  local code

  for line in Text.each_line(text) do
    local marker = Text.fence_marker(line)

    if code then
      if Text.closes_fence(line, code) then
        code = nil
      end
    elseif marker then
      code = marker
    else
      local label, url = M.reference_definition(line)

      if label and not label:match("^%^") then
        url = normalize_url(url)

        if url and url ~= "" then
          references[normalize_label(label)] = url
        end
      end
    end
  end

  return references
end

local function add_link(node, url, links)
  local label = label_node(node)

  if not (label and url and url ~= "") then
    return
  end

  local from, to = node_range(node)
  local label_from, label_to = node_range(label)

  links[#links + 1] = {
    from = from,
    to = to,
    label_from = label_from,
    label_to = label_to,
    url = url,
  }
end

local function collect_links(source, node, references, links)
  local node_type = node:type()

  if node_type == "inline_link" or node_type == "image" then
    local destination = child(node, "link_destination")

    if destination then
      add_link(node, normalize_url(node_text(source, destination)), links)
    end
  elseif reference_links[node_type] then
    local label = label_node(node)
    local reference = child(node, "link_label")
    local label_text = label and node_text(source, label) or nil
    local reference_text = reference and node_text(source, reference):match("^%[(.*)%]$") or label_text
    local url = reference_text and references[normalize_label(reference_text)] or nil

    if not url and label_text then
      url = references[normalize_label(label_text)]
    end

    add_link(node, url, links)
  end

  for child_node in node:iter_children() do
    collect_links(source, child_node, references, links)
  end
end

local function parse(line, references)
  local ok_parser, parser = pcall(vim.treesitter.get_string_parser, line, "markdown_inline")

  if not ok_parser then
    return {}
  end

  local ok, trees = pcall(parser.parse, parser)

  if not (ok and trees and trees[1]) then
    return {}
  end

  local links = {}

  collect_links(line, trees[1]:root(), references, links)
  table.sort(links, function(left, right)
    return left.from < right.from
  end)

  return links
end

local function append(parts, output_col, text)
  if text ~= "" then
    parts[#parts + 1] = text
  end

  return output_col + #text
end

function M.render_inline(line, references)
  local links = parse(line, references)

  if #links == 0 then
    return line, nil
  end

  local parts = {}
  local rendered_links = {}
  local source_pos = 1
  local output_col = 0

  for _, link in ipairs(links) do
    if link.from >= source_pos then
      output_col = append(parts, output_col, line:sub(source_pos, link.from - 1))

      local from = output_col + 1

      output_col = append(parts, output_col, line:sub(link.label_from, link.label_to))
      rendered_links[#rendered_links + 1] = { from = from, to = output_col, url = link.url }
      source_pos = link.to + 1
    end
  end

  append(parts, output_col, line:sub(source_pos))

  return table.concat(parts), rendered_links
end

local function open_link(buf, opts, lhs)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local links = (vim.b[buf].tiny_md_links or {})[tostring(row)] or {}

  for _, link in ipairs(links) do
    if col + 1 >= link.from and col + 1 <= link.to then
      return vim.ui.open(link.url)
    end
  end

  local line = vim.api.nvim_get_current_line()

  for pattern, handler in pairs(opts.hover or {}) do
    local from = 1

    while from do
      local to, url

      from, to, url = line:find(pattern, from)

      if from and col + 1 >= from and col + 1 <= to then
        return handler(url)
      end

      from = to and to + 1 or nil
    end
  end

  vim.api.nvim_feedkeys(lhs, "n", false)
end

function M.set_keys(buf, opts)
  for _, lhs in ipairs({ "gx", "K" }) do
    vim.keymap.set("n", lhs, function()
      open_link(buf, opts, lhs)
    end, { buffer = buf, silent = true })
  end
end

return M
