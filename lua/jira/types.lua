---@class jira.QueryConfig
---@field args string[] Default CLI arguments for sprint list
---@field columns string[] Columns to display
---@field filters string[] Default filters for sprint list
---@field order_by string Sort order field
---@field prefill_search string? Prefill the picker search input field

---@class jira.CliConfig
---@field cmd string Path to jira CLI binary
---@field issues jira.QueryConfig Query settings for sprint issues
---@field epics jira.QueryConfig Query settings for epics
---@field epic_issues jira.QueryConfig Query settings for epic issues

---@class jira.UIConfig
---@field type_icons table<string, string> Icons for issue types
---@field type_highlights table<string, string> Highlight groups for issue types
---@field status_highlights table<string, string> Highlight groups for statuses
---@field issue_highlights table<string, string> Highlight groups for issue fields (key, assignee, summary, labels)
---@field action_highlights table<string, string> Highlight groups for action dialog (icon, number, description, fallback)
---@field sprint_highlights table<string, string> Highlight groups for sprint fields (state, name)

---@class jira.PreviewConfig
---@field nb_comments number Number of comments to show in preview

---@class jira.Keymaps
---@field input table<string, string|snacks.win.Keys> Keymaps for input window
---@field list table<string, string|snacks.win.Keys> Keymaps for list window
---@field preview table<string, string|snacks.win.Keys> Keymaps for preview window

---@class jira.LayoutConfig
---@field issues table? Layout configuration for issues picker
---@field epic_issues table? Layout configuration for epic issues picker
---@field epics table? Layout configuration for epics picker
---@field actions table? Layout configuration for actions picker
---@field sprints table? Layout configuration for sprints picker

---@class jira.CacheConfig
---@field enabled boolean Enable/disable caching of JIRA query results
---@field path? string Path to cache database (defaults to Neovim data directory)

---@class jira.ActionStartWorkSteps
---@field assign? boolean Enable/disable assigning issue to current user (default: true)
---@field move_to_sprint? boolean Enable/disable moving issue to active sprint (default: true)
---@field transition? boolean Enable/disable transitioning issue to configured state (default: true)
---@field git_branch? boolean Enable/disable creating/switching to git branch (default: true)
---@field yank? boolean Enable/disable copying issue key to clipboard (default: true)

---@class jira.ActionStartWorkConfig
---@field transition string the transition name to change for the issue when executing the action
---@field steps? jira.ActionStartWorkSteps configure which steps to execute (all enabled by default)

---@class jira.ActionConfig
---@field start_work jira.ActionStartWorkConfig Start work action settings

---@class jira.Config
---@field cli jira.CliConfig CLI settings
---@field layout jira.LayoutConfig Layout settings
---@field ui jira.UIConfig UI settings
---@field action jira.ActionConfig Action settings
---@field preview jira.PreviewConfig Preview settings
---@field keymaps jira.Keymaps Custom keymaps
---@field cache jira.CacheConfig Cache settings
---@field debug boolean Enable debug mode to print CLI commands
