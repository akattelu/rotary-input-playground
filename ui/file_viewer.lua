local FileViewer = {}
FileViewer.__index = FileViewer

local Highlighter = require("lib.highlighter")
local Syntax = require("lib.syntax")

-- Constants
local DEADZONE = 0.3
local CURSOR_SPEED = 300  -- pixels per second at full stick deflection
local SCROLL_EDGE_LINES = 4  -- scroll when cursor within this many lines of edge
local TRIGGER_THRESHOLD = 0.5  -- threshold for trigger edge detection

-- Constructor
function FileViewer.new(config)
  local self = setmetatable({}, FileViewer)

  -- Store configuration
  self.config = {
    x = config.x or 0,
    y = config.y or 0,
    width = config.width or 400,
    height = config.height or 600,
    line_height = config.line_height or 18,
    gutter_width = config.gutter_width or 45,
    padding = config.padding or 10,
    header_height = config.header_height or 30,
  }

  -- State
  self.scroll_offset = 0
  self.total_lines = 0
  self.visible_lines = 0

  -- Content
  self.filename = ""
  self.highlighted_lines = {}

  -- Syntax buffer for node queries
  self.syntax_buffer = nil
  self.source_text = nil

  -- Cursor state
  self.cursor = { x = 100, y = 100 }  -- screen coords relative to component
  self.highlighted_node = nil  -- {start_row, start_col, end_row, end_col}
  self.scroll_accumulator = 0  -- accumulates fractional scroll amounts

  -- Tree navigation state
  self.navigated_node = nil  -- locked node for tree navigation (FFI reference)
  self.trigger_prev = { l2 = 0, r2 = 0 }  -- edge detection for triggers

  return self
end

-- Initialize component
function FileViewer:load()
  self:recalculate_visible_lines()
end

-- Recalculate visible lines from viewport height
function FileViewer:recalculate_visible_lines()
  local code_height = self.config.height - self.config.header_height
  self.visible_lines = math.floor(code_height / self.config.line_height)
end

-- Set file content to display
-- file: { path, name, content, language }
function FileViewer:set_file(file)
  -- Clean up previous syntax buffer
  if self.syntax_buffer then
    self.syntax_buffer:destroy()
    self.syntax_buffer = nil
  end
  self.source_text = nil
  self.highlighted_node = nil
  self.navigated_node = nil

  if not file then
    self.filename = ""
    self.highlighted_lines = {}
    self.total_lines = 0
    self.scroll_offset = 0
    return
  end

  self.filename = file.name or file.path or "untitled"

  -- Highlight content
  if file.content then
    self.highlighted_lines = Highlighter.highlight(file.content, file.language)
    self.total_lines = #self.highlighted_lines
    self.source_text = file.content

    -- Create syntax buffer for node queries
    local language = file.language or "lua"
    if Syntax.languages[language] then
      local ok, buf = pcall(Syntax.Buffer.new, language)
      if ok then
        buf:set_text(file.content)
        self.syntax_buffer = buf
      end
    end
  else
    self.highlighted_lines = {}
    self.total_lines = 0
  end

  -- Reset scroll
  self.scroll_offset = 0
  self.scroll_accumulator = 0
end

-- Handle resize
function FileViewer:resize(x, y, width, height)
  self.config.x = x
  self.config.y = y
  self.config.width = width
  self.config.height = height
  self:recalculate_visible_lines()

  -- Clamp scroll offset
  local max_scroll = math.max(0, self.total_lines - self.visible_lines)
  self.scroll_offset = math.min(self.scroll_offset, max_scroll)
end

-- Scroll by delta lines (positive = down, negative = up)
function FileViewer:scroll(delta)
  -- Accumulate fractional scroll
  self.scroll_accumulator = self.scroll_accumulator + delta

  -- Only scroll by whole lines
  local whole_lines = math.floor(self.scroll_accumulator)
  if whole_lines ~= 0 then
    self.scroll_accumulator = self.scroll_accumulator - whole_lines
    local max_scroll = math.max(0, self.total_lines - self.visible_lines)
    self.scroll_offset = math.max(0, math.min(max_scroll, self.scroll_offset + whole_lines))
  end
end

-- Scroll to specific line (0-indexed)
function FileViewer:scroll_to(line_number)
  local max_scroll = math.max(0, self.total_lines - self.visible_lines)
  self.scroll_offset = math.floor(math.max(0, math.min(max_scroll, line_number)))
  self.scroll_accumulator = 0
end

