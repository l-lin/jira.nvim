-- Helper function to display the result
---@param ctx snacks.picker.preview.ctx
---@param result snacks.picker.preview.result
local function display_result(ctx, result)
  if not ctx.preview.win:buf_valid() then
    return
  end

  if result.code ~= 0 then
    ctx.preview:reset()
    ctx.preview:set_title(ctx.item.key)
    ctx.preview:notify("Failed to load issue details", "error")
    return
  end

  local markdown = require("jira.markdown")
  local lines = markdown.format_issue(result.stdout or "")

  -- Set preview content
  ctx.preview:reset()
  ctx.preview:set_title(ctx.item.key)
  ctx.preview:set_lines(lines)

  -- Set markdown filetype for syntax highlighting
  vim.bo[ctx.preview.win.buf].filetype = "markdown"

  -- Trigger render-markdown if available
  if package.loaded["render-markdown"] then
    require("render-markdown").render({
      buf = ctx.preview.win.buf,
      event = "JiraPreview",
      config = { render_modes = true },
    })
  end
end

---@param ctx snacks.picker.preview.ctx
local function preview_jira_issue(ctx)
  local item = ctx.item

  if not item or not item.key then
    ctx.preview:reset()
    ctx.preview:notify("No issue selected", "warn")
    return
  end

  local config = require("jira.config").options
  local cli = require("jira.cli")
  local cache = require("jira.cache")

  ctx.preview:reset()
  ctx.preview:set_title(item.key)
  ctx.preview:notify("Loading issue details...", "info")

  if config.cache.enabled then
    local cached = cache.get(cache.keys.ISSUE_VIEW, { key = item.key })
    if cached and cached.items then
      vim.schedule(function()
        display_result(ctx, cached.items)
      end)
      return
    end
  end

  cli.view_issue(item.key, config.preview.nb_comments, function(result)
    if config.cache.enabled then
      cache.set(cache.keys.ISSUE_VIEW, { key = item.key }, result)
    end

    display_result(ctx, result)
  end)
end

local M = {}
M.preview_jira_issue = preview_jira_issue
return M
