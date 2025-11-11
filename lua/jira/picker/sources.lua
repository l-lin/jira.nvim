---Gets the available actions for a JIRA issue and formats them for display in a picker.
---@param opts snacks.picker.finder_opts Options passed to the finder
---@param ctx snacks.picker.finder_context Context for the finder
local function get_actions(opts, ctx)
  local item = opts.item or (ctx.ctx and ctx.ctx.item) or ctx.item

  local actions = require("jira.picker.actions").get_jira_actions(item, ctx)

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
    for i = 1, #items do
      local it = items[i]
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

---Builds the configuration for the JIRA issues picker.
---@return snacks.picker.source The configuration for the JIRA issues picker
local function source_jira_issues()
  local config = require("jira.config").options
  local keymaps = config.keymaps

  return {
    title = "JIRA Issues",
    finder = require("jira.picker.finders"),
    format = "format_jira_issues",
    preview = "preview_jira_issue",
    confirm = "action_jira_list_actions",
    pattern = config.query.prefill_search,

    win = {
      input = {
        title = "JIRA Issues (Current Sprint)",
        keys = keymaps.input,
      },
      list = {
        keys = keymaps.list,
      },
      preview = {
        keys = keymaps.preview,
      },
    },
  }
end

---Builds the configuration for the JIRA actions picker.
---@return snacks.picker.source The configuration for the JIRA actions picker
local function source_jira_actions()
  return {
    layout = { preset = "select", layout = { max_width = 60 } },
    title = "  Actions",
    main = { current = true },
    finder = get_actions,
    format = "format_jira_action",
  }
end

local M = {}
M.source_jira_issues = source_jira_issues()
M.source_jira_actions = source_jira_actions()
return M
