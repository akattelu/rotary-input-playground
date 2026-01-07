# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Laser Love is a LÖVE2D application implementing a radial steno-based input system for word selection using dual gamepad joysticks. Users filter words by phonetic clusters (onset/coda) using left/right sticks, then select from a radial menu to build sentences.
The goal is to be a playground for alternate input systems with a standard game controller.

## Running the Application

```bash
# Run the application (requires LÖVE2D installed)
love .
```

## Architecture

### Two-Mode System

1. **Filter Mode** (default): Live filtering as joysticks move
   - Left stick: Filters by word onset (beginning phonetic clusters)
   - Right stick: Filters by word coda (ending phonetic clusters)
   - Both sticks update `filtered` list in real-time via `Filter.apply()`

2. **Select Mode** (triggered by RB button):
   - Right stick: Selects from radial menu of visible candidates
   - Stick release: Accepts selection, adds word to sentence, returns to filter mode

### Core Components

- **main.lua**: Main application loop, state management, UI rendering
  - Manages `mode` state ("filter" or "select")
  - Tracks `sentence` (accumulated words) and `filtered` (current matches)
  - `get_cluster_from_stick()`: Maps stick angle to 1-8 cluster index
  - `get_radial_selection()`: Maps stick angle to radial menu position

- **filter.lua**: Phonetic clustering system
  - `onset_clusters`: 8 directional groups of word-beginning patterns (s-, t-, p/b-, c/k-, m/n-, f/v-, r/l-, d/g-)
  - `coda_clusters`: 8 directional groups of word-ending patterns (-e, -t, -s, -d, -n, -r, -ing, -l)
  - `Filter.apply(words, left_cluster, right_cluster)`: Returns words matching both onset and coda filters

- **conf.lua**: LÖVE2D configuration (window size, title, modules)

- **words.txt**: Word list loaded at startup (fallback words in code if missing)

### Key State Variables

- `mode`: Current interaction mode ("filter" or "select")
- `filtered`: Current list of words after filtering
- `selected_index`: Index into filtered list for radial selection
- `sentence`: Array of selected words
- `left_stick`/`right_stick`: Normalized joystick positions (-1 to 1)
- `was_selecting`: Tracks if user was actively selecting (for release detection)

### Control Constants

- `DEADZONE = 0.3`: Minimum stick magnitude to register input
- `VISIBLE_COUNT = 8`: Number of words shown in radial menu
- `RADIAL_RADIUS = 90`: Pixel radius for radial menu layout

## Development Notes

The phonetic cluster mappings in filter.lua are rough orthographic/phonetic groupings. When modifying clusters, maintain the 8-direction mapping to match joystick octants (45-degree segments).

The application expects a gamepad with standard Xbox-style layout (left/right analog sticks, RB button, B button).
