---Simple CSV parser for quoted fields
---NOTE: This parser does not handle escaped quotes within fields (e.g., "value with \"quote\"")
---It's sufficient for JIRA CLI CSV output but not a general-purpose CSV parser
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

---Generic JIRA finder factory
---@param args_fn function Function that returns CLI arguments
---@param columns string[] Column names to map
---@param transform_fn function Function that transforms parsed data into picker item
---@return snacks.picker.finder
local function create_jira_finder(args_fn, columns, transform_fn)
  return function(opts, ctx)
    local config = require("jira.config").options
    local args = args_fn(opts)

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

          -- Map values to column names
          local data = {}
          for i = 1, #columns do
            data[columns[i]] = values[i] or ""
          end

          -- Apply custom transformation
          return transform_fn(data, config)
        end,
      }),
      ctx
    )
  end
end

---Transform function for issue items (sprint and epic issues)
---@param issue table Parsed issue data
---@param config table Plugin configuration
---@return table Picker item
local function transform_issue(issue, config)
  -- Fix escaping bugs in all fields: [text[] should be [text]
  for key, value in pairs(issue) do
    issue[key] = value:gsub("%[([^%]]+)%[%]", "[%1]")
  end

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
end

---Transform function for epic items
---@param epic table Parsed epic data
---@param config table Plugin configuration
---@return table Picker item
local function transform_epic(epic, config)
  local icon = config.ui.type_icons.Epic or config.ui.type_icons.default

  return {
    text = string.format("%s %s %s", icon, epic.key or "", epic.summary or ""),
    key = epic.key,
    type = "Epic",
    status = epic.status,
    summary = epic.summary,
    _raw = epic,
  }
end

---@type snacks.picker.finder
local function get_jira_issues(opts, ctx)
  local config = require("jira.config").options
  local cli = require("jira.cli")

  return create_jira_finder(
    cli.get_sprint_list_args,
    config.cli.query.columns,
    transform_issue
  )(opts, ctx)
end

---@type snacks.picker.finder
local function get_jira_epics(opts, ctx)
  local config = require("jira.config").options
  local cli = require("jira.cli")

  return create_jira_finder(
    cli.get_epic_list_args,
    config.cli.epic.columns,
    transform_epic
  )(opts, ctx)
end

--- Get JIRA epic issues
---@param epic_key string? Epic key to fetch issues for
---@param opts snacks.picker.Config
---@param ctx snacks.picker.finder.ctx
---@return snacks.picker.finder.result
local function get_jira_epic_issues(epic_key, opts, ctx)
  if not epic_key then
    error("epic_key is required for get_jira_epic_issues")
  end

  local config = require("jira.config").options
  local cli = require("jira.cli")

  return create_jira_finder(
    function() return cli.get_epic_issues_args(epic_key) end,
    config.cli.epic_issues.columns,
    transform_issue
  )(opts, ctx)
end

local M = {}
M.get_jira_issues = get_jira_issues
M.get_jira_epics = get_jira_epics
M.get_jira_epic_issues = get_jira_epic_issues
return M
