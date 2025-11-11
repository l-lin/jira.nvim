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

---Pure data fetching without cache
---@param args_fn function Function that returns CLI arguments
---@param columns string[] Column names to map
---@param transform_fn function Function that transforms parsed data into picker item
---@return snacks.picker.finder
local function fetch_jira_data(args_fn, columns, transform_fn)
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

---Wraps a finder with caching logic
---@param cache_key string Cache key for this query type
---@param cache_params? table Optional parameters for cache key
---@param finder_fn function Finder function to wrap
---@return snacks.picker.finder
local function with_cache(cache_key, cache_params, finder_fn)
  return function(opts, ctx)
    local config = require("jira.config").options
    local cache = require("jira.cache")

    -- Check if we should use cache
    local use_cache = config.cache.enabled

    -- Try to get from cache first
    if use_cache then
      local cached = cache.get(cache_key, cache_params)
      if cached and cached.items then
        return ctx.filter:filter(cached.items)
      end
    end

    -- Cache miss or skipped, fetch from source and cache results
    local items = {} -- Collect items for caching
    local proc_done = false

    local proc_result = finder_fn(opts, ctx)

    -- Wrap the proc result to cache items after streaming completes
    ---@async
    return function(cb)
      -- Call the original proc streamer, collecting items
      proc_result(function(item)
        if item then
          table.insert(items, item)
        end
        cb(item)
      end)

      -- Schedule caching after event loop (when streaming is done)
      vim.schedule(function()
        if not proc_done and #items > 0 and use_cache then
          proc_done = true
          cache.set(cache_key, cache_params, items)
        end
      end)
    end
  end
end

---Generic JIRA finder factory
---@param cache_key string Cache key for this query type
---@param cache_params? table Optional parameters for cache key
---@param args_fn function Function that returns CLI arguments
---@param columns string[] Column names to map
---@param transform_fn function Function that transforms parsed data into picker item
---@return snacks.picker.finder
local function create_jira_finder(cache_key, cache_params, args_fn, columns, transform_fn)
  local fetcher = fetch_jira_data(args_fn, columns, transform_fn)
  return with_cache(cache_key, cache_params, fetcher)
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
  local cache = require("jira.cache")

  return create_jira_finder(
    cache.keys.ISSUES,
    nil,
    cli.get_sprint_list_args,
    config.cli.issues.columns,
    transform_issue
  )(opts, ctx)
end

---@type snacks.picker.finder
local function get_jira_epics(opts, ctx)
  local config = require("jira.config").options
  local cli = require("jira.cli")
  local cache = require("jira.cache")

  return create_jira_finder(
    cache.keys.EPICS,
    nil,
    cli.get_epic_list_args,
    config.cli.epics.columns,
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
  local cache = require("jira.cache")

  return create_jira_finder(
    cache.keys.EPIC_ISSUES,
    { epic_key = epic_key },
    function() return cli.get_epic_issues_args(epic_key) end,
    config.cli.epic_issues.columns,
    transform_issue
  )(opts, ctx)
end

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


local M = {}
M.get_jira_issues = get_jira_issues
M.get_jira_epics = get_jira_epics
M.get_jira_epic_issues = get_jira_epic_issues
M.get_actions = get_actions
return M
