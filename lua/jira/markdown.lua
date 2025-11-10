---Markdown formatter for JIRA issue text
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

---Detect if a line is code (stack traces, JSON, or heavily indented content)
---@param line string Original line with indentation
---@return boolean
local function is_code_line(line)
  local trimmed_for_detection = trim_line(line)

  return line:match("%.rb:%d+") or
         line:match("%.py:%d+") or
         line:match("%.java:%d+") or
         line:match("^%s+%.%.%.%s*$") or
         line:match("^%s+%(.*frame") or
         (line:match("^%s%s%s%s+%S") and not line:match("^%s+[%u%d%-]+%s")) or
         -- JSON patterns
         trimmed_for_detection:match('^"[^"]*":%s*["{%[]') or  -- JSON key starting object/array
         trimmed_for_detection:match('^"[^"]*":%s*') or        -- JSON key-value
         trimmed_for_detection:match('^%s*["}%]],?%s*$') or    -- Closing braces/brackets
         (trimmed_for_detection:match('^%s+') and trimmed_for_detection:match('"[^"]*":%s*'))
end

---Format linked issue line
---@param line string Trimmed line
---@return string? formatted_line Type of line: "empty", "relationship", "issue", or nil
local function format_linked_issue_line(line)
  -- Skip empty lines
  if line == "" then
    return nil
  end

  -- Detect relationship type lines (all-caps words like BLOCKS, CLONES, etc.)
  if line:match("^[A-Z][A-Z%s]+$") then
    return "**" .. line .. ":**"
  end

  -- Detect issue lines (start with issue key like INTL-94, P3C-123, etc.)
  local issue_key = line:match("^([A-Z][A-Z0-9]+-[0-9]+)")
  if issue_key then
    -- Parse the line: KEY Title • Metadata
    local rest = line:sub(#issue_key + 1):gsub("^%s+", "")
    local title, metadata = rest:match("^(.-)%s*•%s*(.+)$")

    if title and metadata then
      -- Format as bullet point with bold key and italic metadata
      return "- **" .. issue_key .. "**: " .. title .. " *(" .. metadata .. ")*"
    else
      -- Fallback if parsing fails
      return "- **" .. issue_key .. "**: " .. rest
    end
  end

  return nil
end

---Format comment author line
---@param line string Trimmed line to check
---@param in_comments_section boolean Whether we're in comments section
---@return string? formatted_line, boolean is_latest
local function format_comment_author(line, in_comments_section)
  if not (in_comments_section and line:match("^[^•]+•[^•]+") and not line:match("^%s*$")) then
    return nil, false
  end

  -- Check if it's the latest comment
  local is_latest = line:match("•%s*Latest comment")

  -- Remove "• Latest comment" if present
  local author_line = line:gsub("%s*•%s*Latest comment%s*$", "")

  -- Format as H3 with emoji for latest comment
  if is_latest then
    return "### 🔥 " .. author_line, true
  else
    return "### " .. author_line, false
  end
end

---Format section header with emoji
---@param section string Section name
---@return string formatted_header, boolean is_comments, boolean is_linked_issues
local function format_section_header(section)
  local emoji = ""
  local is_comments = false
  local is_linked_issues = false

  if section:match("^%d+%s+Comments?$") then
    emoji = "💬 "
    is_comments = true
  elseif section:match("Linked Issues") then
    emoji = "🔗 "
    is_linked_issues = true
  elseif section:match("Description") then
    emoji = "📝 "
  end

  return "## " .. emoji .. section, is_comments, is_linked_issues
end

---Process header section (metadata and title)
---@param lines string[]
---@param i number Current line index
---@param in_header boolean Whether we're still in header section
---@param metadata_lines string[] Collected metadata lines
---@param title_line string? Title line
---@return boolean in_header, string[] metadata_lines, string? title_line, boolean should_continue
local function process_header(lines, i, in_header, metadata_lines, title_line)
  if not in_header or i > 15 then
    return in_header, metadata_lines, title_line, false
  end

  local line = lines[i]

  -- Check if this is a metadata line (contains emojis/icons)
  if line:match("[🐞🚧⌛👷🔑💭🧵⏱️🔎🚀📦🏷️👀]") then
    -- Trim and collect
    local trimmed = line:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #trimmed > 0 then
      table.insert(metadata_lines, trimmed)
    end
    return in_header, metadata_lines, title_line, true
  elseif line:match("^%s*#%s*.+") then
    -- This is the title line
    title_line = trim_line(line)
    return in_header, metadata_lines, title_line, true
  elseif line:match("^%s*$") then
    -- Skip empty lines in header section
    return in_header, metadata_lines, title_line, true
  else
    -- End of header section
    return false, metadata_lines, title_line, false
  end
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
  local in_linked_issues_section = false

  for i, line in ipairs(lines) do
    -- Process header section
    local should_continue
    in_header, metadata_lines, title_line, should_continue = process_header(lines, i, in_header, metadata_lines, title_line)

    if should_continue then
      goto continue
    end

    -- If we just exited header, add title and metadata to result
    if not in_header and i <= 15 and (title_line or #metadata_lines > 0) then
      if title_line then
        table.insert(result, title_line)
        table.insert(result, "")
        title_line = nil  -- Clear to prevent re-adding
      end
      if #metadata_lines > 0 then
        table.insert(result, table.concat(metadata_lines, " "))
        metadata_lines = {}  -- Clear to prevent re-adding
      end
    end

    -- Convert dashed section headers to markdown headers
    local section = line:match("^%s*%-%-%-+%s+(.-)%s+%-%-%-+%s*$")
    if section and #section > 0 then
      -- Close any open code block before header
      if in_code_block then
        table.insert(result, "```")
        table.insert(result, "")
        in_code_block = false
      end
      -- Add blank line before section header if last line isn't blank
      if #result > 0 and result[#result] ~= "" then
        table.insert(result, "")
      end

      local formatted_header, is_comments, is_linked
      formatted_header, is_comments, is_linked = format_section_header(section)

      in_comments_section = is_comments
      in_linked_issues_section = is_linked
      if is_comments then
        first_comment = true
      end

      table.insert(result, formatted_header)
    else
      -- Detect comment author lines (Name • Date format)
      local trimmed = trim_line(line)
      local formatted_comment = format_comment_author(trimmed, in_comments_section)

      if formatted_comment then
        -- Close any open code block before the comment header
        if in_code_block then
          table.insert(result, "```")
          table.insert(result, "")
          in_code_block = false
        end

        -- Add spacing before comment (except first one) if last line isn't blank
        if not first_comment and #result > 0 and result[#result] ~= "" then
          table.insert(result, "")
        end
        first_comment = false

        table.insert(result, formatted_comment)
        goto continue
      end

      -- Handle linked issues section
      if in_linked_issues_section then
        local formatted_issue = format_linked_issue_line(trimmed)

        if not formatted_issue then
          -- Empty line, skip it
          goto continue
        end

        -- Add blank line before relationship type
        if formatted_issue:match("^%*%*") then
          table.insert(result, "")
        end

        table.insert(result, formatted_issue)
        goto continue
      end

      -- Detect code blocks (stack traces, JSON, and heavily indented content)
      local is_code = is_code_line(line)

      if is_code and not in_code_block then
        -- Start code block
        in_code_block = true
        table.insert(result, "```")
        table.insert(result, trim_line(line))
      elseif in_code_block and (is_code or line:match("^%s+%S")) then
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

---Convert JIRA issue plain text to markdown
---@param text string Plain text with ANSI codes
---@return string[] Markdown formatted lines
function M.format_issue(text)
  -- Strip ANSI codes and split into lines
  local clean_text = strip_ansi_codes(text)
  local lines = vim.split(clean_text, "\n", { trimempty = false })

  -- Transform to markdown
  return transform_to_markdown(lines)
end

-- Expose functions for testing
M._strip_ansi_codes = strip_ansi_codes
M._trim_line = trim_line
M._is_code_line = is_code_line
M._format_linked_issue_line = format_linked_issue_line
M._format_comment_author = format_comment_author
M._format_section_header = format_section_header
M._process_header = process_header
M._transform_to_markdown = transform_to_markdown

return M
