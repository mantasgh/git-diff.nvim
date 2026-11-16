-- Hands a quickfix list to Neovim: creates the list and opens its window.
-- After that the list is Neovim's: it keeps the entries and the selection, and
-- they are read back from it with `getqflist()` rather than kept here.
-- `items` are `setqflist()` items:
--   filename   the buffer the entry opens. `setqflist()` turns it into a
--              buffer number once: the buffer with that name, or a new
--              unlisted, unloaded one. Entries keep only the number.
--   text       what the entry shows
--   user_data  any value, kept as-is and handed back by `getqflist()`
-- `title` names the list in the quickfix window's status line and `:chistory`.
-- The `setqflist()` call:
--   {}                ignored; with a `what` table the list comes from it
--   ' '               add a new list after the current one and make it
--                     current; `:colder` still reaches the lists before it
--   quickfixtextfunc  how entries are drawn; Neovim calls it with
--                     `{ id, start_idx, end_idx }` when it writes the window's
--                     lines: for every entry when the window is filled, for
--                     the new ones after an append, never on scrolling. It
--                     wants one line per entry in that range. Returning `text`
--                     drops quickfix's default `filename|| ` prefix.
-- `copen` opens the quickfix window, or moves to it, and puts the cursor there.
-- Returns the new list's id: `id = 0` asks for the current list, which is the
-- new one. Ids are never reused, so it finds this list after others become
-- current, until the list leaves the stack.
local function open_quickfix_list(items, title)
  vim.fn.setqflist({}, ' ', {
    items = items,
    title = title,
    quickfixtextfunc = function(info)
      -- `items = 1` asks for the entries; only the key counts, not its value.
      local list_items = vim.fn.getqflist({ id = info.id, items = 1 }).items
      local drawn_items = vim.list_slice(list_items, info.start_idx, info.end_idx)
      return vim.tbl_map(function(item)
        return item.text
      end, drawn_items)
    end,
  })
  -- Read before `copen`: its autocommands could create a list of their own,
  -- which would then be the current one.
  local id = vim.fn.getqflist({ id = 0 }).id
  vim.cmd.copen()
  return id
end

-- Empties the list with `id` and closes the quickfix window if it shows that
-- list. One list cannot be deleted, only all of them (`'f'`), so it stays in
-- the stack, empty, under its title. Its entries have to go: they hold buffer
-- numbers, and once their buffers are wiped, jumping to one fails with
-- `E92: Buffer N not found`.
--   'r'    replace the items of the list `id`, keeping its place and title
--   cclose closes the quickfix window of this tab page; Neovim refuses when it
--          is the only window
-- The placeholders `setqflist()` made for entries never opened go too: their
-- buffers are still unlisted and unloaded. A buffer that was opened is loaded
-- or listed, maybe edited, and stays.
local function close_quickfix_list(id)
  if vim.fn.getqflist({ id = id }).id == id then
    local list_items = vim.fn.getqflist({ id = id, items = 1 }).items
    vim.fn.setqflist({}, 'r', { id = id, items = {} })

    for _, item in ipairs(list_items) do
      local buffer = item.bufnr
      local is_placeholder = vim.api.nvim_buf_is_valid(buffer)
        and not vim.api.nvim_buf_is_loaded(buffer)
        and not vim.bo[buffer].buflisted
      if is_placeholder then
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
    end
  end

  -- The window shows whichever list is current; close it only when that is
  -- this one, so a `:grep` opened since keeps its window.
  local is_current = vim.fn.getqflist({ id = 0 }).id == id
  if is_current and #vim.api.nvim_tabpage_list_wins(0) > 1 then
    vim.cmd.cclose()
  end
end

-- Whether two lists of quickfix items show the same entries: the same
-- buffers and texts, in the same order.
local function is_same_items(items, other_items)
  if #items ~= #other_items then
    return false
  end
  for index, item in ipairs(items) do
    local other = other_items[index]
    if item.filename ~= other.filename or item.text ~= other.text then
      return false
    end
  end
  return true
end

-- Makes entry `index` the selected one of the list `id`, without jumping to
-- it.
local function select_entry(id, index)
  vim.fn.setqflist({}, 'a', { id = id, idx = index })
end

-- Quickfix has no "selected entry changed" event. Every way of moving to an
-- entry (`:cnext`, `]q`, `:cc N`, `<CR>` in the quickfix window) opens its
-- file in a window, so `BufWinEnter` is checked for a changed `idx` instead.
-- `on_select` runs once quickfix has finished with its window; what it
-- renders then replaces the buffer quickfix opened. Rendering fires
-- `BufWinEnter` too, but `idx` has not changed then.
local function follow(instance)
  local list = vim.fn.getqflist({ id = instance.id, idx = 0 })
  -- The list is gone once 10 newer lists have pushed it off the stack.
  if list.id ~= instance.id or list.idx == instance.selected then
    return
  end

  -- Recorded before `on_select`, so a render that fails halfway does not
  -- start another one from the `BufWinEnter` it fired itself.
  local selected = list.idx
  instance.selected = selected
  local on_select = instance.props.on_select
  vim.schedule(function()
    on_select(selected)
  end)
end

-- The quickfix element: a quickfix list, opened when mounted and followed
-- until unmounted, calling `props.on_select(index)` when another entry is
-- selected. The instance keeps the list's id, the selected entry and the
-- props, whose `on_select` the next update may replace.
local function mount(props)
  local id = open_quickfix_list(props.items, props.title)
  if props.selected ~= 1 then
    select_entry(id, props.selected)
  end

  local instance = {
    id = id,
    selected = props.selected,
    props = props,
    group = vim.api.nvim_create_augroup('view-quickfix-' .. id, { clear = true }),
  }
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = instance.group,
    callback = function()
      follow(instance)
    end,
  })
  return instance
end

-- Stops following the list, empties it and closes its window.
local function unmount(instance)
  vim.api.nvim_del_augroup_by_id(instance.group)
  close_quickfix_list(instance.id)
end

-- Other entries or another title make a new list; otherwise only the
-- selection follows the props.
local function update(instance, props)
  if props.title ~= instance.props.title or not is_same_items(props.items, instance.props.items) then
    unmount(instance)
    return mount(props)
  end

  if props.selected ~= instance.selected then
    select_entry(instance.id, props.selected)
    instance.selected = props.selected
  end
  instance.props = props
  return instance
end

return {
  mount = mount,
  update = update,
  unmount = unmount,
}
