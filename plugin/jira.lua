vim.api.nvim_create_user_command(
  "JiraIssues",
  require("jira").issues,
  { desc = "Open JIRA issues picker for current sprint" }
)
