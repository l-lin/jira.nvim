local fetchers = require("jira.fetchers")

---@class jira.Buf
---@field buf number
---@field issue_key string
local M = {}
M.__index = M

---@type table<number, jira.Buf>
M.attached = {}
local did_setup = false

---@param buf number
---@param issue_key string
function M.new(buf, issue_key)
  local self = setmetatable({}, M)
  self.buf = buf
  self.issue_key = issue_key

  -- Set buffer metadata
  vim.b[buf].jira_issue_key = issue_key

  -- Configure buffer options
  self:bo()
  self:keys()

  -- Track attached buffers
  M.attached[buf] = self

  vim.schedule(function()
    self:render()
  end)

  return self
end

function M:bo()
  vim.bo[self.buf].buftype = "acwrite"
  vim.bo[self.buf].filetype = "markdown"
  vim.bo[self.buf].modifiable = false
end

function M:valid()
  return self.buf and M.attached[self.buf] == self and vim.api.nvim_buf_is_valid(self.buf)
end

function M:keys()
  vim.keymap.set("n", "<CR>", function()
    local item = { key = self.issue_key }
    require("jira.picker.actions.list_actions").action_jira_list_actions(nil, item, nil)
  end, { buffer = self.buf, desc = "Show actions" })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_buf_delete(self.buf, { force = false })
  end, { buffer = self.buf, desc = "Close buffer" })
end

---@param opts? {force?:boolean}
function M:render(opts)
  if not self:valid() then
    return
  end

  opts = opts or {}

  fetchers.fetch_issue(self.issue_key, function(result, epic)
    self:set_content(result, epic)
  end)
end

---@param result table
---@param epic jira.Epic?
function M:set_content(result, epic)
  if not self:valid() then
    return
  end

  local markdown = require("jira.markdown")
  local lines = markdown.format_issue(result.stdout or "", epic)

  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false
  vim.bo[self.buf].modified = false

  if package.loaded["render-markdown"] then
    require("render-markdown").render({
      buf = self.buf,
      event = "JiraBuffer",
      config = { render_modes = true },
    })
  end
end

---@param buf number
---@param issue_key string
function M.attach(buf, issue_key)
  M.setup()
  local ret = M.attached[buf]
  if ret then
    ret:render({ force = true })
    return ret
  end
  return M.new(buf, issue_key)
end

---@param buf number
function M.detach(buf)
  if not M.attached[buf] then
    return
  end
  M.attached[buf] = nil
end

---Open or focus buffer for issue
---@param issue_key string
function M.open(issue_key)
  -- Check if buffer already exists
  for _, buf_info in ipairs(vim.fn.getbufinfo()) do
    local buf = buf_info.bufnr
    if vim.b[buf].jira_issue_key == issue_key then
      -- Buffer exists, focus it
      local windows = vim.fn.win_findbuf(buf)
      if #windows > 0 then
        vim.api.nvim_set_current_win(windows[1])
      else
        vim.cmd("buffer " .. buf)
      end
      return M.attached[buf]
    end
  end

  -- Create new buffer
  local buf_name = string.format("jira://%s", issue_key)
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, buf_name)
  vim.cmd("buffer " .. buf)

  return M.attach(buf, issue_key)
end

function M.setup()
  if did_setup then
    return
  end
  did_setup = true

  local group = vim.api.nvim_create_augroup("jira.buf", { clear = true })

  -- Attach on BufReadCmd (when buffer is read)
  vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "jira://*",
    group = group,
    callback = function(e)
      vim.schedule(function()
        local buf_name = vim.api.nvim_buf_get_name(e.buf)
        local issue_key = buf_name:match("^jira://(.+)$")
        if not issue_key then
          vim.notify("Invalid jira:// buffer: " .. buf_name, vim.log.levels.ERROR)
          return
        end
        M.attach(e.buf, issue_key)
      end)
    end,
  })

  -- Prevent writes
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    pattern = "jira://*",
    group = group,
    callback = function(e)
      vim.bo[e.buf].modified = false
    end,
  })

  -- Reapply options on window enter
  vim.api.nvim_create_autocmd("BufWinEnter", {
    pattern = "jira://*",
    group = group,
    callback = function(e)
      local buf = M.attached[e.buf]
      if buf then
        buf:bo()
      end
    end,
  })

  -- Cleanup on buffer delete
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    pattern = "jira://*",
    group = group,
    callback = function(ev)
      M.detach(ev.buf)
    end,
  })
end

return M
