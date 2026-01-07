local Filter = require("filter")

-- State
local words = {}
local filtered = {}
local selected_index = 1
local joystick = nil

-- Stick state (normalized -1 to 1)
local left_stick = { x = 0, y = 0 }
local right_stick = { x = 0, y = 0 }

-- Deadzone
local DEADZONE = 0.3

-- Display settings
local VISIBLE_COUNT = 8 -- candidates shown in radial menu
local RADIAL_RADIUS = 150

-- Mode: "filter" or "select"
local mode = "filter"
local held_filter = nil -- stores filter state when entering select mode

function love.load()
  -- Load word list
  local content = love.filesystem.read("words.txt")
  if content then
    for word in content:gmatch("[^\r\n]+") do
      if #word > 0 then
        table.insert(words, word:lower())
      end
    end
  else
    -- Fallback test words
    words = { "the", "be", "to", "of", "and", "a", "in", "that", "have", "it",
      "for", "not", "on", "with", "he", "as", "you", "do", "at", "this",
      "but", "his", "by", "from", "they", "we", "say", "her", "she", "or",
      "an", "will", "my", "one", "all", "would", "there", "their", "what",
      "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
      "function", "return", "const", "let", "var", "string", "number",
      "select", "filter", "search", "find", "start", "stop", "send",
      "think", "thank", "throw", "through", "then", "than", "ten", "ton",
      "token", "taken", "turn", "twin", "tension", "transition", "train" }
  end

  print("Loaded " .. #words .. " words")
  filtered = words
end

function love.joystickadded(j)
  joystick = j
  print("Controller connected: " .. j:getName())
end

function love.update(dt)
  if not joystick then return end

  -- Read stick positions
  left_stick.x = joystick:getGamepadAxis("leftx") or 0
  left_stick.y = joystick:getGamepadAxis("lefty") or 0
  right_stick.x = joystick:getGamepadAxis("rightx") or 0
  right_stick.y = joystick:getGamepadAxis("righty") or 0

  -- Get cluster indices based on stick angles
  local left_cluster = get_cluster_from_stick(left_stick)
  local right_cluster = get_cluster_from_stick(right_stick)

  if mode == "filter" then
    -- Live filtering as sticks move
    filtered = Filter.apply(words, left_cluster, right_cluster)

    -- Check for "hold" to enter select mode (both sticks engaged)
    if left_cluster and right_cluster then
      -- Could use a button press or timer to confirm "hold"
    end
  elseif mode == "select" then
    -- In select mode, stick position picks from visible candidates
    local selection = get_radial_selection(right_stick)
    if selection then
      selected_index = selection
    end
  end
end

function get_cluster_from_stick(stick)
  local magnitude = math.sqrt(stick.x ^ 2 + stick.y ^ 2)
  if magnitude < DEADZONE then
    return nil     -- center position = no filter
  end

  -- Convert to angle (0-7 for 8 directions)
  local angle = math.atan2(stick.y, stick.x)
  local normalized = (angle + math.pi) / (2 * math.pi)   -- 0 to 1
  local cluster = math.floor(normalized * 8) % 8
  return cluster + 1                                     -- 1-indexed
end

function get_radial_selection(stick)
  local magnitude = math.sqrt(stick.x ^ 2 + stick.y ^ 2)
  if magnitude < 0.5 then
    return nil
  end
  local angle = math.atan2(stick.y, stick.x)
  local normalized = (angle + math.pi) / (2 * math.pi)
  local index = math.floor(normalized * VISIBLE_COUNT) % VISIBLE_COUNT
  return index + 1
end

function love.gamepadpressed(j, button)
  if button == "a" then
    -- Confirm selection
    if filtered[selected_index] then
      print("SELECTED: " .. filtered[selected_index])
    end
  elseif button == "rightshoulder" then
    -- Toggle mode
    mode = (mode == "filter") and "select" or "filter"
  elseif button == "b" then
    -- Cycle through filtered results
    selected_index = (selected_index % math.min(#filtered, VISIBLE_COUNT)) + 1
  end
end

function love.draw()
  love.graphics.setBackgroundColor(0.1, 0.1, 0.12)

  -- Draw cluster indicators
  draw_stick_indicator(150, 300, left_stick, "START", Filter.onset_labels)
  draw_stick_indicator(650, 300, right_stick, "END", Filter.coda_labels)

  -- Draw filtered count
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf(
    string.format("Filtered: %d / %d", #filtered, #words),
    0, 30, 800, "center"
  )

  -- Draw mode indicator
  love.graphics.setColor(0.5, 0.8, 0.5)
  love.graphics.printf("Mode: " .. mode:upper(), 0, 55, 800, "center")

  -- Draw radial selection menu (center)
  draw_radial_menu(400, 320)

  -- Draw current selection prominently
  if filtered[selected_index] then
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(filtered[selected_index], 0, 500, 800, "center")
  end

  -- Instructions
  love.graphics.setColor(0.4, 0.4, 0.4)
  love.graphics.printf(
    "[A] Select  [RB] Toggle Mode  [B] Cycle",
    0, 560, 800, "center"
  )
end

function draw_stick_indicator(cx, cy, stick, label, cluster_labels)
  local radius = 80

  -- Outer ring
  love.graphics.setColor(0.3, 0.3, 0.35)
  love.graphics.circle("line", cx, cy, radius)

  -- Cluster segments
  for i = 1, 8 do
    local angle = (i - 1) * math.pi / 4 - math.pi
    local lx = cx + math.cos(angle) * (radius + 20)
    local ly = cy + math.sin(angle) * (radius + 20)

    local cluster = get_cluster_from_stick(stick)
    if cluster == i then
      love.graphics.setColor(0.4, 0.8, 0.4)
    else
      love.graphics.setColor(0.5, 0.5, 0.5)
    end

    local cluster_label = cluster_labels[i] or tostring(i)
    love.graphics.printf(cluster_label, lx - 30, ly - 8, 60, "center")
  end

  -- Stick position
  love.graphics.setColor(0.9, 0.3, 0.3)
  love.graphics.circle("fill",
    cx + stick.x * radius * 0.8,
    cy + stick.y * radius * 0.8,
    8
  )

  -- Label
  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.printf(label, cx - 40, cy + radius + 40, 80, "center")
end

function draw_radial_menu(cx, cy)
  local visible = {}
  for i = 1, math.min(#filtered, VISIBLE_COUNT) do
    table.insert(visible, filtered[i])
  end

  if #visible == 0 then
    love.graphics.setColor(0.5, 0.3, 0.3)
    love.graphics.printf("No matches", cx - 50, cy, 100, "center")
    return
  end

  for i, word in ipairs(visible) do
    local angle = (i - 1) * (2 * math.pi / VISIBLE_COUNT) - math.pi / 2
    local wx = cx + math.cos(angle) * RADIAL_RADIUS
    local wy = cy + math.sin(angle) * RADIAL_RADIUS

    if i == selected_index then
      love.graphics.setColor(0.3, 0.7, 0.9)
      love.graphics.circle("fill", wx, wy, 35)
      love.graphics.setColor(1, 1, 1)
    else
      love.graphics.setColor(0.25, 0.25, 0.3)
      love.graphics.circle("fill", wx, wy, 30)
      love.graphics.setColor(0.8, 0.8, 0.8)
    end

    love.graphics.printf(word, wx - 40, wy - 8, 80, "center")
  end
end
