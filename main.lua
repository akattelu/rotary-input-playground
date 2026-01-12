local Filter = require("lib.filter")
local Dial = require("ui.dial")
local Corpus = require("lib.corpus")
local SelectionWheel = require("ui.selection_wheel")

-- State
local words = {}
local filtered = {}
local joystick = nil
local sentence = {} -- accumulated selected words

-- Stick state (normalized -1 to 1)
local left_stick = { x = 0, y = 0 }
local right_stick = { x = 0, y = 0 }

-- Trigger state (for edge detection)
local zr_prev = 0
local TRIGGER_THRESHOLD = 0.5

-- Mode: "filter" or "select"
local mode = "filter"

-- Component instances (initialized in love.load)
local left_dial = nil
local right_dial = nil
local selection_wheel = nil


function love.load()
  -- Set window to full screen dimensions
  local desktop_width, desktop_height = love.window.getDesktopDimensions()
  love.window.setMode(desktop_width, desktop_height, { resizable = true })

  -- Set Fira Mono font with better rendering quality
  local font = love.graphics.newFont("FiraMonoNerdFont-Regular.otf", 14, "normal")
  font:setFilter("nearest", "nearest") -- Crisp pixel-perfect rendering
  love.graphics.setFont(font)

  -- Load word list
  words = Corpus.load()
  filtered = words

  -- Create and initialize dial instances
  left_dial = Dial.new({
    baseX = 20,
    baseY = 430,
    visualizerX = 145,
    visualizerY = 340,
    label = "START"
  })

  right_dial = Dial.new({
    baseX = 520,
    baseY = 430,
    visualizerX = 655,
    visualizerY = 340,
    label = "END"
  })

  left_dial:load()
  right_dial:load()

  -- Apply initial filtering with default regions (stationary stick position)
  local left_region = left_dial:get_region()
  local right_region = right_dial:get_region()
  filtered = Filter.apply(words, left_region, right_region)

  -- Create and initialize selection wheel
  selection_wheel = SelectionWheel.new({
    cx = 400,
    cy = 280,
    visible_count = 8,
    radial_radius = 90,
    deadzone = 0.3
  })
  selection_wheel:load()
end

function love.joystickadded(j)
  joystick = j
end

function love.update()
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
    if mode == "select" and selection_wheel then
      selection_wheel:advance_page(#filtered)
    end
  end
  zr_prev = zr

  -- Scale stick positions to virtual space (-100 to 100)
  local maxDistance = 100
  local left_vx = left_stick.x * maxDistance
  local left_vy = left_stick.y * maxDistance
  local right_vx = right_stick.x * maxDistance
  local right_vy = right_stick.y * maxDistance

  -- Update dials
  if left_dial then left_dial:update(left_vx, left_vy) end
  if right_dial then right_dial:update(right_vx, right_vy) end

  -- Get regions for filtering
  local left_region = left_dial and left_dial:get_region()
  local right_region = right_dial and right_dial:get_region()

  if mode == "filter" then
    -- Live filtering using letter regions
    filtered = Filter.apply(words, left_region, right_region)
  elseif mode == "select" and selection_wheel then
    -- In select mode, update selection based on stick position
    selection_wheel:update_selection(right_stick)

    -- Check if right stick has been released to accept selection
    if selection_wheel:check_release(right_stick) then
      local word = selection_wheel:get_selected_word(filtered)
      if word then
        table.insert(sentence, word)
        print("Added: " .. word)
      end
      -- Return to filter mode
      mode = "filter"
      selection_wheel:reset()
    end
  end
end

function love.gamepadpressed(_, button)
  if button == "rightshoulder" and selection_wheel then
    if mode == "filter" then
      -- Enter select mode
      mode = "select"
      selection_wheel:reset()
    elseif mode == "select" then
      -- Accept the selected word when RB is pressed again
      local word = selection_wheel:get_selected_word(filtered)
      if word then
        table.insert(sentence, word)
        print("Added: " .. word)
      end
      -- Return to filter mode
      mode = "filter"
      selection_wheel:reset()
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

  -- Draw dials (includes keyboards and visualizers)
  if left_dial then left_dial:draw() end
  if right_dial then right_dial:draw() end

  -- Draw region indicator text
  local left_region = left_dial and left_dial:get_region()
  local right_region = right_dial and right_dial:get_region()

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
  if selection_wheel then
    selection_wheel:draw_mode_indicator(mode)
  end

  -- Draw sentence
  love.graphics.setColor(1, 1, 1)
  local sentence_text = table.concat(sentence, " ")
  if #sentence_text == 0 then
    sentence_text = "(empty)"
    love.graphics.setColor(0.5, 0.5, 0.5)
  end
  love.graphics.printf(sentence_text, 20, 85, 760, "left")

  -- Draw radial selection menu (center)
  if selection_wheel then
    selection_wheel:draw(filtered)
  end

  -- Draw current selection prominently
  if selection_wheel then
    selection_wheel:draw_current_selection(filtered)
  end

  -- Draw pagination info in select mode
  if mode == "select" and selection_wheel then
    selection_wheel:draw_pagination_info(filtered)
  end

  -- Instructions
  love.graphics.setColor(0.4, 0.4, 0.4)
  love.graphics.printf(
    "[RB] Select Mode / Accept  [R2/ZR] Next Page  [B] Delete Last Word  [Release Right Stick] Accept",
    0, 560, 800, "center"
  )
end
