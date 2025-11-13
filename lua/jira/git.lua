---Check if current directory is a git repository
---@return boolean
local function is_git_repo()
  local result = vim.system({ "git", "rev-parse", "--git-dir" }, { text = true }):wait()
  return result.code == 0
end

---Check if branch exists
---@param branch_name string
---@return boolean
local function branch_exists(branch_name)
  local result = vim.system({ "git", "rev-parse", "--verify", branch_name }, { text = true }):wait()
  return result.code == 0
end

---Switch to branch (create if needed based on exists check)
---@param branch_name string
---@param callback fun(err: string?, mode: string?)
local function switch_branch(branch_name, callback)
  local exists = branch_exists(branch_name)
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

local M = {}
M.is_git_repo = is_git_repo
M.branch_exists = branch_exists
M.switch_branch = switch_branch
return M
