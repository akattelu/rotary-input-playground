-- Picker: Modal overlay for selecting from a list of candidates
-- Uses dual-joystick control: left stick for macro selection, right stick for micro

local Picker = {}
Picker.__index = Picker

-- Constants
local DEADZONE = 0.3
local VISIBLE_COUNT = 15
local ITEM_HEIGHT = 28
local BOX_PADDING = 40
local CORNER_RADIUS = 8

function Picker.new(config)
  local self = setmetatable({}, Picker)

  self.config = {
    visible_count = config.visible_count or VISIBLE_COUNT,
    item_height = config.item_height or ITEM_HEIGHT,
    box_padding = config.box_padding or BOX_PADDING
  }

  -- State
  self.visible = false
  self.candidates = {}
  self.selected_index = 1
  self.page = 1
  self.scroll_offset = 0  -- For smooth visual scrolling

  -- Stick state for drawing vectors
  self.left_y = 0
  self.right_y = 0

  return self
end

function Picker:load()
  -- Nothing to initialize post-construction
end

function Picker:show(candidates)
  self.visible = true
  self.candidates = candidates or {}
  self.selected_index = 1
  self.page = 1
  self.scroll_offset = 0
end

function Picker:hide()
  self.visible = false
  self.candidates = {}
  self.selected_index = 1
  self.page = 1
end

function Picker:is_open()
  return self.visible
end

