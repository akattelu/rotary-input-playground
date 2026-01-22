-- Tests for lib/syntax.lua (tree-sitter FFI bindings)
local assert = require("assert")
local Syntax = require("lib.syntax")

-- =============================================================================
-- Language Registry
-- =============================================================================

assert.test("languages: registry contains expected languages", function()
  assert.truthy(Syntax.languages["lua"], "should have lua")
  assert.truthy(Syntax.languages["javascript"], "should have javascript")
  assert.truthy(Syntax.languages["python"], "should have python")
  assert.truthy(Syntax.languages["rust"], "should have rust")
end)

assert.test("languages: registry does not contain invalid names", function()
  assert.falsy(Syntax.languages["notareallanguage"], "should not have fake language")
  assert.falsy(Syntax.languages[""], "should not have empty string")
end)

assert.test("get_language: returns language for valid name", function()
  local lang = Syntax.get_language("lua")
  assert.truthy(lang, "lua language should load")
end)

assert.test("get_language: returns nil for invalid name", function()
  local lang = Syntax.get_language("notareallanguage")
  assert.equal(lang, nil, "invalid language should return nil")
end)

assert.test("get_language: caches loaded languages", function()
  local lang1 = Syntax.get_language("lua")
  local lang2 = Syntax.get_language("lua")
  assert.equal(lang1, lang2, "same language should return cached instance")
end)

-- =============================================================================
-- Buffer Creation
-- =============================================================================

assert.test("Buffer.new: creates buffer for valid language", function()
  local buf = Syntax.Buffer.new("lua")
  assert.truthy(buf, "buffer should be created")
  assert.truthy(buf._parser, "buffer should have parser")
  buf:destroy()
end)

assert.test("Buffer.new: errors for invalid language", function()
  local ok, err = pcall(Syntax.Buffer.new, "notareallanguage")
  assert.falsy(ok, "should error for invalid language")
  assert.truthy(err:match("Unknown language"), "error should mention unknown language")
end)

-- =============================================================================
-- Parsing
-- =============================================================================

assert.test("Buffer:set_text: parses code and creates tree", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  assert.truthy(buf._tree, "tree should exist after parsing")
  assert.equal(buf:get_text(), "local x = 1", "text should be stored")
  buf:destroy()
end)

assert.test("Buffer:root_node: returns root after parsing", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  assert.truthy(root, "root node should exist")
  assert.equal(Syntax.node_type(root), "chunk", "lua root should be 'chunk'")
  buf:destroy()
end)

assert.test("Buffer:root_node: returns nil before parsing", function()
  local buf = Syntax.Buffer.new("lua")
  local root = buf:root_node()
  assert.equal(root, nil, "root should be nil before set_text")
  buf:destroy()
end)

-- =============================================================================
-- Node Inspection
-- =============================================================================

assert.test("node_type: returns correct type", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  assert.equal(Syntax.node_type(root), "chunk", "root type should be chunk")
  buf:destroy()
end)

assert.test("node_type: returns nil for nil node", function()
  assert.equal(Syntax.node_type(nil), nil, "nil node should return nil type")
end)

assert.test("node_text: extracts correct text", function()
  local buf = Syntax.Buffer.new("lua")
  local code = "local x = 42"
  buf:set_text(code)
  local root = buf:root_node()
  assert.equal(Syntax.node_text(root, code), code, "root text should be full code")
  buf:destroy()
end)

assert.test("node_range: returns byte and point positions", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  local range = Syntax.node_range(root)
  assert.truthy(range, "range should exist")
  assert.equal(range.start_byte, 0, "start_byte should be 0")
  assert.equal(range.start_row, 0, "start_row should be 0")
  assert.equal(range.start_col, 0, "start_col should be 0")
  buf:destroy()
end)

assert.test("node_is_named: distinguishes named and anonymous nodes", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  assert.truthy(Syntax.node_is_named(root), "root should be named")
  buf:destroy()
end)

assert.test("node_has_error: detects parse errors", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x =") -- incomplete
  local root = buf:root_node()
  assert.truthy(Syntax.node_has_error(root), "incomplete code should have error")
  buf:destroy()
end)

assert.test("node_has_error: no error for valid code", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  assert.falsy(Syntax.node_has_error(root), "valid code should not have error")
  buf:destroy()
end)

-- =============================================================================
-- Tree Navigation
-- =============================================================================

assert.test("node_child_count: returns correct count", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1\nlocal y = 2")
  local root = buf:root_node()
  local count = Syntax.node_child_count(root)
  assert.truthy(count >= 2, "root should have at least 2 children")
  buf:destroy()
end)

