local view_model = require('git-diff.view-model.elements')
local diff_view_model = require('git-diff.view-model.diff')
local quickfix_view_model = require('git-diff.view-model.quickfix')

-- The whole screen as an element tree: an error notification when the model
-- could not be built or a change cannot be shown, an information when there
-- are no changes, otherwise the diff of entry `selected` and the quickfix
-- list, titled with the command that was run. `model` and `model_error` are
-- what `build_model` returned; `on_select(index)` is called when another
-- entry is selected. It never fails; errors are elements too.
local function build_view_model(model, model_error, selected, on_select)
  if not model then
    return view_model.notification(model_error, 'error')
  end

  if #model.changes == 0 then
    return view_model.notification('git-diff: no changes', 'info')
  end

  local diff_views = {}
  for index, change in ipairs(model.changes) do
    local change_view, view_error = diff_view_model.build_diff_view_model(model, change)
    if not change_view then
      return view_model.notification(view_error, 'error')
    end
    diff_views[index] = change_view
  end

  local entries, error_message = quickfix_view_model.build_quickfix_view_model(model, diff_views)
  if not entries then
    return view_model.notification(error_message, 'error')
  end

  -- The diff first: it splits the current window, and the quickfix window
  -- then opens below both and takes the cursor.
  local title = table.concat(vim.list_extend({ ':GitDiff' }, model.arguments), ' ')
  return view_model.group({
    diff_views[selected],
    view_model.quickfix(title, entries, selected, on_select),
  })
end

return {
  build_view_model = build_view_model,
}
