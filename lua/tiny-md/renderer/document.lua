local Document = {}
Document.__index = Document

function Document.new()
  return setmetatable({
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

function Document:trim_trailing_blank_lines()
  while self.lines[#self.lines] and self.lines[#self.lines]:find("^%s*$") do
    local row = #self.lines

    self.lines[row] = nil
    self.links[tostring(row)] = nil
    self.prose[row] = nil
  end
end

return Document
