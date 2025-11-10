local M = {}

---@type snacks.picker.finder
function M.get_actions(opts, ctx)
  local actions_module = require("jira.picker.actions")
  local item = opts.item or (ctx.ctx and ctx.ctx.item) or ctx.item

  -- Get actions for the current item
  local actions = actions_module.get_actions(item, ctx)

  -- Convert actions to picker items, sorted by priority
  local items = {}
  for name, action_def in pairs(actions) do
    table.insert(items, {
      text = string.format("%s %s", action_def.icon or "", action_def.name),
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
    for _, it in ipairs(items) do
      cb(it)
    end
  end
end

return M
