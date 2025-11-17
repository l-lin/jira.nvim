local cache = require("jira.cache")
local cli = require("jira.cli")

local M = {}

---Fetch epic information for the given issue key
---@param key string
---@param callback fun(epic: jira.Epic?)
function M.fetch_epic(key, callback)
  local cached = cache.get(cache.keys.ISSUE_EPIC, { key = key })
  if cached and cached.items then
    -- Issues without epic have vim.NIL in the cache.
    if cached.items == vim.NIL then
      callback(nil)
    else
      callback(cached.items)
    end
    return
  end

  cli.get_issue_epic(key, function(epic)
    cache.set(cache.keys.ISSUE_EPIC, { key = key }, epic or vim.NIL)
    callback(epic)
  end)
end

---Fetch issue with epic information
---@param issue_key string
---@param callback fun(result: table, epic: jira.Epic?)
function M.fetch_issue(issue_key, callback)
  local config = require("jira.config").options

  local cached = cache.get(cache.keys.ISSUE_VIEW, { key = issue_key })
  if cached and cached.items then
    M.fetch_epic(issue_key, function(epic)
      callback(cached.items, epic)
    end)
    return
  end

  cli.view_issue(issue_key, config.preview.nb_comments, function(result)
    if result.code ~= 0 then
      vim.notify("Failed to load issue: " .. issue_key, vim.log.levels.ERROR)
      return
    end

    cache.set(cache.keys.ISSUE_VIEW, { key = issue_key }, result)

    M.fetch_epic(issue_key, function(epic)
      callback(result, epic)
    end)
  end)
end

---Fetch sprints
---@param callback fun(sprints: table)
function M.fetch_sprints(callback)
  local cached = cache.get(cache.keys.SPRINTS)
  if cached and cached.items then
    callback(cached.items)
    return
  end

  cli.get_sprints(function(sprints)
    cache.set(cache.keys.SPRINTS, nil, sprints)
    callback(sprints)
  end)
end

---Fetch transitions for an issue
---@param issue_key string
---@param callback fun(transitions: string[]?)
function M.fetch_transitions(issue_key, callback)
  local cached = cache.get(cache.keys.TRANSITIONS, { key = issue_key })
  if cached and cached.items then
    callback(cached.items)
    return
  end

  cli.get_transitions(issue_key, function(transitions)
    if transitions and #transitions > 0 then
      cache.set(cache.keys.TRANSITIONS, { key = issue_key }, transitions)
    end
    callback(transitions)
  end)
end

---Fetch issue types
---@param callback fun(issue_types: string[]?)
function M.fetch_issue_types(callback)
  local cached = cache.get(cache.keys.ISSUE_TYPES)
  if cached and cached.items then
    callback(cached.items)
    return
  end

  cli.get_issue_types(function(issue_types)
    if issue_types and #issue_types > 0 then
      cache.set(cache.keys.ISSUE_TYPES, nil, issue_types)
    end
    callback(issue_types)
  end)
end

return M
