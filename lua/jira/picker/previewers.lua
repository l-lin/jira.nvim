---@param ctx snacks.picker.preview.ctx
local function preview_jira_issue(ctx)
  local item = ctx.item

  if not item or not item.key then
    ctx.preview:reset()
    ctx.preview:notify("No issue selected", "warn")
    return
  end

  local config = require("jira.config").options
  local markdown = require("jira.markdown")

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
    -- Validate preview is still valid
    if not ctx.preview.win:buf_valid() then
      return
    end

    if result.code ~= 0 then
      ctx.preview:reset()
      ctx.preview:set_title(item.key)
      ctx.preview:notify("Failed to load issue details", "error")
      return
    end

    -- Convert to markdown
    local lines = markdown.format_issue(result.stdout or "")

    -- Set preview content
    ctx.preview:reset()
    ctx.preview:set_title(item.key)
    ctx.preview:set_lines(lines)

    -- Set markdown filetype for syntax highlighting
    vim.bo[ctx.preview.win.buf].filetype = "markdown"
  end))
end

local M = {}
M.preview_jira_issue = preview_jira_issue
return M
