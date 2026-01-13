local ffi = require("ffi")

local Syntax = {}

-- Load libraries from project root
local script_path = debug.getinfo(1, "S").source:match("@(.*/)")
local lib_path = script_path and script_path:gsub("lib/$", "") or "./"

local ts = ffi.load(lib_path .. "libtree-sitter.dylib")
local grammars = ffi.load(lib_path .. "libsyntax.dylib")

-- C type definitions
ffi.cdef [[
  typedef struct TSParser TSParser;
  typedef struct TSTree TSTree;
  typedef struct TSLanguage TSLanguage;
  typedef struct TSQuery TSQuery;
  typedef struct TSQueryCursor TSQueryCursor;

  typedef struct {
    uint32_t row;
    uint32_t column;
  } TSPoint;

  typedef struct {
    uint32_t context[4];
    const void *id;
    const TSTree *tree;
  } TSNode;

  typedef struct {
    TSPoint start_point;
    TSPoint end_point;
    uint32_t start_byte;
    uint32_t end_byte;
  } TSRange;

  typedef struct {
    uint32_t start_byte;
    uint32_t old_end_byte;
    uint32_t new_end_byte;
    TSPoint start_point;
    TSPoint old_end_point;
    TSPoint new_end_point;
  } TSInputEdit;

  typedef enum {
    TSInputEncodingUTF8,
    TSInputEncodingUTF16
  } TSInputEncoding;

  typedef const char *(*TSReadFn)(void *payload, uint32_t byte_index, TSPoint position, uint32_t *bytes_read);

  typedef struct {
    void *payload;
    TSReadFn read;
    TSInputEncoding encoding;
  } TSInput;

  typedef enum {
    TSSymbolTypeRegular,
    TSSymbolTypeAnonymous,
    TSSymbolTypeAuxiliary
  } TSSymbolType;

  // Parser functions
  TSParser *ts_parser_new(void);
  void ts_parser_delete(TSParser *parser);
  bool ts_parser_set_language(TSParser *parser, const TSLanguage *language);
  const TSLanguage *ts_parser_language(const TSParser *parser);
  TSTree *ts_parser_parse_string(TSParser *parser, const TSTree *old_tree, const char *string, uint32_t length);
  TSTree *ts_parser_parse(TSParser *parser, const TSTree *old_tree, TSInput input);
  void ts_parser_reset(TSParser *parser);

  // Tree functions
  TSTree *ts_tree_copy(const TSTree *tree);
  void ts_tree_delete(TSTree *tree);
  TSNode ts_tree_root_node(const TSTree *tree);
  void ts_tree_edit(TSTree *tree, const TSInputEdit *edit);
  const TSLanguage *ts_tree_language(const TSTree *tree);

  // Node functions
  const char *ts_node_type(TSNode node);
  uint32_t ts_node_symbol(TSNode node);
  const TSLanguage *ts_node_language(TSNode node);
  uint32_t ts_node_start_byte(TSNode node);
  uint32_t ts_node_end_byte(TSNode node);
  TSPoint ts_node_start_point(TSNode node);
  TSPoint ts_node_end_point(TSNode node);
  char *ts_node_string(TSNode node);
  bool ts_node_is_null(TSNode node);
  bool ts_node_is_named(TSNode node);
  bool ts_node_is_missing(TSNode node);
  bool ts_node_is_extra(TSNode node);
  bool ts_node_has_error(TSNode node);
  bool ts_node_has_changes(TSNode node);
  TSNode ts_node_parent(TSNode node);
  TSNode ts_node_child(TSNode node, uint32_t child_index);
  uint32_t ts_node_child_count(TSNode node);
  TSNode ts_node_named_child(TSNode node, uint32_t child_index);
  uint32_t ts_node_named_child_count(TSNode node);
  TSNode ts_node_next_sibling(TSNode node);
  TSNode ts_node_prev_sibling(TSNode node);
  TSNode ts_node_next_named_sibling(TSNode node);
  TSNode ts_node_prev_named_sibling(TSNode node);
  TSNode ts_node_child_by_field_name(TSNode node, const char *field_name, uint32_t field_name_length);
  const char *ts_node_field_name_for_child(TSNode node, uint32_t child_index);
  TSNode ts_node_descendant_for_byte_range(TSNode node, uint32_t start_byte, uint32_t end_byte);
  TSNode ts_node_descendant_for_point_range(TSNode node, TSPoint start_point, TSPoint end_point);
  bool ts_node_eq(TSNode a, TSNode b);

  // Language functions
  uint32_t ts_language_symbol_count(const TSLanguage *language);
  const char *ts_language_symbol_name(const TSLanguage *language, uint32_t symbol);
  TSSymbolType ts_language_symbol_type(const TSLanguage *language, uint32_t symbol);
  uint32_t ts_language_field_count(const TSLanguage *language);
  const char *ts_language_field_name_for_id(const TSLanguage *language, uint32_t id);

  // Memory management
  void free(void *ptr);
]]

