---Get issues from current sprint
---@return table args command arguments for jira CLI
local function build_jira_args()
  local util = require("jira.util")
  local config = require("jira.config").options

  -- Check if jira CLI is available
  if not util.has_jira_cli() then
    error("JIRA CLI not found. Please install: https://github.com/ankitpokhrel/jira-cli")
  end

  -- Build command arguments
  local args = { "sprint", "list", "--current" }

  -- Add filters
  local filters = config.query.filters
  vim.list_extend(args, filters)

  -- Add order
  local order_by =config.query.order_by
  vim.list_extend(args, { "--order-by", order_by })

  -- Add pagination
  local paginate = config.query.paginate
  vim.list_extend(args, { "--paginate", paginate })

  -- Add format
  local columns = config.query.columns
  vim.list_extend(args, { "--csv", "--columns", table.concat(columns, ",") })

  -- Debug: print command
  if config.debug then
    local cmd_str = config.cli.cmd .. " " .. table.concat(args, " ")
    vim.notify("JIRA CLI Command:\n" .. cmd_str, vim.log.levels.INFO)
  end

  return args
end

local M = {}
M.build_jira_args = build_jira_args
return M
