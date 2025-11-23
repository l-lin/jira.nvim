local cache = require("jira.cache")
local cli = require("jira.cli")
local git = require("jira.git")

local CLIPBOARD_REG = "+"
local DEFAULT_REG = '"'

local M = {}

---Get sprints with caching (imported from actions module)
---@param callback fun(sprints: table[]?)
local function get_sprints(callback)
  local cached = cache.get(cache.keys.SPRINTS)
  if cached and cached.items then
    callback(cached.items)
    return
  end

  cli.get_sprints(function(sprints)
    if sprints and #sprints > 0 then
      cache.set(cache.keys.SPRINTS, nil, sprints)
    end
    callback(sprints)
  end)
end

---Assign issue to current user
---@param issue_key string
---@param step_done fun(step_name: string, err: string?, success_msg: string?)
local function do_assign_step(issue_key, step_done)
  cli.get_current_user({
    error_msg = false,
    on_success = function(result)
      local me = vim.trim(result.stdout or "")
      cli.assign_issue(issue_key, me, {
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

---Move issue to active sprint
---@param issue_key string
---@param step_done fun(step_name: string, err: string?, success_msg: string?)
local function do_move_to_sprint_step(issue_key, step_done)
  get_sprints(function(sprints)
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

    cli.move_issue_to_sprint(issue_key, active[1].id, {
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

---Transition issue to target state
---@param issue_key string
---@param transition string
---@param step_done fun(step_name: string, err: string?, success_msg: string?)
local function do_transition_step(issue_key, transition, step_done)
  cli.transition_issue(issue_key, transition, {
    error_msg = false,
    on_success = function()
      step_done("Transition", nil, string.format("transitioned to %s", transition))
    end,
    on_error = function(result)
      step_done("Transition", result.stderr or "Unknown error")
    end,
  })
end

---Create or switch to git branch
---@param issue_key string
---@param summary string?
---@param step_done fun(step_name: string, err: string?, success_msg: string?)
local function do_git_branch_step(issue_key, summary, step_done)
  if not git.is_git_repo() then
    step_done("Git branch", nil, "skipped (not in git repo)")
    return
  end

  local suggested_branch = git.generate_branch_name(issue_key, summary)
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

  -- For some reason, it's starting on normal mode (maybe because it's in another floating window?).
  -- So forcing making it on insert mode.
  vim.schedule(function()
    vim.cmd("startinsert!")
  end)
end

---Yank issue key to clipboard
---@param issue_key string
---@param step_done fun(step_name: string, err: string?, success_msg: string?)
local function do_yank_step(issue_key, step_done)
  vim.schedule(function()
    vim.fn.setreg(CLIPBOARD_REG, issue_key)
    vim.fn.setreg(DEFAULT_REG, issue_key)
    step_done("Yank", nil, "copied to clipboard")
  end)
end

---Start work on issue (assign, sprint, transition, git branch, yank)
---@param picker snacks.Picker?
---@param item snacks.picker.Item
---@param action snacks.picker.Action?
---@diagnostic disable-next-line: unused-local
function M.action_jira_start_work(picker, item, action)
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
        vim.notify(string.format("Started working on %s", item.key or "issue"), vim.log.levels.INFO)
      end

      if item.key then
        cache.clear_issue_caches(item.key)
      end
      if picker then
        picker:refresh()
      end

      if config.action.start_work.on_done then
        local ok = config.action.start_work.on_done({
          item = item,
          errors = errors,
          successes = successes,
          picker = picker,
          action = action,
        })
        if not ok and config.debug then
          vim.notify("jira.nvim on_done error: " .. tostring(err), vim.log.levels.ERROR)
        end
      end
    end
  end

  if steps.assign then
    do_assign_step(item.key, step_done)
  end

  if steps.move_to_sprint then
    do_move_to_sprint_step(item.key, step_done)
  end

  if steps.transition then
    do_transition_step(item.key, transition, step_done)
  end

  if steps.git_branch then
    do_git_branch_step(item.key, item.summary, step_done)
  end

  if steps.yank then
    do_yank_step(item.key, step_done)
  end
end

---Start work on issue (standalone function for command use)
---@param issue_key string
function M.start_work_on_issue(issue_key)
  M.action_jira_start_work(nil, { key = issue_key }, nil)
end

return M
