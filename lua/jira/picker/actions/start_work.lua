local cli = require("jira.cli")
local git = require("jira.git")

local CLIPBOARD_REG = "+"
local DEFAULT_REG = '"'

local M = {}

---Validates that item has a key
---@param item snacks.picker.Item
---@return boolean valid True if item has key, false otherwise
local function validate_item_key(item)
  if not item.key then
    vim.notify("No issue key available", vim.log.levels.WARN)
    return false
  end
  return true
end

---Clear issue-related caches
---@param issue_key string
local function clear_issue_caches(issue_key)
  local cache = require("jira.cache")
  cache.clear(cache.keys.ISSUE_VIEW, { key = issue_key })
  cache.clear(cache.keys.ISSUES)
  cache.clear(cache.keys.EPIC_ISSUES)
end

---Get sprints with caching (imported from actions module)
---@param callback fun(sprints: table[]?)
local function get_sprints_cached(callback)
  -- Import dynamically to avoid circular dependency
  local actions = require("jira.picker.actions")
  actions.get_sprints_cached(callback)
end

---Sanitize text for branch name (replace spaces with underscores, remove special chars)
---@param text string
---@return string
local function sanitize_for_branch(text)
  if not text or text == "" then
    return ""
  end
  -- Replace spaces with underscores, remove special characters (keep alphanumeric, underscores, hyphens)
  return text:gsub("%s+", "_"):gsub("[^%w_-]", "")
end

---Generate suggested branch name from issue key and summary
---@param issue_key string
---@param summary string?
---@return string
local function generate_branch_name(issue_key, summary)
  if not summary or summary == "" then
    return issue_key
  end
  local sanitized = sanitize_for_branch(summary)
  if sanitized == "" then
    return issue_key
  end
  return string.format("%s-%s", issue_key, sanitized)
end

---Start work on issue (assign, sprint, transition, git branch, yank)
---@param picker snacks.Picker?
---@param item snacks.picker.Item
---@param action snacks.picker.Action?
function M.action_jira_start_work(picker, item, action)
  if not validate_item_key(item) then
    return
  end

  local config = require("jira.config").options
  local transition = config.action.start_work.transition

  if not transition or transition == "" then
    vim.notify("action.start_work.transition not configured", vim.log.levels.WARN)
    return
  end

  local steps = vim.tbl_extend("force", {
    assign = true,
    move_to_sprint = true,
    transition = true,
    git_branch = true,
    yank = true,
  }, config.action.start_work.steps or {})

  local total_steps = 0
  for _, enabled in pairs(steps) do
    if enabled then
      total_steps = total_steps + 1
    end
  end

  local errors = {}
  local successes = {}
  local completed_steps = 0

  local function step_done(step_name, err, success_msg)
    completed_steps = completed_steps + 1

    if err then
      table.insert(errors, string.format("%s: %s", step_name, err))
    elseif success_msg then
      table.insert(successes, string.format("%s: %s", step_name, success_msg))
    end

    if completed_steps == total_steps then
      -- Show final result
      if #errors > 0 then
        local msg = string.format("Completed with errors:\n%s", table.concat(errors, "\n"))
        if #successes > 0 then
          msg = msg .. string.format("\n\nSucceeded:\n%s", table.concat(successes, "\n"))
        end
        vim.notify(msg, vim.log.levels.WARN)
      else
        vim.notify(string.format("Started working on %s", item.key), vim.log.levels.INFO)
      end

      clear_issue_caches(item.key)
      if picker then
        picker:refresh()
      end
    end
  end

  -- Step 1: Assign to current user
  if steps.assign then
    cli.get_current_user({
      error_msg = false,
      on_success = function(result)
        local me = vim.trim(result.stdout or "")
        cli.assign_issue(item.key, me, {
          error_msg = false,
          on_success = function()
            step_done("Assign", nil, "assigned to you")
          end,
          on_error = function(err_result)
            step_done("Assign", err_result.stderr or "Unknown error")
          end,
        })
      end,
      on_error = function(result)
        step_done("Assign", result.stderr or "Failed to get current user")
      end,
    })
  end

  -- Step 2: Move to active sprint
  if steps.move_to_sprint then
    get_sprints_cached(function(sprints)
      if not sprints or #sprints == 0 then
        step_done("Move to sprint", nil, "skipped (no sprints)")
        return
      end

      local active = vim.tbl_filter(function(s)
        return s.state == "active"
      end, sprints)

      if #active == 0 then
        step_done("Move to sprint", nil, "skipped (no active sprint)")
        return
      end

      cli.move_issue_to_sprint(item.key, active[1].id, {
        error_msg = false,
        on_success = function()
          step_done("Move to sprint", nil, string.format("moved to %s", active[1].name))
        end,
        on_error = function(result)
          step_done("Move to sprint", result.stderr or "Unknown error")
        end,
      })
    end)
  end

  -- Step 3: Transition to configured state
  if steps.transition then
    cli.transition_issue(item.key, transition, {
      error_msg = false,
      on_success = function()
        step_done("Transition", nil, string.format("transitioned to %s", transition))
      end,
      on_error = function(result)
        step_done("Transition", result.stderr or "Unknown error")
      end,
    })
  end

  -- Step 4: Git branch
  if steps.git_branch then
    if not git.is_git_repo() then
      step_done("Git branch", nil, "skipped (not in git repo)")
    else
      local suggested_branch = generate_branch_name(item.key, item.summary)
      vim.ui.input({
        prompt = "Branch name: ",
        default = suggested_branch,
      }, function(branch_name)
        if not branch_name or branch_name == "" then
          step_done("Git branch", nil, "skipped (cancelled)")
          return
        end
        git.switch_branch(branch_name, function(err, mode)
          if err then
            step_done("Git branch", err)
          else
            step_done("Git branch", nil, string.format("branch %s", mode))
          end
        end)
      end)
    end
  end

  -- Step 5: Yank issue key
  if steps.yank then
    vim.schedule(function()
      vim.fn.setreg(CLIPBOARD_REG, item.key)
      vim.fn.setreg(DEFAULT_REG, item.key)
      step_done("Yank", nil, "copied to clipboard")
    end)
  end
end

-- Expose private functions for testing
M._sanitize_for_branch = sanitize_for_branch
M._generate_branch_name = generate_branch_name

return M
