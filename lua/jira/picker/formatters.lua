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
function M.jira_issues(item, picker)
  local ret = {}

  -- Type badge with icon (more compact)
  local config = require("jira.config").options
  local type_icons = config.display.type_icons
  local icon = type_icons[item.type] or type_icons.default
  local type_highlights = config.display.type_highlights
  local type_hl = type_highlights[item.type] or "Comment"

  ret[#ret + 1] = { icon .. " ", type_hl }

  -- Issue key (compact)
  ret[#ret + 1] = { pad_to_width(item.key or "", 10), "Special" }
  ret[#ret + 1] = { " " }

  -- Assignee (compact)
  local assignee = item.assignee or "Unassigned"
  if assignee == "" then
    assignee = "Unassigned"
  end
  ret[#ret + 1] = { pad_to_width(assignee, 18), "Identifier" }
  ret[#ret + 1] = { " " }

  -- Status badge (compact)
  local status = item.status or "Unknown"
  local status_highlights = config.display.status_highlights
  local status_hl = status_highlights[status] or "Comment"
  ret[#ret + 1] = { pad_to_width(status, 22), status_hl }
  ret[#ret + 1] = { " " }

  -- Summary (main text) - no width constraint
  ret[#ret + 1] = { item.summary or "", "Normal" }

  -- Labels (if present, more compact)
  if item.labels and item.labels ~= "" then
    ret[#ret + 1] = { " ", "Comment" }
    local labels = vim.split(item.labels, ",")
    for i, label in ipairs(labels) do
      if i > 1 then
        ret[#ret + 1] = { " ", "Comment" }
      end
      ret[#ret + 1] = { "#" .. label, "Comment" }
    end
  end

  return ret
end

---Format action item for display in action dialog
---@param item snacks.picker.Item
---@param picker snacks.Picker
---@return snacks.picker.Highlight[]
function M.jira_format_action(item, picker)
  local ret = {}

  -- Format: "icon number. description"
  local icon, num, rest = item.text:match("^([^%s]+)%s(%d+%.%s)(.*)$")

  if icon and num and rest then
    -- Icon
    ret[#ret + 1] = { icon .. " ", "Special" }

    -- Number
    ret[#ret + 1] = { num, "Number" }

    -- Description
    ret[#ret + 1] = { rest, "Normal" }
  else
    -- Fallback if format doesn't match
    ret[#ret + 1] = { item.text, "Normal" }
  end

  return ret
end

return M
