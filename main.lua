local Corpus = require("lib.corpus")
local InputMenu = require("ui.input_menu")
local FileManager = require("lib.file_manager")
local FileViewer = require("ui.file_viewer")

-- State
local words = {}
local joystick = nil
local sentence = {} -- accumulated selected words

-- Stick state (normalized -1 to 1)
local left_stick = { x = 0, y = 0 }
local right_stick = { x = 0, y = 0 }

-- Mode system: "view" or "input"
local mode = "view"

-- Input menu
local input_menu = nil

-- File viewer
local file_viewer = nil
local files = {}
local current_file_index = 1


-- Hot reloading (disabled for web builds)
local isWeb = love.system.getOS() == "Web"
if not isWeb then
  local lick = require "lick"
  lick.reset = true
  lick.updateAllFiles = true
  lick.clearPackages = true
end


function love.load()
  -- Clean up previous file viewer if hot-reloading
  if file_viewer and file_viewer.syntax_buffer then
    file_viewer.syntax_buffer:destroy()
  end
  file_viewer = nil

  -- Set window to full screen dimensions
  local desktop_width, desktop_height = love.window.getDesktopDimensions()
  love.window.setMode(desktop_width, desktop_height, { resizable = true })

  -- Set Fira Mono font with better rendering quality
  local font = love.graphics.newFont("FiraMonoNerdFont-Regular.otf", 14, "normal")
  font:setFilter("nearest", "nearest") -- Crisp pixel-perfect rendering
  love.graphics.setFont(font)

  -- Load word list
  words = Corpus.load()

  -- Get window dimensions
  local width, height = love.graphics.getDimensions()

  -- Create and initialize file viewer (left half)
  file_viewer = FileViewer.new({
    x = 0,
    y = 0,
    width = width / 2,
    height = height
  })
  file_viewer:load()

  -- Load .lua files from current directory
  files = FileManager.scan_directory("lua")
  if #files > 0 then
    file_viewer:set_file(files[current_file_index])
  end

  -- Create and initialize input menu (right half)
  input_menu = InputMenu.new({
    x = width / 2,
    width = width / 2,
    height = height
  })
  input_menu:load()
end

function love.resize(w, h)
  -- Update file viewer dimensions (left half)
  if file_viewer then
    file_viewer:resize(0, 0, w / 2, h)
  end

  -- Update input menu dimensions (right half)
  if input_menu then
    input_menu:resize(w / 2, 0, w / 2, h)
  end
end

function love.joystickadded(j)
  joystick = j
end

function love.update(dt)
  if not joystick then return end

  -- Read stick positions
  left_stick.x = joystick:getGamepadAxis("leftx") or 0
  left_stick.y = joystick:getGamepadAxis("lefty") or 0
  right_stick.x = joystick:getGamepadAxis("rightx") or 0
  right_stick.y = joystick:getGamepadAxis("righty") or 0

  if mode == "input" and input_menu then
    -- Update input menu in input mode
    local sticks = { left = left_stick, right = right_stick }
    local selected_word = input_menu:update(words, sticks, joystick)

    -- Add word to sentence if selected
    if selected_word then
      table.insert(sentence, selected_word)
      print("Added: " .. selected_word)
    end
  elseif mode == "view" and file_viewer then
    -- Update file viewer with left stick for cursor control and triggers for tree navigation
    file_viewer:update(left_stick, dt, joystick)
  end
end

function love.gamepadpressed(_, button)
  if button == "x" then
    -- Toggle between view and input modes
    if mode == "view" then
      mode = "input"
    else
      mode = "view"
    end

  elseif button == "leftshoulder" then
    -- L1: Previous file (only in view mode)
    if mode == "view" and #files > 0 then
      current_file_index = FileManager.prev_index(current_file_index, #files)
      if file_viewer then
        file_viewer:set_file(files[current_file_index])
      end
    end

  elseif button == "rightshoulder" then
    if mode == "view" and #files > 0 then
      -- R1: Next file (in view mode)
      current_file_index = FileManager.next_index(current_file_index, #files)
      if file_viewer then
        file_viewer:set_file(files[current_file_index])
      end
    elseif mode == "input" and input_menu then
      -- RB: Mode toggle in input menu (existing behavior)
      local word = input_menu:handle_mode_toggle()
      if word then
        table.insert(sentence, word)
        print("Added: " .. word)
      end
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

  -- Draw file viewer (always visible, left half)
  if file_viewer then
    file_viewer:draw()
  end

  -- Draw input menu (only in input mode, right half)
  if mode == "input" and input_menu then
    input_menu:draw()

    -- Draw sentence overlay at top of input menu
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", width / 2 + 10, 40, width / 2 - 20, 35)
    love.graphics.setColor(1, 1, 1)
    local sentence_text = table.concat(sentence, " ")
    if #sentence_text == 0 then
      sentence_text = "(empty)"
      love.graphics.setColor(0.5, 0.5, 0.5)
    end
    love.graphics.printf(sentence_text, width / 2 + 20, 48, width / 2 - 40, "left")
  end

  -- Mode indicator
  love.graphics.setColor(0.3, 0.3, 0.35, 1)
  love.graphics.rectangle("fill", width / 2 - 70, 5, 60, 20)
  love.graphics.setColor(0.8, 0.8, 0.8)
  love.graphics.printf(mode:upper(), width / 2 - 70, 8, 60, "center")

  -- File counter (if files loaded)
  if #files > 0 then
    love.graphics.setColor(0.5, 0.5, 0.5)
    local file_info = string.format("File %d/%d", current_file_index, #files)
    love.graphics.print(file_info, 10, 8)
  end

  -- Instructions (aligned to viewport bottom)
  love.graphics.setColor(0.4, 0.4, 0.4)
  local instructions
  if mode == "view" then
    instructions = "[X] Input Mode  [L1/R1] Switch Files"
  else
    instructions = "[X] View Mode  [RB] Select  [ZR] Page  [B] Delete  [Release] Accept"
  end
  love.graphics.printf(instructions, 0, height - 40, width, "center")
end
