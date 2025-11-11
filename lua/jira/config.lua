local M = {}

---@type jira.Config
M.defaults = {
  cli = {
    cmd = "jira",
  },

  query = {
    args = { "sprint", "list", "--current" },
    columns = { "type", "key", "assignee", "status", "summary", "labels" },
    filters = { "-s~archive", "-s~done" },
    order_by = "status",
    prefill_search = "",
  },

  display = {
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
    issue_highlights = {
      key = "Identifier",
      assignee = "Identifier",
      summary = "Identifier",
      labels = "Comment",
    },
    action_highlights = {
      icon = "Special",
      number = "Number",
      description = "Normal",
      fallback = "Normal",
    },
    preview_comments = 10,
  },

  keymaps = {
    input = {
      copy_key = "<M-y>",
      transition = "<M-m>",
    },
    list = {
      actions = "<CR>",
      copy_key = "y",
      transition = "gt",
    },
  },

  debug = false,
}

---@type jira.Config
---@diagnostic disable-next-line: missing-fields
M.options = {}

---Setup configuration with user options
---@param opts jira.Config?
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
