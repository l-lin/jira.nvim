local cli = require("jira.cli")
local cache = require("jira.cache")

local M = {}

---Add issue to epic
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
---@diagnostic disable-next-line: unused-local
function M.action_jira_add_to_epic(picker, item, action)
  require("snacks").picker("source_jira_epics", {
    confirm = function(epic_picker, epic_item)
      if not epic_item or not epic_item.key then
        return
      end

      local epic_key = epic_item.key

      cli.add_issue_to_epic(epic_key, item.key, {
        success_msg = string.format("Added %s to epic: %s", item.key, epic_key),
        error_msg = string.format("Failed to add %s to epic", item.key),
        on_success = function()
          cache.clear_issue_caches(item.key)
          epic_picker:close()
          if picker then
            picker:focus()
            picker:refresh()
          end
        end,
      })
    end,
  })
  -- For some reason, it's starting on normal mode (maybe because it's in another floating window?).
  -- So forcing making it on insert mode.
  vim.schedule(function()
    vim.cmd.startinsert({ bang = true })
  end)
end

return M
