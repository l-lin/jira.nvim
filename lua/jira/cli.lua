---Jira CLI execution and command building
---Centralizes debug logging, error handling, and command argument construction

---Build arguments for sprint list query
---@return table args command arguments for jira CLI
local function _build_sprint_list_args()
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
local function _build_issue_open_args(key)
  return { "open", key }
end

---Build arguments for getting current user
---@return table args command arguments
local function _build_me_args()
  return { "me" }
end

---Build arguments for transitioning an issue
---@param key string Issue key
---@param transition string? Transition name (if nil, returns args for listing transitions)
---@return table args command arguments
local function _build_issue_move_args(key, transition)
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
local function _build_issue_assign_args(key, user)
  return { "issue", "assign", key, user }
end

---Build arguments for unassigning an issue
---@param key string Issue key
---@return table args command arguments
local function _build_issue_unassign_args(key)
  return { "issue", "assign", key, "x" }
end

---Build arguments for adding a comment to an issue
---@param key string Issue key
---@param text string Comment text
---@return table args command arguments
local function _build_issue_comment_args(key, text)
  return { "issue", "comment", "add", key, text }
end

---Build arguments for editing issue summary/title
---@param key string Issue key
---@param summary string New summary/title
---@return table args command arguments
local function _build_issue_edit_summary_args(key, summary)
  return { "issue", "edit", key, "--summary", summary, "--no-input" }
end

---Execute a Jira CLI command
---@param args table Command arguments (e.g., {"issue", "edit", key, "--summary", title})
---@param opts table? Options table with:
---   - on_success: function(result) Callback on success
---   - on_error: function(result) Callback on error
---   - success_msg: string|function(result) Success notification message
---   - error_msg: string|function(result) Error notification message
---@return table result The vim.system result object
local function execute(args, opts)
  opts = opts or {}

  local config = require("jira.config").options
  local cmd = { config.cli.cmd }
  vim.list_extend(cmd, args)

  -- Debug logging
  if config.debug then
    vim.notify("JIRA CLI Command:\n" .. table.concat(cmd, " "), vim.log.levels.INFO)
  end

  -- Execute command
  local result = vim.system(cmd, { text = true }):wait()

  -- Handle result
  if result.code == 0 then
    -- Success notification
    if opts.success_msg then
      local msg = type(opts.success_msg) == "function" and opts.success_msg(result) or opts.success_msg
      vim.notify(msg, vim.log.levels.INFO)
    end

    -- Success callback
    if opts.on_success then
      opts.on_success(result)
    end
  else
    -- Error notification
    if opts.error_msg then
      local msg = type(opts.error_msg) == "function" and opts.error_msg(result) or opts.error_msg
      local error_detail = result.stderr or "Unknown error"
      vim.notify(string.format("%s: %s", msg, error_detail), vim.log.levels.ERROR)
    end

    -- Error callback
    if opts.on_error then
      opts.on_error(result)
    end
  end

  return result
end

---Open an issue in browser
---@param key string Issue key
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
---@return table result The vim.system result object
local function open_issue(key, opts)
  return execute(_build_issue_open_args(key), opts)
end

---Get current user
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
---@return table result The vim.system result object
local function get_current_user(opts)
  return execute(_build_me_args(), opts)
end

---Transition issue to a different status
---@param key string Issue key
---@param transition string Transition name
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
---@return table result The vim.system result object
local function transition_issue(key, transition, opts)
  return execute(_build_issue_move_args(key, transition), opts)
end

---Assign issue to a user
---@param key string Issue key
---@param user string Username or account ID
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
---@return table result The vim.system result object
local function assign_issue(key, user, opts)
  return execute(_build_issue_assign_args(key, user), opts)
end

---Unassign issue
---@param key string Issue key
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
---@return table result The vim.system result object
local function unassign_issue(key, opts)
  return execute(_build_issue_unassign_args(key), opts)
end

---Add comment to issue
---@param key string Issue key
---@param text string Comment text
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
---@return table result The vim.system result object
local function comment_issue(key, text, opts)
  return execute(_build_issue_comment_args(key, text), opts)
end

---Edit issue title/summary
---@param key string Issue key
---@param summary string New summary/title
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
---@return table result The vim.system result object
local function edit_issue_title(key, summary, opts)
  return execute(_build_issue_edit_summary_args(key, summary), opts)
end

---Get sprint list arguments (for finders)
---@return table args command arguments for sprint list query
local function get_sprint_list_args()
  return _build_sprint_list_args()
end

local M = {}
M.execute = execute
M.open_issue = open_issue
M.get_current_user = get_current_user
M.transition_issue = transition_issue
M.assign_issue = assign_issue
M.unassign_issue = unassign_issue
M.comment_issue = comment_issue
M.edit_issue_title = edit_issue_title
M.get_sprint_list_args = get_sprint_list_args
return M
