vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd.packadd("render-markdown.nvim")
vim.o.termguicolors = true
vim.o.swapfile = false
require("tiny-md").setup({
  render_markdown = { code = { priority = 0 }, link = { enabled = false } },
})

for group, attributes in pairs({
  RenderMarkdownCode = { fg = "#ff0000", bg = "#102030" },
  RenderMarkdownCodeInline = { bg = "#203040" },
  RenderMarkdownH1Bg = { bg = "#302010" },
  ["@keyword.lua"] = { fg = "#00ff00" },
  ["@string.lua"] = { fg = "#0000ff" },
  ["@comment.lua"] = { fg = "#00ffff" },
  ["@variable.parameter"] = { fg = "#ff00ff" },
}) do
  vim.api.nvim_set_hl(0, group, attributes)
end

local function run()
  -- Initialize highlight inspection before rendering, then force a fresh grid.
  vim.api.nvim__inspect_cell(1, 0, 0)
  local main = vim.api.nvim_get_current_win()
  local buf
  local function show(text, width)
    local preview = require("tiny-md.window").open({ text = text, enter = true, max_width = width })
    buf = preview.buf
    vim.bo[buf].bufhidden = "hide"
    vim.api.nvim_win_set_buf(main, buf)
    vim.api.nvim_set_current_win(main)
    preview.close()
  end

  local function attributes(text, offset)
    vim.api.nvim_win_set_cursor(main, { 1, 0 })
    assert(vim.fn.search("\\V" .. text, "cW") > 0, "missing text: " .. text)
    vim.cmd.normal({ "zz", bang = true })
    vim.cmd.redraw({ bang = true })
    local cursor = vim.api.nvim_win_get_cursor(main)
    local position = vim.fn.screenpos(main, cursor[1], cursor[2] + 1 + (offset or 0))
    return vim.api.nvim__inspect_cell(1, position.row - 1, position.col - 1)[2]
  end

  local function expect(text, expected, offset)
    local actual = attributes(text, offset)
    for name, value in pairs(expected) do
      assert(actual[name] == value, vim.inspect({ text = text, expected = expected, actual = actual }))
    end
  end

  show(
    [[
# Heading



**bold** *italic* ***both*** ~~deleted~~ `inline`.

```lua
local value = 'string'
-- comment
```

<strong>strong</strong> <em>emphasis</em> <code>htmlcode</code>

[**boldlink**](docs.md) and plain.
]],
    52
  )
  expect("Heading", { background = 0x302010, bold = true })
  expect("bold", { bold = true })
  expect("italic", { italic = true })
  expect("both", { bold = true, italic = true })
  expect("deleted", { strikethrough = true })
  expect("inline", { background = 0x203040 })
  expect("local", { foreground = 0x00ff00, background = 0x102030 })
  expect("string", { foreground = 0x0000ff, background = 0x102030 })
  expect("comment", { foreground = 0x00ffff, background = 0x102030 })
  expect("strong", { bold = true })
  expect("emphasis", { italic = true })
  expect("htmlcode", { background = 0x203040 })
  expect("boldlink", { bold = true, underline = true })
  assert(attributes("plain").background ~= 0x102030, "code background leaked into prose")

  for _, width in ipairs({ 32, 80 }) do
    show(
      "| Field | Notes |\n| --- | --- |\n| @param | **tbold** *titalic* ***tboth*** `tcode` [tlink](target.md) <strong>thtml</strong> 中文 café |",
      width
    )
    expect("@param", { foreground = 0xff00ff })
    expect("tbold", { bold = true })
    expect("titalic", { italic = true })
    expect("tboth", { bold = true, italic = true })
    expect("tcode", { background = 0x203040 })
    expect("tlink", { underline = true })
    expect("thtml", { bold = true })
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    assert(text:find("中文", 1, true) and text:find("café", 1, true), text)
  end
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      local ok, err = pcall(run)
      if not ok then
        io.stderr:write(tostring(err) .. "\n")
        vim.cmd.cquit()
      end
      io.stdout:write("PASS: rendered colors and styles for prose, code, HTML, and narrow/wide tables\n")
      vim.cmd.qa({ bang = true })
    end)
  end,
})
