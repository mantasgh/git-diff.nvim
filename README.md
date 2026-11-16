# git-diff.nvim

Browse `git diff` in Neovim with nothing but built-in parts: the changed files
in a quickfix list, each one side by side in diff mode.

- Any `git diff` arguments: `:GitDiff`, `:GitDiff HEAD`, `:GitDiff --staged`,
  `:GitDiff --merge-base main`.
- Move between files with the usual quickfix commands: `]q`, `:cnext`, `:cc N`.
- Unstaged changes open the real file, so you can edit and `:w` right there.
  Staged and committed versions are read-only.
- Merge conflicts open in three windows: ours | working file | theirs.

## Requirements

- Neovim 0.10 or newer
- git

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 'mantasgh/git-diff.nvim' }
```

With Neovim's built-in package manager (0.12+):

```lua
vim.pack.add({ 'https://github.com/mantasgh/git-diff.nvim' })
```

No setup is needed: the commands are available once the plugin is loaded.

## Usage

| Command | Shows |
| --- | --- |
| `:GitDiff` | Unstaged changes |
| `:GitDiff --staged` | Staged changes |
| `:GitDiff HEAD` | All changes since the last commit |
| `:GitDiff <rev> <rev>` | The changes between two commits |
| `:GitDiff ... -- <paths>` | Only the given paths |
| `:GitDiffClose` | Closes the diff and empties its quickfix list |

## Limitations

- `-R` is not supported; swap the revisions instead.
- Options that change git's output format, such as `--stat` or `--abbrev`,
  are not supported.
- Symlinks and submodules are shown as a note instead of a diff.
