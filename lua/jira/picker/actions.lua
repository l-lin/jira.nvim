local M = {}

--- All available actions with metadata
M.actions = {}

--- Open issue in browser
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function jira_open_browser(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  local config = require("jira.config").options
  local cmd = { config.cli.cmd, "open", item.key }

  if config.debug then
    vim.notify("JIRA CLI Command:\n" .. table.concat(cmd, " "), vim.log.levels.INFO)
  end

  local result = vim.system(cmd, { text = true }):wait()

  if result.code == 0 then
    vim.notify(string.format("Opened %s in browser", item.key), vim.log.levels.INFO)
  else
    vim.notify(string.format("Failed to open %s: %s", item.key, result.stderr or "Unknown error"), vim.log.levels.ERROR)
  end
end

--- Copy issue key to clipboard
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function jira_copy_key(picker, item, action)
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

--- Transition issue to different status
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function jira_transition(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  local config = require("jira.config").options

  -- Common JIRA transitions - can be customized via config
  local transitions = {
    "To Do",
    "In Progress",
    "In Review",
    "Done",
    "Blocked",
    "Backlog",
    "Ready for QA",
    "QA",
    "Closed",
  }

  vim.ui.select(transitions, {
    prompt = "Select transition:",
  }, function(choice)
    if not choice then
      return
    end

    -- Execute transition
    local move_cmd = { config.cli.cmd, "issue", "move", item.key, choice }

    if config.debug then
      vim.notify("JIRA CLI Command:\n" .. table.concat(move_cmd, " "), vim.log.levels.INFO)
    end

    local transition_result = vim.system(move_cmd, { text = true }):wait()

    if transition_result.code == 0 then
      vim.notify(string.format("Transitioned %s to %s", item.key, choice), vim.log.levels.INFO)
      picker:refresh()
    else
      vim.notify(
        string.format("Failed to transition %s: %s", item.key, transition_result.stderr or "Unknown error"),
        vim.log.levels.ERROR
      )
    end
  end)
end

--- Assign issue to current user
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function jira_assign_me(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  local config = require("jira.config").options

  -- First get current user
  local me_result = vim.system({ config.cli.cmd, "me" }, { text = true }):wait()

  if me_result.code ~= 0 then
    vim.notify("Failed to get current user", vim.log.levels.ERROR)
    return
  end

  local me = vim.trim(me_result.stdout)
  local cmd = { config.cli.cmd, "issue", "assign", item.key, me }

  if config.debug then
    vim.notify("JIRA CLI Command:\n" .. table.concat(cmd, " "), vim.log.levels.INFO)
  end

  local result = vim.system(cmd, { text = true }):wait()

  if result.code == 0 then
    vim.notify(string.format("Assigned %s to you", item.key), vim.log.levels.INFO)
    picker:refresh()
  else
    vim.notify(string.format("Failed to assign %s: %s", item.key, result.stderr or "Unknown error"), vim.log.levels.ERROR)
  end
end

--- Unassign issue
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function jira_unassign(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  local config = require("jira.config").options
  local cmd = { config.cli.cmd, "issue", "assign", item.key, "x" }

  if config.debug then
    vim.notify("JIRA CLI Command:\n" .. table.concat(cmd, " "), vim.log.levels.INFO)
  end

  local result = vim.system(cmd, { text = true }):wait()

  if result.code == 0 then
    vim.notify(string.format("Unassigned %s", item.key), vim.log.levels.INFO)
    picker:refresh()
  else
    vim.notify(string.format("Failed to unassign %s: %s", item.key, result.stderr or "Unknown error"), vim.log.levels.ERROR)
  end
end

--- Add comment to issue
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function jira_comment(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "Comment: " }, function(comment)
    if not comment or comment == "" then
      return
    end

    local config = require("jira.config").options
    local cmd = { config.cli.cmd, "issue", "comment", "add", item.key, comment }

    if config.debug then
      vim.notify("JIRA CLI Command:\n" .. table.concat(cmd, " "), vim.log.levels.INFO)
    end

    local result = vim.system(cmd, { text = true }):wait()

    if result.code == 0 then
      vim.notify(string.format("Added comment to %s", item.key), vim.log.levels.INFO)
    else
      vim.notify(
        string.format("Failed to comment on %s: %s", item.key, result.stderr or "Unknown error"),
        vim.log.levels.ERROR
      )
    end
  end)
end

--- Define all actions with metadata
M.actions.open_browser = {
  name = "Open in browser",
  desc = "Open issue in browser",
  icon = "🌐",
  priority = 100,
  action = jira_open_browser,
}

M.actions.copy_key = {
  name = "Copy key",
  desc = "Copy issue key to clipboard",
  icon = "📋",
  priority = 90,
  action = jira_copy_key,
}

M.actions.transition = {
  name = "Move status",
  desc = "Transition issue to different status",
  icon = "🔄",
  priority = 80,
  action = jira_transition,
}

M.actions.assign_me = {
  name = "Assign to me",
  desc = "Assign issue to current user",
  icon = "👤",
  priority = 70,
  action = jira_assign_me,
}

M.actions.unassign = {
  name = "Unassign",
  desc = "Remove assignee from issue",
  icon = "👥",
  priority = 60,
  action = jira_unassign,
}

M.actions.comment = {
  name = "Comment",
  desc = "Add comment to issue",
  icon = "💬",
  priority = 50,
  action = jira_comment,
}

--- Get available actions for an item
---@param item snacks.picker.Item
---@param ctx table?
---@return table<string, table> actions Map of action name to action metadata
function M.get_actions(item, ctx)
  return M.actions
end

--- Perform selected action
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
function M.jira_perform_action(picker, item, action)
  if action.action and type(action.action) == "function" then
    action.action(picker, item, action)
  end
end

--- Action to show action dialog
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
function M.jira_actions(picker, item, action)
  local Snacks = require("snacks")
  Snacks.picker.jira_actions({
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

-- Backward compatibility: export individual action functions
M.jira_open_browser = jira_open_browser
M.jira_copy_key = jira_copy_key
M.jira_transition = jira_transition

return M
