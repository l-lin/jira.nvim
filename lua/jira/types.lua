---@class jira.QueryConfig
---@field args string[] Default CLI arguments for sprint list
---@field columns string[] Columns to display
---@field filters string[] Default filters for sprint list
---@field order_by string Sort order field
---@field prefill_search string? Prefill the picker search input field

---@class jira.CliConfig
---@field cmd string Path to jira CLI binary
---@field query jira.QueryConfig Query settings for sprint issues
---@field epic jira.QueryConfig Query settings for epics
---@field epic_issues jira.QueryConfig Query settings for epic issues

---@class jira.UIConfig
---@field type_icons table<string, string> Icons for issue types
---@field type_highlights table<string, string> Highlight groups for issue types
---@field status_highlights table<string, string> Highlight groups for statuses
---@field issue_highlights table<string, string> Highlight groups for issue fields (key, assignee, summary, labels)
---@field action_highlights table<string, string> Highlight groups for action dialog (icon, number, description, fallback)

---@class jira.PreviewConfig
---@field nb_comments number Number of comments to show in preview

---@class jira.Keymaps
---@field input table<string, string|snacks.win.Keys> Keymaps for input window
---@field list table<string, string|snacks.win.Keys> Keymaps for list window
---@field preview table<string, string|snacks.win.Keys> Keymaps for preview window

---@class jira.LayoutConfig
---@field issues table Layout configuration for issues picker
---@field epic_issues table Layout configuration for epic issues picker
---@field epics table Layout configuration for epics picker
---@field actions table Layout configuration for actions picker

---@class jira.Config
---@field cli jira.CliConfig CLI settings
---@field ui jira.UIConfig UI settings
---@field layout jira.LayoutConfig Layout settings
---@field preview jira.PreviewConfig Preview settings
---@field keymaps jira.Keymaps Custom keymaps
---@field debug boolean Enable debug mode to print CLI commands
