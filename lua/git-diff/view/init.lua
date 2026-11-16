-- Renders element trees (see `view-model/elements.lua`) into Neovim, like
-- React DOM. `render(tree)` compares the tree with what is mounted and mounts,
-- updates or unmounts elements to match; `render(nil)` unmounts everything.
-- It knows element types, not what they are used for.
--
-- Each element type has
--   mount(props, context)            returns its instance
--   update(instance, props, context) returns the instance to keep
--   unmount(instance)
-- `mount` and `update` return an error second when something could not be
-- shown; the instance is kept either way, so it can still be unmounted.

-- The element types, by `type`. `group` is the root's own, below.
local element_types = {
  notification = require('git-diff.view.notification'),
  diff = require('git-diff.view.diff'),
  quickfix = require('git-diff.view.quickfix'),
}

-- A renderer. `context` is handed to every element, like React context:
--   load_blob  `load_blob(root, id)`, which returns a blob's content or nil
--              and an error; the diff element reads `src` sides with it
local function init(context)
  -- What is mounted, as nodes `{ type, instance }`, mirroring the last tree.
  -- nil while nothing is mounted.
  local mounted = nil

  local reconcile

  -- The group element: its children, rendered in order. The instance is the
  -- list of their nodes. Children are matched by position; extra ones are
  -- unmounted, last first.
  local group = {
    mount = function(props)
      local nodes = {}
      for index, child in ipairs(props.children) do
        nodes[index] = reconcile(nil, child)
      end
      return nodes
    end,
    update = function(nodes, props)
      local updated = {}
      for index, child in ipairs(props.children) do
        updated[index] = reconcile(nodes[index], child)
      end
      for index = #nodes, #props.children + 1, -1 do
        reconcile(nodes[index], nil)
      end
      return updated
    end,
    unmount = function(nodes)
      for index = #nodes, 1, -1 do
        reconcile(nodes[index], nil)
      end
    end,
  }

  local function type_of(type_name)
    if type_name == 'group' then
      return group
    end
    return element_types[type_name]
  end

  -- The node for `element` in place of `node`: the same node updated when
  -- both have the same type, otherwise the old one unmounted and a new one
  -- mounted. A nil `element` unmounts `node`.
  reconcile = function(node, element)
    if node and (not element or node.type ~= element.type) then
      type_of(node.type).unmount(node.instance)
      node = nil
    end

    if not element then
      return nil
    end

    local element_type = type_of(element.type)
    if not element_type then
      vim.notify('unsupported element type: ' .. tostring(element.type), vim.log.levels.ERROR)
      return nil
    end

    local instance, error_message
    if node then
      instance, error_message = element_type.update(node.instance, element, context)
    else
      instance, error_message = element_type.mount(element, context)
    end
    if error_message then
      vim.notify(error_message, vim.log.levels.ERROR)
    end
    return { type = element.type, instance = instance }
  end

  -- Makes the screen show `tree`; nil unmounts everything.
  local function render(tree)
    mounted = reconcile(mounted, tree)
  end

  return {
    render = render,
  }
end

return {
  init = init,
}