-- Update cursor position and highlighted node
-- stick: {x, y} normalized -1 to 1
-- joystick: optional LÖVE joystick object for trigger input
function FileViewer:update(stick, dt, joystick)
  dt = dt or love.timer.getDelta()

  local cfg = self.config
  local code_y = cfg.header_height
  local code_height = cfg.height - cfg.header_height

  -- Track if cursor moved (for resetting navigation)
  local cursor_moved = false

  if stick then
    -- Apply deadzone
    local magnitude = math.sqrt(stick.x * stick.x + stick.y * stick.y)
    if magnitude < DEADZONE then
      stick = { x = 0, y = 0 }
    end

    -- Check if stick is active
    if stick.x ~= 0 or stick.y ~= 0 then
      cursor_moved = true
    end

    -- Move cursor
    self.cursor.x = self.cursor.x + stick.x * CURSOR_SPEED * dt
    self.cursor.y = self.cursor.y + stick.y * CURSOR_SPEED * dt

    -- Clamp cursor to code area bounds
    self.cursor.x = math.max(cfg.gutter_width + cfg.padding, math.min(cfg.width - 20, self.cursor.x))
    self.cursor.y = math.max(code_y, math.min(code_y + code_height - cfg.line_height, self.cursor.y))

    -- Edge scrolling
    local scroll_threshold = SCROLL_EDGE_LINES * cfg.line_height

    -- Scroll up when near top
    if self.cursor.y - code_y < scroll_threshold and self.scroll_offset > 0 then
      local proximity = 1 - ((self.cursor.y - code_y) / scroll_threshold)
      self:scroll(-proximity * 0.5)
    end

    -- Scroll down when near bottom
    local bottom_dist = (code_y + code_height) - self.cursor.y
    if bottom_dist < scroll_threshold and self.scroll_offset < self.total_lines - self.visible_lines then
      local proximity = 1 - (bottom_dist / scroll_threshold)
      self:scroll(proximity * 0.5)
    end
  end

  -- Handle trigger input for tree navigation
  if joystick then
    local l2 = joystick:getGamepadAxis("triggerleft") or 0
    local r2 = joystick:getGamepadAxis("triggerright") or 0

    -- R2: Expand to parent node
    if r2 > TRIGGER_THRESHOLD and self.trigger_prev.r2 <= TRIGGER_THRESHOLD then
      self:expand_selection()
    end

    -- L2: Shrink to child node
    if l2 > TRIGGER_THRESHOLD and self.trigger_prev.l2 <= TRIGGER_THRESHOLD then
      self:shrink_selection()
    end

    self.trigger_prev = { l2 = l2, r2 = r2 }
  end

  -- Reset navigation if cursor moved
  if cursor_moved then
    self.navigated_node = nil
  end

  -- Update highlighted node
  if self.navigated_node then
    -- Use the navigated node
    self.highlighted_node = Syntax.node_range(self.navigated_node)
  else
    -- Query syntax node at cursor position
    self.highlighted_node = nil
    local line = math.floor((self.cursor.y - code_y) / cfg.line_height) + 1 + self.scroll_offset
    local font = love.graphics.getFont()
    local char_width = font:getWidth("m")  -- monospace font
    local column = math.floor((self.cursor.x - cfg.gutter_width - cfg.padding) / char_width)

    if self.syntax_buffer and line >= 1 and line <= self.total_lines then
      local root = self.syntax_buffer:root_node()
      if root then
        local node = Syntax.node_at_point(root, line - 1, math.max(0, column))
        if node then
          local range = Syntax.node_range(node)
          if range then
            self.highlighted_node = range
          end
        end
      end
    end
  end
end

-- Get syntax node at current cursor position
function FileViewer:get_cursor_node()
  if not self.syntax_buffer then return nil end

  local cfg = self.config
  local code_y = cfg.header_height
  local line = math.floor((self.cursor.y - code_y) / cfg.line_height) + 1 + self.scroll_offset
  local font = love.graphics.getFont()
  local char_width = font:getWidth("m")
  local column = math.floor((self.cursor.x - cfg.gutter_width - cfg.padding) / char_width)

  if line >= 1 and line <= self.total_lines then
    local root = self.syntax_buffer:root_node()
    if root then
      return Syntax.node_at_point(root, line - 1, math.max(0, column))
    end
  end
  return nil
end

-- Expand selection to parent node
function FileViewer:expand_selection()
  local current = self.navigated_node or self:get_cursor_node()
  if not current then return end

  local parent = Syntax.node_parent(current)
  -- Keep going up to find a named node
  while parent and not Syntax.node_is_named(parent) do
    parent = Syntax.node_parent(parent)
  end

  if parent then
    self.navigated_node = parent
    self.highlighted_node = Syntax.node_range(parent)
  end
end

-- Shrink selection to child node containing cursor
function FileViewer:shrink_selection()
  local current = self.navigated_node or self:get_cursor_node()
  if not current then return end

  -- Get cursor position in tree-sitter coordinates (0-indexed)
  local cfg = self.config
  local code_y = cfg.header_height
  local line = math.floor((self.cursor.y - code_y) / cfg.line_height) + 1 + self.scroll_offset
  local font = love.graphics.getFont()
  local char_width = font:getWidth("m")
  local column = math.floor((self.cursor.x - cfg.gutter_width - cfg.padding) / char_width)
  local cursor_row = line - 1  -- 0-indexed
  local cursor_col = math.max(0, column)

  -- Find named child that contains the cursor position
  local best_child = nil
  for child in Syntax.node_named_children(current) do
    local range = Syntax.node_range(child)
    if range then
      -- Check if cursor is within this child's range
      local in_range = false
      if cursor_row > range.start_row and cursor_row < range.end_row then
        -- Cursor row is strictly between start and end rows
        in_range = true
      elseif cursor_row == range.start_row and cursor_row == range.end_row then
        -- Single-line node: check columns
        in_range = cursor_col >= range.start_col and cursor_col <= range.end_col
      elseif cursor_row == range.start_row then
        -- Cursor on start row of multi-line node
        in_range = cursor_col >= range.start_col
      elseif cursor_row == range.end_row then
        -- Cursor on end row of multi-line node
        in_range = cursor_col <= range.end_col
      end

      if in_range then
        best_child = child
        break
      end
    end
  end

  -- Fall back to first named child if cursor isn't in any child
  local child = best_child or Syntax.node_first_named_child(current)
  if child then
    self.navigated_node = child
    self.highlighted_node = Syntax.node_range(child)
  end
