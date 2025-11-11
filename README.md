# jira.nvim

Neovim plugin for browsing and managing JIRA issues with a fuzzy-finding interface.

> This plugin was heavily inspired by the awesome [snacks.nvim gh plugin](https://github.com/folke/snacks.nvim/blob/main/docs/gh.md)!

![showcase](./.github/showcase.png)

## Features

- 🔍 Fuzzy search JIRA issues and epics
- 📝 Rich markdown previews with syntax highlighting
- ⚡ SQLite-based caching for fast performance
- 🎨 Customizable UI (icons, colors, layouts)
- ⌨️ Configurable keymaps
- 🎯 Interactive actions (transition, assign, comment, edit)
- 🔗 Browse issues within epics
- 💾 Smart caching with granular invalidation

## Requirements

- **Neovim** >= 0.11.0
- **[snacks.nvim](https://github.com/folke/snacks.nvim)** - Picker UI framework
- **[jira-cli](https://github.com/ankitpokhrel/jira-cli)** - JIRA CLI tool (must be installed and authenticated)

### Optional

- **[render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)** - Enhanced markdown rendering in previews

## Installation

### lazy.nvim

```lua
{
  "l-lin/jira.nvim",
  dependencies = {
    "folke/snacks.nvim",
    "MeanderingProgrammer/render-markdown.nvim", -- optional
  },
  cmd = { "JiraIssues", "JiraEpic" },
  opts = {},
}
```

## Quick Start

```lua
require("jira").setup({
  -- Default configuration (optional)
})
```

### Commands

- `:JiraIssues` - Open picker for current sprint issues
- `:JiraEpic` - Open epic picker
- `:JiraEpic PROJ-123` - Open issues for specific epic

### Keymaps

**In picker (input mode):**

- `<M-y>` - Copy issue key
- `<M-t>` - Transition issue
- `<M-c>` - Add comment
- `<M-r>` - Refresh cache

**In picker (list mode):**

- `<CR>` - Show actions menu
- `y` - Copy issue key
- `gt` - Transition issue
- `gc` - Add comment
- `<M-r>` - Refresh cache

**In preview:**

- `<CR>` - Show actions menu
- `<M-y>` - Copy issue key
- `<M-t>` - Transition issue
- `<M-c>` - Add comment

## Configuration

<details>
<summary>View default configuration</summary>

```lua
{
  cli = {
    cmd = "jira",  -- CLI command path

    issues = {  -- Current sprint issues
      args = { "sprint", "list", "--current" },
      columns = { "type", "key", "assignee", "status", "summary", "labels" },
      filters = { "-s~archive", "-s~done" },
      order_by = "status",
      prefill_search = "",
    },

    epics = {  -- Epic list
      args = { "issue", "list", "--type", "Epic" },
      columns = { "key", "summary", "status" },
      filters = { "-s~done", "-s~closed", "-s~archive" },
      order_by = "created",
      prefill_search = "",
    },

    epic_issues = {  -- Issues within epic
      args = { "issue", "list" },
      columns = { "type", "key", "assignee", "status", "summary", "labels" },
      filters = { "-s~archive", "-s~done" },
      order_by = "status",
      prefill_search = "",
    },
  },

  layout = {  -- Picker layouts
    issues = nil,
    epic_issues = nil,
    epics = { preset = "select", layout = { max_width = 120 } },
    actions = { preset = "select", layout = { max_width = 60 } },
  },

  preview = {
    nb_comments = 10,  -- Number of comments in preview
  },

  ui = {
    type_icons = {
      Bug = "󰃤",
      Story = "",
      Task = "",
      ["Sub-task"] = "",
      Epic = "󱐋",
      default = "󰄮",
    },

    type_highlights = {
      Bug = "DiagnosticError",
      Story = "DiagnosticInfo",
      Task = "DiagnosticWarn",
      Epic = "Special",
    },

    status_highlights = {
      ["To Do"] = "DiagnosticHint",
      ["In Progress"] = "DiagnosticWarn",
      ["In Review"] = "DiagnosticInfo",
      ["Done"] = "DiagnosticOk",
      ["Blocked"] = "DiagnosticError",
      ["Awaiting Information"] = "Comment",
      ["Triage"] = "DiagnosticInfo",
    },

    issue_highlights = {
      key = "",
      assignee = "Identifier",
      summary = "",
      labels = "Comment",
    },

    action_highlights = {
      icon = "Special",
      number = "Number",
      description = "",
      fallback = "",
    },
  },

  keymaps = {
    input = {
      ["<M-y>"] = { "action_jira_copy_key", mode = { "i", "n" } },
      ["<M-t>"] = { "action_jira_transition", mode = { "i", "n" } },
      ["<M-c>"] = { "action_jira_add_comment", mode = { "i", "n" } },
      ["<M-r>"] = { "action_jira_refresh_cache", mode = { "i", "n" } },
    },
    list = {
      ["<CR>"] = "action_jira_list_actions",
      ["y"] = "action_jira_copy_key",
      ["gt"] = "action_jira_transition",
      ["gc"] = "action_jira_add_comment",
      ["<M-r>"] = "action_jira_refresh_cache",
    },
    preview = {
      ["<CR>"] = "action_jira_list_actions",
      ["<M-y>"] = "action_jira_copy_key",
      ["<M-t>"] = "action_jira_transition",
      ["<M-c>"] = "action_jira_add_comment",
    },
  },

  cache = {
    enabled = true,
    -- path = vim.fn.stdpath("data") .. "/jira/cache.sqlite3",  -- Optional
  },

  debug = false,
}
```

</details>

## Actions

When you press `<CR>` on an issue, you get the following actions:

1. **Open in browser** - Opens issue in default browser
2. **Copy key** - Yanks issue key to clipboard
3. **Transition** - Change issue status
4. **Assign to me** - Assigns issue to you
5. **Unassign** - Removes assignee
6. **Edit summary** - Edit issue title
7. **Edit description** - Edit issue description (markdown)
8. **Add comment** - Add comment (markdown)

## Customization Examples

### Filter to your assigned issues

```lua
require("jira").setup({
  cli = {
    issues = {
      filters = { "-s~archive", "-s~done", "--assignee", "me" },
    },
  },
})
```

### Add custom keymaps

```lua
require("jira").setup({
  keymaps = {
    list = {
      ["<C-b>"] = "action_jira_open_browser",
      ["<C-a>"] = "action_jira_assign_me",
    },
  },
})
```

### Customize status highlights

```lua
require("jira").setup({
  ui = {
    status_highlights = {
      ["Ready for Review"] = "DiagnosticInfo",
      ["Waiting for Deploy"] = "DiagnosticWarn",
    },
  },
})
```

### Pre-fill search query

```lua
require("jira").setup({
  cli = {
    issues = {
      prefill_search = "To Do",
    },
  },
})
```

## Cache Management

The plugin uses SQLite to cache JIRA data for better performance:

- Cache location: `~/.local/share/nvim/jira/cache.sqlite3`
- Refresh cache: `<M-r>` (default keymap) in picker or manually via actions
- Clear cache: Delete the SQLite file

Cached data includes:

- Sprint issues
- Epic lists
- Issue previews
- Available transitions (per project)

## Health Check

Run `:checkhealth jira` to verify:

- Neovim version
- snacks.nvim installation
- jira CLI availability
- SQLite support

## Troubleshooting

### "jira CLI not found"

Ensure [jira-cli](https://github.com/ankitpokhrel/jira-cli) is installed and in your PATH:

```bash
jira version
```

### "Failed to load issue details"

- Check jira CLI is configured: `jira init`
- Verify you have access to the project
- Try refreshing cache with `<M-r>`

### Previews not rendering markdown

Install [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) for enhanced rendering.

## Lua API

```lua
-- Setup plugin
require("jira").setup(opts)

-- Open issues picker
require("jira").open_jira_issues()

-- Open epic picker
require("jira").open_jira_epic()

-- Open specific epic's issues
require("jira").open_jira_epic("PROJ-123")
```

## License

MIT
