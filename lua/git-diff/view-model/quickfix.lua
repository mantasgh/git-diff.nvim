local view_model = require('git-diff.view-model.elements')

-- The model as quickfix items, in plain data, ready for `setqflist()`: for
-- each entry, the buffer it opens (`filename`), what it shows (`text`) and its
-- change (`user_data`). Nothing here touches Neovim. The text looks like
-- `git diff --name-status`:
--   M	modified.lua
--   R096	old_name.lua	new_name.lua
-- An entry opens the buffer its diff shows in the main window, the right side
-- or the middle of a three-way diff, so that quickfix, which opens it before
-- the diff is shown, changes nothing there and opens nothing to throw away.
-- `diff_views` holds the diff element of each change, in the same order.
local function build_quickfix_view_model(model, diff_views)
  local entries = {}
  for index, change in ipairs(model.changes) do
    local status = change.status
    local diff = diff_views[index]
    local shown_side = diff.panes[diff.main]
    local text

    if status == 'M' or status == 'T' or status == 'A' then
      text = status .. '\t' .. change.new.path
    elseif status == 'D' then
      text = status .. '\t' .. change.old.path
    elseif status == 'R' or status == 'C' then
      text = string.format('%s%03d\t%s\t%s', status, change.similarity, change.old.path, change.new.path)
    elseif status == 'U' then
      text = status .. '\t' .. change.path
    else
      return nil, 'unsupported git diff status: ' .. status
    end

    table.insert(entries, view_model.quickfix_item(shown_side.name, text, change))
  end
  return entries
end

return {
  build_quickfix_view_model = build_quickfix_view_model,
}
