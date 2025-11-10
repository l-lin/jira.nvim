local M = {}

---@type snacks.picker.finder
function M.jira_issues(opts, ctx)
  local util = require("jira.util")
  local config = require("jira.config").options

  -- Check if jira CLI is available
  if not util.has_jira_cli() then
    vim.notify("JIRA CLI not found. Please install: https://github.com/ankitpokhrel/jira-cli", vim.log.levels.ERROR)
    return function() end
  end

  -- Build command arguments
  local args = { "sprint", "list", "--current" }

  -- Add filters
  local filters = opts.filters or config.query.filters
  vim.list_extend(args, filters)

  -- Add order
  local order_by = opts.order_by or config.query.order_by
  vim.list_extend(args, { "--order-by", order_by })

  -- Add pagination
  local paginate = opts.paginate or config.query.paginate
  vim.list_extend(args, { "--paginate", paginate })

  -- Add format
  local columns = opts.columns or config.query.columns
  vim.list_extend(args, { "--csv", "--columns", table.concat(columns, ",") })

  -- Debug: print command
  if config.debug then
    local cmd_str = config.cli.cmd .. " " .. table.concat(args, " ")
    vim.notify("JIRA CLI Command:\n" .. cmd_str, vim.log.levels.INFO)
  end

  -- Simple CSV parser for quoted fields
  local function parse_csv_line(line)
    local values = {}
    local current = ""
    local in_quotes = false
    local i = 1

    while i <= #line do
      local char = line:sub(i, i)
      if char == '"' then
        in_quotes = not in_quotes
      elseif char == "," and not in_quotes then
        table.insert(values, current)
        current = ""
      else
        current = current .. char
      end
      i = i + 1
    end
    table.insert(values, current)
    return values
  end

  -- Use snacks proc to run the command
  local first_line = true
  return require("snacks.picker.source.proc").proc(
    ctx:opts({
      cmd = config.cli.cmd,
      args = args,
      notify = true,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        -- Skip header line
        if first_line then
          first_line = false
          return false
        end

        -- Parse CSV line
        local values = parse_csv_line(item.text)

        -- Validate we have enough columns
        if #values < #columns then
          return false
        end

        -- Map values to column names and fix JIRA CLI CSV escaping bug
        local issue = {}
        for i, col in ipairs(columns) do
          local value = values[i] or ""
          -- Fix JIRA CLI bug: [text[] should be [text]
          value = value:gsub("%[([^%]]+)%[%]", "[%1]")
          issue[col] = value
        end

        -- Return picker item
        return {
          text = string.format("%s %s %s %s %s", issue.key or "", issue.assignee or "", issue.status or "", issue.summary or "", issue.labels or ""),
          key = issue.key,
          type = issue.type,
          assignee = issue.assignee,
          status = issue.status,
          summary = issue.summary,
          labels = issue.labels,
          _raw = issue,
        }
      end,
    }),
    ctx
  )
end

---@type snacks.picker.finder
function M.jira_get_actions(opts, ctx)
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

  return function()
    local results = {}
    for _, item in ipairs(items) do
      results[#results + 1] = item
    end
    return results
  end
end

return M
