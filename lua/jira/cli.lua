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
---@param transition string Transition name (if nil, returns args for listing transitions)
---@return table args command arguments
local function _build_issue_move_args(key, transition)
  return { "issue", "move", key, transition }
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

---Execute a Jira CLI command asynchronously
---@param args table Command arguments (e.g., {"issue", "edit", key, "--summary", title})
---@param opts table? Options table with:
---   - on_success: function(result) Callback on success
---   - on_error: function(result) Callback on error
---   - success_msg: string|function(result) Success notification message
---   - error_msg: string|function(result) Error notification message
---   - progress_msg: string Optional progress notification shown before execution
local function execute(args, opts)
  opts = opts or {}

  local config = require("jira.config").options
  local cmd = { config.cli.cmd }
  vim.list_extend(cmd, args)

  -- Debug logging
  if config.debug then
    vim.notify("JIRA CLI Command:\n" .. table.concat(cmd, " "), vim.log.levels.INFO)
  end

  -- Show progress notification
  if opts.progress_msg then
    vim.notify(opts.progress_msg, vim.log.levels.INFO)
  end

  -- Execute command asynchronously
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
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
    end)
  end)
end

---Open an issue in browser
---@param key string Issue key
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
local function open_issue(key, opts)
  execute(_build_issue_open_args(key), opts)
end

---Get current user
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
local function get_current_user(opts)
  execute(_build_me_args(), opts)
end

---Transition issue to a different status
---@param key string Issue key
---@param transition string Transition name
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
local function transition_issue(key, transition, opts)
  execute(_build_issue_move_args(key, transition), opts)
end

---Assign issue to a user
---@param key string Issue key
---@param user string Username or account ID
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
local function assign_issue(key, user, opts)
  execute(_build_issue_assign_args(key, user), opts)
end

---Unassign issue
---@param key string Issue key
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
local function unassign_issue(key, opts)
  execute(_build_issue_unassign_args(key), opts)
end

---Add comment to issue
---@param key string Issue key
---@param text string Comment text
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
local function comment_issue(key, text, opts)
  execute(_build_issue_comment_args(key, text), opts)
end

---Edit issue title/summary
---@param key string Issue key
---@param summary string New summary/title
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
local function edit_issue_title(key, summary, opts)
  execute(_build_issue_edit_summary_args(key, summary), opts)
end

---Get available transitions for an issue
---@param issue_key string
---@param callback fun(transitions: string[]?)
local function get_transitions(issue_key, callback)
  local config = require("jira.config").options

  -- Note: jira-cli doesn't provide a non-interactive way to list transitions,
  -- so we scrape the interactive prompt output by spawning the command,
  -- capturing stdout, then killing it before it waits for user input
  local stdout_chunks = {}
  local job_id = vim.fn.jobstart({ config.cli.cmd, "issue", "move", issue_key }, {
    stdout_buffered = false,
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(stdout_chunks, line)
        end
      end
    end,
    on_exit = function(_, code, _)
      -- Process terminated, parse output
      local output = table.concat(stdout_chunks, "\n")

      -- Parse transitions from the interactive prompt
      -- Format: "  State Name" or "> State Name" (for selected)
      local transitions = {}
      for line in output:gmatch("[^\r\n]+") do
        -- Strip ANSI escape codes
        local cleaned = line:gsub("\27%[[%d;]*m", "")
        -- Match lines that start with spaces or >
        local state = cleaned:match("^%s+(.+)$") or cleaned:match("^>%s*(.+)$")
        if state and state ~= "" then
          -- Trim whitespace
          state = state:match("^%s*(.-)%s*$")
          if state ~= "" then
            table.insert(transitions, state)
          end
        end
      end

      callback(#transitions > 0 and transitions or nil)
    end,
  })

  if job_id <= 0 then
    callback(nil)
    return
  end

  -- Give it a moment to output the prompt, then kill it
  vim.defer_fn(function()
    vim.fn.jobstop(job_id)
  end, 500)
end

---Get sprint list arguments (for finders)
---@return table args command arguments for sprint list query
local function get_sprint_list_args()
  return _build_sprint_list_args()
end

local M = {}
M.execute = execute
M.get_sprint_list_args = get_sprint_list_args

-- Execute actions
M.open_issue = open_issue
M.get_current_user = get_current_user
M.transition_issue = transition_issue
M.assign_issue = assign_issue
M.unassign_issue = unassign_issue
M.comment_issue = comment_issue
M.edit_issue_title = edit_issue_title
M.get_transitions = get_transitions
return M
