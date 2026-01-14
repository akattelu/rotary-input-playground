local Syntax = require("lib.syntax")

local Highlighter = {}

-- Color theme (RGBA values 0-1)
Highlighter.THEME = {
  default    = {0.85, 0.85, 0.85, 1},    -- light gray
  keyword    = {0.8, 0.5, 0.8, 1},       -- purple
  string     = {0.6, 0.8, 0.5, 1},       -- green
  comment    = {0.5, 0.5, 0.5, 1},       -- gray
  number     = {0.9, 0.7, 0.4, 1},       -- orange
  operator   = {0.7, 0.8, 0.9, 1},       -- light blue
  func_name  = {0.5, 0.7, 0.9, 1},       -- blue
  property   = {0.8, 0.8, 0.6, 1},       -- yellow
  builtin    = {0.7, 0.6, 0.9, 1},       -- violet
  punctuation = {0.6, 0.6, 0.6, 1},      -- dim gray
}

-- Node types to color mapping
local NODE_COLORS = {
  -- Keywords
  ["function"] = "keyword",
  ["local"] = "keyword",
  ["return"] = "keyword",
  ["if"] = "keyword",
  ["then"] = "keyword",
  ["else"] = "keyword",
  ["elseif"] = "keyword",
  ["end"] = "keyword",
  ["for"] = "keyword",
  ["while"] = "keyword",
  ["do"] = "keyword",
  ["repeat"] = "keyword",
  ["until"] = "keyword",
  ["in"] = "keyword",
  ["and"] = "keyword",
  ["or"] = "keyword",
  ["not"] = "keyword",
  ["nil"] = "keyword",
  ["true"] = "keyword",
  ["false"] = "keyword",
  ["break"] = "keyword",
  ["goto"] = "keyword",

  -- Literals
  ["string"] = "string",
  ["string_content"] = "string",
  ["number"] = "number",

  -- Comments
  ["comment"] = "comment",
  ["comment_content"] = "comment",

  -- Function-related
  ["function_name"] = "func_name",
  ["function_name_field"] = "func_name",
  ["method"] = "func_name",

  -- Properties/fields
  ["property_identifier"] = "property",
  ["field"] = "property",
  ["dot_index_expression"] = "property",

  -- Operators
  ["+"] = "operator",
  ["-"] = "operator",
  ["*"] = "operator",
  ["/"] = "operator",
  ["%"] = "operator",
  ["^"] = "operator",
  ["=="] = "operator",
  ["~="] = "operator",
  ["<"] = "operator",
  [">"] = "operator",
  ["<="] = "operator",
  [">="] = "operator",
  [".."] = "operator",
  ["#"] = "operator",
  ["="] = "operator",

  -- Punctuation
  ["("] = "punctuation",
  [")"] = "punctuation",
  ["{"] = "punctuation",
  ["}"] = "punctuation",
  ["["] = "punctuation",
  ["]"] = "punctuation",
  [","] = "punctuation",
  ["."] = "punctuation",
  [":"] = "punctuation",
  [";"] = "punctuation",
}

-- Get color for a node type
function Highlighter.get_color(node_type)
  local color_name = NODE_COLORS[node_type]
  if color_name then
    return Highlighter.THEME[color_name]
  end
  return Highlighter.THEME.default
end

-- Collect all leaf nodes from the AST with their ranges
local function collect_nodes(root, source)
  local nodes = {}

  Syntax.walk(root, function(node)
    local node_type = Syntax.node_type(node)
    local range = Syntax.node_range(node)

    if range then
      -- Only collect leaf nodes (no children) to avoid overlapping ranges
      local child_count = Syntax.node_child_count(node)

      if child_count == 0 then
        table.insert(nodes, {
          type = node_type,
          start_byte = range.start_byte,
          end_byte = range.end_byte,
          start_row = range.start_row,
          start_col = range.start_col,
          end_row = range.end_row,
          end_col = range.end_col,
          text = Syntax.node_text(node, source)
        })
      end
    end

    return true  -- Continue walking
  end)

  -- Sort by start position
  table.sort(nodes, function(a, b)
    return a.start_byte < b.start_byte
  end)

  return nodes
end

-- Split source into lines
local function split_lines(source)
  local lines = {}
  for line in (source .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  return lines
end

-- Highlight source code and return array of coloredtext per line
-- Returns: array where each element is a LOVE2D coloredtext array
function Highlighter.highlight(source, language)
  language = language or "lua"

  -- Check if language is supported
  if not Syntax.languages[language] then
    -- Fall back to plain text
    local lines = split_lines(source)
    local result = {}
    for _, line in ipairs(lines) do
      table.insert(result, {Highlighter.THEME.default, line})
    end
    return result
  end

  -- Parse source
  local ok, buf = pcall(Syntax.Buffer.new, language)
  if not ok then
    -- Parse failed, return plain text
    local lines = split_lines(source)
    local result = {}
    for _, line in ipairs(lines) do
      table.insert(result, {Highlighter.THEME.default, line})
    end
    return result
  end

  buf:set_text(source)
  local root = buf:root_node()

  if not root then
    buf:destroy()
    local lines = split_lines(source)
    local result = {}
    for _, line in ipairs(lines) do
      table.insert(result, {Highlighter.THEME.default, line})
    end
    return result
  end

  -- Collect styled nodes
  local nodes = collect_nodes(root, source)
  buf:destroy()

  -- Split into lines
  local lines = split_lines(source)
  local result = {}

  -- Build coloredtext for each line
  local node_idx = 1
  local byte_offset = 0

  for _, line in ipairs(lines) do
    local line_start = byte_offset
    local line_end = byte_offset + #line
    local segments = {}
    local pos = 0

    -- Process nodes that overlap this line
    while node_idx <= #nodes do
      local node = nodes[node_idx]

      -- Skip nodes that end before this line
      if node.end_byte <= line_start then
        node_idx = node_idx + 1
      -- Stop if node starts after this line
      elseif node.start_byte >= line_end then
        break
      else
        -- Node overlaps with this line
        local node_start_in_line = math.max(0, node.start_byte - line_start)
        local node_end_in_line = math.min(#line, node.end_byte - line_start)

        -- Add default text before this node
        if node_start_in_line > pos then
          local before_text = line:sub(pos + 1, node_start_in_line)
          if #before_text > 0 then
            table.insert(segments, Highlighter.THEME.default)
            table.insert(segments, before_text)
          end
        end

        -- Add colored node text
        local node_text = line:sub(node_start_in_line + 1, node_end_in_line)
        if #node_text > 0 then
          local color = Highlighter.get_color(node.type)
          table.insert(segments, color)
          table.insert(segments, node_text)
        end

        pos = node_end_in_line

        -- Move to next node if this one ends within this line
        if node.end_byte <= line_end then
          node_idx = node_idx + 1
        else
          break
        end
      end
    end

    -- Add remaining text on this line
    if pos < #line then
      local remaining = line:sub(pos + 1)
      if #remaining > 0 then
        table.insert(segments, Highlighter.THEME.default)
        table.insert(segments, remaining)
      end
    end

    -- If no segments, add empty default
    if #segments == 0 then
      table.insert(segments, Highlighter.THEME.default)
      table.insert(segments, "")
    end

    table.insert(result, segments)
    byte_offset = line_end + 1  -- +1 for newline
  end

  return result
end

return Highlighter
