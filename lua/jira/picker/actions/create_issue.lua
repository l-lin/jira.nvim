---@class CreateIssueState
---@field type string?
---@field summary string?
---@field description string?
---@field parent_key string?
---@field sprint_id string?
---@field picker snacks.Picker?
---@field scratch_win any?

local cli = require("jira.cli")
local ui = require("jira.picker.ui")
local fetchers = require("jira.fetchers")

local M = {}

---Show epic selection UI using Snacks picker
---@param callback fun(epic_key: string?)
local function show_epic_select(callback)
  require("snacks").picker("source_jira_epics", {
    ---@diagnostic disable-next-line: unused-local
    confirm = function(epic_picker, epic_item, action)
      epic_picker:close()

      if not epic_item or not epic_item.key then
        callback(nil)
        return
      end

      callback(epic_item.key)
    end,
  })
end

---Step 1: Select issue type
---@param state CreateIssueState
---@param on_complete fun(state: CreateIssueState)
local function step_1_select_type(state, on_complete)
  fetchers.fetch_issue_types(function(issue_types)
    vim.ui.select(issue_types, {
      prompt = "Select issue type:",
    }, function(selected_type)
      if not selected_type then
        return -- User cancelled
      end

      state.type = selected_type
      on_complete(state)
    end)
  end)
end

---Step 2: Input summary
---@param state CreateIssueState
---@param on_complete fun(state: CreateIssueState)
local function step_2_input_summary(state, on_complete)
  ui.prompt_text_input({
    prompt = "Issue summary: ",
    on_submit = function(summary)
      state.summary = summary
      on_complete(state)
    end,
  })
end

---Step 3: Edit description in scratch buffer
---@param state CreateIssueState
---@param on_complete fun(state: CreateIssueState)
local function step_3_edit_description(state, on_complete)
  ui.open_markdown_editor({
    title = string.format("Description for %s", state.type),
    on_submit = function(text, win)
      state.description = text
      state.scratch_win = win
      on_complete(state)
    end,
    submit_desc = "Submit and create issue",
  })
end

---Step 4: Select epic (optional)
---@param state CreateIssueState
---@param on_complete fun(state: CreateIssueState)
local function step_4_select_epic(state, on_complete)
  vim.ui.select(
    { "Yes", "No" },
    { prompt = "Associate to an epic?" },
    function(epic_choice)
      if not epic_choice then
        if state.scratch_win then
          state.scratch_win:close()
        end
        return -- User cancelled
      end

      if epic_choice == "Yes" then
        show_epic_select(function(epic_key)
          state.parent_key = epic_key
          on_complete(state)
        end)
      else
        state.parent_key = nil
        on_complete(state)
      end
    end)
end

---Step 5: Select sprint (optional)
---@param state CreateIssueState
---@param on_complete fun(state: CreateIssueState)
local function step_5_select_sprint(state, on_complete)
  vim.ui.select(
    { "Yes", "No" },
    { prompt = "Move to sprint?" },
    function(sprint_choice)
      if not sprint_choice then
        if state.scratch_win then
          state.scratch_win:close()
        end
        return -- User cancelled
      end

      if sprint_choice == "Yes" then
        fetchers.fetch_sprints(function(sprints)
          if not sprints or #sprints == 0 then
            vim.notify("No sprints available, creating issue without sprint", vim.log.levels.WARN)
            state.sprint_id = nil
            on_complete(state)
            return
          end

          require("snacks").picker("source_jira_sprints", {
            sprints = sprints,
            ---@diagnostic disable-next-line: unused-local
            confirm = function(sprint_picker, sprint_item, action)
              sprint_picker:close()

              if not sprint_item or not sprint_item.sprint then
                state.sprint_id = nil
              else
                state.sprint_id = sprint_item.sprint.id
              end

              on_complete(state)
            end,
          })
        end)
      else
        state.sprint_id = nil
        on_complete(state)
      end
    end)
end

---Step 6: Create issue and open in buffer
---@param state CreateIssueState
local function step_6_create_issue(state)
  cli.create_issue(state.type, state.summary, state.description, {
    success_msg = false, -- Handle manually
    error_msg = string.format("Failed to create %s", state.type),
    on_success = function(_, issue_key)
      if state.scratch_win then
        state.scratch_win:close()
      end

      -- Add to epic if requested
      if state.parent_key then
        cli.add_issue_to_epic(state.parent_key, issue_key, {
          error_msg = string.format("Created %s but failed to add to epic", issue_key),
          success_msg = false,
        })
      end

      -- Move to sprint if requested
      if state.sprint_id then
        cli.move_issue_to_sprint(issue_key, state.sprint_id, {
          error_msg = string.format("Created %s but failed to move to sprint", issue_key),
          success_msg = false,
        })
      end

      vim.notify(string.format("Created issue: %s", issue_key), vim.log.levels.INFO)

      -- Open in buffer with delay to ensure issue is available
      local config = require("jira.config").options
      vim.defer_fn(function()
        require("jira.buf").open(issue_key)
        if state.picker then
          state.picker:close()
        end
      end, config.cli.timeout.issue_open_delay)
    end,
  })
end

---Main action: Create a new JIRA issue
---@param picker snacks.Picker
---@param item snacks.picker.Item
---@param action snacks.picker.Action
---@diagnostic disable-next-line: unused-local
function M.action_jira_create_issue(picker, item, action)
  ---@type CreateIssueState
  local state = {
    type = nil,
    summary = nil,
    description = nil,
    parent_key = nil,
    sprint_id = nil,
    picker = picker,
    scratch_win = nil,
  }

  -- Execute flow: type -> summary -> description -> epic -> sprint -> create
  step_1_select_type(state, function(s1)
    step_2_input_summary(s1, function(s2)
      step_3_edit_description(s2, function(s3)
        step_4_select_epic(s3, function(s4)
          step_5_select_sprint(s4, function(s5)
            step_6_create_issue(s5)
          end)
        end)
      end)
    end)
  end)
end

return M
