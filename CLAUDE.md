# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rotary input playground is a LÖVE2D application combining a syntax-highlighted file viewer with a dual QWERTY keyboard input system for word selection using gamepad joysticks.

**File Viewer (left half):** Displays `.lua` files from the current directory with tree-sitter syntax highlighting. Cycle through files with L1/R1.

**Input Menu (right half):** Dual-stick word selection. Left stick filters by word beginnings, right stick filters by endings. Select from a radial menu to build sentences.

Press X to toggle between **view mode** (file browsing) and **input mode** (word selection).

## Running the Application

```bash
# Run the application (requires LÖVE2D installed)
love .
```

## Architecture

### Code Organization

This project follows a **component-driven development pattern**:

- **`ui/`**: Self-contained UI components
  - `ui/file_viewer.lua` - Syntax-highlighted code display with line numbers and scrolling
  - `ui/input_menu.lua` - Groups selection wheel and both keyboard dials, manages filtering/selection modes
  - `ui/dial.lua` - Individual keyboard dial with stick visualizer
  - `ui/selection_wheel.lua` - Radial word selection menu
- **`lib/`**: Helper functions, utilities, and classes
  - `lib/file_manager.lua` - Directory scanning and file cycling
  - `lib/highlighter.lua` - Syntax highlighting using tree-sitter
  - `lib/syntax.lua` - Tree-sitter FFI bindings for parsing
  - `lib/filter.lua` - Letter-based word filtering
  - `lib/corpus.lua` - Word list loading
- **`main.lua`**: Minimal orchestration - manages app mode, file state, and sentence state

When adding features:
- Extract reusable UI elements into `ui/` components with their own state and rendering
- Move shared logic and utilities into `lib/` modules
- Keep `main.lua` focused on high-level coordination

### App Modes

1. **View Mode** (default): File browsing
   - L1/R1: Cycle through loaded files
   - File viewer displays syntax-highlighted code on left half

2. **Input Mode** (toggle with X): Word selection
   - Input menu appears on right half
   - **Filter sub-mode**: Both sticks filter words (left=start letters, right=end letters)
   - **Select sub-mode** (RB): Right stick selects from radial menu, release to accept

### Core Components

- **main.lua**: Minimal application orchestration
  - Tracks `mode` ("view" or "input"), `files`, `current_file_index`, `sentence`
  - X button toggles mode, L1/R1 cycle files (view mode), B deletes words
  - Coordinates `file_viewer` and `input_menu` components

- **ui/file_viewer.lua**: Code display component
  - `FileViewer:set_file(file)`: Load and highlight a file
  - `FileViewer:draw()`: Render with line numbers and scroll indicator

- **ui/input_menu.lua**: Grouped input component (appears on right half of screen)
  - Manages internal `mode` state ("filter" or "select")
  - Owns and coordinates `left_dial`, `right_dial`, and `selection_wheel` instances
  - Positioned vertically: selection wheel (top) → left keyboard (middle) → right keyboard (bottom)
  - `InputMenu:update(words, sticks, joystick)`: Updates filtering/selection, returns selected word or nil
  - `InputMenu:draw()`: Renders all sub-components with right-half positioning
  - `InputMenu:handle_mode_toggle()`: Handles RB button for filter/select mode switching

- **ui/selection_wheel.lua**: Radial word selection menu
  - Displays up to 8 words in circular layout
  - Supports pagination (ZR trigger) and angle-based selection
  - Drawing methods accept optional `x, width` parameters for flexible positioning

- **ui/dial.lua**: Keyboard dial UI component
  - Self-contained QWERTY keyboard with stick visualizer
  - `Dial.new(config)`: Creates dial instance with position/label configuration
  - `Dial:update(vx, vy)`: Updates highlighted key and region from stick position
  - `Dial:draw()`: Renders keyboard and visualizer
  - `Dial:get_region()`: Returns current filter region (4 closest keys)

- **lib/filter.lua**: Letter-based filtering system with region support
  - `Filter.apply(words, left_region, right_region)`: Returns words matching both start and end letter filters
  - Uses virtual coordinates (-100 to 100) centered at 'g'

- **lib/corpus.lua**: Word list loading utility

- **conf.lua**: LÖVE2D configuration (window size, title, modules)

- **words.txt**: Word list loaded at startup

### Key State Variables

**In main.lua:**
- `mode`: App mode ("view" or "input")
- `files`: Array of loaded file objects `{path, name, content, language}`
- `current_file_index`: Index of currently displayed file
- `sentence`: Array of selected words
- `left_stick`/`right_stick`: Normalized joystick positions (-1 to 1)

**In input_menu:**
- `mode`: Current interaction mode ("filter" or "select")
- `filtered`: Current list of words after filtering
- `zr_prev`: Edge detection for pagination trigger
- `left_dial`/`right_dial`/`selection_wheel`: Component instances

**In selection_wheel:**
- `selected_index`: Index into radial menu (1-8)
- `page`: Current pagination page
- `was_selecting`: Tracks if user was actively selecting (for release detection)

### Control Constants

- `DEADZONE = 0.3`: Minimum stick magnitude to register input
- `VISIBLE_COUNT = 8`: Number of words shown in radial menu
- `RADIAL_RADIUS = 90`: Pixel radius for radial menu layout
- `Filter.REGION_COUNT = 4`: Number of nearby keys included in filter region

## Development Notes

The virtual key positions in lib/filter.lua map joystick coordinates to QWERTY keyboard layout. The coordinate system is -100 to 100, with (0,0) near the center of the keyboard (around 'g').

Both joysticks use the same full QWERTY keyboard layout, allowing any letter to be selected for either word beginnings or endings.

The region-based filtering provides a more forgiving input experience by including nearby keys, so users don't need perfect precision.

The radial selection menu in select mode is angle-aligned with stick position - pointing the right stick in a direction highlights the word in that direction on the radial menu. Only the right stick needs to be released to accept a word, allowing the left stick to remain active for continuous filtering workflow (user can select multiple words rapidly while maintaining a consistent start-letter filter).

The application expects a gamepad with standard layout:
- **X button**: Toggle between view/input modes
- **L1/R1** (view mode): Cycle through files
- **RB** (input mode): Switch between filter/select sub-modes
- **ZR/R2 trigger** (input mode): Advance pagination in select mode
- **B button**: Delete last word from sentence
- **Left/Right analog sticks** (input mode): Control keyboard filtering and selection
- **Right stick release** (input mode): Accept selected word

During development the lick.lua library will provide hot-reloading capability. So, you don't need to run `love .` to test the game because the developer will be testing it via a single hot-reloaded active session.
