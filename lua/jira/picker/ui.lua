---@class TextInputOpts
---@field prompt string?
---@field default string?
---@field on_submit fun(input: string)
---@field on_cancel fun()?
---@field allow_empty boolean?
---@field skip_unchanged boolean?

---@class MarkdownEditorOpts
---@field title string
---@field template string?
---@field width number?
---@field height number?
---@field on_submit fun(text: string, win: snacks.win)
---@field submit_desc string?

local M = {}

---Prompt for text input with validation
---@param opts TextInputOpts
function M.prompt_text_input(opts)
  local prompt = opts.prompt or "Input: "
  local allow_empty = opts.allow_empty or false
  local skip_unchanged = opts.skip_unchanged or false

  vim.ui.input({
    prompt = prompt,
    default = opts.default,
  }, function(input)
    if not input or input == "" then
      if not allow_empty then
        vim.notify("Input is required", vim.log.levels.WARN)
      end
      if opts.on_cancel then
        opts.on_cancel()
      end
      return
    end

    if skip_unchanged and opts.default and input == opts.default then
      if opts.on_cancel then
        opts.on_cancel()
      end
      return
    end

    opts.on_submit(input)
  end)

  -- Start in insert mode at the end of the line
  vim.schedule(function()
    vim.cmd.startinsert({ bang = true })
  end)
end

---Open markdown scratch buffer editor
---@param opts MarkdownEditorOpts
function M.open_markdown_editor(opts)
  local config = require("jira.config")
  Snacks.scratch({
    ft = "markdown",
    name = opts.title,
    template = opts.template or "",
    win = {
      relative = "editor",
      width = opts.width or config.options.ui.scratch.width,
      height = opts.height or config.options.ui.scratch.height,
      title = " " .. opts.title .. " ",
      title_pos = "center",
      border = "rounded",
      keys = {
        submit = {
          "<c-s>",
          function(win)
            opts.on_submit(win:text(), win)
          end,
          desc = opts.submit_desc or "Submit",
          mode = { "n", "i" },
        },
      },
      on_win = function()
        vim.schedule(vim.cmd.startinsert)
      end,
    },
  })
end

return M
