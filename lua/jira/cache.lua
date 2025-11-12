---Cache module for JIRA query results using SQLite

local db = nil

---Get cache file path from config
---@return string
local function get_cache_path()
  local config = require("jira.config").options
  return config.cache.path or (vim.fn.stdpath("data") .. "/jira/cache.sqlite3")
end

---Initialize the cache database
local function init_db()
  if db then
    return db
  end

  local config = require("jira.config").options
  local cache_file = get_cache_path()

  if config.debug then
    vim.notify(string.format("[JIRA Cache] Initializing database: %s", cache_file), vim.log.levels.INFO)
  end

  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(cache_file, ":h")
  vim.fn.mkdir(dir, "p")

  -- Open database
  local ok, result = pcall(function()
    return require("snacks.picker.util.db").new(cache_file, "string")
  end)

  if not ok then
    vim.notify("Failed to initialize JIRA cache: " .. tostring(result), vim.log.levels.WARN)
    return nil
  end

  db = result

  -- Create cache table with custom schema
  -- We'll store JSON-encoded data with timestamps
  db:exec([[
    CREATE TABLE IF NOT EXISTS cache (
      key TEXT PRIMARY KEY,
      data TEXT NOT NULL,
      timestamp INTEGER NOT NULL
    );
  ]])

  if config.debug then
    vim.notify("[JIRA Cache] Database initialized successfully", vim.log.levels.INFO)
  end

  return db
end

---Generate cache key for a query
---@param query_type string Type of query (e.g., "issues", "epics", "epic_issues")
---@param params? table Optional parameters to include in key (e.g., epic_key)
---@return string
local function make_key(query_type, params)
  if not params or vim.tbl_isempty(params) then
    return query_type
  end

  -- Create a deterministic, compact key from params
  local param_parts = {}
  for k, v in pairs(params) do
    table.insert(param_parts, k .. "=" .. tostring(v))
  end
  table.sort(param_parts) -- Ensure consistent ordering

  return query_type .. ":" .. table.concat(param_parts, ",")
end

---Clear cached data for a query (or all if no query_type specified)
---@param query_type? string Type of query to clear (nil = clear all)
---@param params? table Optional parameters (nil = clear all with matching query_type prefix)
local function clear(query_type, params)
  local database = init_db()
  if not database then
    return
  end

  if not query_type then
    database:exec("DELETE FROM cache;")
    if require("jira.config").options.debug then
      vim.notify("[JIRA Cache] Cache cleared", vim.log.levels.INFO)
    end
  elseif not params then
    local delete = database:prepare("DELETE FROM cache WHERE key = ? OR key LIKE ?;")
    delete:exec({ query_type, query_type .. ":%"})
    delete:close()
  else
    local key = make_key(query_type, params)
    local delete = database:prepare("DELETE FROM cache WHERE key = ?;")
    delete:exec({ key })
    delete:close()
  end
end

---Get cached data for a query
---@param query_type string Type of query
---@param params? table Optional parameters
---@return table? items Cached items or nil if not found/expired
local function get(query_type, params)
  local config = require("jira.config").options
  if not config.cache.enabled then
    if config.debug then
      vim.notify("[JIRA Cache] Cache disabled in config", vim.log.levels.INFO)
    end
    return nil
  end

  local database = init_db()
  if not database then
    if config.debug then
      vim.notify("[JIRA Cache] Failed to initialize database", vim.log.levels.WARN)
    end
    return nil
  end

  local key = make_key(query_type, params)
  if config.debug then
    vim.notify(string.format("[JIRA Cache] Checking cache for key: %s", key), vim.log.levels.INFO)
  end

  local query = database:prepare("SELECT data, timestamp FROM cache WHERE key = ?;")
  local code = query:exec({ key })

  if code == 100 then -- SQLITE_ROW
    local data = query:col("string", 0)
    local timestamp = query:col("number", 1)
    query:close()

    -- Parse JSON
    local ok, items = pcall(vim.json.decode, data)
    if not ok then
      if config.debug then
        vim.notify(string.format("[JIRA Cache] Invalid JSON for key: %s", key), vim.log.levels.WARN)
      end
      -- Invalid JSON, clear this entry
      clear(query_type, params)
      return nil
    end

    if config.debug then
      vim.notify(string.format("[JIRA Cache] HIT - Found %d items (cached at %s)", #items, os.date("%Y-%m-%d %H:%M:%S", timestamp)), vim.log.levels.INFO)
    end

    return {
      items = items,
      timestamp = timestamp,
      expired = false, -- For now, no expiry logic
    }
  end

  if config.debug then
    vim.notify(string.format("[JIRA Cache] MISS - No cached data for key: %s", key), vim.log.levels.INFO)
  end

  query:close()
  return nil
end

---Set cached data for a query
---@param query_type string Type of query
---@param params? table Optional parameters
---@param items table Items to cache
local function set(query_type, params, items)
  local config = require("jira.config").options
  if not config.cache.enabled then
    return
  end

  local database = init_db()
  if not database then
    return
  end

  local key = make_key(query_type, params)
  local data = vim.json.encode(items)
  local timestamp = os.time()

  if config.debug then
    vim.notify(string.format("[JIRA Cache] Caching %d items for key: %s", #items, key), vim.log.levels.INFO)
  end

  local insert = database:prepare("INSERT OR REPLACE INTO cache (key, data, timestamp) VALUES (?, ?, ?);")
  local code = insert:exec({ key, data, timestamp })

  if code ~= 101 then -- SQLITE_DONE
    vim.notify("Failed to cache JIRA query: " .. query_type, vim.log.levels.WARN)
  else
    if config.debug then
      vim.notify(string.format("[JIRA Cache] Successfully cached data for key: %s", key), vim.log.levels.INFO)
    end
  end

  insert:close()
end

---Close the database connection
local function close()
  if db then
    db:close()
    db = nil
  end
end

-- Setup autocmd to close database on exit
local group = vim.api.nvim_create_augroup("jira_cache", {})
vim.api.nvim_create_autocmd("ExitPre", {
  group = group,
  callback = close,
})

---@class jira.cache
local M = {}
M.get = get
M.set = set
M.clear = clear
M.close = close
M.keys = {
  ISSUES = "issues",
  EPICS = "epics",
  EPIC_ISSUES = "epic_issues",
  ISSUE_VIEW = "issue_view",
  TRANSITIONS = "transitions",
}
return M
