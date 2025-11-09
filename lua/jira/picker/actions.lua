local M = {}

--- Open issue in browser
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
function M.jira_open_browser(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  local util = require("jira.util")
  local base_url = util.get_jira_base_url()
  local url = string.format("%s/browse/%s", base_url, item.key)

  -- Use vim.ui.open (Neovim 0.10+)
  local ok, err = pcall(vim.ui.open, url)
  if not ok then
    vim.notify(string.format("Failed to open URL: %s", err), vim.log.levels.ERROR)
  else
    vim.notify(string.format("Opened %s in browser", item.key), vim.log.levels.INFO)
  end
end

--- Copy issue key to clipboard
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
function M.jira_copy_key(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  -- Copy to system clipboard
  vim.fn.setreg("+", item.key)

  -- Also copy to unnamed register
  vim.fn.setreg('"', item.key)

  vim.notify(string.format("Copied %s to clipboard", item.key), vim.log.levels.INFO)
end

--- Show full issue details in floating window
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
function M.jira_show_details(picker, item, action)
  local lines = {
    "# " .. (item.key or "Unknown"),
    "",
    "**Type**: " .. (item.type or "Unknown"),
    "**Assignee**: " .. (item.assignee or "Unassigned"),
    "**Status**: " .. (item.status or "Unknown"),
    "**Labels**: " .. (item.labels or "None"),
    "",
    "## Summary",
    item.summary or "No summary available",
  }

  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Issue Details ",
    title_pos = "center",
  })

  -- Close on q or <Esc>
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, nowait = true })
end

--- View issue in jira CLI
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
function M.jira_view_cli(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  local config = require("jira.config").options

  -- Open in terminal
  vim.cmd("tabnew")
  vim.fn.termopen({ config.jira_cmd, "issue", "view", item.key }, {
    on_exit = function(_, code)
      if code ~= 0 then
        vim.notify("Failed to view issue", vim.log.levels.ERROR)
      end
    end,
  })
end

--- Transition issue to different status
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
function M.jira_transition(picker, item, action)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return
  end

  -- Get available transitions
  local config = require("jira.config").options
  local cmd = { config.jira_cmd, "issue", "transitions", item.key, "--plain" }

  if config.debug then
    vim.notify("JIRA CLI Command:\n" .. table.concat(cmd, " "), vim.log.levels.INFO)
  end

  local result = vim.system(cmd, { text = true }):wait()

  if result.code ~= 0 then
    vim.notify("Failed to fetch transitions", vim.log.levels.ERROR)
    return
  end

  -- Parse transitions and show picker
  local transitions = vim.split(result.stdout, "\n", { trimempty = true })

  if #transitions == 0 then
    vim.notify("No transitions available", vim.log.levels.INFO)
    return
  end

  vim.ui.select(transitions, {
    prompt = "Select transition:",
  }, function(choice)
    if not choice then
      return
    end

    -- Execute transition
    local move_cmd = { config.jira_cmd, "issue", "move", item.key, choice }

    if config.debug then
      vim.notify("JIRA CLI Command:\n" .. table.concat(move_cmd, " "), vim.log.levels.INFO)
    end

    local transition_result = vim.system(move_cmd, { text = true }):wait()

    if transition_result.code == 0 then
      vim.notify(string.format("Transitioned %s to %s", item.key, choice), vim.log.levels.INFO)
      -- Refresh picker
      picker:refresh()
    else
      vim.notify("Failed to transition issue", vim.log.levels.ERROR)
    end
  end)
end

return M
