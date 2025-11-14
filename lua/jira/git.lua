local M = {}

---Check if current directory is a git repository
---@return boolean
function M.is_git_repo()
  local result = vim.system({ "git", "rev-parse", "--git-dir" }, { text = true }):wait()
  return result.code == 0
end

---Check if branch exists
---@param branch_name string
---@return boolean
function M.branch_exists(branch_name)
  local result = vim.system({ "git", "rev-parse", "--verify", branch_name }, { text = true }):wait()
  return result.code == 0
end

---Switch to branch (create if needed based on exists check)
---@param branch_name string
---@param callback fun(err: string?, mode: string?)
function M.switch_branch(branch_name, callback)
  local exists = M.branch_exists(branch_name)
  local cmd = exists and { "git", "switch", branch_name } or { "git", "switch", "-c", branch_name }

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        callback(nil, exists and "switched" or "created")
      else
        callback(result.stderr or "Unknown git error")
      end
    end)
  end)
end

return M
