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
  local filters = opts.filters or config.filters
  vim.list_extend(args, filters)

  -- Add order
  local order_by = opts.order_by or config.order_by
  vim.list_extend(args, { "--order-by", order_by })

  -- Add pagination
  local paginate = opts.paginate or config.paginate
  vim.list_extend(args, { "--paginate", paginate })

  -- Add format
  local columns = opts.columns or config.columns
  vim.list_extend(args, { "--csv", "--columns", table.concat(columns, ",") })

  -- Debug: print command
  if config.debug then
    local cmd_str = config.jira_cmd .. " " .. table.concat(args, " ")
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
      cmd = config.jira_cmd,
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

        -- Map values to column names
        local issue = {}
        for i, col in ipairs(columns) do
          issue[col] = values[i] or ""
        end

        -- Return picker item
        return {
          text = string.format("%s %s %s %s", issue.key or "", issue.assignee or "", issue.status or "", issue.summary or ""),
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

return M
