# Rotary Input Playground

A Love2D playground for testing out different input systems with a controller

This requires 2 libraries (used in `lib/syntax.lua`):
* `libtree-sitter.dylib` (copied from treesitter installation)
* `libsyntax.dylib` (built from https://github.com/akattelu/flow-syntax)

## Testing

```bash
luajit spec/test.lua
stylua . # format all code
```

Tests use a minimal framework in `spec/assert.lua`. Create test files as `spec/*_spec.lua`.

## Showcase

##### General Movement
![controlled-general](https://github.com/user-attachments/assets/72a33401-932e-434a-8877-cb764691a692)

##### Typing "Hello World"
![controlled-typing](https://github.com/user-attachments/assets/e5854f38-58d7-4c85-a6c5-7e11d4ed064b)

##### Using picker to select options
![controlled-picker](https://github.com/user-attachments/assets/3766043c-d7a6-4a43-a6a9-bf512e0bf802)
