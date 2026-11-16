-- Runs git commands and parses their output. Each function is one command,
-- takes plain values, and returns the parsed output, or nil and git's error.

local diff_raw_parser = require('git-diff.git.parse-diff-raw')
local ls_files_unmerged_parser = require('git-diff.git.parse-ls-files-unmerged')

-- The one newline git ends its output and error messages with, as a Lua
-- pattern: only a newline at the very end matches, never one inside the text.
local trailing_newline = '\n$'

-- The git functions, running their commands with `system`, which has the
-- interface of `vim.system`: `system(command, options):wait()` returns
-- `{ code, stdout, stderr }`. Consumers pass `vim.system`, tests a fake.
local function init(system)
  -- The absolute path of the working tree that holds `directory`, or nil and
  -- git's error when git fails, such as outside a repository.
  --   -C <directory>   start the search for `.git` there, then upward
  --   rev-parse        git's plumbing for questions about the repository
  --   --show-toplevel  the top of the working tree: where the search found
  --                    `.git`, with symlinks resolved
  local function find_root(directory)
    local result = system({ 'git', '-C', directory, 'rev-parse', '--show-toplevel' }):wait()
    if result.code ~= 0 then
      return nil, (result.stderr:gsub(trailing_newline, ''))
    end

    -- git ends its output with a newline, which would become part of the path.
    return (result.stdout:gsub(trailing_newline, ''))
  end

  -- `git diff` in the raw format, parsed into changes with paths relative to
  -- `root`. `arguments` choose what to diff, as in `git diff`: `{ 'HEAD' }`,
  -- `{ '--staged' }`, `{ '--merge-base', 'main' }`, `{ 'HEAD', '--', 'lua/' }`.
  -- The format `parse_diff_raw` expects:
  --   --raw           modes, object ids and status for each file
  --   --no-abbrev     full object ids
  --   --find-renames  renames as one R entry instead of a D and an A
  --   -z              NUL terminated, unquoted paths; it has no long form
  -- `arguments` go last so a `--` in them still starts the paths. Options in
  -- them that change the format, such as `--stat` or `--abbrev`, break parsing.
  -- `-R` is not supported: it swaps the sides, which puts the working tree on
  -- the old side.
  local function diff_raw(root, arguments)
    local command = { 'git', '-C', root, 'diff', '--raw', '--no-abbrev', '--find-renames', '-z' }
    for _, argument in ipairs(arguments) do
      table.insert(command, argument)
    end

    local result = system(command):wait()
    if result.code ~= 0 then
      return nil, (result.stderr:gsub(trailing_newline, ''))
    end

    return diff_raw_parser.parse_diff_raw(result.stdout)
  end

  -- The index stages of each unmerged path, by path; empty outside a merge
  -- conflict.
  --   ls-files    lists the index's entries
  --   --unmerged  only unmerged entries, with mode, object id and stage
  --   -z          NUL terminated, unquoted paths; it has no long form
  local function list_unmerged(root)
    local result = system({ 'git', '-C', root, 'ls-files', '--unmerged', '-z' }):wait()
    if result.code ~= 0 then
      return nil, (result.stderr:gsub(trailing_newline, ''))
    end

    return ls_files_unmerged_parser.parse_ls_files_unmerged(result.stdout)
  end

  -- A blob's content, as raw bytes.
  --   cat-file  prints objects from the object database
  --   blob      the object must be a blob; anything else fails
  local function read_blob(root, id)
    local result = system({ 'git', '-C', root, 'cat-file', 'blob', id }):wait()
    if result.code ~= 0 then
      return nil, (result.stderr:gsub(trailing_newline, ''))
    end
    return result.stdout
  end

  return {
    find_root = find_root,
    diff_raw = diff_raw,
    list_unmerged = list_unmerged,
    read_blob = read_blob,
  }
end

return {
  init = init,
}
