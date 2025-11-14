---Jira CLI execution and command building
---Centralizes debug logging, error handling, and command argument construction

local UNASSIGN_USER = "x" -- Special value used by jira-cli to unassign

local M = {}

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

  local args = vim.deepcopy(config.cli.issues.args)

  vim.list_extend(args, config.cli.issues.filters)
  vim.list_extend(args, { "--order-by", config.cli.issues.order_by })
  vim.list_extend(args, { "--csv", "--columns", table.concat(config.cli.issues.columns, ",") })

  if config.debug then
    local cmd_str = config.cli.cmd .. " " .. table.concat(args, " ")
    vim.notify("JIRA CLI Command:\n" .. cmd_str, vim.log.levels.INFO)
  end

  return args
end

---Build arguments for epic list query
---@return table args command arguments for jira CLI
local function _build_epic_list_args()
  local util = require("jira.util")
  local config = require("jira.config").options

  if not util.has_jira_cli() then
    error("JIRA CLI not found. Please install: https://github.com/ankitpokhrel/jira-cli")
  end

  local args = vim.deepcopy(config.cli.epics.args)

  vim.list_extend(args, config.cli.epics.filters)
  vim.list_extend(args, { "--order-by", config.cli.epics.order_by })
  vim.list_extend(args, { "--csv", "--columns", table.concat(config.cli.epics.columns, ",") })

  if config.debug then
    local cmd_str = config.cli.cmd .. " " .. table.concat(args, " ")
    vim.notify("JIRA CLI Command:\n" .. cmd_str, vim.log.levels.INFO)
  end

  return args
end

---Build arguments for epic issues query
---@param epic_key string Epic key (e.g., "PROJ-123")
---@return table args command arguments for jira CLI
local function _build_epic_issues_args(epic_key)
  local util = require("jira.util")
  local config = require("jira.config").options

  if not util.has_jira_cli() then
    error("JIRA CLI not found. Please install: https://github.com/ankitpokhrel/jira-cli")
  end

  local args = vim.deepcopy(config.cli.epic_issues.args)

  vim.list_extend(args, { "--parent", epic_key })
  vim.list_extend(args, config.cli.epic_issues.filters)
  vim.list_extend(args, { "--order-by", config.cli.epic_issues.order_by })
  vim.list_extend(args, { "--csv", "--columns", table.concat(config.cli.epic_issues.columns, ",") })

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

---Build arguments for listing sprints
---@return table args command arguments
local function _build_sprint_list_for_selection_args()
  return { "sprint", "list", "--table", "--plain", "--columns", "id,name,state", "--state", "active,future", "--no-headers" }
end

---Build arguments for moving issue to sprint
---@param sprint_id string Sprint ID
---@param issue_key string Issue key
---@return table args command arguments
local function _build_sprint_add_issue_args(sprint_id, issue_key)
  return { "sprint", "add", sprint_id, issue_key }
end

---Build arguments for listing available issue types (interactive prompt)
---@return table args command arguments
local function _build_issue_list_issue_types_args()
  return { "issue", "create" }
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
function M.execute(args, opts)
  vim.validate({
    args = { args, "table" },
    opts = { opts, "table", true },
  })

  opts = opts or {}

  local config = require("jira.config").options
  local cmd = { config.cli.cmd }
  vim.list_extend(cmd, args)

  if config.debug then
    vim.notify("JIRA CLI Command:\n" .. table.concat(cmd, " "), vim.log.levels.INFO)
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
function M.open_issue(key, opts)
  M.execute(_build_issue_open_args(key), opts)
end

---Get current user
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
function M.get_current_user(opts)
  M.execute(_build_me_args(), opts)
end

---Transition issue to a different status
---@param key string Issue key
---@param transition string Transition name
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
function M.transition_issue(key, transition, opts)
  M.execute(_build_issue_transition_args(key, transition), opts)
end

---Assign issue to a user
---@param key string Issue key
---@param user string Username or account ID
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
function M.assign_issue(key, user, opts)
  M.execute(_build_issue_assign_args(key, user), opts)
end

---Unassign issue
---@param key string Issue key
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
function M.unassign_issue(key, opts)
  M.execute(_build_issue_unassign_args(key), opts)
end

---Add comment to issue
---@param key string Issue key
---@param text string Comment text
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
function M.comment_issue(key, text, opts)
  M.execute(_build_issue_comment_args(key, text), opts)
end

---Edit issue title/summary
---@param key string Issue key
---@param summary string New summary/title
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
function M.edit_issue_summary(key, summary, opts)
  M.execute(_build_issue_edit_summary_args(key, summary), opts)
end

---Get issue view (formatted output for preview)
---@param key string Issue key
---@param comments_count number Number of comments to include
---@param callback fun(result: table) Callback with vim.system result
function M.view_issue(key, comments_count, callback)
  local config = require("jira.config").options
  local cmd = { config.cli.cmd }
  vim.list_extend(cmd, _build_issue_view_args(key, comments_count))

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      callback(result)
    end)
  end)
end

---Get issue description
---@param key string Issue key
---@param callback fun(description: string?) Callback with description or nil on error
function M.get_issue_description(key, callback)
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
function M.edit_issue_description(key, description, opts)
  opts = opts or {}
  opts.stdin = description
  M.execute(_build_issue_edit_description_args(key), opts)
