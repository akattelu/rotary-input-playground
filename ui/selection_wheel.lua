local SelectionWheel = {}
SelectionWheel.__index = SelectionWheel

-- Constants
local VISIBLE_COUNT = 8
local RADIAL_RADIUS = 90
local DEADZONE = 0.3

-- Constructor
function SelectionWheel.new(config)
  local self = setmetatable({}, SelectionWheel)

  -- Store configuration
  self.config = {
    cx = config.cx or 400,
    cy = config.cy or 280,
    visible_count = config.visible_count or VISIBLE_COUNT,
    radial_radius = config.radial_radius or RADIAL_RADIUS,
    deadzone = config.deadzone or DEADZONE
  }

  -- State (initialized in load)
  self.selected_index = 1
  self.page = 1
  self.was_selecting = false

  return self
end

-- Initialize state
function SelectionWheel:load()
  self.selected_index = 1
  self.page = 1
  self.was_selecting = false
end

-- Reset to initial state (called when exiting select mode)
function SelectionWheel:reset()
  self.page = 1
  self.was_selecting = false
end

-- Update selection based on stick angle
function SelectionWheel:update_selection(stick)
  local selection = self:get_radial_selection(stick)
  if selection then
    self.selected_index = selection
    self.was_selecting = true
  end
end

-- Check if stick has been released (returns true if selection should be confirmed)
function SelectionWheel:check_release(stick)
  local magnitude = math.sqrt(stick.x ^ 2 + stick.y ^ 2)

  if self.was_selecting and magnitude < self.config.deadzone then
    return true
  end

  return false
end

-- Advance to next page with wrap
function SelectionWheel:advance_page(total_items)
  local total_pages = math.ceil(total_items / self.config.visible_count)
  self.page = (self.page % total_pages) + 1
  print("Page " .. self.page .. " / " .. total_pages)
  return self.page
end

-- Get current selected index (1-8 for radial menu position)
function SelectionWheel:get_selected_index()
  return self.selected_index
end

-- Get current page number
function SelectionWheel:get_page()
  return self.page
end

-- Get the actual selected word from filtered list, accounting for pagination
function SelectionWheel:get_selected_word(filtered)
  local actual_index = (self.page - 1) * self.config.visible_count + self.selected_index
  return filtered[actual_index]
end

-- Draw radial menu with visible words from current page
function SelectionWheel:draw(filtered)
  local cx = self.config.cx
  local cy = self.config.cy

  -- Calculate which words to show based on current page
  local start_idx = (self.page - 1) * self.config.visible_count + 1
  local end_idx = math.min(self.page * self.config.visible_count, #filtered)

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
    local angle = (i - 1) * (2 * math.pi / self.config.visible_count) - math.pi / 2
    local wx = cx + math.cos(angle) * self.config.radial_radius
    local wy = cy + math.sin(angle) * self.config.radial_radius

    if i == self.selected_index then
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

-- Draw mode indicator text
function SelectionWheel:draw_mode_indicator(mode, x, width, height)
  x = x or 0
  width = width or 800
  height = height or 600
  love.graphics.setColor(0.5, 0.8, 0.5)
  love.graphics.printf("Mode: " .. mode:upper(), x, height * 0.28, width, "center")
end

-- Draw current selection prominently centered in wheel
function SelectionWheel:draw_current_selection(filtered, x, width, height)
  x = x or 0
  width = width or 800
  height = height or 600
  local actual_index = (self.page - 1) * self.config.visible_count + self.selected_index
  if filtered[actual_index] then
    love.graphics.setColor(1, 1, 1)
    -- Center text vertically in the wheel (at wheel's cy position)
    local font = love.graphics.getFont()
    local text_height = font:getHeight()
    love.graphics.printf(filtered[actual_index], x, self.config.cy - text_height / 2, width, "center")
  end
end

-- Draw pagination information
function SelectionWheel:draw_pagination_info(filtered, x, width, height)
  x = x or 0
  width = width or 800
  height = height or 600
  if #filtered > self.config.visible_count then
    love.graphics.setColor(0.6, 0.6, 0.7)
    local total_pages = math.ceil(#filtered / self.config.visible_count)
    local start_idx = (self.page - 1) * self.config.visible_count + 1
    local end_idx = math.min(self.page * self.config.visible_count, #filtered)
    love.graphics.printf(
      string.format("Page %d/%d  (%d-%d of %d)", self.page, total_pages, start_idx, end_idx, #filtered),
      x, height * 0.32, width, "center"
    )
  end
end

-- Internal: Map stick angle to radial menu index
function SelectionWheel:get_radial_selection(stick)
  local magnitude = math.sqrt(stick.x ^ 2 + stick.y ^ 2)
  if magnitude < 0.5 then
    return nil
  end
  -- Adjust normalization to match drawing offset (-π/2)
  local angle = math.atan2(stick.y, stick.x)
  local normalized = (angle + math.pi / 2) / (2 * math.pi)
  local index = math.floor(normalized * self.config.visible_count) % self.config.visible_count
  return index + 1
end

return SelectionWheel
