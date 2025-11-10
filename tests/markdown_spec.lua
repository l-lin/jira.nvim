---@module 'luassert'

-- Mock vim global if not available
if not _G.vim then
  _G.vim = {
    tbl_contains = function(t, value)
      for _, v in ipairs(t) do
        if v == value then
          return true
        end
      end
      return false
    end,
    split = function(s, sep, opts)
      local result = {}
      local pattern = string.format("([^%s]+)", sep)
      for match in string.gmatch(s, pattern) do
        table.insert(result, match)
      end
      return result
    end,
  }
end

describe("markdown", function()
  -- Load the module being tested
  local markdown = require("jira.markdown")

  -- Access private functions exposed for testing
  local strip_ansi_codes = markdown._strip_ansi_codes
  local trim_line = markdown._trim_line
  local transform_to_markdown = markdown._transform_to_markdown

  describe("strip_ansi_codes", function()
    it("should remove ANSI color codes", function()
      local input = "\x1b[31mRed text\x1b[0m"
      local expected = "Red text"
      assert.are.equal(expected, strip_ansi_codes(input))
    end)

    it("should remove multiple ANSI codes", function()
      local input = "\x1b[1m\x1b[32mBold Green\x1b[0m\x1b[0m"
      local expected = "Bold Green"
      assert.are.equal(expected, strip_ansi_codes(input))
    end)

    it("should handle text without ANSI codes", function()
      local input = "Plain text"
      local expected = "Plain text"
      assert.are.equal(expected, strip_ansi_codes(input))
    end)

    it("should handle empty string", function()
      local input = ""
      local expected = ""
      assert.are.equal(expected, strip_ansi_codes(input))
    end)
  end)

  describe("trim_line", function()
    it("should remove leading 2 spaces", function()
      local input = "  Hello"
      local expected = "Hello"
      assert.are.equal(expected, trim_line(input))
    end)

    it("should remove trailing whitespace", function()
      local input = "Hello   "
      local expected = "Hello"
      assert.are.equal(expected, trim_line(input))
    end)

    it("should remove both leading 2 spaces and trailing whitespace", function()
      local input = "  Hello   "
      local expected = "Hello"
      assert.are.equal(expected, trim_line(input))
    end)

    it("should not remove more than 2 leading spaces", function()
      local input = "    Hello"
      local expected = "  Hello"
      assert.are.equal(expected, trim_line(input))
    end)

    it("should handle empty string", function()
      local input = ""
      local expected = ""
      assert.are.equal(expected, trim_line(input))
    end)

    it("should handle string with only spaces", function()
      local input = "     "
      local expected = ""  -- Removes 2 leading spaces -> "   ", then trailing whitespace -> ""
      assert.are.equal(expected, trim_line(input))
    end)
  end)

  describe("transform_to_markdown", function()
    describe("header processing", function()
      it("should extract title and metadata", function()
        local lines = {
          "  # PROJ-123: Test Issue",
          "  🐞 Bug • 🚧 In Progress",
          "",
          "  Some content",
        }
        local result = transform_to_markdown(lines)
        assert.are.equal("# PROJ-123: Test Issue", result[1])
        assert.are.equal("", result[2])
        assert.are.equal("🐞 Bug • 🚧 In Progress", result[3])
      end)

      it("should skip empty lines in header", function()
        local lines = {
          "",
          "  # Title",
          "",
          "  🐞 Bug",
          "",
          "  Content",
        }
        local result = transform_to_markdown(lines)
        assert.are.equal("# Title", result[1])
        assert.are.equal("", result[2])
        assert.are.equal("🐞 Bug", result[3])
      end)
    end)

    describe("section headers", function()
      it("should convert dashed headers to markdown headers with emoji", function()
        local lines = {
          "  # Title",
          "  ---- Description ----",
          "  Some description",
        }
        local result = transform_to_markdown(lines)
        assert.is_true(vim.tbl_contains(result, "## 📝 Description"))
      end)

      it("should add emoji to Comments section", function()
        local lines = {
          "  # Title",
          "  ---- 5 Comments ----",
          "  Comment content",
        }
        local result = transform_to_markdown(lines)
        assert.is_true(vim.tbl_contains(result, "## 💬 5 Comments"))
      end)

      it("should add emoji to Linked Issues section", function()
        local lines = {
          "  # Title",
          "  ---- Linked Issues ----",
          "  PROJ-456",
        }
        local result = transform_to_markdown(lines)
        assert.is_true(vim.tbl_contains(result, "## 🔗 Linked Issues"))
      end)

      it("should add blank line before section header if needed", function()
        local lines = {
          "  # Title",
          "  Previous line",
          "  ---- Description ----",
        }
        local result = transform_to_markdown(lines)
        -- Find the section header
        local found_blank = false
        for i, line in ipairs(result) do
          if line == "## 📝 Description" and i > 1 then
            found_blank = result[i - 1] == ""
            break
          end
        end
        assert.is_true(found_blank)
      end)
    end)

    describe("comment formatting", function()
      it("should format comment author as H3", function()
        local lines = {
          "  # Title",
          "  ---- 1 Comment ----",
          "  John Doe • 2024-01-01",
          "  Comment text",
        }
        local result = transform_to_markdown(lines)
        assert.is_true(vim.tbl_contains(result, "### John Doe • 2024-01-01"))
      end)

      it("should mark latest comment with emoji", function()
        local lines = {
          "  # Title",
          "  ---- 2 Comments ----",
          "  John Doe • 2024-01-01 • Latest comment",
          "  Comment text",
        }
        local result = transform_to_markdown(lines)
        assert.is_true(vim.tbl_contains(result, "### 🔥 John Doe • 2024-01-01"))
      end)

      it("should add spacing between comments", function()
        local lines = {
          "  # Title",
          "  ---- 2 Comments ----",
          "  John Doe • 2024-01-01",
          "  First comment",
          "  Jane Smith • 2024-01-02",
          "  Second comment",
        }
        local result = transform_to_markdown(lines)
        -- Find second comment and check for blank line before it
        local found_spacing = false
        for i, line in ipairs(result) do
          if line:match("Jane Smith") and i > 1 then
            found_spacing = result[i - 1] == ""
            break
          end
        end
        assert.is_true(found_spacing)
      end)
    end)

    describe("linked issues formatting", function()
      it("should format relationship type as bold", function()
        local lines = {
          "  # Title",
          "  ---- Linked Issues ----",
          "  BLOCKS",
          "  PROJ-456 Some issue • Status",
        }
        local result = transform_to_markdown(lines)
        assert.is_true(vim.tbl_contains(result, "**BLOCKS:**"))
      end)

      it("should format issue line as bullet with bold key", function()
        local lines = {
          "  # Title",
          "  ---- Linked Issues ----",
          "  PROJ-456 Some issue title • In Progress",
        }
        local result = transform_to_markdown(lines)
        assert.is_true(vim.tbl_contains(result, "- **PROJ-456**: Some issue title *(In Progress)*"))
      end)

      it("should skip empty lines in linked issues section", function()
        local lines = {
          "  # Title",
          "  ---- Linked Issues ----",
          "  ",
          "  BLOCKS",
          "  ",
          "  PROJ-456 Issue • Status",
        }
        local result = transform_to_markdown(lines)
        -- Count empty strings in result
        local empty_count = 0
        for _, line in ipairs(result) do
          if line == "" then
            empty_count = empty_count + 1
          end
        end
        -- Should have some empty lines but not from the linked issues section itself
        -- The empty lines should be for spacing between sections
        assert.is_true(empty_count < 3)
      end)
    end)

    describe("code block detection", function()
      it("should detect stack traces", function()
        local lines = {
          "  # Title",
          "  ---- Description ----",
          "  Error occurred:",
          "      app.rb:123",
          "      lib/helper.py:456",
        }
        local result = transform_to_markdown(lines)
        -- Should have ``` markers
        assert.is_true(vim.tbl_contains(result, "```"))
      end)

      it("should detect JSON patterns", function()
        local lines = {
          "  # Title",
          "  ---- Description ----",
          "  Config:",
          '      "key": "value"',
          '      "nested": {',
          '        "inner": "data"',
          '      }',
        }
        local result = transform_to_markdown(lines)
        assert.is_true(vim.tbl_contains(result, "```"))
      end)

      it("should close code block when hitting non-code content", function()
        local lines = {
          "  # Title",
          "  ---- Description ----",
          "      app.rb:123",
          "  Regular text",
        }
        local result = transform_to_markdown(lines)
        -- Count ``` markers (should be 2: opening and closing)
        local code_block_count = 0
        for _, line in ipairs(result) do
          if line == "```" then
            code_block_count = code_block_count + 1
          end
        end
        assert.are.equal(2, code_block_count)
      end)

      it("should close code block at end if still open", function()
        local lines = {
          "  # Title",
          "  ---- Description ----",
          "      app.rb:123",
          "      lib/helper.py:456",
        }
        local result = transform_to_markdown(lines)
        -- Last non-empty line should be ```
        assert.are.equal("```", result[#result])
      end)
    end)

    describe("complex scenarios", function()
      it("should handle full issue with all sections", function()
        local lines = {
          "  # PROJ-123: Complex Issue",
          "  🐞 Bug • 🚧 In Progress",
          "  ---- Description ----",
          "  This is a description",
          "  ---- Linked Issues ----",
          "  BLOCKS",
          "  PROJ-456 Another issue • Done",
          "  ---- 2 Comments ----",
          "  John Doe • 2024-01-01",
          "  First comment",
          "  Jane Smith • 2024-01-02 • Latest comment",
          "  Second comment",
        }
        local result = transform_to_markdown(lines)

        -- Should have all sections
        assert.is_true(vim.tbl_contains(result, "## 📝 Description"))
        assert.is_true(vim.tbl_contains(result, "## 🔗 Linked Issues"))
        assert.is_true(vim.tbl_contains(result, "## 💬 2 Comments"))

        -- Should have formatted elements
        assert.is_true(vim.tbl_contains(result, "**BLOCKS:**"))
        assert.is_true(vim.tbl_contains(result, "### John Doe • 2024-01-01"))
        assert.is_true(vim.tbl_contains(result, "### 🔥 Jane Smith • 2024-01-02"))
      end)
    end)
  end)
end)
