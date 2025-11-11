-- Pad string to fixed display width (handles multi-byte chars)
local function pad_to_width(str, width)
  local display_width = vim.fn.strdisplaywidth(str)
  if display_width >= width then
    return str
  end
  return str .. string.rep(" ", width - display_width)
end

---Format issue item for display
---@param item snacks.picker.Item
---@param picker snacks.Picker
---@return snacks.picker.Highlight[]
local function format_jira_issues(item, picker)
  local ret = {}

  -- Type badge with icon (more compact)
  local config = require("jira.config").options
  local type_icons = config.display.type_icons
  local icon = type_icons[item.type] or type_icons.default
  local type_highlights = config.display.type_highlights
  local type_hl = type_highlights[item.type] or "Comment"

  table.insert(ret, { icon .. " ", type_hl })

  -- Issue key (compact)
  local issue_hl = config.display.issue_highlights
  table.insert(ret, { pad_to_width(item.key or "", 10), issue_hl.key })
  table.insert(ret, { " " })

  -- Assignee (compact)
  local assignee = (item.assignee and item.assignee ~= "") and item.assignee or "Unassigned"
  table.insert(ret, { pad_to_width(assignee, 18), issue_hl.assignee })
  table.insert(ret, { " " })

  -- Status badge (compact)
  local status = item.status or "Unknown"
  local status_highlights = config.display.status_highlights
  local status_hl = status_highlights[status] or "Comment"
  table.insert(ret, { pad_to_width(status, 22), status_hl })
  table.insert(ret, { " " })

  -- Summary (main text) - no width constraint
  table.insert(ret, { item.summary or "", issue_hl.summary })

  -- Labels (if present, more compact)
  if item.labels and item.labels ~= "" then
    table.insert(ret, { " ", issue_hl.labels })
    local labels = vim.split(item.labels, ",")
    for i = 1, #labels do
      if i > 1 then
        table.insert(ret, { " ", issue_hl.labels })
      end
      table.insert(ret, { "#" .. labels[i], issue_hl.labels })
    end
  end

  return ret
end

---Format action item for display in action dialog
---@param item snacks.picker.Item
---@param picker snacks.Picker
---@return snacks.picker.Highlight[]
local function format_jira_action(item, picker)
  local ret = {}
  local config = require("jira.config").options
  local action_hl = config.display.action_highlights

  -- Format: "icon  number. description" (two spaces after icon)
  local icon, num, rest = item.text:match("^([^%s]+)%s+(%d+%.%s)(.*)$")

  if icon and num and rest then
    table.insert(ret, { icon .. "  ", action_hl.icon })
    table.insert(ret, { num, action_hl.number })
    table.insert(ret, { rest, action_hl.description })
  else
    -- Fallback if format doesn't match
    table.insert(ret, { item.text, action_hl.fallback })
  end

  return ret
end

local M = {}
M.format_jira_issues = format_jira_issues
M.format_jira_action = format_jira_action
return M
