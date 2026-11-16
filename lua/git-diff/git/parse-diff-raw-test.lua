-- Tests for parse-diff-raw.lua. Plain Lua, no Neovim; run from the config
-- directory:
--   luajit lua/git-diff/git/parse-diff-raw-test.lua

package.path = 'lua/?.lua;' .. package.path
local parser = require('git-diff.git.parse-diff-raw')

local old_id = string.rep('a', 40)
local new_id = string.rep('b', 40)
local zero_id = string.rep('0', 40)

-- Modified: both sides, same path.
do
  local changes = assert(parser.parse_diff_raw(':100644 100644 ' .. old_id .. ' ' .. new_id .. ' M\0a.lua\0'))
  assert(#changes == 1)
  local change = changes[1]
  assert(change.status == 'M')
  assert(change.old.path == 'a.lua' and change.old.mode == '100644' and change.old.id == old_id)
  assert(change.new.path == 'a.lua' and change.new.mode == '100644' and change.new.id == new_id)
  assert(change.dissimilarity == nil)
end

-- Modified with `-B`: the score is the dissimilarity.
do
  local changes = assert(parser.parse_diff_raw(':100644 100644 ' .. old_id .. ' ' .. new_id .. ' M095\0a.lua\0'))
  assert(changes[1].dissimilarity == 95)
end

-- Type change: both sides, with their modes.
do
  local changes = assert(parser.parse_diff_raw(':100644 120000 ' .. old_id .. ' ' .. new_id .. ' T\0link\0'))
  assert(changes[1].status == 'T')
  assert(changes[1].old.mode == '100644' and changes[1].new.mode == '120000')
end

-- Added: no old side.
do
  local changes = assert(parser.parse_diff_raw(':000000 100644 ' .. zero_id .. ' ' .. new_id .. ' A\0new.lua\0'))
  assert(changes[1].status == 'A')
  assert(changes[1].old == nil)
  assert(changes[1].new.path == 'new.lua' and changes[1].new.id == new_id)
end

-- Deleted: no new side.
do
  local changes = assert(parser.parse_diff_raw(':100644 000000 ' .. old_id .. ' ' .. zero_id .. ' D\0gone.lua\0'))
  assert(changes[1].status == 'D')
  assert(changes[1].new == nil)
  assert(changes[1].old.path == 'gone.lua' and changes[1].old.id == old_id)
end

-- Renamed and copied: two paths and the similarity.
do
  local output = ':100644 100644 ' .. old_id .. ' ' .. new_id .. ' R096\0old.lua\0new.lua\0'
    .. ':100644 100644 ' .. old_id .. ' ' .. new_id .. ' C075\0src.lua\0copy.lua\0'
  local changes = assert(parser.parse_diff_raw(output))
  assert(#changes == 2)
  assert(changes[1].status == 'R' and changes[1].similarity == 96)
  assert(changes[1].old.path == 'old.lua' and changes[1].new.path == 'new.lua')
  assert(changes[2].status == 'C' and changes[2].similarity == 75)
  assert(changes[2].old.path == 'src.lua' and changes[2].new.path == 'copy.lua')
end

-- Unmerged: only the path.
do
  local changes = assert(parser.parse_diff_raw(':000000 100644 ' .. zero_id .. ' ' .. zero_id .. ' U\0conflict.lua\0'))
  assert(changes[1].status == 'U')
  assert(changes[1].path == 'conflict.lua')
  assert(changes[1].old == nil and changes[1].new == nil)
end

-- Paths are taken as they are: `-z` leaves tabs and newlines unquoted.
do
  local changes = assert(parser.parse_diff_raw(':100644 100644 ' .. old_id .. ' ' .. new_id .. ' M\0a\tb\nc.lua\0'))
  assert(changes[1].new.path == 'a\tb\nc.lua')
end

-- No changes: no entries.
do
  local changes = assert(parser.parse_diff_raw(''))
  assert(#changes == 0)
end

-- Errors: an unknown status, a field that is not metadata, missing paths.
do
  local changes, error_message = parser.parse_diff_raw(':100644 100644 ' .. old_id .. ' ' .. new_id .. ' X\0a.lua\0')
  assert(changes == nil and error_message:find('unsupported git diff status', 1, true))

  changes, error_message = parser.parse_diff_raw('a.lua\0')
  assert(changes == nil and error_message:find('unexpected git diff output', 1, true))

  changes, error_message = parser.parse_diff_raw(':100644 100644 ' .. old_id .. ' ' .. new_id .. ' M\0')
  assert(changes == nil and error_message:find('missing path', 1, true))

  changes, error_message = parser.parse_diff_raw(':100644 100644 ' .. old_id .. ' ' .. new_id .. ' R100\0old.lua\0')
  assert(changes == nil and error_message:find('missing new path', 1, true))
end

print('parse-diff-raw: ok')
