local cli = require("jira.cli")
local cache = require("jira.cache")
local fetchers = require("jira.fetchers")

local M = {}

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
        cache.clear_issue_caches(item.key)
        picker:refresh()
      end,
    })
  end)
end

---Transition issue to different status
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param _ snacks.picker.Action
function M.action_jira_transition(picker, item, _)
  fetchers.fetch_transitions(item.key, function(transitions)
    if not transitions or #transitions == 0 then
      vim.notify("No transitions available", vim.log.levels.WARN)
      return
    end
    show_transition_select(picker, item, transitions)
  end)
end

return M
