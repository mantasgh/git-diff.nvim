-- Tests for init.lua. Plain Lua, no Neovim and no git: `system` is a fake
-- that records each command and returns a prepared result. Run from the
-- config directory:
--   luajit lua/git-diff/git/init-test.lua

package.path = 'lua/?.lua;lua/?/init.lua;' .. package.path
local init_git = require('git-diff.git').init

-- The commands the fake was called with, as `{ command, options }`.
local calls

-- The git functions, with every command returning `result`.
local function init(result)
  calls = {}
  return init_git(function(command, options)
    table.insert(calls, { command = command, options = options })
    return {
      wait = function()
        return result
      end,
    }
  end)
end

local function command_line(index)
  return table.concat(calls[index].command, ' ')
end

local failure = { code = 128, stdout = '', stderr = 'fatal: something\nhint: more\n' }

-- find_root: the command, and only the final newline removed.
do
  local git = init({ code = 0, stdout = '/my repo \n', stderr = '' })
  assert(git.find_root('/my repo /sub') == '/my repo ')
  assert(command_line(1) == 'git -C /my repo /sub rev-parse --show-toplevel')
end

-- diff_raw: the arguments go after the format options; the output is parsed.
do
  local id = string.rep('a', 40)
  local git = init({ code = 0, stdout = ':100644 100644 ' .. id .. ' ' .. id .. ' M\0a.lua\0', stderr = '' })
  local changes = assert(git.diff_raw('/r', { 'HEAD', '--', 'lua/' }))
  assert(command_line(1) == 'git -C /r diff --raw --no-abbrev --find-renames -z HEAD -- lua/')
  assert(#changes == 1 and changes[1].status == 'M' and changes[1].new.path == 'a.lua')
end

-- list_unmerged: the command; the output is parsed.
do
  local id = string.rep('2', 40)
  local git = init({ code = 0, stdout = '100644 ' .. id .. ' 2\tconflict.lua\0', stderr = '' })
  local unmerged = assert(git.list_unmerged('/r'))
  assert(command_line(1) == 'git -C /r ls-files --unmerged -z')
  assert(unmerged['conflict.lua'][2].id == id)
end

-- read_blob: the command; the content as raw bytes, newlines and all.
do
  local id = string.rep('b', 40)
  local git = init({ code = 0, stdout = 'a\r\nb\n', stderr = '' })
  assert(git.read_blob('/r', id) == 'a\r\nb\n')
  assert(command_line(1) == 'git -C /r cat-file blob ' .. id)
end

-- Failures: nil and git's error, without its final newline only.
do
  local git = init(failure)
  local expected = 'fatal: something\nhint: more'
  local value, error_message = git.find_root('/r')
  assert(value == nil and error_message == expected)
  value, error_message = git.diff_raw('/r', {})
  assert(value == nil and error_message == expected)
  value, error_message = git.list_unmerged('/r')
  assert(value == nil and error_message == expected)
  value, error_message = git.read_blob('/r', 'id')
  assert(value == nil and error_message == expected)
end

print('git: ok')
