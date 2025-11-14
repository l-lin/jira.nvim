local cli = require("jira.cli")
local git = require("jira.git")
local create_action = require("jira.picker.actions.create_issue")
local start_work_action = require("jira.picker.actions.start_work")
local ui = require("jira.picker.ui")

local CLIPBOARD_REG = "+"
local DEFAULT_REG = '"'

---Clear issue-related caches
---@param issue_key string
local function clear_issue_caches(issue_key)
  local cache = require("jira.cache")
  cache.clear(cache.keys.ISSUE_VIEW, { key = issue_key })
  cache.clear(cache.keys.ISSUES)
  cache.clear(cache.keys.EPIC_ISSUES)
end

---Validates that item has a key
---@param item snacks.picker.Item
---@return boolean valid True if item has key, false otherwise
local function validate_item_key(item)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return false
  end
  return true
end

---Open issue in browser
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_open_browser(picker, item, action)
  if not validate_item_key(item) then
    return
  end

  cli.open_issue(item.key, {
    success_msg = string.format("Opened %s in browser", item.key),
    error_msg = string.format("Failed to open %s", item.key),
  })
end

---View issue in buffer
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_view_in_buffer(picker, item, action)
  if not validate_item_key(item) then
    return
  end

  require("jira.buf").open(item.key)

  if picker then
    picker:close()
  end
end

---Copy issue key to clipboard
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_copy_key(picker, item, action)
  if not validate_item_key(item) then
    return
  end

  vim.fn.setreg(CLIPBOARD_REG, item.key)
  vim.fn.setreg(DEFAULT_REG, item.key)

  vim.notify(string.format("Copied %s to clipboard", item.key), vim.log.levels.INFO)
end

---Get transitions with caching
---@param issue_key string
---@param callback fun(transitions: string[]?)
local function get_transitions_cached(issue_key, callback)
  local cache = require("jira.cache")
  local project_key = issue_key:match("^([^-]+)")

  if not project_key then
    callback(nil)
    return
  end

  local cached = cache.get(cache.keys.TRANSITIONS, { project = project_key })
  if cached and cached.items then
    callback(cached.items)
    return
  end

  cli.get_transitions(issue_key, function(transitions)
    if transitions and #transitions > 0 then
      cache.set(cache.keys.TRANSITIONS, { project = project_key }, transitions)
    end
    callback(transitions)
  end)
end

---Show transition selection UI
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param transitions string[]
local function show_transition_select(picker, item, transitions)
  vim.ui.select(transitions, {
    prompt = "Select transition:",
  }, function(choice)
    if not choice then
      return
    end

    cli.transition_issue(item.key, choice, {
      success_msg = string.format("Transitioned %s to %s", item.key, choice),
      error_msg = string.format("Failed to transition %s", item.key),
      on_success = function()
        clear_issue_caches(item.key)
        picker:refresh()
      end,
    })
  end)
end

---Transition issue to different status
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param _ snacks.picker.Action
local function action_jira_transition(picker, item, _)
  if not validate_item_key(item) then
    return
  end

  get_transitions_cached(item.key, function(transitions)
    if not transitions or #transitions == 0 then
      vim.notify("No transitions available", vim.log.levels.WARN)
      return
    end

    show_transition_select(picker, item, transitions)
  end)
end

---Assign issue to current user
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_assign_me(picker, item, action)
  if not validate_item_key(item) then
    return
  end

  cli.get_current_user({
    error_msg = "Failed to get current user",
    on_success = function(result)
      local me = vim.trim(result.stdout or "")
      cli.assign_issue(item.key, me, {
        success_msg = string.format("Assigned %s to you", item.key),
        error_msg = string.format("Failed to assign %s", item.key),
        on_success = function()
          clear_issue_caches(item.key)
          picker:refresh()
        end,
      })
    end,
  })
end

---Unassign issue
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_unassign(picker, item, action)
  if not validate_item_key(item) then
    return
  end

  cli.unassign_issue(item.key, {
    success_msg = string.format("Unassigned %s", item.key),
    error_msg = string.format("Failed to unassign %s", item.key),
    on_success = function()
      clear_issue_caches(item.key)
      picker:refresh()
    end,
  })
end

---Get sprints with caching
---@param callback fun(sprints: table[]?)
local function get_sprints_cached(callback)
  local cache = require("jira.cache")

  local cached = cache.get(cache.keys.SPRINTS)
  if cached and cached.items then
    callback(cached.items)
    return
  end

  cli.get_sprints(function(sprints)
    if sprints and #sprints > 0 then
      cache.set(cache.keys.SPRINTS, nil, sprints)
    end
    callback(sprints)
  end)
end

---Show sprint selection UI using Snacks picker
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param sprints table[]
local function show_sprint_select(picker, item, sprints)
  require("snacks").picker("source_jira_sprints", {
    sprints = sprints,
    confirm = function(sprint_picker, sprint_item, action)
      if not sprint_item or not sprint_item.sprint then
        return
      end

      local selected_sprint = sprint_item.sprint

      cli.move_issue_to_sprint(item.key, selected_sprint.id, {
        success_msg = string.format("Moved %s to sprint: %s", item.key, selected_sprint.name),
        error_msg = string.format("Failed to move %s to sprint", item.key),
        on_success = function()
          clear_issue_caches(item.key)
          sprint_picker:close()
          if picker then
            picker:focus()
            picker:refresh()
          end
        end,
      })
    end,
  })
end

---Update issue sprint
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param _ snacks.picker.Action
local function action_jira_update_sprint(picker, item, _)
  if not validate_item_key(item) then
    return
  end

  get_sprints_cached(function(sprints)
    if not sprints or #sprints == 0 then
      vim.notify("No active or future sprints available", vim.log.levels.WARN)
      return
    end

    show_sprint_select(picker, item, sprints)
  end)
