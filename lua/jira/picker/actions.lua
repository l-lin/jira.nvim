local cli = require("jira.cli")

local CLIPBOARD_REG = "+"
local DEFAULT_REG = '"'

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
          local cache = require("jira.cache")
          cache.clear(cache.keys.ISSUE_VIEW, { key = item.key })
          cache.clear(cache.keys.ISSUES)
          cache.clear(cache.keys.EPIC_ISSUES)
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
          local cache = require("jira.cache")
          cache.clear(cache.keys.ISSUE_VIEW, { key = item.key })
          cache.clear(cache.keys.ISSUES)
          cache.clear(cache.keys.EPIC_ISSUES)
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
      local cache = require("jira.cache")
      cache.clear(cache.keys.ISSUE_VIEW, { key = item.key })
      cache.clear(cache.keys.ISSUES)
      cache.clear(cache.keys.EPIC_ISSUES)
      picker:refresh()
    end,
  })
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

  Snacks.scratch({
    ft = "markdown",
    name = string.format("Comment on %s", item.key),
    template = "",
    win = {
      relative = "editor",
      width = 160,
      height = 15,
      title = string.format(" Add Comment to %s ", item.key),
      title_pos = "center",
      border = "rounded",
      keys = {
        submit = {
          "<c-s>",
          function(win) submit_comment(item.key, win) end,
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

---Edit issue title
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
local function action_jira_edit_summary(picker, item, action)
  if not validate_item_key(item) then
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

    cli.edit_issue_summary(item.key, new_title, {
      success_msg = string.format("Updated summary for %s", item.key),
      error_msg = string.format("Failed to update summary for %s", item.key),
      on_success = function()
        local cache = require("jira.cache")
        cache.clear(cache.keys.ISSUE_VIEW, { key = item.key })
        cache.clear(cache.keys.ISSUES)
        cache.clear(cache.keys.EPIC_ISSUES)
        picker:refresh()
      end,
    })
  end)
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
      -- Clear cache for issue queries
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

    Snacks.scratch({
      ft = "markdown",
      name = string.format("Edit Description - %s", item.key),
      template = description,
      win = {
        relative = "editor",
        width = 160,
        height = 20,
        title = string.format(" Edit Description for %s ", item.key),
        title_pos = "center",
        border = "rounded",
        keys = {
          submit = {
            "<c-s>",
            function(win) submit_description(item.key, win, picker) end,
            desc = "Submit description",
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

    copy_key = {
      name = "Copy / Yank issue key to clipboard",
      icon = " ",
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

    edit_summary = {
      name = "Edit summary/title",
      icon = "󰏫 ",
      priority = 50,
      action = action_jira_edit_summary,
    },

    edit_description = {
      name = "Edit description",
      icon = " ",
      priority = 40,
      action = action_jira_edit_description,
    },

    comment = {
      name = "Add comment to issue",
      icon = " ",
      priority = 30,
      action = action_jira_add_comment,
    },

    refresh = {
      name = "Refresh",
      icon = " ",
      priority = 20,
      action = action_jira_refresh_cache,
    },
  }
end

---Action to show action dialog
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
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

local M = {}
M.get_jira_actions = get_jira_actions

M.action_jira_list_actions = action_jira_list_actions
M.action_jira_open_browser = action_jira_open_browser
M.action_jira_copy_key = action_jira_copy_key
M.action_jira_transition = action_jira_transition
M.action_jira_assign_me = action_jira_assign_me
M.action_jira_unassign = action_jira_unassign
M.action_jira_add_comment = action_jira_add_comment
M.action_jira_refresh_cache = action_jira_refresh_cache
return M
