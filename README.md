# tiny-md.nvim

A sensible embedded Markdown renderer for Neovim, powered by render-markdown.nvim.

## Why

LSP hover and completion docs are usually generated Markdown, not files you edit. They need tight paragraph wrapping, syntax-highlighted code, working links, and predictable scrolling.

Noice already handles common Markdown shapes well enough to look nice. The hard parts are the generated-doc Markdown edges spread across editor core, parsers, renderers, and LSP output:

- Noice has had representative LSP Markdown issues around link escaping ([folke/noice.nvim#455](https://github.com/folke/noice.nvim/issues/455)) and concealed code/link rows affecting hover layout ([#158](https://github.com/folke/noice.nvim/issues/158)).
- Some constraints live below plugins: concealed links can still wrap as if the hidden destination text were visible ([MeanderingProgrammer/render-markdown.nvim#82](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/82), duplicates [#160](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/160) and [#519](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/519)), which the maintainer traces to Neovim core behavior ([neovim/neovim#14409](https://github.com/neovim/neovim/issues/14409)).
- render-markdown.nvim integration has its own ownership and conceal tradeoffs, such as working alongside Noice/blink.cmp ([MeanderingProgrammer/render-markdown.nvim#402](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/402)) and generated documentation buffers ([#577](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/577)).

tiny-md.nvim normalizes generated docs before render-markdown.nvim sees them: it joins soft-wrapped prose, rewrites Markdown links to compact labels to avoid surprise wrapping, and keeps `gx` / `K` link actions working inside documentation floats.

## Requirements

- Neovim 0.12+
- render-markdown.nvim 8.9.0+
- Treesitter parsers for `markdown`, `markdown_inline`, and `html`

## Installation

### `lazy.nvim`

```lua
{
  "so1ve/tiny-md.nvim",
  dependencies = {
    "MeanderingProgrammer/render-markdown.nvim",
  },
  opts = {},
}
```

## Usage

Configure the plugin once:

```lua
require("tiny-md").setup()
```

Use tiny-md for LSP hover:

```lua
vim.keymap.set("n", "K", function()
  require("tiny-md.hover").hover()
end, { desc = "LSP hover" })
```

Use specific hover providers when multiple LSP clients are attached and you want to specify which one to use:

```lua
require("tiny-md.hover").hover({ providers = "rust_analyzer" })

require("tiny-md.hover").hover({
  providers = { "vue_ls", "vtsls" },
})
```

Use tiny-md for blink.cmp documentation:

```lua
{
  "saghen/blink.cmp",
  dependencies = {
    "so1ve/tiny-md.nvim",
  },
  opts = {
    completion = {
      documentation = {
        draw = function(opts)
          require("tiny-md.blink").draw(opts)
        end,
      },
    },
  },
}
```

## Configuration

```lua
require("tiny-md").setup({
  keys = true,
  link_hl = "@markup.link",
  hover = {
    ["|(%S-)|"] = vim.cmd.help,
    ["%[.-%]%((%S-)%)"] = vim.ui.open,
  },
  highlights = {
    ["|%S-|"] = "@markup.link",
    ["@%S+"] = "@variable.parameter",
    ["^%s*(Parameters:)"] = "@markup.heading",
    ["^%s*(Return:)"] = "@markup.heading",
    ["^%s*(See also:)"] = "@markup.heading",
    ["{%S-}"] = "@variable.parameter",
  },
  render_markdown = {
    -- Extra render-markdown.nvim options passed only when tiny-md renders
    -- generated documentation buffers.
  },
})
```

tiny-md.nvim does not merge these options into your global render-markdown.nvim setup. It keeps your render-markdown spec untouched and passes generated-doc options only when tiny-md explicitly renders hover or blink.cmp documentation buffers.

By default tiny-md passes these generated-doc options:

- `anti_conceal.enabled = false`
- `link.enabled = false`
- `html.tag.code.scope_highlight = "RenderMarkdownCodeInline"`
- `win_options.concealcursor.rendered = "nvic"`

The HTML tag setting conceals `<code>` / `</code>` and highlights their contents with `RenderMarkdownCodeInline`.

Link rendering is disabled in render-markdown.nvim for generated docs because tiny-md rewrites Markdown links into compact labels and stores their target URLs for `gx` / `K`. `concealcursor` keeps table/code conceals active on the cursor row, avoiding raw Markdown reveal when moving inside a documentation float. Other render-markdown options still come from your normal config, including any `overrides.filetype.markdown_doc` or `overrides.filetype.blink-cmp-documentation` settings such as bullets, HTML comments, tables, code styling, and headings.

tiny-md registers `markdown_doc` and `blink-cmp-documentation` as Markdown Treesitter filetypes, but it does not add them to render-markdown.nvim's global `file_types` list. Normal `markdown` buffers keep your render-markdown.nvim configuration.

## API

### `setup(opts?)`

Configures tiny-md and optional render-markdown.nvim integration options.

```lua
require("tiny-md").setup({})
```

### `hover(opts?)`

Requests LSP hover from one or more providers and opens a rendered documentation float.

```lua
require("tiny-md.hover").hover({ providers = { "vue_ls", "vtsls" } })
```

### `draw(opts)`

blink.cmp documentation drawer.

```lua
opts.completion.documentation.draw = require("tiny-md.blink").draw
```

### `open(opts)`

Opens a rendered Markdown floating window.

```lua
require("tiny-md.window").open({
  text = "# Hello",
  max_width = 88,
  source_buf = vim.api.nvim_get_current_buf(),
})
```

## Highlights

tiny-md.nvim uses existing highlight groups by default:

- `@markup.link`
- `@variable.parameter`
- `@markup.heading`

## Notes

tiny-md.nvim intentionally targets generated documentation buffers, not normal Markdown editing. If you want to use tiny-md.nvim for normal Markdown editing, you might want to use render-markdown.nvim directly instead.

## 📝 License

[MIT](./LICENSE). Made with ❤️ by [Ray](https://github.com/so1ve)
