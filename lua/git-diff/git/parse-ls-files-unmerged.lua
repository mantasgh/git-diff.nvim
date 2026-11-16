-- Parses `git ls-files -u -z` output: one entry per stage of each unmerged
-- path, NUL terminated:
--   100644 <id> 1\t<path>\0
-- Stage 1 is the base, 2 ours, 3 theirs. A stage the conflict has no
-- version for is missing: no 1 when both sides added the path, no 2 when we
-- deleted it, no 3 when they did.
local function parse_ls_files_unmerged(output)
  local unmerged = {}

  for entry in output:gmatch('([^%z]*)%z') do
    local mode, id, stage, path = entry:match('^(%d+) (%x+) ([123])\t(.*)$')
    if not mode then
      return nil, 'unexpected git ls-files output: ' .. entry
    end

    if not unmerged[path] then
      unmerged[path] = {}
    end
    unmerged[path][tonumber(stage)] = { path = path, mode = mode, id = id }
  end

  return unmerged
end

return {
  parse_ls_files_unmerged = parse_ls_files_unmerged,
}