assert.test("node_child: retrieves child by index", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  local child = Syntax.node_child(root, 0)
  assert.truthy(child, "first child should exist")
  buf:destroy()
end)

assert.test("node_child: returns nil for out of bounds", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  local child = Syntax.node_child(root, 999)
  assert.equal(child, nil, "out of bounds should return nil")
  buf:destroy()
end)

assert.test("node_parent: returns parent node", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  local child = Syntax.node_child(root, 0)
  local parent = Syntax.node_parent(child)
  assert.truthy(Syntax.nodes_equal(parent, root), "child's parent should be root")
  buf:destroy()
end)

assert.test("node_named_children: iterates named children", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1\nlocal y = 2")
  local root = buf:root_node()
  local count = 0
  for _ in Syntax.node_named_children(root) do
    count = count + 1
  end
  assert.truthy(count >= 2, "should iterate at least 2 named children")
  buf:destroy()
end)

assert.test("node_first_named_child: returns first named child", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  local first = Syntax.node_first_named_child(root)
  assert.truthy(first, "first named child should exist")
  buf:destroy()
end)

-- =============================================================================
-- Tree Walking
-- =============================================================================

assert.test("walk: visits all nodes depth-first", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  local visited = {}
  Syntax.walk(root, function(node, depth)
    table.insert(visited, { type = Syntax.node_type(node), depth = depth })
  end)
  assert.truthy(#visited > 0, "should visit nodes")
  assert.equal(visited[1].type, "chunk", "first visited should be root")
  assert.equal(visited[1].depth, 0, "root depth should be 0")
  buf:destroy()
end)

assert.test("walk: respects early termination", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1\nlocal y = 2")
  local root = buf:root_node()
  local count = 0
  Syntax.walk(root, function()
    count = count + 1
    return false -- stop descending
  end)
  assert.equal(count, 1, "should only visit root when returning false")
  buf:destroy()
end)

assert.test("walk_named: visits only named nodes", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  local all_named = true
  Syntax.walk_named(root, function(node)
    if not Syntax.node_is_named(node) then
      all_named = false
    end
  end)
  assert.truthy(all_named, "walk_named should only visit named nodes")
  buf:destroy()
end)

-- =============================================================================
-- Node Location
-- =============================================================================

assert.test("node_at_byte: finds node at byte position", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  local node = Syntax.node_at_byte(root, 6) -- 'x'
  assert.truthy(node, "should find node at position")
  buf:destroy()
end)

assert.test("node_at_point: finds node at row/column", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1\nlocal y = 2")
  local root = buf:root_node()
  local node = Syntax.node_at_point(root, 1, 6) -- 'y' on second line
  assert.truthy(node, "should find node at point")
  buf:destroy()
end)

-- =============================================================================
-- S-expression
-- =============================================================================

assert.test("node_sexpr: returns s-expression string", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  local root = buf:root_node()
  local sexpr = Syntax.node_sexpr(root)
  assert.truthy(sexpr, "sexpr should exist")
  assert.truthy(sexpr:match("chunk"), "sexpr should contain 'chunk'")
  buf:destroy()
end)

-- =============================================================================
-- Incremental Editing
-- =============================================================================

assert.test("Buffer:insert: inserts text and reparses", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  buf:insert(6, "y") -- "local yx = 1"
  assert.equal(buf:get_text(), "local yx = 1", "text should be updated")
  assert.truthy(buf:root_node(), "tree should exist after edit")
  buf:destroy()
end)

assert.test("Buffer:delete: deletes text and reparses", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  buf:delete(6, 7) -- "local  = 1" (remove 'x')
  assert.equal(buf:get_text(), "local  = 1", "text should be updated")
  buf:destroy()
end)

assert.test("Buffer:replace: replaces text and reparses", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  buf:replace(6, 7, "abc") -- "local abc = 1"
  assert.equal(buf:get_text(), "local abc = 1", "text should be updated")
  buf:destroy()
end)

-- =============================================================================
-- Cleanup
-- =============================================================================

assert.test("Buffer:destroy: cleans up resources", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  buf:destroy()
  assert.equal(buf._parser, nil, "parser should be nil after destroy")
  assert.equal(buf._tree, nil, "tree should be nil after destroy")
end)

assert.test("Buffer:destroy: safe to call multiple times", function()
  local buf = Syntax.Buffer.new("lua")
  buf:set_text("local x = 1")
  buf:destroy()
  buf:destroy() -- should not error
  assert.truthy(true, "double destroy should not error")
end)
