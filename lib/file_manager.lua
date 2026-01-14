local FileManager = {}

-- File extension to language mapping
local EXTENSION_MAP = {
  lua = "lua",
  js = "javascript",
  ts = "typescript",
  py = "python",
  rb = "ruby",
  rs = "rust",
  go = "go",
  c = "c",
  cpp = "cpp",
  h = "c",
  hpp = "cpp",
  java = "java",
  json = "json",
  yaml = "yaml",
  yml = "yaml",
  toml = "toml",
  md = "markdown",
  sh = "bash",
  bash = "bash",
  zsh = "bash",
}

-- Get language name from file path
function FileManager.get_language(path)
  local ext = path:match("%.([^%.]+)$")
  if ext then
    return EXTENSION_MAP[ext:lower()] or "lua"
  end
  return "lua"
end

-- Recursively scan directory for files with given extension
local function scan_recursive(dir, extension, results)
  local items = love.filesystem.getDirectoryItems(dir)

  for _, item in ipairs(items) do
    local path = dir == "" and item or (dir .. "/" .. item)
    local info = love.filesystem.getInfo(path)

    if info then
      if info.type == "directory" then
        -- Skip hidden directories
        if not item:match("^%.") then
          scan_recursive(path, extension, results)
        end
      elseif info.type == "file" then
        -- Check extension
        if item:match("%." .. extension .. "$") then
          table.insert(results, path)
        end
      end
    end
  end
end

-- Scan current directory for .lua files
-- Returns: array of file entry tables { path, name, content, language }
function FileManager.scan_directory(extension)
  extension = extension or "lua"
  local paths = {}

  scan_recursive("", extension, paths)

  -- Sort alphabetically
  table.sort(paths)

  -- Build file entries
  local files = {}
  for _, path in ipairs(paths) do
    local content = FileManager.load_file(path)
    if content then
      table.insert(files, {
        path = path,
        name = path,
        content = content,
        language = FileManager.get_language(path)
      })
    end
  end

  print("Found " .. #files .. " ." .. extension .. " files")
  return files
end

-- Load file content by path
-- Returns: string content or nil on error
function FileManager.load_file(path)
  local content = love.filesystem.read(path)
  return content
end

-- Cycle to next file index (wraps around)
function FileManager.next_index(current_index, total_files)
  if total_files == 0 then return 1 end
  return (current_index % total_files) + 1
end

-- Cycle to previous file index (wraps around)
function FileManager.prev_index(current_index, total_files)
  if total_files == 0 then return 1 end
  return ((current_index - 2) % total_files) + 1
end

return FileManager
