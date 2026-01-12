local Dial = {}
Dial.__index = Dial

-- Load Filter module
local Filter = require("lib.filter")

-- Constants (extracted from main.lua)
local keyboardRows = {
  { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
  { "a", "s", "d", "f", "g", "h", "j", "k", "l" },
  { "z", "x", "c", "v", "b", "n", "m" }
}

local keySize = 22
local keySpacing = 3
local keyPitch = 25

-- Constructor
function Dial.new(config)
  local self = setmetatable({}, Dial)

  -- Store configuration
  self.config = {
    baseX = config.baseX,
    baseY = config.baseY,
    visualizerX = config.visualizerX,
    visualizerY = config.visualizerY,
    label = config.label
  }

  -- Keyboard layout (constant)
  self.keyboard = {
    rows = keyboardRows
  }

  -- State (initialized in load)
  self.key_positions = {}
  self.highlighted_key = nil
  self.region = nil
  self.stick = { x = 0, y = 0 }  -- normalized -1 to 1 for visualizer

  return self
end

-- Initialize key positions and state
function Dial:load()
  self.key_positions = self:buildKeyPositions()
  self.highlighted_key = "g"  -- default center
  -- Initialize region around center key for stationary stick position
  self.region = Filter.get_key_region(
    0, 0,  -- center position
    Filter.keyboard_virtual_positions,
    Filter.center_key
  )
end

-- Update highlighted key and region based on stick position
function Dial:update(stick_vx, stick_vy)
  -- Store normalized coordinates for visualizer
  self.stick.x = stick_vx / 100
  self.stick.y = stick_vy / 100

  -- Update highlighted key and region
  self.highlighted_key = Filter.get_closest_key(
    stick_vx, stick_vy,
    Filter.keyboard_virtual_positions,
    Filter.center_key
  )

  self.region = Filter.get_key_region(
    stick_vx, stick_vy,
    Filter.keyboard_virtual_positions,
    Filter.center_key
  )
end

-- Render keyboard and stick visualizer
function Dial:draw()
  self:draw_stick_visualizer()
  self:drawKeyboard()
end

-- Get currently highlighted key
function Dial:get_highlighted_key()
  return self.highlighted_key
end

-- Get current filter region
function Dial:get_region()
  return self.region
end

-- Internal: Build screen positions for keyboard keys
function Dial:buildKeyPositions()
  local positions = {}
  local rowY = self.config.baseY

  for _, row in ipairs(self.keyboard.rows) do
    local numKeys = #row
    local rowWidth = numKeys * keyPitch - keySpacing
    local maxRowWidth = 10 * keyPitch - keySpacing  -- Width of 10-key row
    local rowStartX = self.config.baseX + (maxRowWidth - rowWidth) / 2  -- Center each row

    for colIndex, key in ipairs(row) do
      local x = rowStartX + (colIndex - 1) * keyPitch
      local y = rowY
      positions[key] = { x = x, y = y }
    end

    rowY = rowY + keyPitch
  end

  return positions
end

-- Internal: Check if key is in region array
function Dial:key_in_region(key, region)
  if not region then return false end
  for _, k in ipairs(region) do
    if k == key then return true end
  end
  return false
end

-- Internal: Draw a single keyboard key
function Dial:drawKey(x, y, keyChar, isHighlighted, isInRegion)
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

-- Internal: Draw full keyboard with highlighting
function Dial:drawKeyboard()
  for _, row in ipairs(self.keyboard.rows) do
    for _, key in ipairs(row) do
      local pos = self.key_positions[key]
      if pos then
        local isHighlighted = (key == self.highlighted_key)
        local isInRegion = self:key_in_region(key, self.region) and not isHighlighted
        self:drawKey(pos.x, pos.y, key, isHighlighted, isInRegion)
      end
    end
  end
end

-- Internal: Draw stick position visualizer
function Dial:draw_stick_visualizer()
  local cx = self.config.visualizerX
  local cy = self.config.visualizerY
  local radius = 40

  -- Outer ring
  love.graphics.setColor(0.3, 0.3, 0.35)
  love.graphics.circle("line", cx, cy, radius)

  -- Stick position
  love.graphics.setColor(0.9, 0.3, 0.3)
  love.graphics.circle("fill",
    cx + self.stick.x * radius * 0.8,
    cy + self.stick.y * radius * 0.8,
    6
  )

  -- Label
  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.printf(self.config.label, cx - 30, cy + radius + 5, 60, "center")
end

return Dial
