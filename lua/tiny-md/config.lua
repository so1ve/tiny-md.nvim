local M = {}

M.defaults = {
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
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

function M.get(opts)
  local options = vim.deepcopy(M.options)

  if opts then
    options = vim.tbl_deep_extend("force", options, opts)
  end

  return options
end

return M
