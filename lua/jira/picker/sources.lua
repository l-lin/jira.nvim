local M = {}

M.jira_issues = {
  finder = require("jira.picker.finders").jira_issues,
  format = "jira_issues",
  preview = "jira_issue_preview",
  live = false,
  limit = math.huge,

  win = {
    input = {
      title = "JIRA Issues (Current Sprint)",
      keys = {
        ["<C-r>"] = "refresh",
      },
    },
    list = {
      keys = {
        ["<CR>"] = "jira_open_browser",
        ["y"] = "jira_copy_key",
        ["Y"] = "jira_copy_key",
        ["K"] = "jira_show_details",
        ["gv"] = "jira_view_cli",
        ["gt"] = "jira_transition",
      },
    },
  },
}

return M
