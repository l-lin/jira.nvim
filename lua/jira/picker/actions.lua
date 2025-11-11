local cli = require("jira.cli")
local api = require("jira.api")

--- Open issue in browser
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_open_browser(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  cli.execute(api.build_issue_open_args(item.key), {
    success_msg = string.format("Opened %s in browser", item.key),
    error_msg = string.format("Failed to open %s", item.key),
  })
end

--- Copy issue key to clipboard
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_copy_key(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  -- Copy to system clipboard
  vim.fn.setreg("+", item.key)

  -- Also copy to unnamed register
  vim.fn.setreg('"', item.key)

  vim.notify(string.format("Copied %s to clipboard", item.key), vim.log.levels.INFO)
end

--- Get available transitions for an issue
---@param issue_key string
---@param callback fun(transitions: string[]?)
local function get_transitions(issue_key, callback)
  local config = require("jira.config").options

  -- Spawn jira move command which shows interactive prompt with transitions
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

      -- Strip all ANSI escape codes
      local function strip_ansi(str)
        -- Remove ANSI escape sequences: ESC [ ... m
        return str:gsub("\27%[[%d;]*m", "")
      end

      -- Parse transitions from the interactive prompt
      -- Format: "  State Name" or "> State Name" (for selected)
      local transitions = {}
      for line in output:gmatch("[^\r\n]+") do
        local cleaned = strip_ansi(line)
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

--- Transition issue to different status
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_transition(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  -- Get available transitions dynamically
  get_transitions(item.key, function(transitions)
    if not transitions then
      vim.notify("Failed to fetch transitions", vim.log.levels.ERROR)
      return
    end

    if #transitions == 0 then
      vim.notify("No transitions available", vim.log.levels.INFO)
      return
    end

    vim.ui.select(transitions, {
      prompt = "Select transition:",
    }, function(choice)
      if not choice then
        return
      end

      -- Execute transition
      cli.execute(api.build_issue_move_args(item.key, choice), {
        success_msg = string.format("Transitioned %s to %s", item.key, choice),
        error_msg = string.format("Failed to transition %s", item.key),
        on_success = function()
          picker:refresh()
        end,
      })
    end)
  end)
end

--- Assign issue to current user
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_assign_me(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  -- First get current user
  local me_result = cli.execute(api.build_me_args(), {
    error_msg = "Failed to get current user",
  })

  if me_result.code ~= 0 then
    return
  end

  local me = vim.trim(me_result.stdout)

  cli.execute(api.build_issue_assign_args(item.key, me), {
    success_msg = string.format("Assigned %s to you", item.key),
    error_msg = string.format("Failed to assign %s", item.key),
    on_success = function()
      picker:refresh()
    end,
  })
end

--- Unassign issue
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_unassign(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  cli.execute(api.build_issue_unassign_args(item.key), {
    success_msg = string.format("Unassigned %s", item.key),
    error_msg = string.format("Failed to unassign %s", item.key),
    on_success = function()
      picker:refresh()
    end,
  })
end

--- Submit comment from scratch buffer
---@param issue_key string
---@param win snacks.win
local function submit_comment(issue_key, win)
  local comment = win:text()

  -- Validate non-empty comment
  if not comment or comment:match("^%s*$") then
    vim.notify("Comment cannot be empty", vim.log.levels.WARN)
    return
  end

  cli.execute(api.build_issue_comment_args(issue_key, comment), {
    success_msg = string.format("Added comment to %s", issue_key),
    error_msg = string.format("Failed to comment on %s", issue_key),
    on_success = function()
      win:close()
    end,
  })
end

--- Add comment to issue
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_add_comment(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  Snacks.scratch({
    ft = "markdown",
    name = string.format("Comment on %s", item.key),
    template = "",
    win = {
      relative = "editor",
      width = 80,
      height = 15,
      title = string.format(" Add Comment to %s ", item.key),
      title_pos = "center",
      border = "rounded",
      keys = {
        submit = {
          "<c-s>",
          function(win)
            submit_comment(item.key, win)
          end,
          desc = "Submit comment",
          mode = { "n", "i" },
        },
      },
      on_win = function()
        vim.schedule(function()
          vim.cmd.startinsert()
        end)
      end,
    },
  })
end

--- Edit issue title
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_edit_title(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  local current_title = item.summary or ""

  vim.ui.input({ prompt = "Edit title: ", default = current_title }, function(new_title)
    if not new_title or new_title == "" then
      return
    end

    -- Skip if title unchanged
    if new_title == current_title then
      return
    end

    cli.execute(api.build_issue_edit_summary_args(item.key, new_title), {
      success_msg = string.format("Updated title for %s", item.key),
      error_msg = string.format("Failed to update title for %s", item.key),
      on_success = function()
        picker:refresh()
      end,
    })
  end)
end

--- Define all actions with metadata
--- Get available actions for an item
---@param item snacks.picker.Item
---@param ctx table?
---@return table<string, table> actions Map of action name to action metadata
local function get_jira_actions(item, ctx)
  return {
    open_browser = {
      name = "Open issue in browser",
      icon = " ",
      priority = 100,
      action = action_jira_open_browser,
    },

    copy_key = {
      name = "Copy issue key to clipboard",
      icon = " ",
      priority = 90,
      action = action_jira_copy_key,
    },

    transition = {
      name = "Edit status / Move issue",
      icon = " ",
      priority = 80,
      action = action_jira_transition,
    },

    assign_me = {
      name = "Assign issue to me",
      icon = " ",
      priority = 70,
      action = action_jira_assign_me,
    },

    unassign = {
      name = "Unassign issue",
      icon = " ",
      priority = 60,
      action = action_jira_unassign,
    },

    edit_title = {
      name = "Edit title",
      icon = "󰏫 ",
      priority = 55,
      action = action_jira_edit_title,
    },

    comment = {
      name = "Add comment to issue",
      icon = " ",
      priority = 50,
      action = action_jira_add_comment,
    },
  }
end

--- Action to show action dialog
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_list_actions(picker, item, action)
  local Snacks = require("snacks")
  Snacks.picker.source_jira_actions({
    item = item,
    confirm = function(action_picker, action_item, selected_action)
      if not action_item then
        return
      end

      -- Focus parent picker
      if picker then
        picker:focus()
      end

      -- Execute the action
      if action_item.action and action_item.action.action then
        action_item.action.action(picker, item, selected_action)
      end

      -- Close action dialog
      action_picker:close()
    end,
  })
end

local M = {}
M.get_jira_actions = get_jira_actions

M.action_jira_list_actions = action_jira_list_actions
M.action_jira_open_browser = action_jira_open_browser
M.action_jira_copy_key = action_jira_copy_key
M.action_jira_transition = action_jira_transition
M.action_jira_assign_me = action_jira_assign_me
M.action_jira_unassign = action_jira_unassign
M.action_jira_add_comment = action_jira_add_comment
return M
