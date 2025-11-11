---@module 'luassert'

-- Mock vim global if not available
if not _G.vim then
  _G.vim = {
    list_extend = function(dst, src)
      for _, v in ipairs(src) do
        table.insert(dst, v)
      end
      return dst
    end,
    deepcopy = function(t)
      if type(t) ~= "table" then
        return t
      end
      local copy = {}
      for k, v in pairs(t) do
        if type(v) == "table" then
          copy[k] = vim.deepcopy(v)
        else
          copy[k] = v
        end
      end
      return copy
    end,
    notify = function() end,
    system = function(cmd, opts, callback)
      -- Async mode - call callback immediately
      if callback then
        callback({ code = 0, stdout = "", stderr = "" })
      end
    end,
    schedule = function(fn)
      -- Execute immediately in tests
      fn()
    end,
    validate = function(spec)
      -- Simple validation for tests
      for name, def in pairs(spec) do
        local value, expected_type, optional = def[1], def[2], def[3]
        if not optional and value == nil then
          error(string.format("%s: expected %s, got nil", name, expected_type))
        end
        if value ~= nil and type(value) ~= expected_type then
          error(string.format("%s: expected %s, got %s", name, expected_type, type(value)))
        end
      end
    end,
    log = {
      levels = {
        INFO = 1,
        WARN = 2,
        ERROR = 3,
      },
    },
  }
end

