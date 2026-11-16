-- git-diff's commands. `plugin/git-diff.lua` registers them on startup; the
-- code they call loads on first use.
local function register()
  -- `:GitDiff [arguments]` opens `git diff <arguments>` as a quickfix list and
  -- a diff: `:GitDiff`, `:GitDiff HEAD`, `:GitDiff --staged` and so on.
  vim.api.nvim_create_user_command('GitDiff', function(opts)
    require('git-diff').open(opts.fargs)
  end, {
    nargs = '*',
    complete = function()
      return { 'HEAD', '--staged', '--merge-base', 'main', 'main...', 'origin/main', '--' }
    end,
  })

  -- `:GitDiffClose` closes what `:GitDiff` opened.
  vim.api.nvim_create_user_command('GitDiffClose', function()
    require('git-diff').close()
  end, {})
end

return {
  register = register,
}
