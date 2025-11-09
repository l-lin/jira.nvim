local M = {}

---@type jira.Config
M.defaults = {
  jira_cmd = "jira",
  jira_base_url = nil,
  columns = { "type", "key", "assignee", "status", "summary", "labels" },
  filters = { "-s~archive", "-s~done" },
  order_by = "status",
  paginate = "0:100",
  debug = false,
  type_icons = {
    Bug = "󰃤",
    Story = "",
    Task = "",
    ["Sub-task"] = "",
    Epic = "󱐋",
    default = "󰄮",
  },
  type_highlights = {
    Bug = "DiagnosticError",
    Story = "DiagnosticInfo",
    Task = "DiagnosticWarn",
    Epic = "Special",
  },
  status_highlights = {
    ["To Do"] = "DiagnosticHint",
    ["In Progress"] = "DiagnosticWarn",
    ["In Review"] = "DiagnosticInfo",
    ["Done"] = "DiagnosticOk",
    ["Blocked"] = "DiagnosticError",
    ["Awaiting Information"] = "Comment",
    ["Triage"] = "DiagnosticInfo",
  },
  keymaps = {
    open_browser = "<cr>",
    copy_key = "y",
    show_details = "K",
    view_cli = "gv",
    transition = "gt",
  },
}

---@type jira.Config
M.options = {}

---Setup configuration with user options
---@param opts jira.Config?
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
