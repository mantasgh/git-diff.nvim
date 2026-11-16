-- The windows the diff is shown in: opening them next to another window,
-- evening out their widths and closing them again.

-- Whether `window` is still open; nil and closed windows are not.
local function is_open(window)
  return window ~= nil and vim.api.nvim_win_is_valid(window)
end

-- A new window split off `window` to the side `direction` ('left' or
-- 'right'), showing the same buffer until another one is set. The cursor
-- stays where it is.
local function open_split(window, direction)
  return vim.api.nvim_open_win(vim.api.nvim_win_get_buf(window), false, { split = direction, win = window })
end

-- Gives the windows side by side with `window` equal widths. `horizontal`
-- evens out only the widths, not the quickfix height.
local function even_widths(window)
  vim.api.nvim_win_call(window, function()
    vim.cmd('horizontal wincmd =')
  end)
end

-- Closes a split window. Never closes a tab: a window that is alone in its tab
-- stays open.
local function close_split(window)
  local is_alone = #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(window)) == 1
  if not is_alone then
    vim.api.nvim_win_close(window, false)
  end
end

return {
  is_open = is_open,
  open_split = open_split,
  even_widths = even_widths,
  close_split = close_split,
}
