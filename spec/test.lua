#!/usr/bin/env luajit
-- Test runner entry point
-- Usage: luajit spec/test.lua

-- Add project root to path for requiring modules
local script_dir = arg[0]:match("(.*/)")
if script_dir then
  package.path = script_dir .. "../?.lua;" .. package.path
  package.path = script_dir .. "?.lua;" .. package.path
end

local assert = require("assert")

-- Discover and run all *_spec.lua files in spec/
local function run_all_tests()
  local handle = io.popen("ls " .. (script_dir or "./") .. "*_spec.lua 2>/dev/null")
  local files = handle:read("*a")
  handle:close()

  for file in files:gmatch("[^\n]+") do
    local module_name = file:match("([^/]+)%.lua$"):gsub("%.lua$", "")
    print("Running: " .. module_name)
    dofile(file)
  end
end

run_all_tests()

os.exit(assert.summary())
