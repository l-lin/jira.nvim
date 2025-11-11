---Build arguments for sprint list query
---@return table args command arguments for jira CLI
local function build_sprint_list_args()
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
  local order_by = config.query.order_by
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

---Build arguments for opening an issue in browser
---@param key string Issue key (e.g., "PROJ-123")
---@return table args command arguments
local function build_issue_open_args(key)
  return { "open", key }
end

---Build arguments for getting current user
---@return table args command arguments
local function build_me_args()
  return { "me" }
end

---Build arguments for transitioning an issue
---@param key string Issue key
---@param transition string? Transition name (if nil, returns args for listing transitions)
---@return table args command arguments
local function build_issue_move_args(key, transition)
  if transition then
    return { "issue", "move", key, transition }
  else
    return { "issue", "move", key }
  end
end

---Build arguments for assigning an issue to a user
---@param key string Issue key
---@param user string Username or account ID
---@return table args command arguments
local function build_issue_assign_args(key, user)
  return { "issue", "assign", key, user }
end

---Build arguments for unassigning an issue
---@param key string Issue key
---@return table args command arguments
local function build_issue_unassign_args(key)
  return { "issue", "assign", key, "x" }
end

---Build arguments for adding a comment to an issue
---@param key string Issue key
---@param text string Comment text
---@return table args command arguments
local function build_issue_comment_args(key, text)
  return { "issue", "comment", "add", key, text }
end

---Build arguments for editing issue summary/title
---@param key string Issue key
---@param summary string New summary/title
---@return table args command arguments
local function build_issue_edit_summary_args(key, summary)
  return { "issue", "edit", key, "--summary", summary, "--no-input" }
end

local M = {}
M.build_sprint_list_args = build_sprint_list_args
M.build_issue_open_args = build_issue_open_args
M.build_me_args = build_me_args
M.build_issue_move_args = build_issue_move_args
M.build_issue_assign_args = build_issue_assign_args
M.build_issue_unassign_args = build_issue_unassign_args
M.build_issue_comment_args = build_issue_comment_args
M.build_issue_edit_summary_args = build_issue_edit_summary_args
return M
