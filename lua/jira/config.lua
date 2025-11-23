---@type jira.Config
local defaults = {
  cli = {
    -- Cmd to invoke the Jira CLI tool
    cmd = "jira",

    -- Path to jira CLI config file
    config_path = "~/.config/.jira/.config.yml",

    -- Timeout settings for various operations (increase for slow Jira servers)
    timeout = {
      interactive_initial = 300, -- ms to wait for interactive prompt to render
      interactive_render = 200, -- ms to wait after scrolling before killing job
      issue_open_delay = 500, -- ms to wait before opening newly created issue
    },

    -- Configuration for fetching current sprint issues
    issues = {
      args = { "sprint", "list", "--current" },
      columns = { "type", "key", "assignee", "status", "summary", "labels" },
      filters = { "-s~archive", "-s~done" },
      order_by = "status",
      -- Prefill search prompt, e.g. add your name to pre-filter your assigned issues
      prefill_search = "",
    },

    -- Configuration for listing epics
    epics = {
      args = { "issue", "list", "--type", "Epic" },
      columns = { "key", "summary", "status" },
      filters = { "-s~done", "-s~closed", "-s~archive" },
      order_by = "created",
      prefill_search = "",
    },

    -- Configuration for fetching issues within an epic
    epic_issues = {
      args = { "issue", "list" },
      columns = { "type", "key", "assignee", "status", "summary", "labels" },
      filters = { "-s~archive", "-s~done" },
      order_by = "status",
      prefill_search = "",
    },
  },

  -- Layout configuration for pickers
  -- Set to `nil` to use the default layout.
  -- Use `:help snacks.nvim-picker-layouts` for more customization
  layout = {
    issues = nil,
    epic_issues = nil,
    epics = { preset = "select", layout = { max_width = 120 } },
    actions = { preset = "select", layout = { max_width = 60 } },
    sprints = { preset = "select", layout = { max_width = 60 } },
  },

  -- Actions on issues configuration
  action = {
    -- Action to start working on a issue, which does:
    -- 1. assign the issue to current user
    -- 3. move to active sprint
    -- 3. transition the issue to the configured state
    -- 4. create/change to git branch with the issue key as the branch name
    -- 5. yank the issue key to clipboard
    -- 6. optionally run a user callback when all steps finish
    start_work = {
      -- Transition name to use when calling "Start work" action
      transition = "In Progress",
      -- Configure which steps to execute (all enabled by default)
      steps = {
        assign = true, -- Assign issue to current user
        move_to_sprint = true, -- Move issue to active sprint
        transition = true, -- Transition issue to configured state
        git_branch = true, -- Create/switch to git branch
        yank = true, -- Copy issue key to clipboard
      },
      ---Optional callback invoked after all steps complete
      ---@type jira.StartWorkDoneCallback?
      on_done = nil,
    },
  },

  -- Issue preview configuration
  preview = {
    nb_comments = 10,
  },

  ui = {
    -- Icons displayed for each issue type
    type_icons = {
      Bug = "󰃤",
      Story = "",
      Task = "",
      ["Sub-task"] = "",
      Epic = "󱐋",
      default = "󰄮",
    },
    -- Highlight groups for issue type badges
    type_highlights = {
      Bug = "DiagnosticError",
      Story = "DiagnosticInfo",
      Task = "DiagnosticWarn",
      Epic = "Special",
    },
    -- Highlight groups for status badges
    -- Add your own status mappings as needed
    status_highlights = {
      ["To Do"] = "DiagnosticHint",
      ["In Progress"] = "DiagnosticWarn",
      ["In Review"] = "DiagnosticInfo",
      ["Done"] = "DiagnosticOk",
      ["Blocked"] = "DiagnosticError",
      ["Awaiting Information"] = "Comment",
      ["Triage"] = "DiagnosticInfo",
    },
    -- Highlight groups for issue list fields
    issue_highlights = {
      key = "", -- Issue key (e.g., "PROJ-123")
      assignee = "Identifier", -- Assignee name or "Unassigned"
      summary = "", -- Issue title/summary
      labels = "Comment", -- Issue labels (prefixed with #)
    },
    -- Highlight groups for action dialog items
    action_highlights = {
      icon = "Special", -- Action icon
      number = "Number", -- Action number (e.g., "1.")
      description = "", -- Action description text
      fallback = "", -- Used when action format doesn't match expected pattern
    },
    -- Highlight groups for sprint picker items
    sprint_highlights = {
      name = "", -- Sprint name
      state = "Comment", -- Sprint state (e.g., "active", "future")
    },
    -- Scratch window dimensions
    scratch = {
      width = 160,
      height = 20,
    },
  },

  keymaps = {
    -- Keymaps on Snacks input window
    input = {
      ["<M-y>"] = { "action_jira_copy_key", mode = { "i", "n" } },
      ["<M-t>"] = { "action_jira_transition", mode = { "i", "n" } },
      ["<M-c>"] = { "action_jira_add_comment", mode = { "i", "n" } },
      ["<M-r>"] = { "action_jira_refresh_cache", mode = { "i", "n" } },
      ["<M-s>"] = { "action_jira_edit_summary", mode = { "i", "n" } },
      ["<M-d>"] = { "action_jira_edit_description", mode = { "i", "n" } },
      ["<M-b>"] = { "action_jira_open_in_browser", mode = { "i", "n" } },
    },
    -- Keymaps on Snacks list window
    list = {
      ["<CR>"] = "action_jira_list_actions",
      ["<M-y>"] = "action_jira_copy_key",
      ["<M-t>"] = "action_jira_transition",
      ["<M-c>"] = "action_jira_add_comment",
      ["<M-s>"] = "action_jira_edit_summary",
      ["<M-d>"] = "action_jira_edit_description",
      ["<M-b>"] = "action_jira_open_in_browser",
    },
    -- Keymaps on Snacks preview window
    preview = {
      ["<CR>"] = "action_jira_list_actions",
      ["<M-y>"] = "action_jira_copy_key",
      ["<M-t>"] = "action_jira_transition",
      ["<M-c>"] = "action_jira_add_comment",
      ["<M-s>"] = "action_jira_edit_summary",
      ["<M-d>"] = "action_jira_edit_description",
      ["<M-b>"] = "action_jira_open_in_browser",
    },
  },

  -- Cache configuration
  cache = {
    -- Enable/disable caching of JIRA query results
    enabled = true,
    -- Path to cache database (defaults to Neovim data directory)
    -- path = vim.fn.stdpath("data") .. "/jira/cache.sqlite3",
  },

  -- Flag to enable/disable debug logging
  debug = false,
}

local M = {}

---@type jira.Config
---@diagnostic disable-next-line: missing-fields
M.options = {}

---Setup configuration with user options
---@param opts jira.Config?
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {})
end

return M
