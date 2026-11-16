local view_model = require('git-diff.view-model.elements')

-- Whether a side is a regular file, executable or not: the only kind whose
-- content is text to diff. Symlinks (120000) store their target path and
-- submodules (160000) a commit id.
local function is_regular_file(side)
  return side.mode == '100644' or side.mode == '100755'
end

-- Whether a new side is the working tree file: `git diff --raw` reports it as
-- an all-zero id when it differs from the index. A working tree file that
-- matches the index comes with the index's id and is shown as stored content,
-- read-only, like everything staged or committed: only unstaged work is
-- editable.
local function is_working_tree(side)
  return side.id:match('^0+$') ~= nil
end

-- The left window: the old side, before the change. Empty for an added file,
-- otherwise always stored content: `-R` is not supported (see `diff_raw`), the
-- only way to put the working tree on the left. A side that is not a regular
-- file is an unsupported side.
local function build_left_side(model, change)
  local status = change.status

  if status == 'A' then
    return view_model.empty_side()
  elseif status == 'M' or status == 'T' or status == 'R' or status == 'C' or status == 'D' then
    if not is_regular_file(change.old) then
      return view_model.unsupported_side(change.old)
    end
    return view_model.stored_side(model.root, change.old.id, change.old.path)
  else
    return nil, 'unsupported git diff status: ' .. status
  end
end

-- The right window: the new side, after the change. Empty for a deleted file,
-- the working tree file when git reports unstaged work, stored content
-- otherwise. A side that is not a regular file is an unsupported side.
local function build_right_side(model, change)
  local status = change.status

  if status == 'D' then
    return view_model.empty_side()
  elseif status == 'M' or status == 'T' or status == 'R' or status == 'C' or status == 'A' then
    if not is_regular_file(change.new) then
      return view_model.unsupported_side(change.new)
    end
    if is_working_tree(change.new) then
      return view_model.file_side(vim.fs.joinpath(model.root, change.new.path))
    end
    return view_model.stored_side(model.root, change.new.id, change.new.path)
  else
    return nil, 'unsupported git diff status: ' .. status
  end
end

-- The left window of a path both sides deleted: the base, stage 1, the only
-- stage left. A stage that is not a regular file is an unsupported side.
local function build_base_side(model, stages)
  local base = stages[1]

  if not base then
    return view_model.empty_side()
  end
  if not is_regular_file(base) then
    return view_model.unsupported_side(base)
  end
  return view_model.stored_side(model.root, base.id, base.path)
end

-- The left window of a merge conflict: ours, stage 2. Empty when we deleted
-- the path. A stage that is not a regular file is an unsupported side.
local function build_ours_side(model, stages)
  local ours = stages[2]

  if not ours then
    return view_model.empty_side()
  end
  if not is_regular_file(ours) then
    return view_model.unsupported_side(ours)
  end
  return view_model.stored_side(model.root, ours.id, ours.path)
end

-- The middle window of a merge conflict: the working tree file, where the
-- conflict is resolved.
local function build_working_side(model, path)
  return view_model.file_side(vim.fs.joinpath(model.root, path))
end

-- The right window of a merge conflict: theirs, stage 3. Empty when they
-- deleted the path. A stage that is not a regular file is an unsupported
-- side.
local function build_theirs_side(model, stages)
  local theirs = stages[3]

  if not theirs then
    return view_model.empty_side()
  end
  if not is_regular_file(theirs) then
    return view_model.unsupported_side(theirs)
  end
  return view_model.stored_side(model.root, theirs.id, theirs.path)
end

-- The diff windows for one change, in plain data. Nothing here changes
-- Neovim. Each window depends only on its own side of the change. An
-- unmerged path is a three-way diff of its index stages, or, when both sides
-- deleted it, a two-way diff of its base and nothing, like a deletion. Every
-- other change is a two-way diff.
local function build_diff_view_model(model, change)
  local status = change.status

  if status == 'M' or status == 'T' or status == 'A' or status == 'D' or status == 'R' or status == 'C' then
    local left, left_error = build_left_side(model, change)
    if not left then
      return nil, left_error
    end

    local right, right_error = build_right_side(model, change)
    if not right then
      return nil, right_error
    end

    -- Two panes, the main one on the right.
    return view_model.diff({ left, right }, 2)
  elseif status == 'U' then
    local stages = model.unmerged[change.path]
    if not stages then
      return nil, 'no index stages for unmerged path: ' .. change.path
    end

    -- Both deleted, e.g. when each side renamed the file differently: there
    -- is no ours, no theirs and no working tree file.
    if not stages[2] and not stages[3] then
      return view_model.diff({ build_base_side(model, stages), view_model.empty_side() }, 2)
    end

    -- Three panes, the main one, the working tree file, in the middle.
    return view_model.diff({
      build_ours_side(model, stages),
      build_working_side(model, change.path),
      build_theirs_side(model, stages),
    }, 2)
  else
    return nil, 'unsupported git diff status: ' .. status
  end
end

return {
  build_diff_view_model = build_diff_view_model,
}
