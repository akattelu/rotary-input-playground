function buildKeyPositions(keyboard)
  local positions = {}
  local rowY = keyboard.baseY

  for rowIndex, row in ipairs(keyboard.rows) do
    local numKeys = #row
    local rowWidth = numKeys * keyPitch - keySpacing
    local rowStartX = keyboard.baseX + (175 - rowWidth) / 2     -- Center row relative to 5-key width

    for colIndex, key in ipairs(row) do
      local x = rowStartX + (colIndex - 1) * keyPitch
      local y = rowY
      positions[key] = { x = x, y = y }
    end

    rowY = rowY + keyPitch
  end

  return positions
end

function drawKey(x, y, keyChar, isHighlighted)
  if isHighlighted then
    -- Highlighted key colors
    love.graphics.setColor(0.8, 0.6, 0.1)     -- Orange fill
    love.graphics.rectangle("fill", x, y, keySize, keySize)
    love.graphics.setColor(1.0, 0.8, 0.2)     -- Yellow border
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, keySize, keySize)
    love.graphics.setColor(1, 1, 1)     -- White text
  else
    -- Normal key colors
    love.graphics.setColor(0.2, 0.2, 0.2)     -- Dark fill
    love.graphics.rectangle("fill", x, y, keySize, keySize)
    love.graphics.setColor(0.4, 0.4, 0.4)     -- Gray border
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, keySize, keySize)
    love.graphics.setColor(0.8, 0.8, 0.8)     -- Light text
  end

  -- Draw centered text
  local font = love.graphics.getFont()
  local textWidth = font:getWidth(keyChar)
  local textHeight = font:getHeight()
  love.graphics.print(keyChar, x + (keySize - textWidth) / 2, y + (keySize - textHeight) / 2)
end

function drawKeyboard(keyboard, keyPositions, highlightedKey)
  for _, row in ipairs(keyboard.rows) do
    for _, key in ipairs(row) do
      local pos = keyPositions[key]
      if pos then
        local isHighlighted = (key == highlightedKey)
        drawKey(pos.x, pos.y, key, isHighlighted)
      end
    end
  end
end

function getHighlightedKey(stickX, stickY, virtualPositions, centerKey)
  -- Calculate magnitude
  local magnitude = math.sqrt(stickX * stickX + stickY * stickY)

  -- If joystick is near center, return center key
  if magnitude < 20 then
    return centerKey
  end

  -- Find closest key using distance-based algorithm
  local minDistance = math.huge
  local closestKey = centerKey

  for key, virtualPos in pairs(virtualPositions) do
    local vx, vy = virtualPos[1], virtualPos[2]
    local distance = math.sqrt((stickX - vx) * (stickX - vx) + (stickY - vy) * (stickY - vy))

    if distance < minDistance then
      minDistance = distance
      closestKey = key
    end
  end

  return closestKey
end

