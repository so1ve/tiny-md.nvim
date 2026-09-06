local Buffer = require("tiny-md.renderer.buffer")
local Config = require("tiny-md.config")
local Document = require("tiny-md.renderer.document")
local Links = require("tiny-md.renderer.links")
local Text = require("tiny-md.renderer.text")

local M = {}

M.ns = vim.api.nvim_create_namespace("tiny-md")

function M.render_text(text, opts)
  opts = Config.get(opts)

  local source = Text.source(text)
  local references = Links.references_from(source)
  local doc = Document.new()
  local code
  local paragraph = {}

  local function add_prose(line)
    local block = doc.code_blocks[#doc.code_blocks]

    if block and block.to == #doc.lines then
      doc:add_line("")
    end

    local rendered, links = Links.render_inline(line, references)

    doc:add_line(rendered, { links = links, prose = true })
  end

  local function flush_paragraph()
    for _, line in ipairs(Text.paragraph_lines(paragraph)) do
      add_prose(line)
    end

    paragraph = {}
  end

  for raw in Text.each_line(source) do
    if code then
      if Text.closes_fence(raw, code.marker) then
        doc:add_code_block(code.lines, code.language)
        code = nil
      else
        code.lines[#code.lines + 1] = raw
      end
    else
      local line = raw:gsub("\\|", "|")
      local marker, language

      marker, language = Text.fence(line, opts.code_filetype)

      if marker then
        flush_paragraph()
        code = { language = language, lines = {}, marker = marker }
      elseif Text.is_blank(line) then
        flush_paragraph()
        doc:add_line("")
      elseif Links.reference_definition(line) then
        flush_paragraph()
      elseif Text.is_block_line(line) then
        flush_paragraph()
        add_prose(line)
      else
        paragraph[#paragraph + 1] = line
      end
    end
  end

  if code then
    doc:add_code_block(code.lines, code.language)
  end

  flush_paragraph()
  doc:trim_trailing_blank_lines()

  return doc
end

function M.render(ctx)
  local opts = Config.get(ctx.config)
  local buf = ctx.buf

  local doc = ctx.doc

  if not doc then
    doc = M.render_text(ctx.text, opts)
  end

  Buffer.render(buf, M.ns, doc, opts)

  if opts.keys then
    Links.set_keys(buf, opts)
  end

  return doc
end

return M
