# jira.nvim

Neovim plugin for browsing and managing JIRA issues with a fuzzy-finding interface.

> This plugin was heavily inspired by the awesome [snacks.nvim gh plugin](https://github.com/folke/snacks.nvim/blob/main/docs/gh.md)!

![showcase](./.github/showcase.png)

## Features

- 🔍 Fuzzy search JIRA issues and epics
- ➕ Create new issues with epic and sprint association
- 📝 Rich markdown previews with syntax highlighting
- 📄 View issues in dedicated read-only buffers
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
  cmd = { "JiraIssues", "JiraEpic", "JiraStartWorkingOn" },
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
- `:JiraStartWorkingOn PROJ-123` - Start working on an issue (assign, move to sprint, transition, create git branch, yank key)

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

[View default configuration](./lua/jira/config.lua)

## Actions

When you press `<CR>` on an issue, you get the following actions:

1. **Open in browser** - Opens issue in default browser
1. **View issue in buffer** - View issue in a dedicated read-only markdown buffer (inherits your default settings)
1. **Start work on issue** - Assign to you, move to active sprint, transition, create git branch, yank key
1. **Copy key** - Yanks issue key to clipboard
1. **Copy URL** - Yanks issue URL to clipboard
1. **Transition** - Change issue status
1. **Assign to me** - Assigns issue to you
1. **Unassign** - Removes assignee
1. **Create issue** - Create a new JIRA issue with type selection, markdown description editor, optional epic association, and optional sprint assignment
1. **Move issue to sprint** - Move the issue to a sprint
1. **Add issue to epic** - Link the issue to a parent epic
1. **Remove issue from epic** - Unlink the issue from its epic
1. **Add/edit labels** - Add or modify issue labels (comma-separated)
1. **Edit summary** - Edit issue title
1. **Edit description** - Edit issue description (markdown)
1. **Add comment** - Add comment (markdown)

### Creating Issues

The **Create issue** action provides a guided workflow:

1. **Select issue type** - Choose from Bug, Story, Task, or Epic
2. **Enter summary** - Provide the issue title
3. **Write description** - Edit in a markdown scratch buffer (press `<c-s>` to submit)
4. **Associate to epic** (optional) - Link to a parent epic
5. **Move to sprint** (optional) - Assign to active or future sprint
6. **Auto-open** - Created issue automatically opens in a buffer

The action filters epics by status (In Progress, To Do, Open, New) and sprints by state (active, future) to show only relevant options.

### Buffer View Keymaps

When viewing an issue in a buffer (`jira://ISSUE-KEY`):

- `<CR>` - Show actions menu
- `q` - Close buffer

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
      ["<C-b>"] = "action_jira_open_in_browser",
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

### Customize "Start Work" action

```lua
require("jira").setup({
  action = {
    start_work = {
      -- Change the transition state for "Start Work" action
      transition = "In Progress",
      -- Configure which steps to execute (all enabled by default)
      steps = {
        assign = true,         -- Assign issue to current user
        move_to_sprint = true, -- Move issue to active sprint
        transition = true,     -- Transition issue to configured state
        git_branch = true,     -- Create/switch to git branch
        yank = true,           -- Copy issue key to clipboard
      },
      -- Optional callback invoked after all steps complete
      on_done = function(ctx)
        vim.notify("Starting to work on " .. ctx.item.key, vim.log.levels.INFO)
      end,
    },
  },
})
```

You can disable any step by setting it to `false`. For example, to skip git branch creation:

```lua
require("jira").setup({
  action = {
    start_work = {
      transition = "In Progress",
      steps = {
        git_branch = false, -- Disable git branch creation
      },
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
- Epics
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

-- Start working on issue
require("jira").start_working_on({ fargs = { "PROJ-123" } })

-- Open issue in buffer
require("jira.buf").open("PROJ-123")
```

## License

MIT
