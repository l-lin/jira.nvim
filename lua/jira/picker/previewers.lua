local M = {}

---Strip ANSI color codes from text
---@param text string
---@return string
local function strip_ansi_codes(text)
  return text:gsub("\x1b%[[0-9;]*m", "")
end

---@param ctx snacks.picker.preview.ctx
function M.jira_issue_preview(ctx)
  local item = ctx.item

  if not item or not item.key then
    ctx.preview:reset()
    ctx.preview:notify("No issue selected", "warn")
    return
  end

  local config = require("jira.config").options

  -- Show loading indicator
  ctx.preview:reset()
  ctx.preview:set_title(item.key)
  ctx.preview:notify("Loading issue details...", "info")

  -- Build command
  local cmd = {
    config.cli.cmd,
    "issue",
    "view",
    item.key,
    "--plain",
    "--comments",
    tostring(config.display.preview_comments),
  }

  -- Execute command asynchronously
  vim.system(cmd, { text = true }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      ctx.preview:reset()
      ctx.preview:set_title(item.key)
      ctx.preview:notify("Failed to load issue details", "error")
      return
    end

    -- Strip ANSI codes and split into lines
    local output = strip_ansi_codes(result.stdout or "")
    local lines = vim.split(output, "\n", { trimempty = false })

    -- Set preview content
    ctx.preview:reset()
    ctx.preview:set_title(item.key)
    ctx.preview:set_lines(lines)
  end))
end

return M
