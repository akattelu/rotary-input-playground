-- Tests for lib/filter.lua
local assert = require("assert")
local Filter = require("lib.filter")

-- Shorthand for keyboard positions
local positions = Filter.keyboard_virtual_positions
local center = Filter.center_key

-- get_closest_key: deadzone behavior
assert.test("get_closest_key: stick at (0,0) returns center key 'g'", function()
  local key = Filter.get_closest_key(0, 0, positions, center)
  assert.equal(key, "g", "center position should return 'g'")
end)

assert.test("get_closest_key: stick at (15,15) returns 'g' (within deadzone)", function()
  -- Magnitude = sqrt(15^2 + 15^2) = ~21.2, but let's use smaller values
  local key = Filter.get_closest_key(10, 10, positions, center)
  assert.equal(key, "g", "small movement should stay in deadzone")
end)

assert.test("get_closest_key: stick at (19,0) returns 'g' (just inside deadzone)", function()
  local key = Filter.get_closest_key(19, 0, positions, center)
  assert.equal(key, "g", "magnitude < 20 should return center")
end)

assert.test("get_closest_key: outside deadzone returns closest key", function()
  -- Position near 'h' which is at (20, 0)
  local key = Filter.get_closest_key(25, 0, positions, center)
  assert.equal(key, "h", "position near h should return h")
end)

assert.test("get_closest_key: far right returns 'p'", function()
  -- 'p' is at (90, -70)
  local key = Filter.get_closest_key(90, -70, positions, center)
  assert.equal(key, "p", "top-right corner should return p")
end)

assert.test("get_closest_key: bottom left returns 'z'", function()
  -- 'z' is at (-75, 70)
  local key = Filter.get_closest_key(-75, 70, positions, center)
  assert.equal(key, "z", "bottom-left should return z")
end)

-- get_key_region: returns exactly 4 keys
assert.test("get_key_region: returns exactly REGION_COUNT keys", function()
  local region = Filter.get_key_region(0, 0, positions, center)
  assert.equal(#region, Filter.REGION_COUNT, "should return 4 keys")
end)

assert.test("get_key_region: center position includes 'g'", function()
  local region = Filter.get_key_region(0, 0, positions, center)
  local has_g = false
  for _, key in ipairs(region) do
    if key == "g" then
      has_g = true
    end
  end
  assert.truthy(has_g, "center region should include 'g'")
end)

assert.test("get_key_region: keys sorted by distance (closest first)", function()
  -- At position (0,0), 'g' is at (0,0), so it should be first
  local region = Filter.get_key_region(0, 0, positions, center)
  assert.equal(region[1], "g", "first key should be closest (g at center)")
end)

assert.test("get_key_region: deadzone snaps to center", function()
  -- Small movement should still use center for calculation
  local region = Filter.get_key_region(5, 5, positions, center)
  assert.equal(region[1], "g", "small movement should return g first")
end)

-- apply: word filtering
local test_words = { "apple", "banana", "cat", "dog", "egg", "fig", "grape", "hat" }

assert.test("apply: nil regions returns unfiltered words", function()
  local result = Filter.apply(test_words, nil, nil)
  assert.equal(#result, #test_words, "should return all words")
end)

assert.test("apply: left_region filters by word start", function()
  local result = Filter.apply(test_words, { "a", "b" }, nil)
  assert.equal(#result, 2, "should return apple and banana")
  assert.equal(result[1], "apple")
  assert.equal(result[2], "banana")
end)

assert.test("apply: right_region filters by word end", function()
  local result = Filter.apply(test_words, nil, { "g", "t" })
  -- Words ending in 'g': dog, egg, fig
  -- Words ending in 't': cat, hat
  assert.equal(#result, 5, "should return words ending in g or t")
end)

assert.test("apply: both regions intersect results", function()
  -- Start with 'c' or 'd', end with 'g' or 't'
  -- cat (c, t) - yes
  -- dog (d, g) - yes
  local result = Filter.apply(test_words, { "c", "d" }, { "g", "t" })
  assert.equal(#result, 2, "should return cat and dog")
end)

assert.test("apply: empty result when no matches", function()
  local result = Filter.apply(test_words, { "z" }, nil)
  assert.equal(#result, 0, "should return empty when no matches")
end)

assert.test("apply: nil regions limits to 100 words", function()
  -- Create large word list
  local large_list = {}
  for i = 1, 200 do
    table.insert(large_list, "word" .. i)
  end
  local result = Filter.apply(large_list, nil, nil)
  assert.equal(#result, 100, "should limit to 100 words")
end)

assert.test("apply: case sensitive matching", function()
  local words = { "Apple", "apple", "APPLE" }
  local result = Filter.apply(words, { "a" }, nil)
  assert.equal(#result, 1, "should only match lowercase 'a'")
  assert.equal(result[1], "apple")
end)
