local Filter = require("filter")

-- State
local words = {}
local filtered = {}
local selected_index = 1
local page = 1      -- current page in select mode (1-indexed)
local joystick = nil
local sentence = {} -- accumulated selected words

-- Stick state (normalized -1 to 1)
local left_stick = { x = 0, y = 0 }
local right_stick = { x = 0, y = 0 }
local was_selecting = false -- track if sticks were engaged in select mode

-- Trigger state (for edge detection)
local zr_prev = 0
local TRIGGER_THRESHOLD = 0.5

-- Deadzone
local DEADZONE = 0.3

-- Display settings
local VISIBLE_COUNT = 8 -- candidates shown in radial menu
local RADIAL_RADIUS = 90

-- Mode: "filter" or "select"
local mode = "filter"

-- Keyboard display properties
local keySize = 22
local keySpacing = 3
local keyPitch = 25

-- Full QWERTY keyboard layout (same for both sides)
local keyboardRows = {
  { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
  { "a", "s", "d", "f", "g", "h", "j", "k", "l" },
  { "z", "x", "c", "v", "b", "n", "m" }
}

-- Left keyboard definition
local leftKeyboard = {
  rows = keyboardRows,
  baseX = 20,
  baseY = 430
}

-- Right keyboard definition
local rightKeyboard = {
  rows = keyboardRows,
  baseX = 520,
  baseY = 430
}

-- Key position lookup tables (built in love.load)
local leftKeyPositions = {}
local rightKeyPositions = {}

-- State for highlighted keys and regions
local left_highlighted_key = "g"
local right_highlighted_key = "g"
local left_region = nil
local right_region = nil

-- Build screen positions for keyboard keys
function buildKeyPositions(keyboard)
  local positions = {}
  local rowY = keyboard.baseY

  for rowIndex, row in ipairs(keyboard.rows) do
    local numKeys = #row
    local rowWidth = numKeys * keyPitch - keySpacing
    local maxRowWidth = 10 * keyPitch - keySpacing  -- Width of 10-key row
    local rowStartX = keyboard.baseX + (maxRowWidth - rowWidth) / 2  -- Center each row

    for colIndex, key in ipairs(row) do
      local x = rowStartX + (colIndex - 1) * keyPitch
      local y = rowY
      positions[key] = { x = x, y = y }
    end

    rowY = rowY + keyPitch
  end

  return positions
end

-- Check if key is in region array
local function key_in_region(key, region)
  if not region then return false end
  for _, k in ipairs(region) do
    if k == key then return true end
  end
  return false
end

-- Draw a single keyboard key
function drawKey(x, y, keyChar, isHighlighted, isInRegion)
  if isHighlighted then
    -- Highlighted key (primary selection)
    love.graphics.setColor(0.8, 0.6, 0.1)
    love.graphics.rectangle("fill", x, y, keySize, keySize)
    love.graphics.setColor(1.0, 0.8, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, keySize, keySize)
    love.graphics.setColor(1, 1, 1)
  elseif isInRegion then
    -- Key in region (included in filter)
    love.graphics.setColor(0.3, 0.5, 0.3)
    love.graphics.rectangle("fill", x, y, keySize, keySize)
    love.graphics.setColor(0.5, 0.7, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, keySize, keySize)
    love.graphics.setColor(0.9, 0.9, 0.9)
  else
    -- Normal key
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, keySize, keySize)
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, keySize, keySize)
    love.graphics.setColor(0.8, 0.8, 0.8)
  end

  -- Draw centered text
  local font = love.graphics.getFont()
  local textWidth = font:getWidth(keyChar)
  local textHeight = font:getHeight()
  love.graphics.print(keyChar, x + (keySize - textWidth) / 2, y + (keySize - textHeight) / 2)
end

-- Draw full keyboard with highlighting
function drawKeyboard(keyboard, keyPositions, highlightedKey, region)
  for _, row in ipairs(keyboard.rows) do
    for _, key in ipairs(row) do
      local pos = keyPositions[key]
      if pos then
        local isHighlighted = (key == highlightedKey)
        local isInRegion = key_in_region(key, region) and not isHighlighted
        drawKey(pos.x, pos.y, key, isHighlighted, isInRegion)
      end
    end
  end
