local cli = require("jira.cli")
local cache = require("jira.cache")
local fetchers = require("jira.fetchers")

local M = {}

---Show sprint selection UI using Snacks picker
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param sprints table[]
local function show_sprint_select(picker, item, sprints)
  require("snacks").picker("source_jira_sprints", {
    sprints = sprints,
    ---@diagnostic disable-next-line: unused-local
    confirm = function(sprint_picker, sprint_item, action)
      if not sprint_item or not sprint_item.sprint then
        return
      end

      local selected_sprint = sprint_item.sprint

      cli.move_issue_to_sprint(item.key, selected_sprint.id, {
        success_msg = string.format("Moved %s to sprint: %s", item.key, selected_sprint.name),
        error_msg = string.format("Failed to move %s to sprint", item.key),
        on_success = function()
          cache.clear_issue_caches(item.key)
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
---@param action snacks.picker.Action
---@diagnostic disable-next-line: unused-local
function M.action_jira_update_sprint(picker, item, action)
  fetchers.fetch_sprints(function(sprints)
    if not sprints or #sprints == 0 then
      vim.notify("No active or future sprints available", vim.log.levels.WARN)
      return
    end

    show_sprint_select(picker, item, sprints)
  end)
end

return M
