---Simple CSV parser for quoted fields
---@param line string
---@return string[]
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

---@type snacks.picker.finder
local function get_jira_issues(opts, ctx)
  local config = require("jira.config").options
  local args = require("jira.api").build_jira_args()
  local columns = config.query.columns

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
          text = string.format(
            "%s %s %s %s %s",
            issue.key or "",
            issue.assignee or "",
            issue.status or "",
            issue.summary or "",
            issue.labels or ""
          ),
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

return get_jira_issues
