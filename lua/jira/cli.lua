---Execute a Jira CLI command
---Centralizes debug logging, error handling, and notifications
---@param args table Command arguments (e.g., {"issue", "edit", key, "--summary", title})
---@param opts table? Options table with:
---   - on_success: function(result) Callback on success
---   - on_error: function(result) Callback on error
---   - success_msg: string|function(result) Success notification message
---   - error_msg: string|function(result) Error notification message
---@return table result The vim.system result object
local function execute(args, opts)
  opts = opts or {}

  local config = require("jira.config").options
  local cmd = { config.cli.cmd }
  vim.list_extend(cmd, args)

  -- Debug logging
  if config.debug then
    vim.notify("JIRA CLI Command:\n" .. table.concat(cmd, " "), vim.log.levels.INFO)
  end

  -- Execute command
  local result = vim.system(cmd, { text = true }):wait()

  -- Handle result
  if result.code == 0 then
    -- Success notification
    if opts.success_msg then
      local msg = type(opts.success_msg) == "function" and opts.success_msg(result) or opts.success_msg
      vim.notify(msg, vim.log.levels.INFO)
    end

    -- Success callback
    if opts.on_success then
      opts.on_success(result)
    end
  else
    -- Error notification
    if opts.error_msg then
      local msg = type(opts.error_msg) == "function" and opts.error_msg(result) or opts.error_msg
      local error_detail = result.stderr or "Unknown error"
      vim.notify(string.format("%s: %s", msg, error_detail), vim.log.levels.ERROR)
    end

    -- Error callback
    if opts.on_error then
      opts.on_error(result)
    end
  end

  return result
end

local M = {}
M.execute = execute
return M
