--- Setup plugin with user configuration
---@param opts jira.Config?
local function setup(opts)
  require("jira.config").setup(opts)

  -- Register with snacks.picker if available
  if package.loaded["snacks"] then
    require("jira.picker").register()
  end
end

--- Open issues picker
---@param opts table? Picker options
local function issues(opts)
  if not package.loaded["snacks"] then
    vim.notify("jira.nvim requires snacks.nvim", vim.log.levels.ERROR)
    return
  end

  -- Register picker if not already done
  if not package.loaded["jira.picker"] then
    require("jira.picker").register()
  end

  return require("snacks").picker("jira_issues", opts)
end

local M = {}
M.setup = setup
M.issues = issues
return M
