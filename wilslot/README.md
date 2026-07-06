# WilSlot
Amalgam has a feature to bind options directly to selected weapon slots or classes. This script ports this capability to LMAOBOX, allowing you to configure different setups for distinct classes and loadouts (e.g., soldier rocket launcher vs. shotgun).

![screen1](https://i.imgur.com/sPvMCdz.png)

## Features
- **Config Saving System** (Saved in `wilconfigs/wilslot.cfg`).
- **Remember Menu Position**: Drag positions are saved dynamically to configuration.
- **Multi-Column Layout**: Slider lets you specify binds per column to keep the interface compact.
- **Anti-Out-of-Bounds**: Clamps menu drag safely to your screen area.
- **Global Toggle**: Enable/disable all loadout slot conditions globally.
- **Class & Slot Matching**: Bind values to specific classes, active weapon loadout slots, or both.
- **Multiple Options Support (`&&`)**: Execute multiple commands simultaneously under a single condition.

## Requirements
- [wilgui.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilgui/wilgui.lua)
    - An optimized, auto-updating fork of LNX's Menu library that adds multi-column support, limits drag borders, and prevents overlap crashes.

## How to use
- Place [wilslot.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilslot/wilslot.lua) & [wilgui.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilgui/wilgui.lua) in your `%LOCALAPPDATA%` (or game's lua directory).
- Refresh and load **wilslot** in LMAOBOX.
- Add a bind and select the conditional filters (e.g. Class, Slot) to apply the variable.
    - *Example*: `Scout > 2 > aim method > silent` (while playing Scout and holding your secondary weapon, aim method changes to silent).

## PS
- Check out [WilBind](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilbind/README.md) for custom key input binds.
- Keep the game console open when typing option names to prevent typing from triggering default binds.
- Code is heavily commented. Bug reports can be submitted [here](https://github.com/GNWilber/lmaobox-luas-public/issues).

### Special thanks to
- [LNX](https://github.com/lnx00/) — Original menu base design
- **AI** — Assistance with logic, safety features, and layout structure