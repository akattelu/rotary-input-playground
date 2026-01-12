# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rotary input playground is a LÖVE2D application implementing a dual QWERTY keyboard input system for word selection using dual gamepad joysticks. Each joystick controls a full QWERTY keyboard - left stick filters by word beginnings, right stick filters by word endings. Users point joysticks at letter regions, then select from a radial menu to build sentences.

The app starts with a blank screen. Press X (Nintendo Y/PlayStation Square) to summon the input menu on the right half of the screen. The goal is to be a playground for alternate input systems with a standard game controller.

## Running the Application

```bash
# Run the application (requires LÖVE2D installed)
love .
```

## Architecture

### Code Organization

This project follows a **component-driven development pattern**:

- **`ui/`**: Self-contained UI components
  - `ui/input_menu.lua` - Groups selection wheel and both keyboard dials, manages filtering/selection modes
  - `ui/dial.lua` - Individual keyboard dial with stick visualizer
  - `ui/selection_wheel.lua` - Radial word selection menu
- **`lib/`**: Helper functions, utilities, and classes (e.g., `lib/filter.lua` - filtering logic, `lib/corpus.lua` - word loading)
- **`main.lua`**: Minimal orchestration - manages sentence state and input menu visibility

When adding features:
- Extract reusable UI elements into `ui/` components with their own state and rendering
- Move shared logic and utilities into `lib/` modules
- Keep `main.lua` focused on high-level coordination

### Two-Mode System

1. **Filter Mode** (default): Live filtering as joysticks move
   - Left stick: Points to full QWERTY keyboard to filter word beginnings
   - Right stick: Points to full QWERTY keyboard to filter word endings
   - Region-based filtering: includes 4 closest keys to stick position
   - Both sticks update `filtered` list in real-time via `Filter.apply()`

2. **Select Mode** (triggered by RB button):
   - Right stick: Selects from radial menu of visible candidates (angle-aligned with visual positions)
   - Right stick release: Accepts selection, adds word to sentence, returns to filter mode
   - Left stick: Can remain active to maintain start-letter filtering for the next word

### Core Components

- **main.lua**: Minimal application orchestration
  - Tracks `sentence` (accumulated words) and `input_menu_visible` toggle
  - Handles X button to toggle input menu visibility
  - Handles B button to delete last word from sentence
  - Delegates all input/filtering logic to `input_menu` component

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
- `sentence`: Array of selected words (global app state)
- `input_menu_visible`: Boolean controlling menu visibility
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
- **X/Square/Y button** (left face): Toggle input menu visibility
- **RB button** (right shoulder): Switch between filter/select modes
- **ZR/R2 trigger**: Advance pagination in select mode
- **B button**: Delete last word from sentence
- **Left/Right analog sticks**: Control keyboard filtering and selection
- **Right stick release**: Accept selected word in select mode
