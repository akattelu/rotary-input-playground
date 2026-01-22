# Rotary Input Playground

A Love2D playground for testing out different input systems with a controller

This requires 2 libraries (used in `lib/syntax.lua`):
* `libtree-sitter.dylib` (copied from treesitter installation)
* `libsyntax.dylib` (built from https://github.com/akattelu/flow-syntax)

## Testing

```bash
luajit spec/test.lua
```

Tests use a minimal framework in `spec/assert.lua`. Create test files as `spec/*_spec.lua`.
