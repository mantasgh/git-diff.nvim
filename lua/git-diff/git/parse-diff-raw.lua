-- Parses `git diff --raw -z` output. Fields are NUL terminated: each entry is
-- its metadata followed by one path, or two for renames (R) and copies (C):
--   :100644 100644 <old id> <new id> M\0<path>\0
--   :100644 100644 <old id> <new id> R096\0<old path>\0<new path>\0
-- Added files have no `old` side, deleted files no `new` side. Unmerged
-- entries have only a `path`.
local function parse_diff_raw(output)
  local next_match = output:gmatch('([^%z]*)%z')
  local changes = {}

  for field in next_match do
    -- The field before an entry's paths: `:100644 100644 <old id> <new id> R096`.
    local old_mode, new_mode, old_id, new_id, status, score =
      field:match('^:(%d+) (%d+) (%x+) (%x+) (%u)(%d*)$')
    if not status then
      return nil, 'unexpected git diff output: ' .. field
    end

    local change = { status = status }

    local path = next_match()
    if not path then
      return nil, 'missing path: ' .. field
    end

    if status == 'M' or status == 'T' then
      change.old = { path = path, mode = old_mode, id = old_id }
      change.new = { path = path, mode = new_mode, id = new_id }
      -- With `-B`, a rewritten file's dissimilarity: `M095` is 95% changed.
      if score ~= '' then
        change.dissimilarity = tonumber(score)
      end
    elseif status == 'A' then
      change.new = { path = path, mode = new_mode, id = new_id }
    elseif status == 'D' then
      change.old = { path = path, mode = old_mode, id = old_id }
    elseif status == 'R' or status == 'C' then
      local new_path = next_match()
      if not new_path then
        return nil, 'missing new path: ' .. field
      end
      change.old = { path = path, mode = old_mode, id = old_id }
      change.new = { path = new_path, mode = new_mode, id = new_id }
      change.similarity = tonumber(score)
    elseif status == 'U' then
      -- Unmerged: the index holds several versions of the path (stages 1-3)
      -- and no single one to diff, so the entry has only its path.
      change.path = path
    else
      return nil, 'unsupported git diff status: ' .. field
    end

    table.insert(changes, change)
  end

  return changes
end

return {
  parse_diff_raw = parse_diff_raw,
}
