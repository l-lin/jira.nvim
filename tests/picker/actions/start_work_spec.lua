describe("start_work", function()
  local start_work = require("jira.picker.actions.start_work")

  local sanitize_for_branch = start_work._sanitize_for_branch
  local generate_branch_name = start_work._generate_branch_name

  describe("sanitize_for_branch", function()
    it("should replace spaces with underscores", function()
      local input = "this is a test"
      local expected = "this_is_a_test"
      assert.are.equal(expected, sanitize_for_branch(input))
    end)

    it("should replace multiple consecutive spaces with single underscore", function()
      local input = "this  is   a    test"
      local expected = "this_is_a_test"
      assert.are.equal(expected, sanitize_for_branch(input))
    end)

    it("should remove special characters", function()
      local input = "fix: bug (critical)"
      local expected = "fix_bug_critical"
      assert.are.equal(expected, sanitize_for_branch(input))
    end)

    it("should keep hyphens and underscores", function()
      local input = "my-feature_name"
      local expected = "my-feature_name"
      assert.are.equal(expected, sanitize_for_branch(input))
    end)

    it("should remove various special characters", function()
      local input = "bug@#$%fix!&*()+=[]{}|\\;:'\",<>?/"
      local expected = "bugfix"
      assert.are.equal(expected, sanitize_for_branch(input))
    end)

    it("should handle empty string", function()
      local input = ""
      local expected = ""
      assert.are.equal(expected, sanitize_for_branch(input))
    end)

    it("should handle nil input", function()
      local input = nil
      local expected = ""
      assert.are.equal(expected, sanitize_for_branch(input))
    end)

    it("should handle string with only special characters", function()
      local input = "!@#$%^&*()"
      local expected = ""
      assert.are.equal(expected, sanitize_for_branch(input))
    end)

    it("should handle mixed alphanumeric and special characters", function()
      local input = "fix-123: add new feature (v2.0)"
      local expected = "fix-123_add_new_feature_v20"
      assert.are.equal(expected, sanitize_for_branch(input))
    end)

    it("should handle unicode characters by removing them", function()
      local input = "fix 🐛 bug"
      local expected = "fix__bug"
      assert.are.equal(expected, sanitize_for_branch(input))
    end)
  end)

  describe("generate_branch_name", function()
    it("should concatenate issue key and sanitized summary", function()
      local issue_key = "PROJ-123"
      local summary = "fix the bug"
      local expected = "PROJ-123-fix_the_bug"
      assert.are.equal(expected, generate_branch_name(issue_key, summary))
    end)

    it("should handle summary with special characters", function()
      local issue_key = "PROJ-456"
      local summary = "Add new feature (critical)"
      local expected = "PROJ-456-Add_new_feature_critical"
      assert.are.equal(expected, generate_branch_name(issue_key, summary))
    end)

    it("should return only issue key when summary is nil", function()
      local issue_key = "PROJ-789"
      local summary = nil
      local expected = "PROJ-789"
      assert.are.equal(expected, generate_branch_name(issue_key, summary))
    end)

    it("should return only issue key when summary is empty string", function()
      local issue_key = "PROJ-101"
      local summary = ""
      local expected = "PROJ-101"
      assert.are.equal(expected, generate_branch_name(issue_key, summary))
    end)

    it("should return only issue key when sanitized summary is empty", function()
      local issue_key = "PROJ-202"
      local summary = "!@#$%"
      local expected = "PROJ-202"
      assert.are.equal(expected, generate_branch_name(issue_key, summary))
    end)

    it("should handle long summary", function()
      local issue_key = "PROJ-303"
      local summary = "This is a very long summary that describes the issue in great detail"
      local expected = "PROJ-303-This_is_a_very_long_summary_that_describes_the_issue_in_great_detail"
      assert.are.equal(expected, generate_branch_name(issue_key, summary))
    end)

    it("should handle summary with mixed case", function()
      local issue_key = "PROJ-404"
      local summary = "Fix BUG in UserAuthentication"
      local expected = "PROJ-404-Fix_BUG_in_UserAuthentication"
      assert.are.equal(expected, generate_branch_name(issue_key, summary))
    end)
  end)
end)
