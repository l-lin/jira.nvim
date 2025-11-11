vim.api.nvim_create_user_command(
  "JiraIssues",
  require("jira").open_jira_issues,
  { desc = "Open JIRA issues picker for current sprint" }
)

vim.api.nvim_create_user_command(
  "JiraEpic",
  require("jira").open_jira_epic,
  { nargs = "?", desc = "Open JIRA epic issues (or select epic if no arg provided)" }
)