-- Language grammar function declarations
local LANGUAGE_NAMES = {
  "agda", "astro", "awk", "bash", "c", "c_sharp", "cmake", "commonlisp",
  "cpp", "css", "diff", "dockerfile", "dtd", "elixir", "elm", "fish",
  "fsharp", "git_rebase", "gitcommit", "gleam", "go", "hare", "haskell",
  "hcl", "html", "hurl", "java", "javascript", "json", "julia", "kdl",
  "latex", "lua", "mail", "make", "markdown", "markdown_inline", "nasm",
  "nickel", "nim", "ninja", "nix", "nu", "ocaml", "odin", "openscad",
  "org", "perl", "php", "po", "powershell", "proto", "purescript",
  "python", "regex", "rpmspec", "rst", "ruby", "rust", "scheme", "sql",
  "ssh_config", "superhtml", "swift", "toml", "typescript", "typst",
  "uxntal", "verilog", "vim", "xml", "yaml", "zig", "ziggy", "ziggy_schema"
}

-- Declare language functions
local lang_decls = {}
for _, name in ipairs(LANGUAGE_NAMES) do
  table.insert(lang_decls, string.format("const TSLanguage *tree_sitter_%s(void);", name))
end
ffi.cdef(table.concat(lang_decls, "\n"))

-- Language registry
Syntax.languages = {}
local language_cache = {}

for _, name in ipairs(LANGUAGE_NAMES) do
  Syntax.languages[name] = true
end

function Syntax.get_language(name)
  if not Syntax.languages[name] then
    return nil
  end

  if not language_cache[name] then
    local func_name = "tree_sitter_" .. name
    local ok, lang = pcall(function()
      return grammars[func_name]()
    end)
    if ok and lang ~= nil then
      language_cache[name] = lang
    else
      return nil
    end
  end

  return language_cache[name]
end

-- Buffer class
local Buffer = {}
Buffer.__index = Buffer
Syntax.Buffer = Buffer

function Buffer.new(language_name)
  local lang = Syntax.get_language(language_name)
  if not lang then
    error("Unknown language: " .. tostring(language_name))
  end

  local self = setmetatable({}, Buffer)
  self._parser = ts.ts_parser_new()
  if self._parser == nil then
    error("Failed to create parser")
  end

  if not ts.ts_parser_set_language(self._parser, lang) then
    ts.ts_parser_delete(self._parser)
    error("Failed to set language: " .. language_name)
  end

  self._tree = nil
  self._text = ""
  self._language_name = language_name

  return self
end

