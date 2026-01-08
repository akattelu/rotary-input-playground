# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rotary input playground is a LÖVE2D application implementing a dual QWERTY keyboard input system for word selection using dual gamepad joysticks. Each joystick controls a full QWERTY keyboard - left stick filters by word beginnings, right stick filters by word endings. Users point joysticks at letter regions, then select from a radial menu to build sentences.
The goal is to be a playground for alternate input systems with a standard game controller.

## Running the Application

```bash
# Run the application (requires LÖVE2D installed)
love .
```

## Architecture

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

- **main.lua**: Main application loop, state management, UI rendering
  - Manages `mode` state ("filter" or "select")
  - Tracks `sentence` (accumulated words) and `filtered` (current matches)
  - `buildKeyPositions()`: Calculates screen positions for keyboard keys
  - `drawKeyboard()`: Renders full keyboard with highlighting
  - `get_radial_selection()`: Maps stick angle to radial menu position

- **filter.lua**: Letter-based filtering system with region support
  - `keyboard_virtual_positions`: Virtual coordinates for all 26 keys (used for distance calculation)
  - `Filter.get_closest_key()`: Returns single closest key to stick position
  - `Filter.get_key_region()`: Returns array of N closest keys for filtering
  - `Filter.apply(words, left_region, right_region)`: Returns words matching both start and end letter filters

- **conf.lua**: LÖVE2D configuration (window size, title, modules)

- **words.txt**: Word list loaded at startup (fallback words in code if missing)

### Key State Variables

- `mode`: Current interaction mode ("filter" or "select")
- `filtered`: Current list of words after filtering
- `selected_index`: Index into filtered list for radial selection
- `sentence`: Array of selected words
- `left_stick`/`right_stick`: Normalized joystick positions (-1 to 1)
- `left_highlighted_key`/`right_highlighted_key`: Currently highlighted key on each keyboard
- `left_region`/`right_region`: Array of keys included in current filter
- `was_selecting`: Tracks if user was actively selecting with right stick (for release detection)

### Control Constants

- `DEADZONE = 0.3`: Minimum stick magnitude to register input
- `VISIBLE_COUNT = 8`: Number of words shown in radial menu
- `RADIAL_RADIUS = 90`: Pixel radius for radial menu layout
- `Filter.REGION_COUNT = 4`: Number of nearby keys included in filter region

## Development Notes

The virtual key positions in filter.lua map joystick coordinates to QWERTY keyboard layout. The coordinate system is -100 to 100, with (0,0) near the center of the keyboard (around 'g').

Both joysticks use the same full QWERTY keyboard layout, allowing any letter to be selected for either word beginnings or endings.

The region-based filtering provides a more forgiving input experience by including nearby keys, so users don't need perfect precision.

The radial selection menu in select mode is angle-aligned with stick position - pointing the right stick in a direction highlights the word in that direction on the radial menu. Only the right stick needs to be released to accept a word, allowing the left stick to remain active for continuous filtering workflow (user can select multiple words rapidly while maintaining a consistent start-letter filter).

The application expects a gamepad with standard Xbox-style layout (left/right analog sticks, RB button, B button).
