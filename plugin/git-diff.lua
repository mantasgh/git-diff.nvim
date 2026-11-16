if vim.g.loaded_git_diff then
  return
end
vim.g.loaded_git_diff = true

require('git-diff.commands').register()
