local fetchers = require("jira.fetchers")

local M = {}

---Helper function to display the result
---@param ctx snacks.picker.preview.ctx
---@param result snacks.picker.preview.result
---@param epic jira.Epic? Optional epic info
local function display_result(ctx, result, epic)
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
  local lines = markdown.format_issue(result.stdout or "", epic)

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
function M.preview_jira_issue(ctx)
  local item = ctx.item

  if not item or not item.key then
    ctx.preview:reset()
    ctx.preview:notify("No issue selected", "warn")
    return
  end

  ctx.preview:reset()
  ctx.preview:set_title(item.key)
  ctx.preview:notify("Loading issue details...", "info")

  fetchers.fetch_issue(item.key, function(result, epic)
    display_result(ctx, result, epic)
  end)
end

return M
