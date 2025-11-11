---@module 'luassert'

-- Mock vim global if not available
if not _G.vim then
  _G.vim = {
    fn = {
      fnamemodify = function(path, mod)
        if mod == ":h" then
          return path:match("(.*/)")
        end
        return path
      end,
      mkdir = function() end,
      stdpath = function(what)
        return "/tmp/test"
      end,
    },
    inspect = function(t)
      return "table"
    end,
    tbl_isempty = function(t)
      return next(t) == nil
    end,
    json = {
      encode = function(t)
        return "json:" .. tostring(t)
      end,
      decode = function(s)
        if s:match("^json:") then
          -- Simple decode for testing
          return {}
        end
        error("Invalid JSON")
      end,
    },
    notify = function() end,
    schedule = function(fn)
      fn()
    end,
    log = {
      levels = {
        INFO = 1,
        WARN = 2,
        ERROR = 3,
      },
    },
    api = {
      nvim_create_augroup = function()
        return 1
      end,
      nvim_create_autocmd = function() end,
    },
  }
end

describe("cache", function()
  local cache
  local mock_db
  local mock_stmt
  local notify_called
  local notify_message

  -- Helper to create mock database
  local function create_mock_db()
    local db_data = {}
    local prepared_stmts = {}

    local function create_stmt(sql)
      local stmt = {
        exec_result = 100, -- SQLITE_ROW by default
        col_data = {},
        sql = sql,
        exec = function(self, params)
          -- Store params for testing
          self.last_params = params
          return self.exec_result
        end,
        col = function(self, type_hint, idx)
          local value = self.col_data[idx]
          if type_hint == "number" and type(value) ~= "number" then
            return tonumber(value) or 0
          end
          return value or ""
        end,
        close = function() end,
      }
      mock_stmt = stmt
      return stmt
    end

    mock_db = {
      exec = function(self, sql)
        self.last_exec_sql = sql
      end,
      prepare = function(self, sql)
        self.last_prepare_sql = sql
        local stmt = create_stmt(sql)
        table.insert(prepared_stmts, { sql = sql, stmt = stmt })
        return stmt
      end,
      close = function(self)
        self.closed = true
      end,
      closed = false,
      last_exec_sql = nil,
      last_prepare_sql = nil,
      prepared_stmts = prepared_stmts,
    }

    return mock_db
  end

  before_each(function()
    -- Clear package cache
    package.loaded["jira.cache"] = nil
    package.loaded["jira.config"] = nil
    package.loaded["snacks.picker.util.db"] = nil

    -- Reset tracking
    notify_called = false
    notify_message = nil

    -- Mock vim.notify
    vim.notify = function(msg, level)
      notify_called = true
      notify_message = msg
    end

    -- Mock snacks.picker.util.db
    package.loaded["snacks.picker.util.db"] = {
      new = function(path, type)
        return create_mock_db()
      end,
    }

    -- Mock config
    package.loaded["jira.config"] = {
      options = {
        cache = {
          enabled = true,
          path = "/tmp/test/cache.sqlite3",
        },
        debug = false,
      },
    }
  end)

  after_each(function()
    package.loaded["jira.cache"] = nil
    package.loaded["jira.config"] = nil
    package.loaded["snacks.picker.util.db"] = nil
  end)

  describe("keys constants", function()
    it("should expose cache key constants", function()
      cache = require("jira.cache")

      assert.are.equal("issues", cache.keys.ISSUES)
      assert.are.equal("epics", cache.keys.EPICS)
      assert.are.equal("epic_issues", cache.keys.EPIC_ISSUES)
    end)
  end)

  describe("set", function()
    it("should cache items with timestamp", function()
      cache = require("jira.cache")
      local items = { { key = "TEST-1" }, { key = "TEST-2" } }

      cache.set("issues", nil, items)

      assert.is_not_nil(mock_db)
      assert.are.equal("INSERT OR REPLACE INTO cache (key, data, timestamp) VALUES (?, ?, ?);", mock_db.last_prepare_sql)
    end)

    it("should not cache when cache is disabled", function()
      local db_created = false
      package.loaded["snacks.picker.util.db"] = {
        new = function()
          db_created = true
          return create_mock_db()
        end,
      }

      package.loaded["jira.config"].options.cache.enabled = false
      cache = require("jira.cache")

      cache.set("issues", nil, { { key = "TEST-1" } })

      -- Database should not be initialized when cache is disabled
      assert.is_false(db_created)
    end)

    it("should generate cache key without params", function()
      cache = require("jira.cache")
      cache.set("issues", nil, {})

      assert.are.equal("issues", mock_stmt.last_params[1])
    end)

    it("should generate cache key with params", function()
      cache = require("jira.cache")
      cache.set("epic_issues", { epic_key = "EPIC-1" }, {})

      assert.are.equal("epic_issues:epic_key=EPIC-1", mock_stmt.last_params[1])
    end)

    it("should generate deterministic key with multiple params", function()
      cache = require("jira.cache")
      cache.set("test", { b = "2", a = "1" }, {})

      -- Params should be sorted alphabetically
      assert.are.equal("test:a=1,b=2", mock_stmt.last_params[1])
    end)

    it("should notify when debug is enabled", function()
      package.loaded["jira.config"].options.debug = true

      -- Create a custom mock db that returns SQLITE_DONE
      package.loaded["snacks.picker.util.db"] = {
        new = function()
          return {
            exec = function() end,
            prepare = function()
              return {
                exec = function() return 101 end, -- SQLITE_DONE
                close = function() end,
              }
            end,
            close = function() end,
          }
        end,
      }

      cache = require("jira.cache")
      cache.set("issues", nil, { { key = "TEST-1" } })

      assert.is_true(notify_called)
      assert.is_true(notify_message:match("Successfully cached") ~= nil)
    end)
  end)

  describe("get", function()
    it("should return nil when cache is disabled", function()
      package.loaded["jira.config"].options.cache.enabled = false
      cache = require("jira.cache")

      local result = cache.get("issues", nil)

      assert.is_nil(result)
    end)

    it("should return nil on cache miss", function()
      cache = require("jira.cache")
      mock_stmt.exec_result = 101 -- Not SQLITE_ROW

      local result = cache.get("issues", nil)

      assert.is_nil(result)
    end)

    it("should return cached data on cache hit", function()
      -- Mock json.decode to return actual data
      local original_decode = vim.json.decode
      vim.json.decode = function(s)
        return { { key = "TEST-1" } }
      end

      -- Create a special mock db that returns our test data
      local test_stmt = {
        exec_result = 100,
        col_data = {
          [0] = 'json:[{"key":"TEST-1"}]',
          [1] = 1234567890,
        },
        last_params = {},
        exec = function(self, params)
          self.last_params = params
          return self.exec_result
        end,
        col = function(self, type_hint, idx)
          local value = self.col_data[idx]
          if type_hint == "number" then
            return tonumber(value) or value
          end
          return value or ""
        end,
        close = function() end,
      }

      package.loaded["snacks.picker.util.db"] = {
        new = function()
          return {
            exec = function() end,
            prepare = function() return test_stmt end,
            close = function() end,
          }
        end,
      }

      cache = require("jira.cache")
      local result = cache.get("issues", nil)

      vim.json.decode = original_decode

      assert.is_not_nil(result)
      assert.is_not_nil(result.items)
      assert.are.equal(1, #result.items)
      assert.are.equal("TEST-1", result.items[1].key)
      assert.are.equal(1234567890, result.timestamp)
      assert.is_false(result.expired)
    end)

    it("should clear entry on invalid JSON", function()
      cache = require("jira.cache")
      mock_stmt.exec_result = 100 -- SQLITE_ROW
      mock_stmt.col_data = {
        [0] = "invalid json",
        [1] = 1234567890,
      }

      local result = cache.get("issues", nil)

      assert.is_nil(result)
      -- Should have called DELETE
      assert.is_not_nil(mock_db.last_prepare_sql)
    end)

    it("should query with correct cache key", function()
      cache = require("jira.cache")

      cache.get("issues", nil)

      -- Check that the SELECT query was prepared
      local found_select = false
      for _, prep in ipairs(mock_db.prepared_stmts) do
        if prep.sql:match("^SELECT") then
          found_select = true
          assert.are.equal("SELECT data, timestamp FROM cache WHERE key = ?;", prep.sql)
          assert.are.equal("issues", prep.stmt.last_params[1])
        end
      end

      assert.is_true(found_select, "SELECT query should have been prepared")
    end)

    it("should query with params in cache key", function()
      cache = require("jira.cache")
      mock_stmt.exec_result = 101

      cache.get("epic_issues", { epic_key = "EPIC-1" })

      assert.are.equal("epic_issues:epic_key=EPIC-1", mock_stmt.last_params[1])
    end)

    it("should notify on cache hit when debug is enabled", function()
      package.loaded["jira.config"].options.debug = true
      cache = require("jira.cache")
      mock_stmt.exec_result = 100
      mock_stmt.col_data = {
        [0] = 'json:[]',
        [1] = 1234567890,
      }

      vim.json.decode = function() return {} end

      cache.get("issues", nil)

      assert.is_true(notify_called)
      assert.is_true(notify_message:match("HIT") ~= nil)

      vim.json.decode = function(s)
        if s:match("^json:") then return {} end
        error("Invalid JSON")
      end
    end)

    it("should notify on cache miss when debug is enabled", function()
      package.loaded["jira.config"].options.debug = true

      -- Create a custom mock db that returns no results (cache miss)
      package.loaded["snacks.picker.util.db"] = {
        new = function()
          return {
            exec = function() end,
            prepare = function()
              return {
                exec = function() return 101 end, -- Not SQLITE_ROW = cache miss
                close = function() end,
              }
            end,
            close = function() end,
          }
        end,
      }

      cache = require("jira.cache")
      cache.get("issues", nil)

      assert.is_true(notify_called)
      assert.is_true(notify_message:match("MISS") ~= nil)
    end)
  end)

  describe("clear", function()
    it("should clear all cache when no query_type provided", function()
      cache = require("jira.cache")

      cache.clear()

      assert.are.equal("DELETE FROM cache;", mock_db.last_exec_sql)
    end)

    it("should clear specific entry when query_type provided", function()
      cache = require("jira.cache")

      cache.clear("issues", nil)

      assert.are.equal("DELETE FROM cache WHERE key = ?;", mock_db.last_prepare_sql)
      assert.are.equal("issues", mock_stmt.last_params[1])
    end)

    it("should clear entry with params", function()
      cache = require("jira.cache")

      cache.clear("epic_issues", { epic_key = "EPIC-1" })

      assert.are.equal("epic_issues:epic_key=EPIC-1", mock_stmt.last_params[1])
    end)

    it("should notify when clearing all cache with debug enabled", function()
      package.loaded["jira.config"].options.debug = true
      cache = require("jira.cache")

      cache.clear()

      assert.is_true(notify_called)
      assert.is_true(notify_message:match("Cache cleared") ~= nil)
    end)

    it("should not notify when debug is disabled", function()
      package.loaded["jira.config"].options.debug = false
      cache = require("jira.cache")

      cache.clear()

      assert.is_false(notify_called)
    end)
  end)

  describe("close", function()
    it("should close database connection", function()
      local close_called = false
      local test_db = nil

      package.loaded["snacks.picker.util.db"] = {
        new = function()
          test_db = {
            exec = function() end,
            prepare = function()
              return {
                exec = function() return 101 end,
                close = function() end,
              }
            end,
            close = function()
              close_called = true
            end,
          }
          return test_db
        end,
      }

      cache = require("jira.cache")

      -- Initialize cache by calling get
      cache.get("issues", nil)

      -- Call close
      cache.close()

      assert.is_true(close_called)
    end)
  end)

  describe("database initialization", function()
    it("should create cache directory if it doesn't exist", function()
      local mkdir_called = false
      local mkdir_path = nil

      vim.fn.mkdir = function(path, flags)
        mkdir_called = true
        mkdir_path = path
      end

      cache = require("jira.cache")
      cache.get("issues", nil)

      assert.is_true(mkdir_called)
      assert.is_not_nil(mkdir_path)
    end)

    it("should create cache table on init", function()
      cache = require("jira.cache")
      cache.get("issues", nil) -- Force init

      assert.is_not_nil(mock_db.last_exec_sql)
      assert.is_true(mock_db.last_exec_sql:match("CREATE TABLE IF NOT EXISTS cache") ~= nil)
    end)

    it("should use config cache path", function()
      local db_path = nil
      package.loaded["snacks.picker.util.db"] = {
        new = function(path, type)
          db_path = path
          return create_mock_db()
        end,
      }

      cache = require("jira.cache")
      cache.get("issues", nil)

      assert.are.equal("/tmp/test/cache.sqlite3", db_path)
    end)

    it("should handle database initialization failure", function()
      package.loaded["snacks.picker.util.db"] = {
        new = function()
          error("Database error")
        end,
      }

      cache = require("jira.cache")
      local result = cache.get("issues", nil)

      assert.is_nil(result)
      assert.is_true(notify_called)
      assert.is_true(notify_message:match("Failed to initialize") ~= nil)
    end)
  end)
end)
