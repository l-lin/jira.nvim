local M = {}

M.jira_issues = {
  finder = require("jira.picker.finders").jira_issues,
  format = "jira_issues",
  preview = "jira_issue_preview",
  confirm = "jira_actions",

  win = {
    input = {
      title = "JIRA Issues (Current Sprint)",
    },
    list = {
      keys = {
        ["<CR>"] = "jira_actions",
        ["y"] = "jira_copy_key",
        ["Y"] = "jira_copy_key",
        ["K"] = "jira_show_details",
        ["gv"] = "jira_view_cli",
        ["gt"] = "jira_transition",
      },
    },
  },
}

M.jira_actions = {
  layout = { preset = "select", layout = { max_width = 60 } },
  title = "  Actions",
  main = { current = true },
  finder = require("jira.picker.source_jira").get_actions,
  format = "jira_format_action",
}

return M
