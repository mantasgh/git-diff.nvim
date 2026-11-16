-- Diff sides: what one diff window shows, as the props of a buffer element,
-- like the attributes of an HTML element. The view turns them into a buffer:
--   name        the buffer's name; for a file on disk, its path
--   buftype     '' for a file on disk, opened as-is; 'nofile' for a buffer
--               filled from `lines` or `src`
--   lines       the content of a 'nofile' buffer
--   src         or where the view loads it from, like `<img src>`: the blob
--               `{ root, id }`
--   modifiable  whether the buffer can be edited
--   filetype    its filetype, when there is one
-- Each kind of side has one factory, so every side of a kind has the same
-- props.

-- The file does not exist on this side: one shared, empty, read-only buffer.
local function empty_side()
  return { name = 'git-diff://empty', buftype = 'nofile', lines = {}, modifiable = false }
end

-- The working tree file itself, opened as-is so it can be edited.
--   filename  absolute path
local function file_side(filename)
  return { name = filename, buftype = '' }
end

-- Stored content: the blob `id` in the repository at `root`, read-only.
-- `path` is relative to the root and gives the name and the filetype. An id
-- always means the same content, so one buffer per name is enough.
local function stored_side(root, id, path)
  return {
    name = 'git-diff://' .. id .. '/' .. path,
    buftype = 'nofile',
    src = { root = root, id = id },
    modifiable = false,
    filetype = vim.filetype.match({ filename = path }),
  }
end

-- What a file mode stands for, for notes about sides that are not files.
local function describe_mode(mode)
  if mode == '100644' then
    return 'a regular file'
  elseif mode == '100755' then
    return 'an executable file'
  elseif mode == '120000' then
    return 'a symlink'
  elseif mode == '160000' then
    return 'a submodule'
  else
    return 'mode ' .. mode
  end
end

-- A side git-diff cannot show yet, such as a symlink or a submodule: a
-- read-only, one-line note in place of its content. The id in the name,
-- `git-diff://unsupported/<id>/<path>`, keeps the two sides of one change
-- apart.
local function unsupported_side(side)
  return {
    name = 'git-diff://unsupported/' .. side.id .. '/' .. side.path,
    buftype = 'nofile',
    lines = { side.path .. ' is ' .. describe_mode(side.mode) .. ' here; git-diff only diffs regular files' },
    modifiable = false,
  }
end

-- Elements: what the view renders, as a tree of plain data. Each element has
-- a `type`, which tells the view how to render it, and props. Each type has
-- one factory.

-- A notification, shown when it is rendered.
--   text   the message
--   level  'info' or 'error'
local function notification(text, level)
  return { type = 'notification', text = text, level = level }
end

-- Elements rendered together, in order.
local function group(children)
  return { type = 'group', children = children }
end

-- Buffers side by side in diff mode, from left to right, each pane the props
-- of a buffer (a side, above). `main` is the index of the pane shown in the
-- window the diff was opened from; the others are split off to its left and
-- right.
local function diff(panes, main)
  return { type = 'diff', panes = panes, main = main }
end

-- One quickfix entry, in the shape `setqflist()` takes:
--   filename   the buffer the entry opens
--   text       what the entry shows
--   user_data  the change it stands for, handed back by `getqflist()`
local function quickfix_item(filename, text, change)
  return { filename = filename, text = text, user_data = change }
end

-- A quickfix list:
--   title      names the list in the quickfix window's status line and
--              `:chistory`
--   items      its quickfix items
--   selected   the index of the selected entry
--   on_select  called with the index of an entry when it gets selected
local function quickfix(title, items, selected, on_select)
  return { type = 'quickfix', title = title, items = items, selected = selected, on_select = on_select }
end

return {
  empty_side = empty_side,
  file_side = file_side,
  stored_side = stored_side,
  unsupported_side = unsupported_side,
  quickfix_item = quickfix_item,
  notification = notification,
  group = group,
  diff = diff,
  quickfix = quickfix,
}
