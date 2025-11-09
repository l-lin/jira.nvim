local M = {}

---@param ctx snacks.picker.preview.ctx
function M.jira_issue_preview(ctx)
  local item = ctx.item

  if not item or not item.key then
    ctx.preview:reset()
    ctx.preview:notify("No issue selected", "warn")
    return
  end

  -- Get type icon from config
  local config = require("jira.config").options
  local type_icons = config.type_icons
  local icon = type_icons[item.type] or config.type_icons.default

  -- Build preview text
  local lines = {
    "# " .. item.key,
    "",
    "**Type**: " .. icon .. " " .. (item.type or "Unknown"),
    "**Assignee**: " .. (item.assignee or "Unassigned"),
    "**Status**: " .. (item.status or "Unknown"),
    "",
  }

  -- Add labels if present
  if item.labels and item.labels ~= "" then
    local labels = vim.split(item.labels, ",")
    local prefixed_labels = {}
    for _, label in ipairs(labels) do
      table.insert(prefixed_labels, "#" .. label)
    end
    table.insert(lines, "**Labels**: " .. table.concat(prefixed_labels, " "))
    table.insert(lines, "")
  end

  -- Add summary
  table.insert(lines, "## Summary")
  table.insert(lines, "")
  table.insert(lines, item.summary or "No summary available")

  -- Add URL
  local util = require("jira.util")
  local base_url = util.get_jira_base_url()
  table.insert(lines, "")
  table.insert(lines, "## Links")
  table.insert(lines, string.format("[View in browser](%s/browse/%s)", base_url, item.key))

  -- Set preview content
  ctx.preview:reset()
  ctx.preview:set_title(item.key)
  ctx.preview:set_lines(lines)
  ctx.preview:highlight({ ft = "markdown" })
end

return M
