-- Minimal testing framework for LuaJIT
local M = {}

-- Track test results
M.passed = 0
M.failed = 0
M.errors = {}

-- Colors for terminal output
local colors = {
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  reset = "\27[0m"
}

-- Core assert function with descriptive error logging
function M.equal(actual, expected, message)
  message = message or "values should be equal"
  if actual == expected then
    M.passed = M.passed + 1
    return true
  else
    M.failed = M.failed + 1
    local info = debug.getinfo(2, "Sl")
    local err = string.format(
      "%s:%d: %s\n  expected: %s\n  actual:   %s",
      info.short_src, info.currentline, message,
      tostring(expected), tostring(actual)
    )
    table.insert(M.errors, err)
    return false
  end
end

-- Truthy assert
function M.truthy(value, message)
  message = message or "value should be truthy"
  return M.equal(not not value, true, message)
end

-- Falsy assert
function M.falsy(value, message)
  message = message or "value should be falsy"
  return M.equal(not not value, false, message)
end

-- Run a named test with error catching
function M.test(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    M.failed = M.failed + 1
    local info = debug.getinfo(2, "Sl")
    table.insert(M.errors, string.format(
      "%s:%d: %s\n  error: %s",
      info.short_src, info.currentline, name, tostring(err)
    ))
  end
end

-- Print summary and return exit code
function M.summary()
  print(string.rep("-", 40))

  if #M.errors > 0 then
    print(colors.red .. "FAILURES:" .. colors.reset)
    for _, err in ipairs(M.errors) do
      print("  " .. err)
    end
    print()
  end

  local total = M.passed + M.failed
  local color = M.failed > 0 and colors.red or colors.green
  print(string.format("%s%d/%d tests passed%s", color, M.passed, total, colors.reset))

  return M.failed > 0 and 1 or 0
end

-- Reset state (useful if running multiple test files)
function M.reset()
  M.passed = 0
  M.failed = 0
  M.errors = {}
end

return M
