local M = {}

local metadata = {
  open_in_browser = {
    name = "Open issue in browser",
    icon = " ",
    priority = 100,
  },
  view_in_buffer = {
    name = "View issue in buffer",
    icon = " ",
    priority = 98,
  },
  start_work = {
    name = "Start work on issue",
    icon = " ",
    priority = 95,
  },
  copy_key = {
    name = "Copy / Yank issue key to clipboard",
    icon = " ",
    priority = 90,
  },
  copy_url = {
    name = "Copy / Yank issue URL to clipboard",
    icon = " ",
    priority = 88,
  },
  transition = {
    name = "Edit issue status / Transition",
    icon = " ",
    priority = 80,
  },
  assign_me = {
    name = "Assign issue to me",
    icon = " ",
    priority = 70,
  },
  unassign = {
    name = "Unassign issue",
    icon = " ",
    priority = 60,
  },
  create_issue = {
    name = "Create issue",
    priority = 55,
    icon = " ",
  },
  update_sprint = {
    name = "Move issue to sprint",
    icon = " ",
    priority = 50,
  },
  add_to_epic = {
    name = "Add issue to epic",
    icon = "󱐋 ",
    priority = 48,
  },
  remove_from_epic = {
    name = "Remove issue from epic",
    icon = "󱐋 ",
    priority = 46,
  },
  add_labels = {
    name = "Add/edit labels",
    icon = "󰌕 ",
    priority = 45,
  },
  edit_summary = {
    name = "Edit summary/title",
    icon = "󰏫 ",
    priority = 40,
  },
  edit_description = {
    name = "Edit description",
    icon = " ",
    priority = 30,
  },
  add_comment = {
    name = "Add comment to issue",
    icon = " ",
    priority = 20,
  },
  refresh_cache = {
    name = "Refresh",
    icon = " ",
    priority = 10,
  },
}

for name in pairs(metadata) do
  local module = require("jira.picker.actions." .. name)
  for key, value in pairs(module) do
    -- Only register function starting with `action_jira_`
    if key:match("^action_") then
      M[key] = value
    end
  end
end

-- We need to hard code this one, as this is the one that will display the list of actions.
M.action_jira_list_actions = require("jira.picker.actions.list_actions").action_jira_list_actions

---Get available actions for an item
---@return table<string, table> actions Map of action name to action metadata
function M.get_jira_actions()
  local actions = {}
  for name in pairs(metadata) do
    local module = require("jira.picker.actions." .. name)
    local meta = metadata[name]

    for key, value in pairs(module) do
      -- Only register function starting with `action_jira_`
      if key:match("^action_") then
        actions[key] = {
          name = meta.name,
          icon = meta.icon,
          priority = meta.priority,
          action = value,
        }
        break
      end
    end
  end
  return actions
end

return M