describe("cli", function()
  local cli
  local notify_called
  local notify_message
  local notify_level
  local system_called
  local system_cmd

  before_each(function()
    -- Clear package cache
    package.loaded["jira.cli"] = nil
    package.loaded["jira.config"] = nil
    package.loaded["jira.util"] = nil

    -- Reset tracking
    notify_called = false
    notify_message = nil
    notify_level = nil
    system_called = false
    system_cmd = nil

    -- Mock vim.notify to track calls
    vim.notify = function(msg, level)
      notify_called = true
      notify_message = msg
      notify_level = level
    end

    -- Mock vim.schedule to execute immediately
    vim.schedule = function(fn)
      fn()
    end

    -- Mock vim.system to track calls and execute callback immediately
    vim.system = function(cmd, opts, callback)
      system_called = true
      system_cmd = cmd
      if callback then
        callback({ code = 0, stdout = "output", stderr = "" })
      end
    end

    -- Mock jira.util
    package.loaded["jira.util"] = {
      has_jira_cli = function()
        return true
      end,
    }

    -- Mock config with defaults
    package.loaded["jira.config"] = {
      options = {
        cli = {
          cmd = "jira",
        },
        debug = false,
      },
    }
  end)

  after_each(function()
    -- Clean up
    package.loaded["jira.cli"] = nil
    package.loaded["jira.config"] = nil
    package.loaded["jira.util"] = nil
  end)

  describe("execute", function()
    it("should build and execute command with args", function()
      cli = require("jira.cli")
      cli.execute({ "issue", "view", "PROJ-123" })

      assert.is_true(system_called)
      assert.are.same({ "jira", "issue", "view", "PROJ-123" }, system_cmd)
    end)

    it("should call vim.notify with debug message when debug is enabled", function()
      package.loaded["jira.config"].options.debug = true

      cli = require("jira.cli")
      cli.execute({ "issue", "view", "PROJ-123" })

      assert.is_true(notify_called)
      assert.is_not_nil(notify_message)
      assert.is_true(notify_message:match("JIRA CLI Command") ~= nil)
      assert.are.equal(vim.log.levels.INFO, notify_level)
    end)

    it("should not call vim.notify when debug is disabled", function()
      package.loaded["jira.config"].options.debug = false

      cli = require("jira.cli")
      cli.execute({ "issue", "view", "PROJ-123" })

      -- Should not call notify for debug
      assert.is_false(notify_called)
    end)

    it("should call vim.notify with success message on success", function()
      cli = require("jira.cli")
      cli.execute({ "issue", "view", "PROJ-123" }, {
        success_msg = "Viewed issue successfully",
      })

      assert.is_true(notify_called)
      assert.are.equal("Viewed issue successfully", notify_message)
      assert.are.equal(vim.log.levels.INFO, notify_level)
    end)

    it("should support function for success message", function()
      cli = require("jira.cli")
      cli.execute({ "issue", "view", "PROJ-123" }, {
        success_msg = function(result)
          return "Got output: " .. result.stdout
        end,
      })

      assert.is_true(notify_called)
      assert.are.equal("Got output: output", notify_message)
    end)

    it("should call vim.notify with error message on failure", function()
      vim.system = function(cmd, opts, callback)
        if callback then
          callback({ code = 1, stdout = "", stderr = "Not found" })
        end
      end

      cli = require("jira.cli")
      cli.execute({ "issue", "view", "PROJ-123" }, {
        error_msg = "Failed to view issue",
      })

      assert.is_true(notify_called)
      assert.are.equal("Failed to view issue: Not found", notify_message)
      assert.are.equal(vim.log.levels.ERROR, notify_level)
    end)

    it("should support function for error message", function()
      vim.system = function(cmd, opts, callback)
        if callback then
          callback({ code = 1, stdout = "", stderr = "Not found" })
        end
      end

      cli = require("jira.cli")
      cli.execute({ "issue", "view", "PROJ-123" }, {
        error_msg = function(result)
          return "Command failed with code " .. result.code
        end,
      })

      assert.is_true(notify_called)
      assert.are.equal("Command failed with code 1: Not found", notify_message)
    end)

    it("should call on_success callback on success", function()
      local callback_called = false
      local callback_result = nil

      cli = require("jira.cli")
      cli.execute({ "issue", "view", "PROJ-123" }, {
        on_success = function(result)
          callback_called = true
          callback_result = result
        end,
      })

      assert.is_true(callback_called)
      assert.are.equal(0, callback_result.code)
    end)

    it("should call on_error callback on failure", function()
      vim.system = function(cmd, opts, callback)
        if callback then
          callback({ code = 1, stdout = "", stderr = "Error" })
        end
      end

      local callback_called = false
      local callback_result = nil

      cli = require("jira.cli")
      cli.execute({ "issue", "view", "PROJ-123" }, {
        on_error = function(result)
          callback_called = true
          callback_result = result
        end,
      })

      assert.is_true(callback_called)
      assert.are.equal(1, callback_result.code)
    end)

    it("should handle empty args", function()
      cli = require("jira.cli")
      cli.execute({})

      assert.is_true(system_called)
      assert.are.same({ "jira" }, system_cmd)
    end)

    it("should handle opts being nil", function()
      cli = require("jira.cli")
      cli.execute({ "me" }, nil)

      assert.is_true(system_called)
    end)
  end)

  describe("get_sprint_list_args", function()
    it("should build basic args with default config", function()
      -- Mock config with defaults
      package.loaded["jira.config"] = {
        options = {
          cli = {
            cmd = "jira",
            issues = {
              args = { "sprint", "list", "--current" },
              filters = { "--assignee", "me" },
              order_by = "created",
              columns = { "key", "summary", "status" },
            },
          },
          cache = { enabled = true },
          debug = false,
        },
      }

      cli = require("jira.cli")
      local args = cli.get_sprint_list_args()

      local expected = {
        "sprint",
        "list",
        "--current",
        "--assignee",
        "me",
        "--order-by",
        "created",
        "--csv",
        "--columns",
        "key,summary,status",
      }

      assert.are.same(expected, args)
    end)

    it("should handle custom filters", function()
      package.loaded["jira.config"] = {
        options = {
          cli = {
            cmd = "jira",
            issues = {
              args = { "sprint", "list", "--current" },
              filters = { "--status", "In Progress", "--priority", "High" },
              order_by = "updated",
              columns = { "key", "summary" },
            },
          },
          cache = { enabled = true },
          debug = false,
        },
      }

      cli = require("jira.cli")
      local args = cli.get_sprint_list_args()

      assert.are.equal("--status", args[4])
      assert.are.equal("In Progress", args[5])
      assert.are.equal("--priority", args[6])
      assert.are.equal("High", args[7])
    end)

    it("should handle custom order_by", function()
      package.loaded["jira.config"] = {
        options = {
          cli = {
            cmd = "jira",
            issues = {
              args = { "sprint", "list", "--current" },
              filters = {},
              order_by = "priority",
              columns = { "key" },
            },
          },
          cache = { enabled = true },
          debug = false,
        },
      }

      cli = require("jira.cli")
      local args = cli.get_sprint_list_args()

      local order_idx = nil
      for i, v in ipairs(args) do
        if v == "--order-by" then
          order_idx = i
          break
        end
      end

      assert.is_not_nil(order_idx)
      assert.are.equal("priority", args[order_idx + 1])
    end)

    it("should handle custom columns", function()
      package.loaded["jira.config"] = {
        options = {
          cli = {
            cmd = "jira",
            issues = {
              args = { "sprint", "list", "--current" },
              filters = {},
              order_by = "created",
              columns = { "key", "summary", "assignee", "priority" },
            },
          },
          cache = { enabled = true },
          debug = false,
        },
      }

      cli = require("jira.cli")
      local args = cli.get_sprint_list_args()

      local columns_idx = nil
      for i, v in ipairs(args) do
        if v == "--columns" then
          columns_idx = i
          break
        end
      end

      assert.is_not_nil(columns_idx)
      assert.are.equal("key,summary,assignee,priority", args[columns_idx + 1])
    end)

    it("should call vim.notify when debug is enabled", function()
      package.loaded["jira.config"] = {
        options = {
          cli = {
            cmd = "jira",
            issues = {
              args = { "sprint", "list", "--current" },
              filters = {},
              order_by = "created",
              columns = { "key" },
            },
          },
          cache = { enabled = true },
          debug = true,
        },
      }

      cli = require("jira.cli")
      cli.get_sprint_list_args()

      assert.is_true(notify_called)
      assert.is_not_nil(notify_message)
      assert.is_true(notify_message:match("JIRA CLI Command") ~= nil)
    end)

    it("should not call vim.notify when debug is disabled", function()
      package.loaded["jira.config"] = {
        options = {
          cli = {
            cmd = "jira",
            issues = {
              args = { "sprint", "list", "--current" },
              filters = {},
              order_by = "created",
              columns = { "key" },
            },
          },
          cache = { enabled = true },
          debug = false,
        },
      }

      cli = require("jira.cli")
      cli.get_sprint_list_args()

      assert.is_false(notify_called)
    end)

    it("should handle empty filters", function()
      package.loaded["jira.config"] = {
        options = {
          cli = {
            cmd = "jira",
            issues = {
              args = { "sprint", "list", "--current" },
              filters = {},
              order_by = "created",
              columns = { "key" },
            },
          },
          cache = { enabled = true },
          debug = false,
        },
      }

      cli = require("jira.cli")
      local args = cli.get_sprint_list_args()

      assert.are.equal("sprint", args[1])
      assert.are.equal("list", args[2])
      assert.are.equal("--current", args[3])
      assert.are.equal("--order-by", args[4])
    end)

    it("should error when jira CLI is not available", function()
      -- Mock util to return false
      package.loaded["jira.util"] = {
        has_jira_cli = function()
          return false
        end,
      }

      package.loaded["jira.config"] = {
        options = {
          cli = {
            cmd = "jira",
            issues = {
              args = { "sprint", "list", "--current" },
              filters = {},
              order_by = "created",
              columns = { "key" },
            },
          },
          cache = { enabled = true },
          debug = false,
        },
      }

      cli = require("jira.cli")

      assert.has_error(function()
        cli.get_sprint_list_args()
      end, "JIRA CLI not found. Please install: https://github.com/ankitpokhrel/jira-cli")
    end)
  end)
end)
