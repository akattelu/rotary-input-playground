local Corpus = require("lib.corpus")
local InputMenu = require("ui.input_menu")

-- State
local words = {}
local joystick = nil
local sentence = {} -- accumulated selected words

-- Stick state (normalized -1 to 1)
local left_stick = { x = 0, y = 0 }
local right_stick = { x = 0, y = 0 }

-- Input menu
local input_menu = nil
local input_menu_visible = false


-- Hot reloading (disabled for web builds)
local isWeb = love.system.getOS() == "Web"
if not isWeb then
  local lick = require "lick"
  lick.reset = true
  lick.updateAllFiles = true
  lick.clearPackages = true
end


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

  -- Create and initialize input menu with responsive dimensions
  local width, height = love.graphics.getDimensions()
  input_menu = InputMenu.new({
    x = width / 2,
    width = width / 2,
    height = height
  })
  input_menu:load()
end

function love.resize(w, h)
  -- Update input menu dimensions when window is resized
  if input_menu then
    input_menu:resize(w / 2, 0, w / 2, h)
  end
end

function love.joystickadded(j)
  joystick = j
end

function love.update()
  if not joystick or not input_menu_visible then return end

  -- Read stick positions
  left_stick.x = joystick:getGamepadAxis("leftx") or 0
  left_stick.y = joystick:getGamepadAxis("lefty") or 0
  right_stick.x = joystick:getGamepadAxis("rightx") or 0
  right_stick.y = joystick:getGamepadAxis("righty") or 0

  -- Update input menu
  local sticks = { left = left_stick, right = right_stick }
  local selected_word = input_menu:update(words, sticks, joystick)

  -- Add word to sentence if selected
  if selected_word then
    table.insert(sentence, selected_word)
    print("Added: " .. selected_word)
  end
end

function love.gamepadpressed(_, button)
  if button == "x" then
    -- Toggle input menu visibility
    input_menu_visible = not input_menu_visible
  elseif button == "rightshoulder" and input_menu_visible and input_menu then
    -- Handle mode toggle in input menu
    local word = input_menu:handle_mode_toggle()
    if word then
      table.insert(sentence, word)
      print("Added: " .. word)
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

  -- Get current window dimensions
  local width, height = love.graphics.getDimensions()

  -- Draw sentence (always visible, left half of screen)
  love.graphics.setColor(1, 1, 1)
  local sentence_text = table.concat(sentence, " ")
  if #sentence_text == 0 then
    sentence_text = "(empty)"
    love.graphics.setColor(0.5, 0.5, 0.5)
  end
  love.graphics.printf(sentence_text, 20, 85, width / 2 - 40, "left")

  -- Draw input menu if visible
  if input_menu_visible and input_menu then
    input_menu:draw()
  end

  -- Instructions (aligned to viewport bottom)
  love.graphics.setColor(0.4, 0.4, 0.4)
  love.graphics.printf(
    "[X/□] Toggle Menu  [RB] Select Mode  [ZR/R2] Next Page  [B] Delete  [Release Stick] Accept",
    0, height - 40, width, "center"
  )
end
