local M = {}

---Check if jira CLI is available
---@return boolean true if jira CLI is available, false otherwise
function M.has_jira_cli()
  local config = require("jira.config").options
  return vim.fn.executable(config.cli.cmd) == 1
end

return M
