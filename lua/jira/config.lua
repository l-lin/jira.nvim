local M = {}

---@type jira.Config
M.defaults = {
  cli = {
    cmd = "jira",
    base_url = nil,
  },

  query = {
    columns = { "type", "key", "assignee", "status", "summary", "labels" },
    filters = { "-s~archive", "-s~done" },
    order_by = "status",
    paginate = "0:100",
  },

  display = {
    type_icons = {
      Bug = "󰃤",
      Story = "",
      Task = "",
      ["Sub-task"] = "",
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
    preview_comments = 10,
  },

  keymaps = {
    open_browser = "<cr>",
    copy_key = "y",
    show_details = "K",
    view_cli = "gv",
    transition = "gt",
  },

  debug = false,
}

---@type jira.Config
M.options = {}

---Setup configuration with user options
---@param opts jira.Config?
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
