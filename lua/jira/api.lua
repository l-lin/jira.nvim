local M = {}

---Parse plain text output from jira CLI
---@param output string Raw CLI output (tab-separated)
---@param columns string[] Column names
---@return table[] issues Structured issue data
function M.parse_plain_output(output, columns)
  if not output or output == "" then
    return {}
  end

  local lines = vim.split(output, "\n", { trimempty = true })
  local issues = {}

  for _, line in ipairs(lines) do
    local values = vim.split(line, "\t", { plain = true })
    local issue = {}

    -- Map values to column names
    for i, col in ipairs(columns) do
      issue[col] = values[i] or ""
    end

    table.insert(issues, issue)
  end

  return issues
end

---Execute jira CLI command
---@param args string[] CLI arguments
---@param callback fun(result: vim.SystemCompleted)
function M.execute(args, callback)
  local config = require("jira.config").options

  vim.system(
    vim.list_extend({ config.cli.cmd }, args),
    { text = true },
    vim.schedule_wrap(callback)
  )
end

---Get issues from current sprint
---@param opts table? Options
---@param callback fun(issues: table[], error: string?)
function M.get_sprint_issues(opts, callback)
  opts = opts or {}
  local config = require("jira.config").options

  -- Build command arguments
  local args = vim.list_extend({}, opts.cli_args or config.cli.args)

  -- Add filters
  local filters = opts.filters or config.query.filters
  vim.list_extend(args, filters)

  -- Add order
  local order_by = opts.order_by or config.query.order_by
  vim.list_extend(args, { "--order-by", order_by })

  -- Add format
  local columns = opts.columns or config.query.columns
  vim.list_extend(args, { "--plain", "--columns", table.concat(columns, ",") })

  -- Execute command
  M.execute(args, function(result)
    if result.code ~= 0 then
      local error_msg = result.stderr or "Unknown error"
      callback({}, error_msg)
      return
    end

    -- Parse output
    local issues = M.parse_plain_output(result.stdout, columns)
    callback(issues, nil)
  end)
end

return M
