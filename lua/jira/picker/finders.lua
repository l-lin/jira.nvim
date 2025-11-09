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

  -- Add format
  local columns = opts.columns or config.columns
  vim.list_extend(args, { "--plain", "--columns", table.concat(columns, ",") })

  -- Debug: print command
  if config.debug then
    local cmd_str = config.jira_cmd .. " " .. table.concat(args, " ")
    vim.notify("JIRA CLI Command:\n" .. cmd_str, vim.log.levels.INFO)
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

        -- Parse tab-separated line
        local values = vim.split(item.text, "\t", { plain = true })

        -- Filter out empty strings from consecutive tabs
        local filtered = {}
        for _, v in ipairs(values) do
          if v ~= "" then
            table.insert(filtered, v)
          end
        end

        -- Validate we have enough columns
        if #filtered < #columns then
          return false
        end

        -- Map values to column names
        local issue = {}
        for i, col in ipairs(columns) do
          issue[col] = filtered[i] or ""
        end

        -- Return picker item
        return {
          text = string.format("%s: %s", issue.key or "", issue.summary or ""),
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
