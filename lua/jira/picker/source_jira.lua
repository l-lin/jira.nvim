local M = {}

---@type snacks.picker.finder
function M.get_actions(opts, ctx)
  local actions_module = require("jira.picker.actions")
  local item = opts.item or (ctx.ctx and ctx.ctx.item) or ctx.item

  -- Get actions for the current item
  local actions = actions_module.get_actions(item, ctx)

  -- Convert actions to picker items, sorted by priority
  local items = {}
  local issue_key = item and item.key or ""

  for name, action_def in pairs(actions) do
    -- Build descriptive text with issue key where appropriate
    local text
    if name == "open_browser" or name == "view_cli" or name == "show_details" then
      text = string.format("%s %s", action_def.icon or "", action_def.desc)
    elseif name == "copy_key" then
      text = string.format("%s Copy %s to clipboard", action_def.icon or "", issue_key)
    elseif name == "transition" or name == "assign_me" or name == "unassign" or name == "comment" then
      text = string.format("%s %s", action_def.icon or "", action_def.desc)
    else
      text = string.format("%s %s", action_def.icon or "", action_def.name)
    end

    table.insert(items, {
      text = text,
      name = name,
      desc = action_def.desc,
      action = action_def,
      priority = action_def.priority or 0,
    })
  end

  -- Sort by priority (highest first), then by name
  table.sort(items, function(a, b)
    if a.priority ~= b.priority then
      return a.priority > b.priority
    end
    return a.name < b.name
  end)

  ---@async
  return function(cb)
    for i, it in ipairs(items) do
      -- Extract icon from the beginning of text (emoji followed by space)
      local icon, rest = it.text:match("^([^%s]+)%s(.+)$")
      if icon and rest then
        it.text = ("%s  %d. %s"):format(icon, i, rest)
      else
        it.text = ("%d. %s"):format(i, it.text)
      end
      cb(it)
    end
  end
end

return M
