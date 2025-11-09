local M = {}

-- Highlight groups for issue types
local TYPE_HIGHLIGHTS = {
  Bug = "DiagnosticError",
  Story = "DiagnosticInfo",
  Task = "DiagnosticWarn",
  Epic = "Special",
}

-- Highlight groups for statuses
local STATUS_HIGHLIGHTS = {
  ["To Do"] = "DiagnosticHint",
  ["In Progress"] = "DiagnosticWarn",
  ["In Review"] = "DiagnosticInfo",
  ["Done"] = "DiagnosticOk",
  ["Blocked"] = "DiagnosticError",
  ["Awaiting Information"] = "Comment",
  ["Triage"] = "DiagnosticInfo",
}

---Format issue item for display
---@param item snacks.picker.Item
---@param picker snacks.Picker
---@return snacks.picker.Highlight[]
function M.jira_issues(item, picker)
  local ret = {}

  -- Type badge with icon (more compact)
  local type_icon = {
    Bug = "󰃤",
    Story = "",
    Task = "",
    ["Sub-task"] = "",
    Epic = "󱐋",
  }
  local icon = type_icon[item.type] or "󰄮"
  local type_hl = TYPE_HIGHLIGHTS[item.type] or "Comment"

  ret[#ret + 1] = { icon .. " ", type_hl }
  ret[#ret + 1] = { string.format("%-8s", item.type or "Unknown"), type_hl }
  ret[#ret + 1] = { " " }

  -- Issue key (compact)
  ret[#ret + 1] = { string.format("%-10s", item.key or ""), "Special" }
  ret[#ret + 1] = { " " }

  -- Assignee (compact)
  local assignee = item.assignee or "Unassigned"
  if assignee == "" then
    assignee = "Unassigned"
  end
  ret[#ret + 1] = { string.format("%-18s", assignee), "Identifier" }
  ret[#ret + 1] = { " " }

  -- Status badge (compact)
  local status = item.status or "Unknown"
  local status_hl = STATUS_HIGHLIGHTS[status] or "Comment"
  ret[#ret + 1] = { string.format("%-22s", status), status_hl }
  ret[#ret + 1] = { " " }

  -- Summary (main text) - no width constraint
  ret[#ret + 1] = { item.summary or "", "Normal" }

  -- Labels (if present, more compact)
  if item.labels and item.labels ~= "" then
    ret[#ret + 1] = { " ", "Comment" }
    local labels = vim.split(item.labels, ",")
    for i, label in ipairs(labels) do
      if i > 1 then
        ret[#ret + 1] = { ",", "Comment" }
      end
      ret[#ret + 1] = { "", "Comment" }
      ret[#ret + 1] = { label, "Comment" }
    end
  end

  return ret
end

return M
