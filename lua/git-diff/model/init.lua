-- The model functions, getting their data from `git`, the functions of the
-- git module, after checking with `executable`, which has the interface of
-- `vim.fn.executable`: `executable(name)` is 1 when the program is on `PATH`,
-- 0 otherwise. Consumers pass `require('git-diff.git').init(vim.system)` and
-- `vim.fn.executable`, tests fakes.
local function init(git, executable)
  -- The model of `git diff <arguments>` in the repository that holds
  -- `directory`, or nil and the error when git fails. Plain data from git:
  -- the repo root, the `git diff` arguments, the parsed changes with paths
  -- relative to the root, and the index stages of unmerged paths.
  local function build_model(directory, arguments)
    -- Without git on `PATH`, `vim.system` raises an error instead of
    -- returning one.
    if executable('git') == 0 then
      return nil, 'git-diff: git is not installed'
    end

    local root, root_error = git.find_root(directory)
    if not root then
      return nil, root_error
    end

    local changes, diff_error = git.diff_raw(root, arguments)
    if not changes then
      return nil, diff_error
    end

    local unmerged, unmerged_error = git.list_unmerged(root)
    if not unmerged then
      return nil, unmerged_error
    end

    return {
      root = root,
      arguments = arguments,
      changes = changes,
      unmerged = unmerged,
    }
  end

  return {
    build_model = build_model,
  }
end

return {
  init = init,
}
