local function register()
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
    snacks.picker.sources[name] = source
  end
end

local M = {}
M.register = register
return M
