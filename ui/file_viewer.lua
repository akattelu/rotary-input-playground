local FileViewer = {}
FileViewer.__index = FileViewer

local Highlighter = require("lib.highlighter")

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
  else
    self.highlighted_lines = {}
    self.total_lines = 0
  end

  -- Reset scroll
  self.scroll_offset = 0
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
  local max_scroll = math.max(0, self.total_lines - self.visible_lines)
  self.scroll_offset = math.max(0, math.min(max_scroll, self.scroll_offset + delta))
end

-- Scroll to specific line (0-indexed)
function FileViewer:scroll_to(line_number)
  local max_scroll = math.max(0, self.total_lines - self.visible_lines)
  self.scroll_offset = math.max(0, math.min(max_scroll, line_number))
end

-- Update (for smooth scrolling, future use)
function FileViewer:update()
  -- Currently no-op
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
end

return FileViewer
