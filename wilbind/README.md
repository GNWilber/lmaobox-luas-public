# Wilbind
LMAOBOX doesn't have a native bind manager, meaning only a limited set of options are bindable by default.
This script allows you to bind **ANYTHING** in LMAOBOX to your key controls.

![screen1](https://i.imgur.com/5kQAqP6.png)

## Features
- **Config Saving System** (Saved in `wilconfigs/wilbind.cfg`).
- **Remember Menu Position**: Keeps track of where you dragged your settings window and auto-saves it when you release your mouse drag.
- **Multi-Column Formatting**: Includes a slider to define how many binds display per column, preventing the menu from stretching off-screen when managing multiple binds.
- **Clamped Window Boundaries**: The menu cannot be dragged off-screen (restricts at top and left edges).
- **Different Bind Modes**:
    - **Press**: Changes a value once when pressed.
    - **Hold**: Temporarily alters a value, reverting back to the original when released.
    - **Toggle**: Switches back and forth between states with each keypress.
- **Value Increments**: Supports sequence toggling with `increment [start] [end] [step]`.
    - *Aim method switching example*:
        - Option Name: `aim method`
        - Value: `increment 1 5 1`
- **Multiple Options Support (`&&`)**: Bind multiple commands together in the "Option Name" field (e.g., `aim method && aim enable`). Works with all modes and increments.

## Requirements
- [wilgui.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilgui/wilgui.lua)
    - This is an optimized, auto-updating fork of LNX's Menu library. It clamps window drag borders, adds multi-column wrapping, and prevents interface crashes.

## How to use
- Place [wilbind.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilbind/wilbind.lua) & [wilgui.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilgui/wilgui.lua) into your `%LOCALAPPDATA%` (or game's lua directory).
- Refresh and load **wilbind** in LMAOBOX.
- Add a bind, select the key/mode, and type the LMAOBOX "Option Name" and target "Value".
    - *Example*: `H > Toggle > aim bot > 1` (toggles aimbot on and off with `H`).

## PS
- Please check out [WilSlot](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilslot/README.md), my class/slot bind manager.
- It's recommended to open the game console when typing option names, as standard key inputs can still trigger default actions.
- Code is heavily commented for customization. Report issues [here](https://github.com/GNWilber/lmaobox-luas-public/issues).

### Special thanks to
- [LNX](https://github.com/lnx00/) — Original menu base design
- **AI** — Assistance with optimization, documentation, and logic