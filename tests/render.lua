vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd.packadd("render-markdown.nvim")
vim.cmd.runtime("plugin/man.lua")
require("tiny-md").setup({ render_markdown = { link = { enabled = false } } })

local Window = require("tiny-md.window")
local opened
vim.ui.open = function(target)
  opened = target
end

local function lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function press(keys)
  vim.api.nvim_feedkeys(keys, "xt", false)
end

local function find(text)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  assert(vim.fn.search("\\V" .. text, "cW") > 0, "missing text: " .. text)
end

local function check_link(label, target)
  find(label)
  for _, key in ipairs({ "K", "gx" }) do
    opened = nil
    press(key)
    assert(opened == target, vim.inspect({ label, key, opened }))
  end
end

local preview = Window.open({
  text = "Use `printf` to format.\n\n```lua\nlocal value = '`literal` **bold**'\nprint(value)\n```\n\n---\n\nDone.",
  enter = true,
})
local displayed = lines(preview.buf)
assert(displayed[1] == "Use printf to format.")
assert(displayed[3] == "local value = '`literal` **bold**'")
assert(displayed[4] == "print(value)")
assert(displayed[6] == string.rep("─", vim.api.nvim_win_get_width(preview.win)))
press("gg0w")
assert(vim.fn.expand("<cword>") == "printf")
press('viw"ay')
assert(vim.fn.getreg("a") == "printf")
press('ggVG"ay')
assert(vim.fn.getreg("a") == table.concat(displayed, "\n") .. "\n")
assert(vim.wo.conceallevel == 0)
assert(not vim.bo.modifiable)
preview.close()
print("PASS: native movement and selection use the displayed text; code literals survive")

preview = Window.open({
  text = table.concat({
    "First paragraph.",
    "",
    " \t",
    "",
    "Second paragraph.",
    "",
    "*@param* `value` — input",
    "",
    "",
    "*@returns* — result",
    "",
    "```lua",
    "first()",
    "",
    "",
    "second()",
    "```",
    "",
    "    indented()",
    "",
    "",
    "    more()",
    "",
    "Before empty code.",
    "",
    "```",
    "```",
    "",
    "After empty code.",
  }, "\n"),
  enter = true,
})
assert(
  vim.deep_equal(lines(preview.buf), {
    "First paragraph.",
    "",
    "Second paragraph.",
    "",
    "@param value — input",
    "",
    "@returns — result",
    "",
    "first()",
    "",
    "",
    "second()",
    "",
    "    indented()",
    "",
    "",
    "    more()",
    "",
    "Before empty code.",
    "",
    "After empty code.",
  }),
  vim.inspect(lines(preview.buf))
)
preview.close()
print("PASS: paragraph spacing is compact while fenced and indented code keep blank lines")

preview = Window.open({
  text = "**粗体**和*斜体*，`中文`，[链接](https://example.com)。 <code>printf</code>",
  enter = true,
})
assert(lines(preview.buf)[1] == "粗体和斜体，中文，链接。 printf")
check_link("链接", "https://example.com")
preview.close()

preview = Window.open({ text = "[printf](printf) and [manual](docs/manual.md)", enter = true })
check_link("printf", "printf")
check_link("manual", "docs/manual.md")
preview.close()
print("PASS: Unicode, inline markup, HTML, and relative links")

preview = Window.open({ text = "printf", enter = true })
opened = nil
press("K")
assert(opened == nil)
assert(vim.bo.filetype == "man")
assert(vim.api.nvim_buf_get_name(0):match("man://printf%(1%)$"))
preview.close()
print("PASS: K falls back to man")

preview = Window.open({
  text = "| Name | Description |\n| --- | --- |\n| [First](first.md) | a long description with [Second](second.md) that wraps across several lines |",
  enter = true,
  max_width = 32,
})
displayed = lines(preview.buf)
assert(#displayed > 5, vim.inspect(displayed))
for _, line in ipairs(displayed) do
  assert(vim.api.nvim_strwidth(line) <= 32, line)
end
check_link("First", "first.md")
check_link("Second", "second.md")
press('ggVG"ay')
assert(vim.fn.getreg("a") == table.concat(displayed, "\n") .. "\n")
preview.close()
print("PASS: wrapped table rows are selectable and retain link targets")

preview = Window.open({ text = string.rep("A `word`.\n\n", 60) .. "Final `entry`.", enter = true })
press("G")
assert(vim.api.nvim_get_current_line() == "Final entry.")
preview.close()
print("PASS: content below the initial viewport is rendered")

preview = Window.open({ text = "initial", enter = true, filetype = "blink-cmp-documentation" })
local window = {
  get_buf = function()
    return preview.buf
  end,
  get_win = function()
    return preview.win
  end,
}
local draw = require("tiny-md.blink").draw
draw({ window = window, item = { documentation = "Stale `content`." } })
draw({ window = window, item = { documentation = "Current `content`." } })
assert(vim.wait(1000, function()
  return lines(preview.buf)[1] == "Current content."
end))
assert(not vim.bo[preview.buf].modifiable)
draw({ window = window, item = {} })
assert(vim.wait(1000, function()
  return #vim.api.nvim_buf_get_extmarks(preview.buf, -1, 0, -1, {}) == 0
end))
assert(vim.deep_equal(lines(preview.buf), { "" }))
preview.close()
print("PASS: blink redraws the latest item and clears empty documentation")

require("tiny-md").setup({ render_markdown = { link = { hyperlink = "↗ " } } })
for _, text in ipairs({
  "[First](first.md)",
  "| Name | Description |\n| --- | --- |\n| [First](first.md) | a long description that wraps across several lines |",
}) do
  preview = Window.open({ text = text, enter = true, max_width = 32 })
  check_link("↗", "first.md")
  check_link("First", "first.md")
  preview.close()
end
print("PASS: link icons keep their targets in prose and wrapped tables")

local handled
preview = Window.open({
  text = "See |topic| here.",
  enter = true,
  code_filetype = "lua",
  config = {
    hover = {
      ["|(%S-)|"] = {
        function(value)
          handled = value
        end,
        languages = { "lua", "vim" },
      },
    },
  },
})
find("topic")
handled = nil
press("K")
assert(handled == "topic", vim.inspect(handled))
preview.close()

preview = Window.open({
  text = "See |topic| here.",
  enter = true,
  code_filetype = "typescript",
  config = {
    hover = {
      ["|(%S-)|"] = {
        handler = function(value)
          handled = value
        end,
        languages = { "lua", "vim" },
      },
    },
  },
})
find("topic")
handled = nil
opened = nil
press("gx")
assert(handled == nil, vim.inspect(handled))
preview.close()

preview = Window.open({
  text = "See |topic| here.",
  enter = true,
  code_filetype = "lua",
  config = {
    hover = {
      ["|(%S-)|"] = false,
    },
  },
})
find("topic")
handled = nil
opened = nil
press("gx")
assert(handled == nil, vim.inspect(handled))
preview.close()
print("PASS: hover rules support language filtering and false disabling")

vim.cmd.qa({ bang = true })
