local ffi = require('ffi')

ffi.cdef([[
    void* malloc(size_t size);
    void free(void* ptr);
]])

local syntax = ffi.load("./libsyntax.dylib")
print(syntax.malloc)

local x = syntax.malloc(100)
print(x)
syntax.free(x)
