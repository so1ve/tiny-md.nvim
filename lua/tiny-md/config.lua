local M = {}

M.defaults = {
  keys = true,
  fenced_code_highlight = true,
  indented_code_highlight = false,
  providers = {},
  window = {
    border = "rounded",
    max_width = nil,
    max_height = nil,
  },
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

local function language_keys(code_filetype)
  if type(code_filetype) ~= "string" then
    return nil
  end

  local filetype = code_filetype:match("^[^%.]+")
  if not filetype or filetype == "" then
    return nil
  end

  local lang = vim.treesitter.language.get_lang(filetype) or filetype
  return code_filetype, filetype, lang
end

local function lookup_exact(map, raw, filetype, lang)
  if not raw then
    return nil, false
  end

  if map[raw] ~= nil then
    return map[raw], true
  end
  if map[filetype] ~= nil then
    return map[filetype], true
  end
  if lang ~= filetype and map[lang] ~= nil then
    return map[lang], true
  end

  return nil, false
end

function M.lookup_language(map, code_filetype)
  if type(map) ~= "table" then
    return nil, false
  end

  local raw, filetype, lang = language_keys(code_filetype)
  local value, found = lookup_exact(map, raw, filetype, lang)
  if found then
    return value, true
  end

  if map["*"] ~= nil then
    return map["*"], true
  end

  return nil, false
end

function M.match_language(spec, code_filetype, default_enabled)
  if spec == nil then
    return default_enabled == true
  end

  if type(spec) == "boolean" then
    return spec
  end

  if type(spec) ~= "table" then
    return false
  end

  local raw, filetype, lang = language_keys(code_filetype)
  local value, found = lookup_exact(spec, raw, filetype, lang)

  if not found and #spec > 0 then
    if raw then
      for _, entry in ipairs(spec) do
        if entry == raw or entry == filetype or entry == lang then
          return true
        end
      end
    end

    if spec["*"] ~= nil then
      value, found = spec["*"], true
    else
      return false
    end
  elseif not found and spec["*"] ~= nil then
    value, found = spec["*"], true
  end

  if found then
    if value == true then
      return true
    end
    if type(value) == "string" and value ~= "" then
      return value
    end
    return false
  end

  if not default_enabled then
    return false
  end

  for key, entry in pairs(spec) do
    if key ~= "*" and entry == true then
      return false
    end
  end

  return true
end

function M.resolve_code_language(spec, code_filetype, default_enabled)
  local raw, _, default_lang = language_keys(code_filetype)
  if not raw then
    return nil
  end

  local matched = M.match_language(spec, code_filetype, default_enabled)
  if matched == true then
    return default_lang
  end
  if type(matched) == "string" then
    return vim.treesitter.language.get_lang(matched) or matched
  end

  return nil
end

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

function M.get(opts)
  return vim.tbl_deep_extend("force", vim.deepcopy(M.options), opts or {})
end

return M
