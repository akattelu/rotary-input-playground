local InputMenu = {}
InputMenu.__index = InputMenu

local Filter = require("lib.filter")
local Dial = require("ui.dial")
local SelectionWheel = require("ui.selection_wheel")

-- Constants
local TRIGGER_THRESHOLD = 0.5

-- Constructor
function InputMenu.new(config)
  local self = setmetatable({}, InputMenu)

  -- Configuration
  self.config = {
    x = config.x or 400,
    y = config.y or 0,
    width = config.width or 400,
    height = config.height or 600
  }

  -- State
  self.mode = "filter"
  self.filtered = {}
  self.zr_prev = 0  -- For edge detection

  -- Components (initialized in load)
  self.left_dial = nil
  self.right_dial = nil
  self.selection_wheel = nil

  return self
end

-- Initialize components
function InputMenu:load()
  -- Calculate center x of right half
  local center_x = self.config.x + self.config.width / 2

  -- Keyboard dimensions (from dial.lua constants)
  local keyPitch = 25
  local keySpacing = 3
  local keyboardWidth = 10 * keyPitch - keySpacing  -- 247 pixels
  local gap = 20  -- Gap between keyboards

  -- Selection wheel (top)
  self.selection_wheel = SelectionWheel.new({
    cx = center_x,
    cy = self.config.height * 0.18,
    visible_count = 8,
    radial_radius = 80,
    deadzone = 0.3
  })
  self.selection_wheel:load()

  -- Keyboards positioned side by side
  local keyboardY = self.config.height * 0.55

  -- Left dial (START keyboard) - on the left
  self.left_dial = Dial.new({
    baseX = center_x - gap/2 - keyboardWidth,
    baseY = keyboardY,
    label = "START"
  })
  self.left_dial:load()

  -- Right dial (END keyboard) - on the right
  self.right_dial = Dial.new({
    baseX = center_x + gap/2,
    baseY = keyboardY,
    label = "END"
  })
  self.right_dial:load()
end

-- Resize and reposition all components
function InputMenu:resize(x, y, width, height)
  -- Update configuration
  self.config.x = x
  self.config.y = y
  self.config.width = width
  self.config.height = height

  -- Recalculate positions and update components
  local center_x = x + width / 2

  -- Keyboard dimensions (from dial.lua constants)
  local keyPitch = 25
  local keySpacing = 3
  local keyboardWidth = 10 * keyPitch - keySpacing  -- 247 pixels
  local gap = 20  -- Gap between keyboards
  local keyboardY = height * 0.55

  -- Update selection wheel
  if self.selection_wheel then
    self.selection_wheel.config.cx = center_x
    self.selection_wheel.config.cy = height * 0.18
  end

  -- Update left dial (START keyboard on left)
  if self.left_dial then
    self.left_dial.config.baseX = center_x - gap/2 - keyboardWidth
    self.left_dial.config.baseY = keyboardY
    self.left_dial.key_positions = self.left_dial:buildKeyPositions()
  end

  -- Update right dial (END keyboard on right)
  if self.right_dial then
    self.right_dial.config.baseX = center_x + gap/2
    self.right_dial.config.baseY = keyboardY
    self.right_dial.key_positions = self.right_dial:buildKeyPositions()
  end
end

-- Update input menu state and return selected word if any
function InputMenu:update(words, sticks, joystick)
  -- Returns: selected_word (string) or nil

  -- Scale sticks to virtual space (-100 to 100)
  local max_distance = 100
  local left_vx = sticks.left.x * max_distance
  local left_vy = sticks.left.y * max_distance
  local right_vx = sticks.right.x * max_distance
  local right_vy = sticks.right.y * max_distance

  -- Update dials
  if self.left_dial then self.left_dial:update(left_vx, left_vy) end
  if self.right_dial then self.right_dial:update(right_vx, right_vy) end

  -- Get regions for filtering
  local left_region = self.left_dial and self.left_dial:get_region()
  local right_region = self.right_dial and self.right_dial:get_region()

  -- Mode-specific logic
  if self.mode == "filter" then
    -- Live filtering using letter regions
    self.filtered = Filter.apply(words, left_region, right_region)

  elseif self.mode == "select" and self.selection_wheel then
    -- Update selection based on right stick position
    self.selection_wheel:update_selection(sticks.right)

    -- Check if right stick has been released to accept selection
    if self.selection_wheel:check_release(sticks.right) then
      local word = self.selection_wheel:get_selected_word(self.filtered)
      if word then
        self.mode = "filter"
        self.selection_wheel:reset()
        return word  -- Return selected word
      end
    end

    -- Check ZR for pagination (edge detection)
    if joystick then
      local zr = joystick:getGamepadAxis("triggerright") or 0
      if zr > TRIGGER_THRESHOLD and self.zr_prev <= TRIGGER_THRESHOLD then
        self.selection_wheel:advance_page(#self.filtered)
      end
      self.zr_prev = zr
    end
  end

  return nil  -- No word selected
end

-- Draw all input menu components
function InputMenu:draw()
  -- Draw dials (keyboards and visualizers)
  if self.left_dial then self.left_dial:draw() end
  if self.right_dial then self.right_dial:draw() end

  -- Draw region indicators (aligned to bottom)
  local left_region = self.left_dial and self.left_dial:get_region()
  local right_region = self.right_dial and self.right_dial:get_region()

  love.graphics.setColor(0.6, 0.8, 0.6)
  if left_region then
    love.graphics.printf(
      "Start: " .. table.concat(left_region, ", "),
      self.config.x,
      self.config.height - 90,
      self.config.width,
      "center"
    )
  else
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf(
      "Start: (any)",
      self.config.x,
      self.config.height - 90,
      self.config.width,
      "center"
    )
  end

  love.graphics.setColor(0.6, 0.8, 0.6)
  if right_region then
    love.graphics.printf(
      "End: " .. table.concat(right_region, ", "),
      self.config.x,
      self.config.height - 70,
      self.config.width,
      "center"
    )
  else
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf(
      "End: (any)",
      self.config.x,
      self.config.height - 70,
      self.config.width,
      "center"
    )
  end

  -- Draw filtered count (above wheel)
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf(
    string.format("Filtered: %d", #self.filtered),
    self.config.x,
    self.config.height * 0.02,
    self.config.width,
    "center"
  )

  -- Draw selection wheel
  if self.selection_wheel then
    self.selection_wheel:draw(self.filtered)
  end

  -- Draw mode indicator (with positioning bounds for right half)
  if self.selection_wheel then
    self.selection_wheel:draw_mode_indicator(self.mode, self.config.x, self.config.width, self.config.height)
  end

  -- Draw current selection
  if self.selection_wheel then
    self.selection_wheel:draw_current_selection(self.filtered, self.config.x, self.config.width, self.config.height)
  end

  -- Draw pagination info in select mode
  if self.mode == "select" and self.selection_wheel then
    self.selection_wheel:draw_pagination_info(self.filtered, self.config.x, self.config.width, self.config.height)
  end
end

-- Handle RB button for mode toggle
function InputMenu:handle_mode_toggle()
  if self.mode == "filter" then
    -- Enter select mode
    self.mode = "select"
    self.selection_wheel:reset()
  elseif self.mode == "select" then
    -- Accept the selected word when RB is pressed again
    local word = self.selection_wheel:get_selected_word(self.filtered)
    self.mode = "filter"
    self.selection_wheel:reset()
    return word  -- Return selected word for immediate accept
  end
  return nil
end

return InputMenu
