-- Tests for lib/file_manager.lua (pure functions only)
-- Skips scan_directory and load_file which require love.filesystem
local assert = require("assert")
local FileManager = require("lib.file_manager")

-- get_language: extension mapping
assert.test("get_language: .lua returns lua", function()
  assert.equal(FileManager.get_language("test.lua"), "lua")
end)

assert.test("get_language: .js returns javascript", function()
  assert.equal(FileManager.get_language("app.js"), "javascript")
end)

assert.test("get_language: .ts returns typescript", function()
  assert.equal(FileManager.get_language("index.ts"), "typescript")
end)

assert.test("get_language: .py returns python", function()
  assert.equal(FileManager.get_language("script.py"), "python")
end)

assert.test("get_language: .rs returns rust", function()
  assert.equal(FileManager.get_language("main.rs"), "rust")
end)

assert.test("get_language: .go returns go", function()
  assert.equal(FileManager.get_language("server.go"), "go")
end)

assert.test("get_language: .md returns markdown", function()
  assert.equal(FileManager.get_language("README.md"), "markdown")
end)

assert.test("get_language: .sh returns bash", function()
  assert.equal(FileManager.get_language("build.sh"), "bash")
end)

assert.test("get_language: unknown extension returns lua (default)", function()
  assert.equal(FileManager.get_language("file.xyz"), "lua")
end)

assert.test("get_language: no extension returns lua (default)", function()
  assert.equal(FileManager.get_language("Makefile"), "lua")
end)

assert.test("get_language: uppercase extension handled", function()
  assert.equal(FileManager.get_language("FILE.LUA"), "lua")
end)

assert.test("get_language: path with directories", function()
  assert.equal(FileManager.get_language("lib/utils/helper.js"), "javascript")
end)

assert.test("get_language: file with multiple dots", function()
  assert.equal(FileManager.get_language("test.spec.ts"), "typescript")
end)

-- next_index: cycling forward
assert.test("next_index: 1 of 5 returns 2", function()
  assert.equal(FileManager.next_index(1, 5), 2)
end)

assert.test("next_index: 4 of 5 returns 5", function()
  assert.equal(FileManager.next_index(4, 5), 5)
end)

assert.test("next_index: 5 of 5 wraps to 1", function()
  assert.equal(FileManager.next_index(5, 5), 1)
end)

assert.test("next_index: single file stays at 1", function()
  assert.equal(FileManager.next_index(1, 1), 1)
end)

assert.test("next_index: zero files returns 1", function()
  assert.equal(FileManager.next_index(1, 0), 1)
end)

-- prev_index: cycling backward
assert.test("prev_index: 2 of 5 returns 1", function()
  assert.equal(FileManager.prev_index(2, 5), 1)
end)

assert.test("prev_index: 5 of 5 returns 4", function()
  assert.equal(FileManager.prev_index(5, 5), 4)
end)

assert.test("prev_index: 1 of 5 wraps to 5", function()
  assert.equal(FileManager.prev_index(1, 5), 5)
end)

assert.test("prev_index: single file stays at 1", function()
  assert.equal(FileManager.prev_index(1, 1), 1)
end)

assert.test("prev_index: zero files returns 1", function()
  assert.equal(FileManager.prev_index(1, 0), 1)
end)

assert.test("prev_index: middle index returns previous", function()
  assert.equal(FileManager.prev_index(3, 5), 2)
end)
