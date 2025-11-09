---@class jira.CliConfig
---@field cmd string Path to jira CLI binary
---@field base_url? string JIRA instance base URL (auto-detected if nil)

---@class jira.QueryConfig
---@field columns string[] Columns to display
---@field filters string[] Default filters for sprint list
---@field order_by string Sort order field
---@field paginate string Pagination format (e.g., "0:100")

---@class jira.DisplayConfig
---@field type_icons table<string, string> Icons for issue types
---@field type_highlights table<string, string> Highlight groups for issue types
---@field status_highlights table<string, string> Highlight groups for statuses
---@field preview_comments number Number of comments to show in preview (default: 0)

---@class jira.Config
---@field cli jira.CliConfig CLI settings
---@field query jira.QueryConfig Query settings
---@field display jira.DisplayConfig Display settings
---@field keymaps table<string, string> Custom keymaps
---@field debug boolean Enable debug mode to print CLI commands