function Picker:get_page_candidates()
  local start_idx = (self.page - 1) * self.config.visible_count + 1
  local end_idx = math.min(start_idx + self.config.visible_count - 1, #self.candidates)

  local page_items = {}
  for i = start_idx, end_idx do
    table.insert(page_items, self.candidates[i])
  end
  return page_items, start_idx
end

function Picker:get_total_pages()
  return math.ceil(#self.candidates / self.config.visible_count)
end

function Picker:next_page()
  local total_pages = self:get_total_pages()
  if total_pages > 1 then
    self.page = (self.page % total_pages) + 1
    self.selected_index = 1
  end
end

function Picker:update(left_stick, right_stick)
  if not self.visible or #self.candidates == 0 then
    return nil
  end

  local page_items = self:get_page_candidates()
  local item_count = #page_items

  if item_count == 0 then
    return nil
  end

  -- Apply deadzone and store for drawing
  local left_y = math.abs(left_stick.y) > DEADZONE and left_stick.y or 0
  local right_y = math.abs(right_stick.y) > DEADZONE and right_stick.y or 0
  self.left_y = left_y
  self.right_y = right_y

  -- Dual-stick selection:
  -- Left stick (macro): covers full range of visible items
  -- Right stick (micro): covers half range for fine control

  local center = (item_count + 1) / 2
  local macro_range = (item_count - 1) / 2    -- Full range
  local micro_range = (item_count - 1) / 4    -- Half range

  local macro_offset = left_y * macro_range
  local micro_offset = right_y * micro_range

  local raw_index = center + macro_offset + micro_offset
  self.selected_index = math.floor(math.max(1, math.min(item_count, raw_index)) + 0.5)

  return nil  -- Selection happens on button press, not stick movement
end

function Picker:confirm_selection()
  if not self.visible or #self.candidates == 0 then
    return nil
  end

  local page_items, start_idx = self:get_page_candidates()
  if self.selected_index >= 1 and self.selected_index <= #page_items then
    local global_index = start_idx + self.selected_index - 1
    return self.candidates[global_index]
  end

  return nil
end

function Picker:draw()
  if not self.visible then
    return
  end

  local width, height = love.graphics.getDimensions()

  -- Dim background
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, width, height)

  -- Calculate box dimensions (80% of screen)
  local box_width = width * 0.8
  local box_height = height * 0.8
  local box_x = (width - box_width) / 2
  local box_y = (height - box_height) / 2

  -- Draw modal box background
  love.graphics.setColor(0.15, 0.15, 0.18, 0.98)
  love.graphics.rectangle("fill", box_x, box_y, box_width, box_height, CORNER_RADIUS, CORNER_RADIUS)

  -- Draw box border
  love.graphics.setColor(0.3, 0.3, 0.35, 1)
  love.graphics.rectangle("line", box_x, box_y, box_width, box_height, CORNER_RADIUS, CORNER_RADIUS)

  -- Header
  love.graphics.setColor(0.5, 0.6, 0.8, 1)
  love.graphics.printf("Command Palette", box_x, box_y + 15, box_width, "center")

  -- Divider line
  love.graphics.setColor(0.3, 0.3, 0.35, 1)
  love.graphics.line(box_x + 20, box_y + 45, box_x + box_width - 20, box_y + 45)

  -- Content area
  local content_x = box_x + self.config.box_padding
  local content_y = box_y + 60
  local content_width = box_width - self.config.box_padding * 2
  local content_height = box_height - 120  -- Leave room for header and footer

  -- Set scissor for content area
  love.graphics.setScissor(content_x, content_y, content_width, content_height)

  -- Draw candidates
  local page_items, start_idx = self:get_page_candidates()
  for i, candidate in ipairs(page_items) do
    local item_y = content_y + (i - 1) * self.config.item_height

    -- Highlight selected item
    if i == self.selected_index then
      love.graphics.setColor(0.3, 0.4, 0.6, 0.8)
      love.graphics.rectangle("fill", content_x - 5, item_y, content_width + 10, self.config.item_height - 2, 4, 4)
      love.graphics.setColor(1, 1, 1, 1)
    else
      love.graphics.setColor(0.7, 0.7, 0.7, 1)
    end

    -- Draw candidate name
    local display_name = type(candidate) == "table" and candidate.name or tostring(candidate)
    local index_str = string.format("%2d. ", start_idx + i - 1)
    love.graphics.print(index_str .. display_name, content_x + 10, item_y + 4)
  end

  love.graphics.setScissor()

  -- Footer with controls and page info
  local footer_y = box_y + box_height - 50

  -- Page indicator
  local total_pages = self:get_total_pages()
  if total_pages > 1 then
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    local page_text = string.format("Page %d/%d", self.page, total_pages)
    love.graphics.printf(page_text, box_x, footer_y, box_width, "center")
  end

  -- Controls hint
  love.graphics.setColor(0.4, 0.4, 0.4, 1)
  local controls = "[L-Stick] Macro  [R-Stick] Micro  [R1] Page  [A] Select  [B] Cancel"
  love.graphics.printf(controls, box_x, footer_y + 20, box_width, "center")

  -- Draw vector indicators on the right side of the list
  self:draw_vectors(box_x + box_width - 80, content_y, content_height, #page_items)
end

function Picker:draw_vectors(x, content_y, content_height, item_count)
  if item_count == 0 then return end

  local line_width = love.graphics.getLineWidth()
  love.graphics.setLineWidth(2)

  -- Calculate the Y positions based on item layout
  local list_height = item_count * self.config.item_height
  local center_y = content_y + list_height / 2

  -- Macro range covers full list height, micro covers half
  local macro_range = list_height / 2
  local micro_range = list_height / 4

  -- Calculate vector endpoints
  local macro_offset = self.left_y * macro_range
  local micro_offset = self.right_y * micro_range

  -- Start point (center of list)
  local start_y = center_y

  -- End of macro vector
  local macro_end_y = start_y + macro_offset

  -- End of micro vector (final position)
  local final_y = macro_end_y + micro_offset

  -- Draw center line marker
  love.graphics.setColor(0.3, 0.3, 0.35, 0.5)
  love.graphics.line(x - 10, start_y, x + 40, start_y)

  -- Draw macro vector (blue) - from center
  love.graphics.setColor(0.4, 0.5, 0.7, 0.9)
  love.graphics.line(x, start_y, x, macro_end_y)
  -- Arrow head for macro
  if math.abs(macro_offset) > 5 then
    local arrow_dir = macro_offset > 0 and 1 or -1
    love.graphics.polygon("fill",
      x, macro_end_y,
      x - 5, macro_end_y - 8 * arrow_dir,
      x + 5, macro_end_y - 8 * arrow_dir
    )
  end
  -- Macro dot at start
  love.graphics.circle("fill", x, start_y, 4)

  -- Draw micro vector (green) - from end of macro
  love.graphics.setColor(0.5, 0.7, 0.5, 0.9)
  love.graphics.line(x + 15, macro_end_y, x + 15, final_y)
  -- Arrow head for micro
  if math.abs(micro_offset) > 5 then
    local arrow_dir = micro_offset > 0 and 1 or -1
    love.graphics.polygon("fill",
      x + 15, final_y,
      x + 10, final_y - 6 * arrow_dir,
      x + 20, final_y - 6 * arrow_dir
    )
  end
  -- Micro dot at macro end
  love.graphics.circle("fill", x + 15, macro_end_y, 3)

  -- Draw final position indicator (connects to selected item)
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.circle("fill", x + 15, final_y, 5)
  love.graphics.setColor(0.3, 0.3, 0.35, 0.6)
  love.graphics.line(x + 20, final_y, x + 40, final_y)

  -- Legend
  love.graphics.setColor(0.4, 0.5, 0.7, 0.8)
  love.graphics.print("L", x - 5, content_y - 20)
  love.graphics.setColor(0.5, 0.7, 0.5, 0.8)
  love.graphics.print("R", x + 10, content_y - 20)

  love.graphics.setLineWidth(line_width)
end

return Picker
