---@class jira.CliConfig
---@field cmd string Path to jira CLI binary

---@class jira.QueryConfig
---@field args string[] Default CLI arguments for sprint list
---@field columns string[] Columns to display
---@field filters string[] Default filters for sprint list
---@field order_by string Sort order field
---@field prefill_search string? Prefill the picker search input field

---@class jira.DisplayConfig
---@field type_icons table<string, string> Icons for issue types
---@field type_highlights table<string, string> Highlight groups for issue types
---@field status_highlights table<string, string> Highlight groups for statuses
---@field issue_highlights table<string, string> Highlight groups for issue fields (key, assignee, summary, labels)
---@field action_highlights table<string, string> Highlight groups for action dialog (icon, number, description, fallback)
---@field preview_comments number Number of comments to show in preview (default: 0)

---@class jira.Keymaps
---@field input table<string, string|snacks.win.Keys> Keymaps for input window
---@field list table<string, string|snacks.win.Keys> Keymaps for list window
---@field preview table<string, string|snacks.win.Keys> Keymaps for preview window

---@class jira.Config
---@field cli jira.CliConfig CLI settings
---@field query jira.QueryConfig Query settings
---@field epic jira.QueryConfig Epic query settings
---@field epic_issues jira.QueryConfig Epic issues query settings
---@field display jira.DisplayConfig Display settings
---@field keymaps jira.Keymaps Custom keymaps
---@field debug boolean Enable debug mode to print CLI commands
