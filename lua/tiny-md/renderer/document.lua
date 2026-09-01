local Document = {}
Document.__index = Document

function Document.new()
  return setmetatable({
    code_blocks = {},
    lines = {},
    links = {},
    prose = {},
  }, Document)
end

function Document:add_line(line, meta)
  self.lines[#self.lines + 1] = line

  if meta and meta.prose then
    self.prose[#self.lines] = true
  end

  if meta and meta.links then
    self.links[tostring(#self.lines)] = meta.links
  end
end

function Document:add_code_block(lines, language)
  if #lines == 0 then
    return
  end

  local from = #self.lines + 1

  for _, line in ipairs(lines) do
    self:add_line(line)
  end

  self.code_blocks[#self.code_blocks + 1] = {
    from = from,
    to = #self.lines,
    language = language,
  }
end

function Document:trim_trailing_blank_lines()
  while self.lines[#self.lines] and self.lines[#self.lines]:find("^%s*$") do
    local row = #self.lines
    local block = self.code_blocks[#self.code_blocks]

    if block and row == block.to then
      break
    end

    self.lines[row] = nil
    self.links[tostring(row)] = nil
    self.prose[row] = nil
  end
end

return Document
