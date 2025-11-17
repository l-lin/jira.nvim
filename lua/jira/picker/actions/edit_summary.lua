local cli = require("jira.cli")
local ui = require("jira.picker.ui")
local cache = require("jira.cache")

local M = {}

---Edit issue title
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
---@diagnostic disable-next-line: unused-local
function M.action_jira_edit_summary(picker, item, action)
  local current_title = item.summary or ""

  ui.prompt_text_input({
    prompt = "Issue summary: ",
    default = current_title,
    skip_unchanged = true,
    on_submit = function(new_title)
      cli.edit_issue_summary(item.key, new_title, {
        success_msg = string.format("Updated summary for %s", item.key),
        error_msg = string.format("Failed to update summary for %s", item.key),
        on_success = function()
          cache.clear_issue_caches(item.key)
          picker:refresh()
        end,
      })
    end,
  })
end

return M
