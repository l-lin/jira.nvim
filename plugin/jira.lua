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

vim.api.nvim_create_user_command(
  "JiraStartWorkingOn",
  require("jira").start_working_on,
  { nargs = 1, desc = "Start working on a JIRA issue (assign, sprint, transition, git branch)" }
)