end

-- Draw the file viewer
function FileViewer:draw()
  local cfg = self.config

  -- Background
  love.graphics.setColor(0.12, 0.12, 0.14, 1)
  love.graphics.rectangle("fill", cfg.x, cfg.y, cfg.width, cfg.height)

  -- Header background
  love.graphics.setColor(0.18, 0.18, 0.22, 1)
  love.graphics.rectangle("fill", cfg.x, cfg.y, cfg.width, cfg.header_height)

  -- Header filename
  love.graphics.setColor(0.8, 0.8, 0.8, 1)
  local display_name = self.filename
  if #display_name == 0 then
    display_name = "No file loaded"
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
  end
  love.graphics.print(display_name, cfg.x + cfg.padding, cfg.y + 8)

  -- File counter (if we have lines)
  if self.total_lines > 0 then
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    local info = string.format("%d lines", self.total_lines)
    local font = love.graphics.getFont()
    local info_width = font:getWidth(info)
    love.graphics.print(info, cfg.x + cfg.width - info_width - cfg.padding, cfg.y + 8)
  end

  -- Code area setup
  local code_y = cfg.y + cfg.header_height
  local code_height = cfg.height - cfg.header_height

  -- Set scissor for clipping
  love.graphics.setScissor(cfg.x, code_y, cfg.width, code_height)

  -- Draw highlighted node background
  if self.highlighted_node then
    local font = love.graphics.getFont()
    local char_width = font:getWidth("m")
    local node = self.highlighted_node

    love.graphics.setColor(0.3, 0.5, 0.7, 0.3)

    -- Draw highlight for each line the node spans
    for row = node.start_row, node.end_row do
      local line_idx = row + 1  -- Convert 0-indexed to 1-indexed
      local visible_line = line_idx - self.scroll_offset

      if visible_line >= 1 and visible_line <= self.visible_lines + 1 then
        local y = code_y + (visible_line - 1) * cfg.line_height
        local start_col = (row == node.start_row) and node.start_col or 0
        local end_col = (row == node.end_row) and node.end_col or 1000

        local x = cfg.x + cfg.gutter_width + cfg.padding + start_col * char_width
        local width = (end_col - start_col) * char_width

        love.graphics.rectangle("fill", x, y, width, cfg.line_height)
      end
    end
  end

  -- Draw lines
  for i = 1, self.visible_lines + 1 do
    local line_idx = self.scroll_offset + i
    if line_idx > self.total_lines then break end

    local y = code_y + (i - 1) * cfg.line_height

    -- Line number gutter
    love.graphics.setColor(0.4, 0.4, 0.45, 1)
    love.graphics.printf(
      tostring(line_idx),
      cfg.x + 5,
      y,
      cfg.gutter_width - 10,
      "right"
    )

    -- Gutter separator
    love.graphics.setColor(0.25, 0.25, 0.28, 1)
    love.graphics.line(
      cfg.x + cfg.gutter_width,
      y,
      cfg.x + cfg.gutter_width,
      y + cfg.line_height
    )

    -- Code line (highlighted)
    -- Reset to white so coloredtext colors aren't multiplied/dimmed
    love.graphics.setColor(1, 1, 1, 1)
    local line = self.highlighted_lines[line_idx]
    if line then
      love.graphics.print(line, cfg.x + cfg.gutter_width + cfg.padding, y)
    end
  end

  love.graphics.setScissor()  -- Reset scissor

  -- Scroll indicator
  if self.total_lines > self.visible_lines then
    local max_scroll = self.total_lines - self.visible_lines
    local scroll_ratio = self.scroll_offset / max_scroll
    local indicator_height = math.max(20, code_height * (self.visible_lines / self.total_lines))
    local indicator_y = code_y + scroll_ratio * (code_height - indicator_height)

    -- Track
    love.graphics.setColor(0.2, 0.2, 0.22, 1)
    love.graphics.rectangle("fill", cfg.x + cfg.width - 8, code_y, 6, code_height)

    -- Thumb
    love.graphics.setColor(0.4, 0.4, 0.45, 1)
    love.graphics.rectangle("fill", cfg.x + cfg.width - 8, indicator_y, 6, indicator_height)
  end

  -- Draw cursor (grey unfilled circle)
  love.graphics.setColor(0.6, 0.6, 0.6, 1)
  love.graphics.circle("line", cfg.x + self.cursor.x, cfg.y + self.cursor.y, 8)
end

return FileViewer
