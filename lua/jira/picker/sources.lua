local M = {}

local function build_jira_issues()
  local config = require("jira.config").options
  local keymaps = config.keymaps

  return {
    title = "JIRA Issues",
    finder = require("jira.picker.finders").jira_issues,
    format = "jira_issues",
    preview = "jira_issue_preview",
    confirm = "jira_actions",

    win = {
      input = {
        title = "JIRA Issues (Current Sprint)",
        keys = {
          [keymaps.input.copy_key] = "jira_copy_key",
          [keymaps.input.transition] = "jira_transition",
        },
      },
      list = {
        keys = {
          [keymaps.list.actions] = "jira_actions",
          [keymaps.list.copy_key] = "jira_copy_key",
          [keymaps.list.transition] = "jira_transition",
        },
      },
    },
  }
end

M.jira_issues = build_jira_issues()

M.jira_actions = {
  layout = { preset = "select", layout = { max_width = 60 } },
  title = "  Actions",
  main = { current = true },
  finder = require("jira.picker.source_jira").get_actions,
  format = "jira_format_action",
}

return M