end

---Submit comment from scratch buffer
---@param issue_key string
---@param win snacks.win
local function submit_comment(issue_key, win)
  local comment = win:text()

  -- Validate non-empty comment
  if not comment or comment:match("^%s*$") then
    vim.notify("Comment cannot be empty", vim.log.levels.WARN)
    return
  end

  cli.comment_issue(issue_key, comment, {
    success_msg = string.format("Added comment to %s", issue_key),
    error_msg = string.format("Failed to comment on %s", issue_key),
    on_success = function()
      local cache = require("jira.cache")
      cache.clear(cache.keys.ISSUE_VIEW, { key = issue_key })
      win:close()
    end,
  })
end

---Add comment to issue
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_add_comment(picker, item, action)
  if not validate_item_key(item) then
    return
  end

  ui.open_markdown_editor({
    title = string.format("Add Comment to %s", item.key),
    height = 15,
    on_submit = function(text, win)
      submit_comment(item.key, win)
    end,
    submit_desc = "Submit comment",
  })
end

---Edit issue title
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_edit_summary(picker, item, action)
  if not validate_item_key(item) then
    return
  end

  local current_title = item.summary or ""

  ui.prompt_summary_input({
    default = current_title,
    skip_unchanged = true,
    on_submit = function(new_title)
      cli.edit_issue_summary(item.key, new_title, {
        success_msg = string.format("Updated summary for %s", item.key),
        error_msg = string.format("Failed to update summary for %s", item.key),
        on_success = function()
          clear_issue_caches(item.key)
          picker:refresh()
        end,
      })
    end,
  })
end

---Submit description from scratch buffer
---@param issue_key string
---@param win snacks.win
---@param picker snacks.Picker
local function submit_description(issue_key, win, picker)
  local description = win:text()

  cli.edit_issue_description(issue_key, description, {
    success_msg = string.format("Updated description for %s", issue_key),
    error_msg = string.format("Failed to update description for %s", issue_key),
    on_success = function()
      local cache = require("jira.cache")
      cache.clear(cache.keys.ISSUE_VIEW, { key = issue_key })
      win:close()
      picker:refresh()
    end,
  })
end

---Edit issue description
---@param picker snacks.Picker
---@paget_issue_description.Item
---@param action snacks.picker.Action
local function action_jira_edit_description(picker, item, action)
  if not validate_item_key(item) then
    return
  end

  cli.get_issue_description(item.key, function(description)
    if not description then
      vim.notify(string.format("Failed to fetch description for %s", item.key), vim.log.levels.ERROR)
      return
    end

    ui.open_markdown_editor({
      title = string.format("Edit Description for %s", item.key),
      template = description,
      on_submit = function(text, win)
        submit_description(item.key, win, picker)
      end,
      submit_desc = "Submit description",
    })
  end)
end

---Refresh picker and clear cache
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_refresh_cache(picker, item, action)
  require("jira.cache").clear()
  picker:refresh()
end

---Define all actions with metadata
---Get available actions for an item
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

    view_in_buffer = {
      name = "View issue in buffer",
      icon = " ",
      priority = 98,
      action = action_jira_view_in_buffer,
    },

    start_work = {
      name = "Start work on issue",
      icon = " ",
      priority = 95,
      action = start_work_action.action_jira_start_work,
    },

    copy_key = {
      name = "Copy / Yank issue key to clipboard",
      icon = " ",
      priority = 90,
      action = action_jira_copy_key,
    },

    transition = {
      name = "Edit issue status / Transition",
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

    create = {
      name = "Create issue",
      icon = " ",
      priority = 55,
      action = create_action.action_jira_create,
    },

    update_sprint = {
      name = "Move issue to sprint",
      icon = " ",
      priority = 50,
      action = action_jira_update_sprint,
    },

    edit_summary = {
      name = "Edit summary/title",
      icon = "󰏫 ",
      priority = 40,
      action = action_jira_edit_summary,
    },

    edit_description = {
      name = "Edit description",
      icon = " ",
      priority = 30,
      action = action_jira_edit_description,
    },

    comment = {
      name = "Add comment to issue",
      icon = " ",
      priority = 20,
      action = action_jira_add_comment,
    },

    refresh = {
      name = "Refresh",
      icon = " ",
      priority = 10,
      action = action_jira_refresh_cache,
    },
  }
end

---Action to show action dialog
---@param picker? snacks.Picker
---@param item snacks.picker.Item
---@param action? snacks.picker.Action
local function action_jira_list_actions(picker, item, action)
  require("snacks").picker("source_jira_actions", {
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

---Start work on issue (standalone function for command use)
---@param issue_key string
local function start_work_on_issue(issue_key)
  start_work_action.action_jira_start_work(nil, { key = issue_key }, nil)
end

local M = {}
M.get_jira_actions = get_jira_actions
M.start_work_on_issue = start_work_on_issue
M.get_sprints_cached = get_sprints_cached

M.action_jira_list_actions = action_jira_list_actions
M.action_jira_open_browser = action_jira_open_browser
M.action_jira_view_in_buffer = action_jira_view_in_buffer
M.action_jira_copy_key = action_jira_copy_key
M.action_jira_transition = action_jira_transition
M.action_jira_assign_me = action_jira_assign_me
M.action_jira_unassign = action_jira_unassign
M.action_jira_update_sprint = action_jira_update_sprint
M.action_jira_add_comment = action_jira_add_comment
M.action_jira_refresh_cache = action_jira_refresh_cache
M.action_jira_create = create_action.action_jira_create
M.action_jira_start_work = start_work_action.action_jira_start_work
return M