end

-- Draw stick position visualizer
function draw_stick_visualizer(cx, cy, stick, label)
  local radius = 40

  -- Outer ring
  love.graphics.setColor(0.3, 0.3, 0.35)
  love.graphics.circle("line", cx, cy, radius)

  -- Stick position
  love.graphics.setColor(0.9, 0.3, 0.3)
  love.graphics.circle("fill",
    cx + stick.x * radius * 0.8,
    cy + stick.y * radius * 0.8,
    6
  )

  -- Label
  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.printf(label, cx - 30, cy + radius + 5, 60, "center")
end

function love.load()
  -- Set window to full screen dimensions
  local desktop_width, desktop_height = love.window.getDesktopDimensions()
  love.window.setMode(desktop_width, desktop_height, {resizable = true})

  -- Set Fira Mono font with better rendering quality
  local font = love.graphics.newFont("FiraMonoNerdFont-Regular.otf", 14, "normal")
  font:setFilter("nearest", "nearest")  -- Crisp pixel-perfect rendering
  love.graphics.setFont(font)

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

  -- Build key position lookup tables
  leftKeyPositions = buildKeyPositions(leftKeyboard)
  rightKeyPositions = buildKeyPositions(rightKeyboard)
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

  -- Read trigger positions (analog 0-1)
  local zr = joystick:getGamepadAxis("triggerright") or 0

  -- Detect ZR press (rising edge)
  if zr > TRIGGER_THRESHOLD and zr_prev <= TRIGGER_THRESHOLD then
    -- ZR just pressed
    if mode == "select" then
      local total_pages = math.ceil(#filtered / VISIBLE_COUNT)
      page = (page % total_pages) + 1
      print("Page " .. page .. " / " .. total_pages)
    end
  end
  zr_prev = zr

  -- Scale stick positions to virtual space (-100 to 100)
  local maxDistance = 100
  local left_vx = left_stick.x * maxDistance
  local left_vy = left_stick.y * maxDistance
  local right_vx = right_stick.x * maxDistance
  local right_vy = right_stick.y * maxDistance

  -- Get highlighted keys (for visual display) - both use same keyboard layout
  left_highlighted_key = Filter.get_closest_key(left_vx, left_vy, Filter.keyboard_virtual_positions, Filter.center_key)
  right_highlighted_key = Filter.get_closest_key(right_vx, right_vy, Filter.keyboard_virtual_positions, Filter.center_key)

  -- Get key regions for filtering
  left_region = Filter.get_key_region(left_vx, left_vy, Filter.keyboard_virtual_positions, Filter.center_key)
  right_region = Filter.get_key_region(right_vx, right_vy, Filter.keyboard_virtual_positions, Filter.center_key)

  if mode == "filter" then
    -- Live filtering using letter regions
    filtered = Filter.apply(words, left_region, right_region)
  elseif mode == "select" then
    -- In select mode, stick position picks from visible candidates
    local selection = get_radial_selection(right_stick)
    if selection then
      selected_index = selection
      was_selecting = true
    end

    -- Check if right stick has been released
    local right_mag = math.sqrt(right_stick.x ^ 2 + right_stick.y ^ 2)

    if was_selecting and right_mag < DEADZONE then
      -- Accept the selected word (offset by current page)
      local actual_index = (page - 1) * VISIBLE_COUNT + selected_index
      if filtered[actual_index] then
        table.insert(sentence, filtered[actual_index])
        print("Added: " .. filtered[actual_index])
      end
      -- Return to filter mode
      mode = "filter"
      page = 1
      was_selecting = false
    end
  end
end

function get_radial_selection(stick)
  local magnitude = math.sqrt(stick.x ^ 2 + stick.y ^ 2)
  if magnitude < 0.5 then
    return nil
  end
  -- Adjust normalization to match drawing offset (-π/2)
  local angle = math.atan2(stick.y, stick.x)
  local normalized = (angle + math.pi / 2) / (2 * math.pi)
  local index = math.floor(normalized * VISIBLE_COUNT) % VISIBLE_COUNT
  return index + 1
end

function love.gamepadpressed(j, button)
  if button == "rightshoulder" then
    if mode == "filter" then
      -- Enter select mode
      mode = "select"
      page = 1
      was_selecting = false
    elseif mode == "select" then
      -- Accept the selected word when RB is pressed again
      local actual_index = (page - 1) * VISIBLE_COUNT + selected_index
      if filtered[actual_index] then
        table.insert(sentence, filtered[actual_index])
        print("Added: " .. filtered[actual_index])
      end
      -- Return to filter mode
      mode = "filter"
      page = 1
      was_selecting = false
    end
  elseif button == "b" then
    -- Delete last word from sentence
    if #sentence > 0 then
      local removed = table.remove(sentence)
      print("Removed: " .. removed)
    end
  end
end

function love.draw()
  love.graphics.setBackgroundColor(0.1, 0.1, 0.12)

  -- Draw stick visualizers
  draw_stick_visualizer(145, 340, left_stick, "START")
  draw_stick_visualizer(655, 340, right_stick, "END")

  -- Draw full QWERTY keyboards
  drawKeyboard(leftKeyboard, leftKeyPositions, left_highlighted_key, left_region)
  drawKeyboard(rightKeyboard, rightKeyPositions, right_highlighted_key, right_region)

  -- Draw region indicator text
  love.graphics.setColor(0.6, 0.8, 0.6)
  if left_region then
    love.graphics.printf("Start: " .. table.concat(left_region, ", "), 20, 510, 250, "center")
  else
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Start: (any)", 20, 510, 250, "center")
  end

  love.graphics.setColor(0.6, 0.8, 0.6)
  if right_region then
    love.graphics.printf("End: " .. table.concat(right_region, ", "), 520, 510, 250, "center")
  else
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("End: (any)", 520, 510, 250, "center")
  end

  -- Draw filtered count
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf(
    string.format("Filtered: %d / %d", #filtered, #words),
    0, 30, 800, "center"
  )

  -- Draw mode indicator
  love.graphics.setColor(0.5, 0.8, 0.5)
  love.graphics.printf("Mode: " .. mode:upper(), 0, 55, 800, "center")

  -- Draw sentence
  love.graphics.setColor(1, 1, 1)
  local sentence_text = table.concat(sentence, " ")
  if #sentence_text == 0 then
    sentence_text = "(empty)"
    love.graphics.setColor(0.5, 0.5, 0.5)
  end
  love.graphics.printf(sentence_text, 20, 85, 760, "left")

  -- Draw radial selection menu (center)
  draw_radial_menu(400, 280)

  -- Draw current selection prominently
  local actual_index = (page - 1) * VISIBLE_COUNT + selected_index
  if filtered[actual_index] then
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(filtered[actual_index], 0, 130, 800, "center")
  end

  -- Draw pagination info in select mode
  if mode == "select" and #filtered > VISIBLE_COUNT then
    love.graphics.setColor(0.6, 0.6, 0.7)
    local total_pages = math.ceil(#filtered / VISIBLE_COUNT)
    local start_idx = (page - 1) * VISIBLE_COUNT + 1
    local end_idx = math.min(page * VISIBLE_COUNT, #filtered)
    love.graphics.printf(
      string.format("Page %d/%d  (%d-%d of %d)", page, total_pages, start_idx, end_idx, #filtered),
      0, 155, 800, "center"
    )
  end

  -- Instructions
  love.graphics.setColor(0.4, 0.4, 0.4)
  love.graphics.printf(
    "[RB] Select Mode / Accept  [R2/ZR] Next Page  [B] Delete Last Word  [Release Right Stick] Accept",
    0, 560, 800, "center"
  )
end

function draw_radial_menu(cx, cy)
  -- Calculate which words to show based on current page
  local start_idx = (page - 1) * VISIBLE_COUNT + 1
  local end_idx = math.min(page * VISIBLE_COUNT, #filtered)

  local visible = {}
  for i = start_idx, end_idx do
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
