local M = {}

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
function M.format_jira_issues(item, picker)
  local ret = {}

  -- Type badge with icon (more compact)
  local config = require("jira.config").options
  local type_icons = config.ui.type_icons
  local icon = type_icons[item.type] or type_icons.default
  local type_highlights = config.ui.type_highlights
  local type_hl = type_highlights[item.type] or "Comment"

  table.insert(ret, { icon .. " ", type_hl })

  -- Issue key (compact)
  local issue_hl = config.ui.issue_highlights
  table.insert(ret, { pad_to_width(item.key or "", 10), issue_hl.key })
  table.insert(ret, { " " })

  -- Assignee (compact)
  local assignee = (item.assignee and item.assignee ~= "") and item.assignee or "Unassigned"
  table.insert(ret, { pad_to_width(assignee, 18), issue_hl.assignee })
  table.insert(ret, { " " })

  -- Status badge (compact)
  local status = item.status or "Unknown"
  local status_highlights = config.ui.status_highlights
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
function M.format_jira_action(item, picker)
  local ret = {}
  local config = require("jira.config").options
  local action_hl = config.ui.action_highlights

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

---Format epic item for display in epic picker
---@param item snacks.picker.Item
---@param picker snacks.Picker
---@return snacks.picker.Highlight[]
function M.format_jira_epics(item, picker)
  local ret = {}
  local config = require("jira.config").options

  -- Epic icon
  local type_icons = config.ui.type_icons
  local icon = type_icons.Epic or type_icons.default
  local type_highlights = config.ui.type_highlights
  local type_hl = type_highlights.Epic or "Comment"
  table.insert(ret, { icon .. " ", type_hl })

  -- Epic key
  local issue_hl = config.ui.issue_highlights
  table.insert(ret, { pad_to_width(item.key or "", 10), issue_hl.key })
  table.insert(ret, { " " })

  -- Status
  local status = item.status or "Unknown"
  local status_highlights = config.ui.status_highlights
  local status_hl = status_highlights[status] or "Comment"
  table.insert(ret, { pad_to_width(status, 13), status_hl })
  table.insert(ret, { " " })

  -- Summary
  table.insert(ret, { item.summary or "", issue_hl.summary })

  return ret
end

---Format sprint item for display in sprint picker
---@param item snacks.picker.Item
---@param picker snacks.Picker
---@return snacks.picker.Highlight[]
function M.format_jira_sprint(item, picker)
  local ret = {}
  local config = require("jira.config").options
  local sprint_hl = config.ui.sprint_highlights

  -- Parse the display text: "name [state]" or "name []"
  local name, state = (item.text or ""):match("^(.*)%s%[([^%]]*)%]$")

  if name then
    if state and state ~= "" then
      table.insert(ret, { pad_to_width(name, 30), sprint_hl.name })
      table.insert(ret, { " " })
      table.insert(ret, { state, sprint_hl.state })
    else
      table.insert(ret, { name, sprint_hl.name })
    end
  else
    table.insert(ret, { item.text or "", sprint_hl.name })
  end

  return ret
end

return M
