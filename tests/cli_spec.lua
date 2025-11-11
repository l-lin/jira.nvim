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
        copy[k] = vim.deepcopy(v)
      end
      return copy
    end,
    notify = function() end,
    system = function()
      return {
        wait = function()
          return { code = 0, stdout = "", stderr = "" }
        end,
      }
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

    -- Mock vim.system to track calls
    vim.system = function(cmd, opts)
      system_called = true
      system_cmd = cmd
      return {
        wait = function()
          return { code = 0, stdout = "output", stderr = "" }
        end,
      }
    end

    -- Mock config with defaults
    package.loaded["jira.config"] = {
      options = {
        cli = {
          cmd = "jira",
          args = {},
        },
        debug = false,
      },
    }
  end)

  after_each(function()
    -- Clean up
    package.loaded["jira.cli"] = nil
    package.loaded["jira.config"] = nil
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
      vim.system = function(cmd, opts)
        return {
          wait = function()
            return { code = 1, stdout = "", stderr = "Not found" }
          end,
        }
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
      vim.system = function(cmd, opts)
        return {
          wait = function()
            return { code = 1, stdout = "", stderr = "Not found" }
          end,
        }
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
      vim.system = function(cmd, opts)
        return {
          wait = function()
            return { code = 1, stdout = "", stderr = "Error" }
          end,
        }
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

    it("should return result object", function()
      cli = require("jira.cli")
      local result = cli.execute({ "issue", "view", "PROJ-123" })

      assert.is_not_nil(result)
      assert.are.equal(0, result.code)
      assert.are.equal("output", result.stdout)
    end)

    it("should handle empty args", function()
      cli = require("jira.cli")
      cli.execute({})

      assert.is_true(system_called)
      assert.are.same({ "jira" }, system_cmd)
    end)

    it("should handle opts being nil", function()
      cli = require("jira.cli")
      local result = cli.execute({ "me" }, nil)

      assert.is_not_nil(result)
      assert.are.equal(0, result.code)
    end)
  end)
end)