function love.load()
  love.window.setTitle("Controller Input Visualizer")
  love.window.setMode(800, 650)

  -- Joystick state
  joystick = nil

  -- Circle properties
  circleRadius = 30
  deadzone = 0.1
  maxDistance = 100

  -- Left stick position
  leftStickX = 0
  leftStickY = 0

  -- Right stick position
  rightStickX = 0
  rightStickY = 0

  -- Base positions on screen
  leftBaseX = 250
  leftBaseY = 300
  rightBaseX = 550
  rightBaseY = 300

  -- Keyboard properties
  keySize = 30
  keySpacing = 5
  keyPitch = 35

  -- Left keyboard definition
  leftKeyboard = {
    rows = {
      { "q", "w", "e", "r", "t" },
      { "a", "s", "d", "f", "g" },
      { "z", "x", "c", "v" }
    },
    baseX = 165,
    baseY = 450,
    centerKey = "d"
  }

  -- Right keyboard definition
  rightKeyboard = {
    rows = {
      { "y", "u", "i", "o", "p" },
      { "h", "j", "k", "l" },
      { "b", "n", "m", "." }
    },
    baseX = 465,
    baseY = 450,
    centerKey = "j"
  }

  -- Virtual positions for mapping (distance-based algorithm)
  leftKeyVirtualPositions = {
    q = { -85, -85 },
    w = { 0, -85 },
    e = { 85, -85 },
    r = { 60, -60 },
    t = { 85, -50 },
    a = { -85, 0 },
    s = { -30, 0 },
    d = { 0, 0 },
    f = { 30, 0 },
    g = { 85, 0 },
    z = { -85, 85 },
    x = { -30, 85 },
    c = { 30, 85 },
    v = { 85, 85 }
  }

  rightKeyVirtualPositions = {
    y = { -85, -50 },
    u = { -60, -60 },
    i = { 0, -85 },
    o = { 85, -85 },
    p = { 85, -60 },
    h = { -85, 0 },
    j = { 0, 0 },
    k = { 30, 0 },
    l = { 85, 0 },
    b = { -85, 85 },
    n = { -30, 85 },
    m = { 30, 85 },
    ["."] = { 85, 85 }
  }

  -- State variables for highlighted keys
  leftHighlightedKey = "d"
  rightHighlightedKey = "j"

  -- Build key position lookup tables
  leftKeyPositions = buildKeyPositions(leftKeyboard)
  rightKeyPositions = buildKeyPositions(rightKeyboard)
end

function love.update(dt)
  -- Get the first connected joystick
  local joysticks = love.joystick.getJoysticks()
  if #joysticks > 0 then
    joystick = joysticks[1]

    -- Get left stick axes
    local leftX = joystick:getGamepadAxis("leftx")
    local leftY = joystick:getGamepadAxis("lefty")

    -- Apply deadzone
    if math.abs(leftX) < deadzone then leftX = 0 end
    if math.abs(leftY) < deadzone then leftY = 0 end

    leftStickX = leftX * maxDistance
    leftStickY = leftY * maxDistance

    -- Get right stick axes
    local rightX = joystick:getGamepadAxis("rightx")
    local rightY = joystick:getGamepadAxis("righty")

    -- Apply deadzone
    if math.abs(rightX) < deadzone then rightX = 0 end
    if math.abs(rightY) < deadzone then rightY = 0 end

    rightStickX = rightX * maxDistance
    rightStickY = rightY * maxDistance

    -- Calculate highlighted keys based on joystick positions
    leftHighlightedKey = getHighlightedKey(leftStickX, leftStickY, leftKeyVirtualPositions, leftKeyboard.centerKey)
    rightHighlightedKey = getHighlightedKey(rightStickX, rightStickY, rightKeyVirtualPositions, rightKeyboard.centerKey)
  end
end

function love.draw()
  love.graphics.setBackgroundColor(0.1, 0.1, 0.1)

  if joystick then
    -- Draw left stick
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.circle("fill", leftBaseX, leftBaseY, maxDistance)
    love.graphics.setColor(0.2, 0.8, 0.2)
    love.graphics.circle("fill", leftBaseX + leftStickX, leftBaseY + leftStickY, circleRadius)

    -- Draw right stick
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.circle("fill", rightBaseX, rightBaseY, maxDistance)
    love.graphics.setColor(0.2, 0.2, 0.8)
    love.graphics.circle("fill", rightBaseX + rightStickX, rightBaseY + rightStickY, circleRadius)

    -- Draw keyboards
    drawKeyboard(leftKeyboard, leftKeyPositions, leftHighlightedKey)
    drawKeyboard(rightKeyboard, rightKeyPositions, rightHighlightedKey)

    -- Draw labels
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Left Stick", leftBaseX - 30, leftBaseY - 130)
    love.graphics.print("Right Stick", rightBaseX - 35, rightBaseY - 130)
    love.graphics.print("Controller: " .. joystick:getName(), 10, 10)
  else
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("No controller connected", 300, 300)
  end
end
