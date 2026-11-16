-- Utilities for one buffer of the view at a time. Nothing here keeps track of
-- buffers: the view decides which ones it made and when they go.

-- A buffer that is not a file, found by name or created. `bufadd()` returns
-- the existing buffer for a name, so each name is one buffer, also when
-- quickfix created it first by jumping to an entry.
--   buftype=nofile  never written, and `:w` refuses
--   bufhidden=hide  kept when no window shows it, so it is filled only once
--   nobuflisted     kept out of `:ls`, where quickfix's jump would put it
--   swapfile off    nothing to recover
local function scratch_buffer(name)
  local buffer = vim.fn.bufadd(name)
  vim.fn.bufload(buffer)
  vim.bo[buffer].buftype = 'nofile'
  vim.bo[buffer].buflisted = false
  vim.bo[buffer].bufhidden = 'hide'
  vim.bo[buffer].swapfile = false
  return buffer
end

-- The lines of the blob `src`, read with `load_blob(root, id)`, like a browser
-- loading and decoding an `<img src>`. Binary content is replaced by a note.
local function load_lines(src, load_blob)
  local content, error_message = load_blob(src.root, src.id)
  if not content then
    return nil, error_message
  end

  if content:find('\0') then
    return { '(binary content, not shown)' }
  end

  -- Like Neovim reading a file: when every line ends in `\r\n`, the `\r`s
  -- are dropped ('fileformat' dos); one line ending in a plain `\n` keeps them
  -- all ('fileformat' unix).
  local has_plain_newline = content:find('^\n') ~= nil or content:find('[^\r]\n') ~= nil
  if not has_plain_newline then
    content = content:gsub('\r\n', '\n')
  end
  local lines = vim.split(content, '\n')
  -- A file's last line ends with a newline, which would add an empty line.
  if lines[#lines] == '' then
    table.remove(lines)
  end
  return lines
end

-- The buffer element: shows the buffer its props describe (see
-- `view-model/elements.lua`) in `window`, and returns its number, or nil and an
-- error. A buffer with `buftype` '' is a file on disk, opened with `:edit`, so
-- `:w`, LSP and filetype work as anywhere else. A 'nofile' buffer gets its
-- lines from `lines`, or from `src`, read with `load_blob(root, id)`. The
-- buffer notes the id it holds in `b:src_id`: an id always means the same
-- content, so it is read once.
local function show_buffer(window, props, load_blob)
  local buftype = props.buftype

  if buftype == '' then
    local ok, error_message = pcall(vim.api.nvim_win_call, window, function()
      vim.cmd.edit(vim.fn.fnameescape(props.name))
    end)
    if not ok then
      return nil, error_message
    end
    return vim.api.nvim_win_get_buf(window)
  elseif buftype == 'nofile' then
    local buffer = scratch_buffer(props.name)

    local lines = props.lines
    if props.src and vim.b[buffer].src_id ~= props.src.id then
      local loaded, load_error = load_lines(props.src, load_blob)
      if not loaded then
        return nil, load_error
      end
      lines = loaded
      vim.b[buffer].src_id = props.src.id
    end

    if lines then
      vim.bo[buffer].modifiable = true
      vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
    end
    vim.bo[buffer].modifiable = props.modifiable
    if props.filetype and vim.bo[buffer].filetype ~= props.filetype then
      vim.bo[buffer].filetype = props.filetype
    end
    vim.api.nvim_win_set_buf(window, buffer)
    return buffer
  else
    return nil, 'unsupported buftype: ' .. buftype
  end
end

-- What `window` shows instead of a buffer about to be wiped, since wiping a
-- buffer closes the windows that show it: the window's alternate buffer when
-- that is a normal listed one, otherwise an empty buffer that wipes itself
-- once something replaces it. The 'nofile' buffers `show_buffer` makes are
-- unlisted, so they are never the replacement.
local function replacement_buffer(window)
  local alternate = vim.api.nvim_win_call(window, function()
    return vim.fn.bufnr('#')
  end)
  if alternate > 0 and vim.bo[alternate].buflisted then
    return alternate
  end

  local replacement = vim.api.nvim_create_buf(false, true)
  vim.bo[replacement].bufhidden = 'wipe'
  return replacement
end

-- Wipes `buffer`, when it still exists. Windows that show it get another
-- buffer first.
local function wipe_buffer(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end

  for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
    vim.api.nvim_win_set_buf(window, replacement_buffer(window))
  end
  vim.api.nvim_buf_delete(buffer, { force = true })
end

return {
  show_buffer = show_buffer,
  wipe_buffer = wipe_buffer,
}
