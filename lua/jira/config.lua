local M = {}

---@type jira.Config
M.defaults = {
  cli = {
    -- Cmd to invoke the Jira CLI tool
    cmd = "jira",
  },

  -- Configuration for fetching current sprint issues
  query = {
    args = { "sprint", "list", "--current" },
    columns = { "type", "key", "assignee", "status", "summary", "labels" },
    filters = { "-s~archive", "-s~done" },
    order_by = "status",
    -- Prefill search prompt, e.g. add your current name
    prefill_search = "",
  },

  -- Configuration for listing epics
  epic = {
    args = { "issue", "list", "--type", "Epic" },
    columns = { "key", "summary", "status" },
    filters = { "-s~done", "-s~closed", "-s~archive" },
    order_by = "created",
    prefill_search = "",
  },

  -- Configuration for fetching issues within an epic
  epic_issues = {
    args = { "issue", "list" },
    columns = { "type", "key", "assignee", "status", "summary", "labels" },
    filters = { "-s~archive", "-s~done" },
    order_by = "status",
    prefill_search = "",
  },

  display = {
    -- Icons displayed for each issue type
    type_icons = {
      Bug = "󰃤",
      Story = "",
      Task = "",
      ["Sub-task"] = "",
      Epic = "󱐋",
      default = "󰄮",
    },
    -- Highlight groups for issue type badges
    type_highlights = {
      Bug = "DiagnosticError",
      Story = "DiagnosticInfo",
      Task = "DiagnosticWarn",
      Epic = "Special",
    },
    -- Highlight groups for status badges
    -- Add your own status mappings as needed
    status_highlights = {
      ["To Do"] = "DiagnosticHint",
      ["In Progress"] = "DiagnosticWarn",
      ["In Review"] = "DiagnosticInfo",
      ["Done"] = "DiagnosticOk",
      ["Blocked"] = "DiagnosticError",
      ["Awaiting Information"] = "Comment",
      ["Triage"] = "DiagnosticInfo",
    },
    -- Highlight groups for issue list fields
    issue_highlights = {
      key = "", -- Issue key (e.g., "PROJ-123")
      assignee = "Identifier", -- Assignee name or "Unassigned"
      summary = "", -- Issue title/summary
      labels = "Comment", -- Issue labels (prefixed with #)
    },
    -- Highlight groups for action dialog items
    action_highlights = {
      icon = "Special", -- Action icon
      number = "Number", -- Action number (e.g., "1.")
      description = "", -- Action description text
      fallback = "", -- Used when action format doesn't match expected pattern
    },
    -- Number of comments to display in issue preview
    preview_comments = 10,
  },

  keymaps = {
    -- Keymaps on Snacks input window
    input = {
      ["<M-y>"] = { "action_jira_copy_key", mode = { "i", "n" } },
      ["<M-m>"] = { "action_jira_transition", mode = { "i", "n" } },
      ["<M-c>"] = { "action_jira_add_comment", mode = { "i", "n" } },
    },
    -- Keymaps on Snacks list window
    list = {
      ["<CR>"] = "action_jira_list_actions",
      ["y"] = "action_jira_copy_key",
      ["gt"] = "action_jira_transition",
      ["gc"] = "action_jira_add_comment",
    },
    -- Keymaps on Snacks preview window
    preview = {
      ["<CR>"] = "action_jira_list_actions",
      ["<M-c>"] = "action_jira_add_comment",
    },
  },

  -- Flag to enable/disable debug logging
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
