---Check if jira CLI is available
---@return boolean true if jira CLI is available, false otherwise
local function has_jira_cli()
  local config = require("jira.config").options
  return vim.fn.executable(config.cli.cmd) == 1
end

local M = {}
M.has_jira_cli = has_jira_cli
return M
