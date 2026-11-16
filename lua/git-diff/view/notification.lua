-- The notification element: shows its text with `vim.notify()` when mounted,
-- and again when updated with another text or level.

-- The `vim.notify()` level of each `level` prop.
local levels = {
  info = vim.log.levels.INFO,
  error = vim.log.levels.ERROR,
}

local function notify(props)
  local level = levels[props.level]
  if not level then
    return 'unsupported notification level: ' .. tostring(props.level)
  end
  vim.notify(props.text, level)
end

local function mount(props)
  return props, notify(props)
end

local function update(shown, props)
  if props.text == shown.text and props.level == shown.level then
    return props
  end
  return props, notify(props)
end

-- A notification cannot be taken back.
local function unmount() end

return {
  mount = mount,
  update = update,
  unmount = unmount,
}
