local Filter = {}

-- Full QWERTY keyboard virtual positions for distance-based selection
-- Coordinates are in virtual space (-100 to 100)
-- Both left and right joysticks use the same full keyboard layout
Filter.keyboard_virtual_positions = {
  -- Top row (q w e r t y u i o p)
  q = { -90, -70 }, w = { -70, -70 }, e = { -50, -70 }, r = { -30, -70 }, t = { -10, -70 },
  y = { 10, -70 }, u = { 30, -70 }, i = { 50, -70 }, o = { 70, -70 }, p = { 90, -70 },
  -- Middle row (a s d f g h j k l)
  a = { -80, 0 }, s = { -60, 0 }, d = { -40, 0 }, f = { -20, 0 }, g = { 0, 0 },
  h = { 20, 0 }, j = { 40, 0 }, k = { 60, 0 }, l = { 80, 0 },
  -- Bottom row (z x c v b n m)
  z = { -75, 70 }, x = { -50, 70 }, c = { -25, 70 }, v = { 0, 70 },
  b = { 25, 70 }, n = { 50, 70 }, m = { 75, 70 }
}

Filter.center_key = "g"  -- Center of keyboard

-- Number of nearby keys to include in filter
Filter.REGION_COUNT = 4

-- Center deadzone threshold (in virtual space units)
local CENTER_DEADZONE = 20

-- Get the single closest key to stick position
function Filter.get_closest_key(stick_x, stick_y, virtual_positions, center_key)
  local magnitude = math.sqrt(stick_x * stick_x + stick_y * stick_y)

  -- If near center, return center key
  if magnitude < CENTER_DEADZONE then
    return center_key
  end

  local min_distance = math.huge
  local closest_key = center_key

  for key, pos in pairs(virtual_positions) do
    local vx, vy = pos[1], pos[2]
    local distance = math.sqrt((stick_x - vx) ^ 2 + (stick_y - vy) ^ 2)
    if distance < min_distance then
      min_distance = distance
      closest_key = key
    end
  end

  return closest_key
end

-- Get array of N closest keys for region-based filtering
function Filter.get_key_region(stick_x, stick_y, virtual_positions, center_key)
  local magnitude = math.sqrt(stick_x * stick_x + stick_y * stick_y)

  -- If near center, return nil (no filter applied)
  if magnitude < CENTER_DEADZONE then
    return nil
  end

  -- Calculate distances to all keys
  local distances = {}
  for key, pos in pairs(virtual_positions) do
    local vx, vy = pos[1], pos[2]
    local distance = math.sqrt((stick_x - vx) ^ 2 + (stick_y - vy) ^ 2)
    table.insert(distances, { key = key, distance = distance })
  end

  -- Sort by distance (ascending)
  table.sort(distances, function(a, b) return a.distance < b.distance end)

  -- Return the N closest keys
  local region = {}
  for i = 1, math.min(Filter.REGION_COUNT, #distances) do
    table.insert(region, distances[i].key)
  end

  return region
end

-- Check if word starts with any letter in the region
local function matches_start_letters(word, letter_region)
  if not letter_region then return true end

  local first_char = word:sub(1, 1)
  for _, letter in ipairs(letter_region) do
    if first_char == letter then
      return true
    end
  end
  return false
end

-- Check if word ends with any letter in the region
local function matches_end_letters(word, letter_region)
  if not letter_region then return true end

  local last_char = word:sub(-1)
  for _, letter in ipairs(letter_region) do
    if last_char == letter then
      return true
    end
  end
  return false
end

-- Apply filtering based on letter regions
-- left_region: array of letters for word start filtering (or nil)
-- right_region: array of letters for word end filtering (or nil)
function Filter.apply(words, left_region, right_region)
  -- No filtering if both sticks centered
  if not left_region and not right_region then
    local result = {}
    for i = 1, math.min(100, #words) do
      table.insert(result, words[i])
    end
    return result
  end

  local result = {}
  for _, word in ipairs(words) do
    if matches_start_letters(word, left_region) and matches_end_letters(word, right_region) then
      table.insert(result, word)
    end
    -- Limit for performance
    if #result >= 500 then break end
  end
  return result
end

return Filter
