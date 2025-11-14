local M = {}

function M.register()
  local snacks = require("snacks")

  -- Register formatters
  local formatters = require("jira.picker.formatters")
  for name, formatter in pairs(formatters) do
    snacks.picker.format[name] = formatter
  end

  -- Register previewers
  local previewers = require("jira.picker.previewers")
  for name, previewer in pairs(previewers) do
    snacks.picker.preview[name] = previewer
  end

  -- Register actions
  local actions = require("jira.picker.actions")
  for name, action in pairs(actions) do
    snacks.picker.actions[name] = action
  end

  -- Register sources
  local sources = require("jira.picker.sources")
  for name, source in pairs(sources) do
    -- Only register source configs (tables), skip factory functions
    -- Factory functions like source_jira_epic_issues(epic_key) need parameters
    -- and would cause fix_keys to fail when it tries to index them
    if type(source) == "table" then
      snacks.picker.sources[name] = source
    end
  end
end

return M
