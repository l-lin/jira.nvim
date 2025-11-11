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
local function open_jira_issues(opts)
  if not package.loaded["snacks"] then
    vim.notify("jira.nvim requires snacks.nvim", vim.log.levels.ERROR)
    return
  end

  if not package.loaded["jira.picker"] then
    require("jira.picker").register()
  end

  return require("snacks").picker("source_jira_issues", opts)
end

--- Open epic picker or epic issues picker
---@param opts table? Command options (from nvim_create_user_command)
local function open_jira_epic(opts)
  if not package.loaded["snacks"] then
    vim.notify("jira.nvim requires snacks.nvim", vim.log.levels.ERROR)
    return
  end

  if not package.loaded["jira.picker"] then
    require("jira.picker").register()
  end

  opts = opts or {}
  local epic_key = opts.fargs and opts.fargs[1]

  if epic_key then
    -- Open issues picker for specific epic
    local sources = require("jira.picker.sources")
    return require("snacks").picker(sources.source_jira_epic_issues(epic_key))
  else
    -- Open epic picker (which will chain to issues picker on selection)
    return require("snacks").picker("source_jira_epics")
  end
end

local M = {}
M.setup = setup
M.open_jira_issues = open_jira_issues
M.open_jira_epic = open_jira_epic
return M
