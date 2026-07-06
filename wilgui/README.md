# WilGUI
An optimized, independent graphical user interface framework designed specifically for LMAOBOX Lua scripts. Forked and heavily upgraded from [LNX's](https://github.com/lnx00/) `Menu.lua`, it acts as a standalone library that can be shared across multiple active scripts without collision.

## 🌟 Key Upgrades & Features
- **Dynamic Multi-Column Layout**: Built-in support for column breaks (`wilgui.ColumnBreak()`) that wrap elements horizontally to keep highly customizable scripts readable.
- **Screen Boundary Clamping**: Window coordinates are restricted in real-time. Dragging a menu is bounded to prevent windows from being lost off-screen (protects top, left, right, and bottom borders).
- **Auto-Updating Engine**: Automatically checks for updates and overrides local files securely. Update calls are safely sandboxed in `pcall` structures to prevent script crashes in case of network rate-limiting.
- **Safe Hot-Reloading & Garbage Collection**: Exposes `wilgui.RemoveMenu(menu)` and clean lookup iterators, enabling scripts to properly erase their windows when unloaded. Prevents visual script "ghosting" when modifying your code in-game.

## 📦 Supported Components
- **Labels** (`wilgui.Label`) — Custom text boxes.
- **Checkboxes** (`wilgui.Checkbox`) — Boolean toggles.
- **Buttons** (`wilgui.Button`) — Triggers custom Lua callback functions.
- **Sliders** (`wilgui.Slider`) — Number adjustments.
- **Textboxes** (`wilgui.Textbox`) — Input fields that capture custom keyboard characters (including parenthesis, special characters, and uppercase modifier keys).
- **Keybinds** (`wilgui.Keybind`) — Custom key capture fields.
- **Dropdown Combos** (`wilgui.Combo`) — Collapsible pop-up list selectors.

## 💻 Developer Integration Example
Using `wilgui.lua` in your own plugins is simple. Because it is a shared library, multiple scripts can import it concurrently. Each script should clean up its own window upon loading and unloading.

```lua
local success, wilgui = pcall(require, "wilgui")
if not success then
    print("wilgui.lua is missing! Ensure it is in your lua folder.")
    return
end

-- 1. Scan and remove any old instance of this menu on script reload
for i = #wilgui.Menus, 1, -1 do
    if wilgui.Menus[i].Title == "My Menu Title" then
        table.remove(wilgui.Menus, i)
    end
end

-- 2. Create the window
local myMenu = wilgui.Create("My Menu Title", wilgui.MenuFlags.AutoSize)
myMenu:SetPosition(100, 100)

-- 3. Add components
local myCheckbox = myMenu:AddComponent(wilgui.Checkbox("Toggle Feature", true))
local mySlider   = myMenu:AddComponent(wilgui.Slider("Sensitivity", 1, 10, 5))

-- 4. Clean up dynamically if the script unloads
callbacks.Register("Unload", "cleanup_mymenu", function()
    if success and wilgui and myMenu then
        wilgui.RemoveMenu(myMenu)
    end
end)