function Buffer:set_text(text)
  self._text = text
  if self._tree ~= nil then
    ts.ts_tree_delete(self._tree)
  end
  self._tree = ts.ts_parser_parse_string(self._parser, nil, text, #text)
end

function Buffer:get_text()
  return self._text
end

function Buffer:root_node()
  if self._tree == nil then
    return nil
  end
  return ts.ts_tree_root_node(self._tree)
end

function Buffer:edit(start_byte, old_end_byte, new_end_byte, start_point, old_end_point, new_end_point, new_text)
  if self._tree == nil then
    self:set_text(new_text or "")
    return
  end

  -- Create edit descriptor
  local edit = ffi.new("TSInputEdit", {
    start_byte = start_byte,
    old_end_byte = old_end_byte,
    new_end_byte = new_end_byte,
    start_point = start_point or { row = 0, column = 0 },
    old_end_point = old_end_point or { row = 0, column = 0 },
    new_end_point = new_end_point or { row = 0, column = 0 }
  })

  -- Apply edit to tree
  ts.ts_tree_edit(self._tree, edit)

  -- Update internal text
  if new_text then
    self._text = new_text
  end

  -- Reparse with old tree for incremental parsing
  local old_tree = self._tree
  self._tree = ts.ts_parser_parse_string(self._parser, old_tree, self._text, #self._text)
  ts.ts_tree_delete(old_tree)
end

-- Helper to count newlines and get column at byte position
local function byte_to_point(text, byte_pos)
  local row = 0
  local last_newline = 0
  for i = 1, byte_pos do
    if text:sub(i, i) == "\n" then
      row = row + 1
      last_newline = i
    end
  end
  return { row = row, column = byte_pos - last_newline }
end

function Buffer:insert(byte_offset, text)
  local old_text = self._text
  local new_text = old_text:sub(1, byte_offset) .. text .. old_text:sub(byte_offset + 1)

  local start_point = byte_to_point(old_text, byte_offset)
  local old_end_point = start_point
  local new_end_point = byte_to_point(new_text, byte_offset + #text)

  self:edit(byte_offset, byte_offset, byte_offset + #text, start_point, old_end_point, new_end_point, new_text)
end

function Buffer:delete(start_byte, end_byte)
  local old_text = self._text
  local new_text = old_text:sub(1, start_byte) .. old_text:sub(end_byte + 1)

  local start_point = byte_to_point(old_text, start_byte)
  local old_end_point = byte_to_point(old_text, end_byte)
  local new_end_point = start_point

  self:edit(start_byte, end_byte, start_byte, start_point, old_end_point, new_end_point, new_text)
end

function Buffer:replace(start_byte, end_byte, text)
  local old_text = self._text
  local new_text = old_text:sub(1, start_byte) .. text .. old_text:sub(end_byte + 1)

  local start_point = byte_to_point(old_text, start_byte)
  local old_end_point = byte_to_point(old_text, end_byte)
  local new_end_point = byte_to_point(new_text, start_byte + #text)

  self:edit(start_byte, end_byte, start_byte + #text, start_point, old_end_point, new_end_point, new_text)
end

function Buffer:destroy()
  if self._tree ~= nil then
    ts.ts_tree_delete(self._tree)
    self._tree = nil
  end
  if self._parser ~= nil then
    ts.ts_parser_delete(self._parser)
    self._parser = nil
  end
end

-- Node helper functions
function Syntax.node_type(node)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  return ffi.string(ts.ts_node_type(node))
end

function Syntax.node_text(node, source)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local start_byte = ts.ts_node_start_byte(node)
  local end_byte = ts.ts_node_end_byte(node)
  return source:sub(start_byte + 1, end_byte)
end

function Syntax.node_range(node)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local start_point = ts.ts_node_start_point(node)
  local end_point = ts.ts_node_end_point(node)
  return {
    start_byte = ts.ts_node_start_byte(node),
    end_byte = ts.ts_node_end_byte(node),
    start_row = start_point.row,
    start_col = start_point.column,
    end_row = end_point.row,
    end_col = end_point.column
  }
end

function Syntax.node_is_named(node)
  if node == nil or ts.ts_node_is_null(node) then
    return false
  end
  return ts.ts_node_is_named(node)
end

function Syntax.node_has_error(node)
  if node == nil or ts.ts_node_is_null(node) then
    return false
  end
  return ts.ts_node_has_error(node)
end

function Syntax.node_child_count(node)
  if node == nil or ts.ts_node_is_null(node) then
    return 0
  end
  return ts.ts_node_child_count(node)
end

function Syntax.node_named_child_count(node)
  if node == nil or ts.ts_node_is_null(node) then
    return 0
  end
  return ts.ts_node_named_child_count(node)
end

function Syntax.node_child(node, index)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local child = ts.ts_node_child(node, index)
  if ts.ts_node_is_null(child) then
    return nil
  end
  return child
end

function Syntax.node_named_child(node, index)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local child = ts.ts_node_named_child(node, index)
  if ts.ts_node_is_null(child) then
    return nil
  end
  return child
end

function Syntax.node_parent(node)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local parent = ts.ts_node_parent(node)
  if ts.ts_node_is_null(parent) then
    return nil
  end
  return parent
end

function Syntax.node_next_sibling(node)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local sibling = ts.ts_node_next_sibling(node)
  if ts.ts_node_is_null(sibling) then
    return nil
  end
  return sibling
end

function Syntax.node_prev_sibling(node)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local sibling = ts.ts_node_prev_sibling(node)
  if ts.ts_node_is_null(sibling) then
    return nil
  end
  return sibling
end

function Syntax.node_next_named_sibling(node)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local sibling = ts.ts_node_next_named_sibling(node)
  if ts.ts_node_is_null(sibling) then
    return nil
  end
  return sibling
end

function Syntax.node_prev_named_sibling(node)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local sibling = ts.ts_node_prev_named_sibling(node)
  if ts.ts_node_is_null(sibling) then
    return nil
  end
  return sibling
end

function Syntax.node_child_by_field(node, field_name)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local child = ts.ts_node_child_by_field_name(node, field_name, #field_name)
  if ts.ts_node_is_null(child) then
    return nil
  end
  return child
end

-- Iterator for children
function Syntax.node_children(node)
  local count = Syntax.node_child_count(node)
  local i = 0
  return function()
    if i < count then
      local child = Syntax.node_child(node, i)
      i = i + 1
      return child
    end
    return nil
  end
end

-- Iterator for named children
function Syntax.node_named_children(node)
  local count = Syntax.node_named_child_count(node)
  local i = 0
  return function()
    if i < count then
      local child = Syntax.node_named_child(node, i)
      i = i + 1
      return child
    end
    return nil
  end
end

-- Depth-first tree walk
function Syntax.walk(node, callback, depth)
  if node == nil or ts.ts_node_is_null(node) then
    return
  end

  depth = depth or 0
  local should_continue = callback(node, depth)

  if should_continue == false then
    return
  end

  for child in Syntax.node_children(node) do
    Syntax.walk(child, callback, depth + 1)
  end
end

-- Walk only named nodes
function Syntax.walk_named(node, callback, depth)
  if node == nil or ts.ts_node_is_null(node) then
    return
  end

  depth = depth or 0
  local should_continue = callback(node, depth)

  if should_continue == false then
    return
  end

  for child in Syntax.node_named_children(node) do
    Syntax.walk_named(child, callback, depth + 1)
  end
end

-- Get S-expression representation of tree
function Syntax.node_sexpr(node)
  if node == nil or ts.ts_node_is_null(node) then
    return nil
  end
  local str = ts.ts_node_string(node)
  if str == nil then
    return nil
  end
  local result = ffi.string(str)
  ffi.C.free(str)
  return result
end

-- Find node at byte position
function Syntax.node_at_byte(root, byte_pos)
  if root == nil or ts.ts_node_is_null(root) then
    return nil
  end
  local node = ts.ts_node_descendant_for_byte_range(root, byte_pos, byte_pos)
  if ts.ts_node_is_null(node) then
    return nil
  end
  return node
end

-- Find node at point (row, column)
function Syntax.node_at_point(root, row, column)
  if root == nil or ts.ts_node_is_null(root) then
    return nil
  end
  local point = ffi.new("TSPoint", { row = row, column = column })
  local node = ts.ts_node_descendant_for_point_range(root, point, point)
  if ts.ts_node_is_null(node) then
    return nil
  end
  return node
end

-- Expose internals for debugging
Syntax._ts = ts
Syntax._grammars = grammars
Syntax._ffi = ffi

-- Test function to verify the module works
function Syntax.test()
  print("=== Syntax Module Test ===")

  -- Test 1: Count languages
  local count = 0
  for _ in pairs(Syntax.languages) do count = count + 1 end
  print("Available languages: " .. count)

  -- Test 2: Try to load lua language
  print("Loading lua grammar...")
  local lang = Syntax.get_language("lua")
  if lang then
    print("  lua language loaded: " .. tostring(lang))
  else
    print("  ERROR: Failed to load lua language")
    return false
  end

  -- Test 3: Create buffer and parse
  print("Creating buffer...")
  local ok, buf = pcall(Syntax.Buffer.new, "lua")
  if not ok then
    print("  ERROR: " .. tostring(buf))
    return false
  end
  print("  Buffer created")

  -- Test 4: Parse some code
  print("Parsing code...")
  buf:set_text("local x = 1\nfunction hello()\n  return 'world'\nend")
  local root = buf:root_node()
  if root then
    print("  Root node type: " .. (Syntax.node_type(root) or "nil"))
  else
    print("  ERROR: No root node")
    buf:destroy()
    return false
  end

  -- Test 5: Walk tree
  print("Tree structure:")
  Syntax.walk_named(root, function(node, depth)
    print(string.rep("  ", depth + 1) .. Syntax.node_type(node))
    return depth < 2
  end)

  buf:destroy()
  print("=== Test Complete ===")
  return true
end

return Syntax
