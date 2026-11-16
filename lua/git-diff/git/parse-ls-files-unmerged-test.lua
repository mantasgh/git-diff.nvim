-- Tests for parse-ls-files-unmerged.lua. Plain Lua, no Neovim; run from the
-- config directory:
--   luajit lua/git-diff/git/parse-ls-files-unmerged-test.lua

package.path = 'lua/?.lua;' .. package.path
local parser = require('git-diff.git.parse-ls-files-unmerged')

local base_id = string.rep('1', 40)
local ours_id = string.rep('2', 40)
local theirs_id = string.rep('3', 40)

-- Both modified: all three stages, grouped by path.
do
  local output = '100644 ' .. base_id .. ' 1\tconflict.lua\0'
    .. '100644 ' .. ours_id .. ' 2\tconflict.lua\0'
    .. '100755 ' .. theirs_id .. ' 3\tconflict.lua\0'
  local unmerged = assert(parser.parse_ls_files_unmerged(output))
  local stages = assert(unmerged['conflict.lua'])
  assert(stages[1].id == base_id and stages[1].mode == '100644' and stages[1].path == 'conflict.lua')
  assert(stages[2].id == ours_id)
  assert(stages[3].id == theirs_id and stages[3].mode == '100755')
end

-- Missing stages: both added (no base), deleted by us (no ours).
do
  local output = '100644 ' .. ours_id .. ' 2\tadded.lua\0'
    .. '100644 ' .. theirs_id .. ' 3\tadded.lua\0'
    .. '100644 ' .. base_id .. ' 1\tdeleted.lua\0'
    .. '100644 ' .. theirs_id .. ' 3\tdeleted.lua\0'
  local unmerged = assert(parser.parse_ls_files_unmerged(output))
  assert(unmerged['added.lua'][1] == nil and unmerged['added.lua'][2].id == ours_id)
  assert(unmerged['deleted.lua'][2] == nil and unmerged['deleted.lua'][1].id == base_id)
end

-- Paths are taken as they are: `-z` leaves tabs and newlines unquoted.
do
  local unmerged = assert(parser.parse_ls_files_unmerged('100644 ' .. ours_id .. ' 2\ta\tb\nc.lua\0'))
  assert(unmerged['a\tb\nc.lua'][2].id == ours_id)
end

-- No conflicts: no paths.
do
  local unmerged = assert(parser.parse_ls_files_unmerged(''))
  assert(next(unmerged) == nil)
end

-- Errors: a stage other than 1-3, an entry that does not match the format.
do
  local unmerged, error_message = parser.parse_ls_files_unmerged('100644 ' .. ours_id .. ' 0\ta.lua\0')
  assert(unmerged == nil and error_message:find('unexpected git ls-files output', 1, true))

  unmerged, error_message = parser.parse_ls_files_unmerged('a.lua\0')
  assert(unmerged == nil and error_message:find('unexpected git ls-files output', 1, true))
end

print('parse-ls-files-unmerged: ok')
