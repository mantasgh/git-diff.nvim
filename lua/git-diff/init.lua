local git = require('git-diff.git').init(vim.system)
local app_model = require('git-diff.model').init(git, vim.fn.executable)
local app_view_model = require('git-diff.view-model')
local view = require('git-diff.view').init({ load_blob = git.read_blob })

-- Opens `git diff <arguments>` as a quickfix list and a diff: `{}` for
-- unstaged changes, `{ 'HEAD' }`, `{ '--staged' }`, `{ '--merge-base', 'main' }`
-- and so on. Each run starts over: close, model, view model, view.
local function open(arguments)
  view.render(nil)

  -- The window's directory, which follows `:cd`, `:tcd` and `:lcd`.
  local model, model_error = app_model.build_model(vim.fn.getcwd(), arguments)

  -- Renders the view model with entry `selected` shown; the quickfix element
  -- calls it again when another entry is selected.
  local function on_select(selected)
    local view_model = app_view_model.build_view_model(model, model_error, selected, on_select)
    view.render(view_model)
  end

  on_select(1)
end

-- Closes what `open` opened.
local function close()
  view.render(nil)
end

return {
  open = open,
  close = close,
}