end

---Scrape interactive prompt options from jira-cli
---@param args table CLI arguments
---@param callback fun(options: string[]?)
local function _get_interactive_options(args, callback)
  local config = require("jira.config").options

  local stdout_chunks = {}
  local cmd = { config.cli.cmd }
  vim.list_extend(cmd, args)
  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    pty = true,
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(stdout_chunks, line)
        end
      end
    end,
    on_exit = function()
      local output = table.concat(stdout_chunks, "\n")

      -- Parse options from interactive prompt
      -- Format: "  Option Name" or "> Option Name" (for selected)
      local seen = {}
      local options = {}
      for line in output:gmatch("[^\r\n]+") do
        -- Strip ANSI escape codes
        local cleaned = line:gsub("\27%[[%d;]*m", "")
        -- Match lines that start with spaces or >
        local option = cleaned:match("^%s+(.+)$") or cleaned:match("^>%s*(.+)$")
        if option and option ~= "" then
          -- Trim whitespace
          option = option:match("^%s*(.-)%s*$")
          if option ~= "" and not seen[option] then
            seen[option] = true
            table.insert(options, option)
          end
        end
      end

      callback(#options > 0 and options or nil)
    end,
  })

  if job_id <= 0 then
    callback(nil)
    return
  end

  -- Wait for prompt to render, then scroll through all options
  vim.defer_fn(function()
    for _ = 1, 20 do
      vim.fn.chansend(job_id, "\27[B") -- Down arrow
    end
    -- Give it time to render, then kill
    vim.defer_fn(function()
      vim.fn.jobstop(job_id)
    end, 200)
  end, 300)
end

---Get available transitions for an issue
---@param issue_key string
---@param callback fun(transitions: string[]?)
function M.get_transitions(issue_key, callback)
  _get_interactive_options(_build_issue_list_transitions_args(issue_key), callback)
end

---Get available sprints
---@param callback fun(sprints: table[]?) Callback with array of {id, name, state} or nil on error
function M.get_sprints(callback)
  local config = require("jira.config").options
  local cmd = { config.cli.cmd }
  vim.list_extend(cmd, _build_sprint_list_for_selection_args())

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil)
        return
      end

      -- Parse TSV output: ID\tNAME\tSTATE
      local sprints = {}
      for line in result.stdout:gmatch("[^\r\n]+") do
        local id, name, state = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)$")
        if id and name and state then
          table.insert(sprints, {
            id = vim.trim(id),
            name = vim.trim(name),
            state = vim.trim(state),
            display = string.format("%s [%s]", vim.trim(name), vim.trim(state)),
          })
        end
      end

      callback(#sprints > 0 and sprints or nil)
    end)
  end)
end

---Move issue to sprint
---@param issue_key string Issue key
---@param sprint_id string Sprint ID
---@param opts table? Options for execute (success_msg, error_msg, callbacks)
function M.move_issue_to_sprint(issue_key, sprint_id, opts)
  M.execute(_build_sprint_add_issue_args(sprint_id, issue_key), opts)
end

---Build args for creating issue
---@param issue_type string Type (Bug, Story, Task, Epic, etc.)
---@param summary string Issue title
---@param description string? Issue description (optional)
---@param parent_key string? Parent epic key (optional)
---@return table args CLI arguments
local function _build_issue_create_args(issue_type, summary, description, parent_key)
  local args = { "issue", "create", "-t", issue_type, "-s", summary, "--no-input" }

  if description and description ~= "" then
    table.insert(args, "-b")
    table.insert(args, description)
  end

  if parent_key and parent_key ~= "" then
    table.insert(args, "-P")
    table.insert(args, parent_key)
  end

  return args
end

---Create a new issue
---@param issue_type string
---@param summary string
---@param description string?
---@param parent_key string?
---@param opts table Options with on_success callback receiving (result, issue_key)
function M.create_issue(issue_type, summary, description, parent_key, opts)
  local args = _build_issue_create_args(issue_type, summary, description, parent_key)

  -- Wrap on_success to parse issue key from output
  local original_on_success = opts.on_success
  opts.on_success = function(result, _)
    -- Parse issue key from output (format: "Issue created: PROJ-123" or JSON with --raw)
    local issue_key = result.stdout:match("([A-Z]+-[0-9]+)")

    if issue_key and original_on_success then
      original_on_success(result, issue_key)
    elseif not issue_key then
      vim.notify("Failed to parse created issue key", vim.log.levels.ERROR)
    end
  end

  M.execute(args, opts)
end

---Get sprint list arguments (for finders)
---@return table args command arguments for sprint list query
function M.get_sprint_list_args()
  return _build_sprint_list_args()
end

---Get epic list arguments (for finders)
---@return table args command arguments for epic list query
function M.get_epic_list_args()
  return _build_epic_list_args()
end

---Get epic issues arguments (for finders)
---@param epic_key string Epic key (e.g., "PROJ-123")
---@return table args command arguments for epic issues query
function M.get_epic_issues_args(epic_key)
  return _build_epic_issues_args(epic_key)
end

---Get available issue types
---@param callback fun(issue_types: string[]?)
function M.get_issue_types(callback)
  _get_interactive_options(_build_issue_list_issue_types_args(), callback)
end

return M
