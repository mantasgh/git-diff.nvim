-- The diff element: buffers side by side in diff mode (see
-- `view-model/elements.lua`). Its instance keeps the windows it opened and the
-- 'nofile' buffers it made, so updates reuse the windows and unmounting closes
-- and wipes them. Files on disk are the user's and stay.

local buffer = require('git-diff.view.buffer')
local window = require('git-diff.view.window')

-- Turns diff mode off in every window of `target`'s tab page, and for hidden
-- buffers too: `diffoff!`.
local function diff_off(target)
  vim.api.nvim_win_call(target, function()
    vim.cmd('diffoff!')
  end)
end

-- `count` windows split off `main` to `direction`, 'left' or 'right', in pane
-- order. `splits` are reused while all of them are open and as many;
-- otherwise they are closed and opened anew. Each split opens next to `main`,
-- so the left ones open in order and the right ones in reverse. Returns the
-- windows and whether they changed, or nil and an error.
local function arrange(main, splits, count, direction)
  local is_reusable = #splits == count
  for _, split in ipairs(splits) do
    if not window.is_open(split) then
      is_reusable = false
    end
  end
  if is_reusable then
    return splits, false
  end

  for _, split in ipairs(splits) do
    if window.is_open(split) then
      window.close_split(split)
    end
  end

  local opened = {}
  if direction == 'left' then
    for index = 1, count do
      opened[index] = window.open_split(main, 'left')
    end
  elseif direction == 'right' then
    for index = count, 1, -1 do
      opened[index] = window.open_split(main, 'right')
    end
  else
    return nil, 'unsupported split direction: ' .. direction
  end
  return opened, true
end

-- Shows the panes of `props` in the instance's windows, opening and closing
-- splits as the number of panes needs. The first time, the current window
-- becomes the main one.
--   diffoff!  before changing buffers: every window of the tab page leaves
--             diff mode, and hidden buffers leave the diff too. A buffer
--             hidden while in diff mode stays in the diff otherwise; quickfix
--             hides one on every jump, before this runs.
--   diffthis  after, in every shown window: diff mode, scroll and cursor
--             binding
-- Returns the instance, and an error when a pane could not be shown.
local function update(instance, props, context)
  local main = instance.main
  if not window.is_open(main) then
    main = vim.api.nvim_get_current_win()
  end

  -- `arrange` returns nil and an error in place of the windows and whether
  -- they changed.
  local before, before_changed = arrange(main, instance.before, props.main - 1, 'left')
  if not before then
    return instance, before_changed
  end
  local after, after_changed = arrange(main, instance.after, #props.panes - props.main, 'right')
  if not after then
    return instance, after_changed
  end
  instance.main = main
  instance.before = before
  instance.after = after
  if before_changed or after_changed then
    window.even_widths(main)
  end

  diff_off(main)

  local shown_windows = {}
  for index, pane in ipairs(props.panes) do
    local pane_window
    if index < props.main then
      pane_window = before[index]
    elseif index == props.main then
      pane_window = main
    else
      pane_window = after[index - props.main]
    end

    local shown, error_message = buffer.show_buffer(pane_window, pane, context.load_blob)
    if not shown then
      return instance, error_message
    end
    if pane.buftype == 'nofile' then
      instance.buffers[shown] = true
    end
    table.insert(shown_windows, pane_window)
  end

  for _, shown_window in ipairs(shown_windows) do
    vim.api.nvim_win_call(shown_window, function()
      vim.cmd('diffthis')
    end)
  end

  return instance
end

local function mount(props, context)
  return update({ before = {}, after = {}, buffers = {} }, props, context)
end

-- Closes the split windows, wipes the buffers the element made and turns
-- diff mode off. The main window was the user's own, so it stays, showing
-- the working tree file if it did. A split `close_split` keeps open, alone in
-- its tab, gets another buffer like any window showing a wiped one. Diff mode
-- goes last: a buffer put back in a window gets the window options it last
-- had there, `diff` too.
local function unmount(instance)
  for _, splits in ipairs({ instance.before, instance.after }) do
    for _, split in ipairs(splits) do
      if window.is_open(split) then
        window.close_split(split)
      end
    end
  end

  for made in pairs(instance.buffers) do
    buffer.wipe_buffer(made)
  end

  if window.is_open(instance.main) then
    diff_off(instance.main)
  else
    diff_off(vim.api.nvim_get_current_win())
  end
end

return {
  mount = mount,
  update = update,
  unmount = unmount,
}
