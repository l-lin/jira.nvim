local M = {}

---Strip ANSI color codes from text
---@param text string
---@return string
local function strip_ansi_codes(text)
  return text:gsub("\x1b%[[0-9;]*m", "")
end

---Trim leading 2 spaces and trailing whitespace from a line
---@param line string
---@return string
local function trim_line(line)
  return (line:gsub("^  ", ""):gsub("%s+$", ""))
end

---Transform plain text output to markdown format
---@param lines string[]
---@return string[]
local function transform_to_markdown(lines)
  local result = {}
  local in_code_block = false
  local metadata_lines = {}
  local title_line = nil
  local in_header = true
  local in_comments_section = false
  local first_comment = true

  for i, line in ipairs(lines) do
    -- Collect metadata and title at the beginning (first ~15 lines before sections)
    if in_header and i <= 15 then
      -- Check if this is a metadata line (contains emojis/icons)
      if line:match("[🐞🚧⌛👷🔑💭🧵⏱️🔎🚀📦🏷️👀]") then
        -- Trim and collect
        local trimmed = line:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if #trimmed > 0 then
          table.insert(metadata_lines, trimmed)
        end
        goto continue
      elseif line:match("^%s*#%s*.+") then
        -- This is the title line
        title_line = trim_line(line)
        goto continue
      elseif line:match("^%s*$") then
        -- Skip empty lines in header section
        goto continue
      else
        -- End of header section
        if #metadata_lines > 0 then
          -- Merge all metadata into one line
          table.insert(result, table.concat(metadata_lines, " "))
          table.insert(result, "")
        end
        if title_line then
          table.insert(result, title_line)
        end
        in_header = false
      end
    end

    -- Convert dashed section headers to markdown headers
    -- Match pattern: "---- Section Name ----" with at least 3 dashes on each side
    local section = line:match("^%s*%-%-%-+%s+(.-)%s+%-%-%-+%s*$")
    if section and #section > 0 then
      -- Close any open code block before header
      if in_code_block then
        table.insert(result, "```")
        table.insert(result, "")
        in_code_block = false
      end
      table.insert(result, "")
      table.insert(result, "## " .. section)

      -- Check if this is the Comments section
      if section:match("^%d+%s+Comments?$") then
        in_comments_section = true
        first_comment = true
      else
        in_comments_section = false
      end
    else
      -- Detect comment author lines (Name • Date format)
      local trimmed = trim_line(line)
      if in_comments_section and trimmed:match("^[^•]+•[^•]+") and not trimmed:match("^%s*$") then
        -- This is a comment author line
        -- Check if it's the latest comment
        local is_latest = trimmed:match("•%s*Latest comment")

        -- Remove "• Latest comment" if present
        local author_line = trimmed:gsub("%s*•%s*Latest comment%s*$", "")

        -- Add spacing before comment (except first one)
        if not first_comment then
          table.insert(result, "")
        end
        first_comment = false

        -- Format as H3 with emoji for latest comment
        if is_latest then
          table.insert(result, "### 🔥 " .. author_line)
        else
          table.insert(result, "### " .. author_line)
        end
        goto continue
      end
      -- Detect code blocks (stack traces with file paths and line numbers)
      local is_code_line = line:match("%.rb:%d+") or
                           line:match("%.py:%d+") or
                           line:match("%.java:%d+") or
                           line:match("^%s+%.%.%.%s*$") or
                           line:match("^%s+%(.*frame") or
                           (line:match("^%s%s%s%s+%S") and not line:match("^%s+[%u%d%-]+%s"))

      if is_code_line and not in_code_block then
        -- Start code block
        in_code_block = true
        table.insert(result, "```")
        table.insert(result, trim_line(line))
      elseif in_code_block and (is_code_line or line:match("^%s+%S")) then
        -- Continue code block (code line or indented line)
        table.insert(result, trim_line(line))
      elseif in_code_block and line:match("^%s*$") then
        -- Keep empty lines in code block
        table.insert(result, "")
      elseif in_code_block then
        -- End code block when we hit non-code content
        table.insert(result, "```")
        table.insert(result, "")
        in_code_block = false
        table.insert(result, trim_line(line))
      else
        -- Normal line
        table.insert(result, trim_line(line))
      end
    end

    ::continue::
  end

  -- Close any remaining code block
  if in_code_block then
    table.insert(result, "```")
  end

  return result
end

---@param ctx snacks.picker.preview.ctx
function M.jira_issue_preview(ctx)
  local item = ctx.item

  if not item or not item.key then
    ctx.preview:reset()
    ctx.preview:notify("No issue selected", "warn")
    return
  end

  local config = require("jira.config").options

  -- Show loading indicator
  ctx.preview:reset()
  ctx.preview:set_title(item.key)
  ctx.preview:notify("Loading issue details...", "info")

  -- Build command
  local cmd = {
    config.cli.cmd,
    "issue",
    "view",
    item.key,
    "--plain",
    "--comments",
    tostring(config.display.preview_comments),
  }

  -- Execute command asynchronously
  vim.system(cmd, { text = true }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      ctx.preview:reset()
      ctx.preview:set_title(item.key)
      ctx.preview:notify("Failed to load issue details", "error")
      return
    end

    -- Strip ANSI codes and split into lines
    local output = strip_ansi_codes(result.stdout or "")
    local lines = vim.split(output, "\n", { trimempty = false })

    -- Transform to markdown
    lines = transform_to_markdown(lines)

    -- Set preview content
    ctx.preview:reset()
    ctx.preview:set_title(item.key)
    ctx.preview:set_lines(lines)

    -- Set markdown filetype for syntax highlighting
    vim.bo[ctx.preview.win.buf].filetype = "markdown"
  end))
end

return M
