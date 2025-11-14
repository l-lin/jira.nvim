local M = {}

--- Setup plugin with user configuration
---@param opts jira.Config?
function M.setup(opts)
  require("jira.config").setup(opts)

  -- Setup buffer system
  require("jira.buf").setup()

  -- Register with snacks.picker if available
  if package.loaded["snacks"] then
    require("jira.picker").register()
  end
end

--- Open issues picker
---@param opts table? Picker options
function M.open_jira_issues(opts)
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
function M.open_jira_epic(opts)
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

--- Start working on issue (assign, sprint, transition, git branch, yank)
---@param opts table? Command options (from nvim_create_user_command)
function M.start_working_on(opts)
  opts = opts or {}
  local issue_key = opts.fargs and opts.fargs[1]

  if not issue_key or issue_key == "" then
    vim.notify("Issue key required", vim.log.levels.WARN)
    return
  end

  local actions = require("jira.picker.actions")
  actions.start_work_on_issue(issue_key)
end

return M
