---Jira CLI execution and command building
---Centralizes debug logging, error handling, and command argument construction

local UNASSIGN_USER = "x" -- Special value used by jira-cli to unassign

--
-- BUILD ARGUMENT FUNCTIONS
--

---Build arguments for sprint list query
---@return table args command arguments for jira CLI
local function _build_sprint_list_args()
  local util = require("jira.util")
  local config = require("jira.config").options

  if not util.has_jira_cli() then
    error("JIRA CLI not found. Please install: https://github.com/ankitpokhrel/jira-cli")
  end

  local args = vim.deepcopy(config.query.args)

  vim.list_extend(args, config.query.filters)
  vim.list_extend(args, { "--order-by", config.query.order_by })
  vim.list_extend(args, { "--csv", "--columns", table.concat(config.query.columns, ",") })

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
---@param transition string Transition name
---@return table args command arguments
local function _build_issue_transition_args(key, transition)
  return { "issue", "transition", key, transition }
end

---Build arguments for listing available transitions (interactive prompt)
---@param key string Issue key
---@return table args command arguments
local function _build_issue_list_transitions_args(key)
  return { "issue", "transition", key }
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
  return { "issue", "assign", key, UNASSIGN_USER }
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

---Build arguments for editing issue description
---@param key string Issue key
---@return table args command arguments
local function _build_issue_edit_description_args(key)
  return { "issue", "edit", key, "--no-input" }
end

---Build arguments for viewing an issue
---@param key string Issue key
---@param comments_count number Number of comments to include
---@return table args command arguments
local function _build_issue_view_args(key, comments_count)
  return { "issue", "view", key, "--plain", "--comments", tostring(comments_count) }
end

---Build arguments for getting issue in raw format (for description)
---@param key string Issue key
---@return table args command arguments
local function _build_issue_view_raw_args(key)
  return { "issue", "view", key, "--raw" }
end

--
-- EXECUTION FUNCTIONS
--

---Execute a Jira CLI command asynchronously
---@param args table Command arguments (e.g., {"issue", "edit", key, "--summary", title})
---@param opts table? Options table with:
---   - on_success: function(result) Callback on success
---   - on_error: function(result) Callback on error
---   - success_msg: string|function(result) Success notification message
---   - error_msg: string|function(result) Error notification message
---   - progress_msg: string Optional progress notification shown before execution
---   - stdin: string Optional stdin input for the command
local function execute(args, opts)
  vim.validate({
    args = { args, "table" },
    opts = { opts, "table", true },
  })

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

  -- Prepare system options
  local system_opts = { text = true }
  if opts.stdin then
    system_opts.stdin = opts.stdin
  end

  -- Execute command asynchronously
  -- Note: vim.schedule() ensures UI updates happen on main loop
  vim.system(cmd, system_opts, function(result)
    vim.schedule(function()
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
  execute(_build_issue_transition_args(key, transition), opts)
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
local function edit_issue_summary(key, summary, opts)
  execute(_build_issue_edit_summary_args(key, summary), opts)
end

---Get issue view (formatted output for preview)
---@param key string Issue key
---@param comments_count number Number of comments to include
---@param callback fun(result: table) Callback with vim.system result
local function view_issue(key, comments_count, callback)
  local config = require("jira.config").options
  local cmd = { config.cli.cmd }
  vim.list_extend(cmd, _build_issue_view_args(key, comments_count))

  -- Execute command asynchronously
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      callback(result)
    end)
  end)
end

---Get issue description
---@param key string Issue key
---@param callback fun(description: string?) Callback with description or nil on error
local function view_issue_description(key, callback)
  local config = require("jira.config").options
  local cmd = { config.cli.cmd }
  vim.list_extend(cmd, _build_issue_view_raw_args(key))

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil)
        return
      end

      -- Parse JSON to extract description
      local ok, data = pcall(vim.json.decode, result.stdout)
      if not ok or not data or not data.fields then
        callback(nil)
        return
      end

      local description = data.fields.description

      -- Handle ADF (Atlassian Document Format) - description is a table
      if type(description) == "table" then
        -- Extract plain text from ADF for editing
        local markdown = require("jira.markdown")
        description = markdown.adf_to_markdown(description)
      elseif type(description) ~= "string" then
        description = ""
      end

      callback(description or "")
    end)
  end)
end

---Edit issue description
---@param key string Issue key
---@param description string New description
---@param opts table? Options table with callbacks and messages
local function edit_issue_description(key, description, opts)
  opts = opts or {}
  opts.stdin = description
  execute(_build_issue_edit_description_args(key), opts)
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
  local cmd = { config.cli.cmd }
  vim.list_extend(cmd, _build_issue_list_transitions_args(issue_key))
  local job_id = vim.fn.jobstart(cmd, {
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
M.edit_issue_summary = edit_issue_summary
M.view_issue = view_issue
M.view_issue_description = view_issue_description
M.edit_issue_description = edit_issue_description
M.get_transitions = get_transitions
return M
