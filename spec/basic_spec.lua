-- Basic sanity tests
local assert = require("assert")

assert.test("arithmetic: 1 + 1 = 2", function()
  assert.equal(1 + 1, 2, "addition should work")
end)
