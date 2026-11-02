# tiny-md.nvim

A sensible embedded Markdown renderer for Neovim, powered by render-markdown.nvim.

## Why

LSP hover and completion docs are usually generated Markdown, not files you edit. They need tight paragraph wrapping, syntax-highlighted code, working links, and predictable scrolling.

Noice already handles common Markdown shapes well enough to look nice. The hard parts are the generated-doc Markdown edges spread across parsers, renderers, and LSP output:

- Noice has had representative LSP Markdown issues around link escaping ([folke/noice.nvim#455](https://github.com/folke/noice.nvim/issues/455)) and concealed code/link rows affecting hover layout ([#158](https://github.com/folke/noice.nvim/issues/158)).
- Concealed links used to wrap using the width of their hidden destinations. Neovim 0.13's conceal-aware wrapping ([neovim/neovim#42370](https://github.com/neovim/neovim/pull/42370)) fixes this in core.
- render-markdown.nvim integration has its own ownership and conceal tradeoffs, such as working alongside Noice/blink.cmp ([MeanderingProgrammer/render-markdown.nvim#402](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/402)) and generated documentation buffers ([#577](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/577)).

tiny-md.nvim joins soft-wrapped prose, then lets Neovim and render-markdown.nvim handle links, code, and conceal natively in documentation floats.

## Requirements

- Neovim 0.13+
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
  hover = {
    ["|(%S-)|"] = vim.cmd.help,
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

tiny-md.nvim does not change the options in your render-markdown.nvim setup spec. It passes the generated-doc options only when tiny-md renders hover or blink.cmp documentation buffers.

By default tiny-md passes these generated-doc options:

- `anti_conceal.enabled = false`
- `code.border = "hide"` and `code.language = false`
- `link.enabled = true`
- `html.tag` mappings for `code`, `kbd`, `samp`, `var`, `strong`, and `em`
- `win_options.concealcursor.rendered = "nvic"`

The HTML tag mappings conceal their opening and closing tags. `code`, `kbd`, and `samp` use `RenderMarkdownCodeInline`; `var`, `strong`, and `em` use their corresponding Treesitter highlight groups.

Neovim's Markdown Treesitter query supplies link URLs and conceals link syntax. `gx` and `K` use that metadata inside documentation floats, and custom `hover` patterns still work. `concealcursor` keeps table/code conceals active on the cursor row, avoiding raw Markdown reveal when moving inside a documentation float. Other render-markdown options still come from your normal config, including `overrides.filetype.markdown_doc` or `overrides.filetype.blink-cmp-documentation` settings for bullets, HTML comments, tables, code styling, and headings.

tiny-md registers `markdown_doc` and `blink-cmp-documentation` as Markdown Treesitter filetypes and adds them to render-markdown.nvim's runtime `file_types` list. This lets render-markdown.nvim's manager handle cursor movement and scrolling inside documentation buffers. Normal `markdown` buffers keep your render-markdown.nvim configuration.

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
