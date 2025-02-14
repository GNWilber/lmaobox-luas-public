--[[
    Wilbind - Keybinds manager for LMAOBOX
    GitHub - https://github.com/GNWilber/lmaobox-luas-public/wilbind/README.md
    Author - Wilber (https://github.com/GNWilber)
    Version - 1.01 - Added pulling library from GitHub
    Required library - Menu.lib (https://github.com/GNWilber/lmaobox-luas-public/Menu.lua)
--]]

-- local MenuLib = load(http.Get("https://raw.githubusercontent.com/GNWilber/lmaobox-luas-public/refs/heads/main/Menu.lua"))()
local MenuLib = require("Menu")

-- Version check for required Menu library
assert(MenuLib.Version >= 1.52, "Wilbind: MenuLib version is too old! Current version: " .. MenuLib.Version)

-- Configuration constants (folder and file path for saving settings)
local configFolder = "wilconfigs"
local configPath = configFolder .. "/wilbind.cfg"

-- Create the main menu for the bind manager
local menu = MenuLib.Create("Wilbind", MenuFlags.AutoSize)
print("Wilbind: Menu initialized")

-- Cosmetic customization for the menu window
menu:SetPosition(400, 0)
menu.Style.Space    = 1
menu.Style.WindowBg = { 30, 30, 30, 240 }
menu.Style.TitleBg  = { 0, 106, 255, 240 }
menu.Style.Item     = { 60, 60, 60, 240 }
-- menu.Style.Font = draw.CreateFont("Verdana", 14, 510) -- Uncomment and adjust if you want to change the font

-- State management variables
local binds = {}         -- Table holding all bind configurations
local uuidCounter = 0    -- Counter for generating unique IDs
local globalEnableCheckbox, disableInMenuCheckbox  -- Global control checkboxes

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Generates a unique ID for each bind based on the current time and an incrementing counter.
local function GenerateUUID()
    uuidCounter = uuidCounter + 1
    return string.format("%X-%X", os.time(), uuidCounter)
end

-- Parses a string command for incrementing values.
-- Example input: "increment 1 10 1" returns a table with start=1, finish=10, step=1.
local function ParseIncrement(value)
    if type(value) ~= "string" then return nil end
    local start, finish, step = value:match("^increment%s+(%d+)%s+(%d+)%s+(%d+)$")
    if start and finish and step then
        return {
            start = tonumber(start),
            finish = tonumber(finish),
            step = tonumber(step)
        }
    end
    return nil
end

-- Converts the given value (string or number) for a bind.
-- Uses caching so if the value hasn't changed, it returns the previously converted value.
-- Also handles the special "increment" command.
local function ConvertValue(bind, value)
    if bind.lastValue and bind.lastValue.original == value then
        return bind.lastValue.converted
    end

    -- Check for the "increment" command
    local incrementData = ParseIncrement(value)
    if incrementData then
        bind.incrementData = incrementData
        bind.currentValue = incrementData.start
        local converted = incrementData.start
        bind.lastValue = { original = value, converted = converted }
        return converted
    end

    -- Convert value normally (attempt to convert to a number)
    local num = tonumber(value)
    local converted
    if num then
        converted = num % 1 == 0 and math.floor(num) or num
        print(("Wilbind: Converted value '%s' to %s"):format(value, math.type(converted) or "float"))
    else
        converted = (value ~= "" and value) or "0"
        print("Wilbind: Keeping value as string: " .. converted)
    end

    bind.incrementData = nil
    bind.lastValue = { original = value, converted = converted }
    return converted
end

-- Handles the increment logic: increases the current value by step and resets when exceeding the finish value.
local function HandleIncrement(bind)
    if not bind.incrementData then return bind.currentValue end

    bind.currentValue = bind.currentValue + bind.incrementData.step
    if bind.currentValue > bind.incrementData.finish then
        bind.currentValue = bind.incrementData.start
    end
    return bind.currentValue
end

--------------------------------------------------------------------------------
-- Filesystem & Configuration Handling
--------------------------------------------------------------------------------

-- Utility function: Ensures the config folder exists.
-- It attempts to create the directory, and if that fails, checks if it already exists.
local function ensureConfigDirectoryExists()
    local success, fullPath = filesystem.CreateDirectory(configFolder)
    if not success then
        -- It might fail because the directory already exists.
        local attributes = filesystem.GetFileAttributes(configFolder)
        if not attributes then
            print("Wilbind: Failed to create config directory!")
            return false
        end
    end
    return true
end

-- Saves the current bind configuration to a file.
local function SaveSettings()
    if not ensureConfigDirectoryExists() then
        return
    end

    local config = {
        globalEnable = globalEnableCheckbox:IsChecked(),
        disableInMenu = disableInMenuCheckbox:IsChecked(),
        keybinds = {}
    }

    -- Collect settings for each bind.
    for uuid, bind in pairs(binds) do
        config.keybinds[uuid] = {
            enabled    = bind.enableCheckbox:IsChecked(),
            key        = bind.keybind:GetValue(),
            mode       = bind.modeCombo:GetSelectedIndex(),
            optionName = bind.optionNameBox:GetValue(),
            optionValue= bind.optionValueBox:GetValue()
        }
    end

    -- Open the configuration file for writing.
    local file = io.open(configPath, "w")
    if file then
        file:write("return {\n")
        file:write("globalEnable = " .. tostring(config.globalEnable) .. ",\n")
        file:write("disableInMenu = " .. tostring(config.disableInMenu) .. ",\n")
        file:write("keybinds = {\n")
        for uuid, bind in pairs(config.keybinds) do
            file:write(string.format([[
    [%q] = {
        enabled = %s,
        key = %d,
        mode = %d,
        optionName = %q,
        optionValue = %q
    },]], 
            uuid, tostring(bind.enabled), bind.key, bind.mode, 
            bind.optionName, tostring(bind.optionValue)))
        end
        file:write("\n}\n}")
        file:close()
        print("Wilbind: Config saved successfully!")
    else
        print("Wilbind: Failed to save config!")
    end
end

-- Loads the bind configuration from a file.
local function LoadSettings()
    if not ensureConfigDirectoryExists() then
        return
    end

    local file = io.open(configPath, "r")
    if not file then
        print("Wilbind: No saved config found! Using defaults.")
        return
    end

    local content = file:read("*a")
    file:close()
    
    local chunk, err = load(content)
    if not chunk then
        print("Wilbind: Config load failed:", err)
        return
    end

    local success, config = pcall(chunk)
    if not success then
        print("Wilbind: Config parse failed:", config)
        return
    end

    -- Remove any existing components from the menu.
    if globalEnableCheckbox then menu:RemoveComponent(globalEnableCheckbox) end
    if disableInMenuCheckbox then menu:RemoveComponent(disableInMenuCheckbox) end
    for uuid, bind in pairs(binds) do
        menu:RemoveComponent(bind.enableCheckbox)
        menu:RemoveComponent(bind.keybind)
        menu:RemoveComponent(bind.modeCombo)
        menu:RemoveComponent(bind.optionNameBox)
        menu:RemoveComponent(bind.optionValueBox)
        menu:RemoveComponent(bind.removeButton)
    end
    binds = {}

    -- Recreate global checkboxes with loaded values.
    globalEnableCheckbox = menu:AddComponent(MenuLib.Checkbox("Enable All Binds", config.globalEnable))
    disableInMenuCheckbox = menu:AddComponent(MenuLib.Checkbox("Disable Binds At Menu", config.disableInMenu))

    -- Recreate each saved bind.
    for uuid, bindData in pairs(config.keybinds or {}) do
        local newUUID = GenerateUUID()
        local bindContainer = {
            prevKeyState      = false,
            holdOriginalValue = nil,
            toggleState       = false,
            toggleOriginalValue = nil,
            lastValue         = nil,
            currentValue      = nil,
            incrementData     = nil
        }

        bindContainer.enableCheckbox = menu:AddComponent(MenuLib.Checkbox("Enabled", bindData.enabled))
        bindContainer.keybind = menu:AddComponent(MenuLib.Keybind("Key", bindData.key, ItemFlags.FullWidth))
        bindContainer.modeCombo = menu:AddComponent(MenuLib.Combo("Mode", {"Press", "Hold", "Toggle"}, ItemFlags.FullWidth))
        bindContainer.modeCombo:Select(bindData.mode)
        bindContainer.optionNameBox = menu:AddComponent(MenuLib.Textbox("Option Name", bindData.optionName))
        bindContainer.optionValueBox = menu:AddComponent(MenuLib.Textbox("Value", bindData.optionValue))
        
        -- Removal button for this bind.
        bindContainer.removeButton = menu:AddComponent(MenuLib.Button("Remove", function()
            menu:RemoveComponent(bindContainer.enableCheckbox)
            menu:RemoveComponent(bindContainer.keybind)
            menu:RemoveComponent(bindContainer.modeCombo)
            menu:RemoveComponent(bindContainer.optionNameBox)
            menu:RemoveComponent(bindContainer.optionValueBox)
            menu:RemoveComponent(bindContainer.removeButton)
            binds[newUUID] = nil
        end, ItemFlags.FullWidth))

        binds[newUUID] = bindContainer
    end

    print("Wilbind: Config loaded successfully!")
end

--------------------------------------------------------------------------------
-- Menu Component Setup
--------------------------------------------------------------------------------

-- Buttons to save and load the configuration.
menu:AddComponent(MenuLib.Button("Save Config", SaveSettings, ItemFlags.FullWidth))
menu:AddComponent(MenuLib.Button("Load Config", LoadSettings, ItemFlags.FullWidth))

-- Button to add a new bind.
menu:AddComponent(MenuLib.Button("Add New Bind", function()
    local newUUID = GenerateUUID()
    
    local bindContainer = {
        prevKeyState      = false,
        holdOriginalValue = nil,
        toggleState       = false,
        toggleOriginalValue = nil,
        lastValue         = nil,
        currentValue      = nil,
        incrementData     = nil
    }

    -- Create components with default values.
    bindContainer.enableCheckbox = menu:AddComponent(MenuLib.Checkbox("Enabled", true))
    bindContainer.keybind = menu:AddComponent(MenuLib.Keybind("Key", KEY_INSERT, ItemFlags.FullWidth))
    bindContainer.modeCombo = menu:AddComponent(MenuLib.Combo("Mode", {"Press", "Hold", "Toggle"}, ItemFlags.FullWidth))
    bindContainer.optionNameBox = menu:AddComponent(MenuLib.Textbox("Name", ""))
    bindContainer.optionValueBox = menu:AddComponent(MenuLib.Textbox("Value", ""))
    
    -- Removal button for this new bind.
    bindContainer.removeButton = menu:AddComponent(MenuLib.Button("Remove", function()
        menu:RemoveComponent(bindContainer.enableCheckbox)
        menu:RemoveComponent(bindContainer.keybind)
        menu:RemoveComponent(bindContainer.modeCombo)
        menu:RemoveComponent(bindContainer.optionNameBox)
        menu:RemoveComponent(bindContainer.optionValueBox)
        menu:RemoveComponent(bindContainer.removeButton)
        binds[newUUID] = nil
    end, ItemFlags.FullWidth))

    binds[newUUID] = bindContainer
end, ItemFlags.FullWidth))

-- Global control checkboxes (positioned after the "Add New Bind" button).
globalEnableCheckbox = menu:AddComponent(MenuLib.Checkbox("Enable All Binds", true))
disableInMenuCheckbox = menu:AddComponent(MenuLib.Checkbox("Disable Binds At Menu", true))

--------------------------------------------------------------------------------
-- Main Logic and Callbacks
--------------------------------------------------------------------------------

-- The Draw callback is executed every frame.
-- It checks global and individual bind conditions and applies the bind actions.
local function OnDraw()
    -- Determine if binds are allowed based on the global checkboxes and whether the menu is open.
    local allowByGlobal = globalEnableCheckbox:IsChecked()
    local allowByMenu = not disableInMenuCheckbox:IsChecked() or not gui.IsMenuOpen()

    for uuid, bind in pairs(binds) do
        -- Skip if this bind is disabled.
        if not bind.enableCheckbox:IsChecked() then goto continue end
        if not allowByGlobal then goto continue end
        if not allowByMenu then goto continue end

        local currentKey = bind.keybind:GetValue()
        local currentKeyState = input.IsButtonDown(currentKey)
        local modeIndex = bind.modeCombo:GetSelectedIndex()
        local optionName = bind.optionNameBox:GetValue()
        local optionValue = ConvertValue(bind, bind.optionValueBox:GetValue())

        -- Skip if no option name is provided.
        if optionName == "" then goto continue end

        -- Process bind according to its mode:
        if modeIndex == 1 then  -- Press mode: Trigger on key press (transition from off to on)
            if currentKeyState and not bind.prevKeyState then
                local finalValue = bind.incrementData and HandleIncrement(bind) or optionValue
                gui.SetValue(optionName, finalValue)
                client.ChatPrintf(optionName..": "..gui.GetValue(optionName))
            end
        elseif modeIndex == 2 then  -- Hold mode: Set value while key is held; restore when released
            if currentKeyState and not bind.prevKeyState then
                bind.holdOriginalValue = gui.GetValue(optionName)
                local finalValue = bind.incrementData and HandleIncrement(bind) or optionValue
                gui.SetValue(optionName, finalValue)
                client.ChatPrintf(optionName..": "..gui.GetValue(optionName))
            elseif not currentKeyState and bind.prevKeyState and bind.holdOriginalValue then
                gui.SetValue(optionName, bind.holdOriginalValue)
                client.ChatPrintf(optionName..": "..gui.GetValue(optionName))
                bind.holdOriginalValue = nil
            end
        elseif modeIndex == 3 then  -- Toggle mode: Switch between two states on key press
            if currentKeyState and not bind.prevKeyState then
                bind.toggleState = not bind.toggleState
                if bind.toggleState then
                    bind.toggleOriginalValue = gui.GetValue(optionName)
                    local finalValue = bind.incrementData and HandleIncrement(bind) or optionValue
                    gui.SetValue(optionName, finalValue)
                    client.ChatPrintf(optionName..": "..gui.GetValue(optionName))
                else
                    gui.SetValue(optionName, bind.toggleOriginalValue)
                    client.ChatPrintf(optionName..": "..gui.GetValue(optionName))
                    bind.toggleOriginalValue = nil
                end
            end
        end

        bind.prevKeyState = currentKeyState
        ::continue::
    end
end

-- OnUnload callback to clean up when the script is unloaded.
local function OnUnload()
    print("Wilbind: Unloading...")
    -- Restore original values for binds that are in a hold or toggle state.
    for _, bind in pairs(binds) do
        local optionName = bind.optionNameBox:GetValue()
        if bind.holdOriginalValue then
            gui.SetValue(optionName, bind.holdOriginalValue)
            client.ChatPrintf(optionName..": "..gui.GetValue(optionName))
        end
        if bind.toggleOriginalValue then
            gui.SetValue(optionName, bind.toggleOriginalValue)
            client.ChatPrintf(optionName..": "..gui.GetValue(optionName))
        end
    end
    MenuLib.RemoveMenu(menu)
    print("Wilbind: Unloaded successfully")
end

-- Register the Draw and Unload callbacks.
callbacks.Register("Draw", OnDraw)
callbacks.Register("Unload", OnUnload)

-- Attempt to load saved configuration on startup.
LoadSettings()