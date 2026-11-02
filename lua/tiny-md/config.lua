local M = {}

M.defaults = {
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
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

function M.get(opts)
  return vim.tbl_deep_extend("force", vim.deepcopy(M.options), opts or {})
end

return M
