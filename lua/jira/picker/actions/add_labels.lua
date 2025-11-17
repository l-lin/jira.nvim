local cli = require("jira.cli")
local ui = require("jira.picker.ui")
local cache = require("jira.cache")

local M = {}

---Add/edit labels for an issue
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
---@diagnostic disable-next-line: unused-local
function M.action_jira_add_labels(picker, item, action)
  ui.prompt_text_input({
    prompt = "Labels (comma-separated): ",
    on_submit = function(new_labels)
      -- Parse comma-separated labels and trim whitespace
      local label_list = {}
      for label in new_labels:gmatch("[^,]+") do
        local trimmed = vim.trim(label)
        if trimmed ~= "" then
          table.insert(label_list, trimmed)
        end
      end

      cli.edit_issue_labels(item.key, label_list, {
        success_msg = string.format("Updated labels for %s", item.key),
        error_msg = string.format("Failed to update labels for %s", item.key),
        on_success = function()
          cache.clear_issue_caches(item.key)
          picker:refresh()
        end,
      })
    end,
  })
end

return M
