--[[
    Wilslot - Weapon slot and class bind manager for LMAOBOX
    GitHub - (https://github.com/GNWilber/lmaobox-luas-public/wilslot/README.md)
    Author - Wilber (https://github.com/GNWilber)
    Version - 1.01 - Added pulling library from GitHub
    Required library - Menu.lib (https://github.com/GNWilber/lmaobox-luas-public/Menu.lua)
--]]

-- local MenuLib = load(http.Get("https://raw.githubusercontent.com/GNWilber/lmaobox-luas-public/refs/heads/main/Menu.lua"))()
local MenuLib = require("Menu")

-- Version check for required Menu library
assert(MenuLib.Version >= 1.52, "Wilslot: MenuLib version is too old! Current version: " .. MenuLib.Version)

-- Configuration constants (folder and file path for saving settings)
local configFolder = "wilconfigs"
local configPath = configFolder .. "/wilslot.cfg"

-- Create the main menu for the bind manager (named "Wilslot")
local menu = MenuLib.Create("Wilslot", MenuFlags.AutoSize)
menu:SetPosition(600, 0)  -- Updated menu position
print("Wilslot: Menu initialized")

-- Cosmetic customization for the menu window
menu.Style.Space    = 1
menu.Style.WindowBg = { 30, 30, 30, 240 }
menu.Style.TitleBg  = { 0, 106, 255, 240 }
menu.Style.Item     = { 60, 60, 60, 240 }
-- menu.Style.Font = draw.CreateFont("Verdana", 14, 510) -- Uncomment if desired

-- Global state
local binds = {}         -- Table keyed by bind UUID; each value is a bind container.
local bindOrder = {}     -- Array (ordered list) of bind UUIDs (to preserve the order in the menu).
local uuidCounter = 0    -- Counter for generating unique IDs.
local globalEnableCheckbox  -- Global enable checkbox (only one, not the "disable at menu" one).

--------------------------------------------------------------------------------
-- Mapping Tables for Class and Weapon Slot
--------------------------------------------------------------------------------
-- For the Class combobox:
-- Index 1: "Any" (i.e. no check), then:
-- 2: Scout (1), 3: Soldier (3), 4: Pyro (7), 5: Demoman (4),
-- 6: Heavy (6), 7: Engineer (9), 8: Medic (5), 9: Sniper (2), 10: Spy (8)
local classOptions = { "Any", "Scout", "Soldier", "Pyro", "Demoman", "Heavy", "Engineer", "Medic", "Sniper", "Spy" }
local classMap = { [1] = nil, [2] = 1, [3] = 3, [4] = 7, [5] = 4, [6] = 6, [7] = 9, [8] = 5, [9] = 2, [10] = 8 }

-- For the Weapon Slot combobox:
-- Index 1: "Any" (no check), then:
-- 2: "1" corresponds to slot 0, 3: "2" to slot 1, 4: "3" to slot 2, 5: "4" to slot 3, 6: "5" to slot 4.
local slotOptions = { "Any", "1", "2", "3", "4", "5" }
local slotMap = { [1] = nil, [2] = 0, [3] = 1, [4] = 2, [5] = 3, [6] = 4 }

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Generates a unique ID for each bind.
local function GenerateUUID()
    uuidCounter = uuidCounter + 1
    return string.format("%X-%X", os.time(), uuidCounter)
end

-- (Same as before:) Parses an "increment" command string.
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

-- Converts a given value (string or number) and caches it.
local function ConvertValue(bind, value)
    if bind.lastValue and bind.lastValue.original == value then
        return bind.lastValue.converted
    end

    local incrementData = ParseIncrement(value)
    if incrementData then
        bind.incrementData = incrementData
        bind.currentValue = incrementData.start
        local converted = incrementData.start
        bind.lastValue = { original = value, converted = converted }
        return converted
    end

    local num = tonumber(value)
    local converted
    if num then
        converted = (num % 1 == 0) and math.floor(num) or num
        print(("Wilslot: Converted value '%s' to %s"):format(value, math.type(converted) or "float"))
    else
        converted = (value ~= "" and value) or "0"
        print("Wilslot: Keeping value as string: " .. converted)
    end

    bind.incrementData = nil
    bind.lastValue = { original = value, converted = converted }
    return converted
end

-- (Optional) Increment handler (if you ever need it)
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

local function ensureConfigDirectoryExists()
    local success, fullPath = filesystem.CreateDirectory(configFolder)
    if not success then
        local attributes = filesystem.GetFileAttributes(configFolder)
        if not attributes then
            print("Wilslot: Failed to create config directory!")
            return false
        end
    end
    return true
end

local function SaveSettings()
    if not ensureConfigDirectoryExists() then return end

    local config = {
        globalEnable = globalEnableCheckbox:IsChecked(),
        keybinds = {}
    }

    for _, uuid in ipairs(bindOrder) do
        local bind = binds[uuid]
        config.keybinds[uuid] = {
            enabled    = bind.enableCheckbox:GetValue(),
            classIndex = bind.classCombo:GetSelectedIndex(),
            slotIndex  = bind.slotCombo:GetSelectedIndex(),
            optionName = bind.optionNameBox:GetValue(),
            optionValue= bind.optionValueBox:GetValue()
        }
    end

    local file = io.open(configPath, "w")
    if file then
        file:write("return {\n")
        file:write("globalEnable = " .. tostring(config.globalEnable) .. ",\n")
        file:write("keybinds = {\n")
        for uuid, b in pairs(config.keybinds) do
            file:write(string.format([[
    [%q] = {
        enabled = %s,
        classIndex = %d,
        slotIndex = %d,
        optionName = %q,
        optionValue = %q
    },]], 
            uuid, tostring(b.enabled), b.classIndex, b.slotIndex, 
            b.optionName, tostring(b.optionValue)))
        end
        file:write("\n}\n}")
        file:close()
        print("Wilslot: Config saved successfully!")
    else
        print("Wilslot: Failed to save config!")
    end
end

local function LoadSettings()
    if not ensureConfigDirectoryExists() then return end

    local file = io.open(configPath, "r")
    if not file then
        print("Wilslot: No saved config found! Using defaults.")
        return
    end

    local content = file:read("*a")
    file:close()
    
    local chunk, err = load(content)
    if not chunk then
        print("Wilslot: Config load failed:", err)
        return
    end

    local success, config = pcall(chunk)
    if not success then
        print("Wilslot: Config parse failed:", config)
        return
    end

    -- Remove existing bind components
    if globalEnableCheckbox then
        menu:RemoveComponent(globalEnableCheckbox)
    end
    for _, uuid in ipairs(bindOrder) do
        local bind = binds[uuid]
        menu:RemoveComponent(bind.enableCheckbox)
        menu:RemoveComponent(bind.classCombo)
        menu:RemoveComponent(bind.slotCombo)
        menu:RemoveComponent(bind.optionNameBox)
        menu:RemoveComponent(bind.optionValueBox)
        menu:RemoveComponent(bind.removeButton)
    end
    binds = {}
    bindOrder = {}

    -- Recreate global checkbox
    globalEnableCheckbox = menu:AddComponent(MenuLib.Checkbox("Enable All Binds", config.globalEnable))
    
    -- Recreate each saved bind in order.
    for uuid, bData in pairs(config.keybinds or {}) do
        local newUUID = GenerateUUID()
        local bindContainer = {
            holdOriginalValue = nil,  -- to store the original option value when active
            lastValue = nil,
            currentValue = nil,
            incrementData = nil,
            dynamicLabel = nil
        }
        bindContainer.enableCheckbox = menu:AddComponent(MenuLib.Checkbox(
            classOptions[bData.classIndex] .. " | " .. slotOptions[bData.slotIndex], 
            bData.enabled))
        bindContainer.dynamicLabel = classOptions[bData.classIndex] .. " | " .. slotOptions[bData.slotIndex]
        bindContainer.classCombo = menu:AddComponent(MenuLib.Combo("Class", classOptions, ItemFlags.FullWidth))
        bindContainer.classCombo:Select(bData.classIndex)
        bindContainer.slotCombo = menu:AddComponent(MenuLib.Combo("Weapon Slot", slotOptions, ItemFlags.FullWidth))
        bindContainer.slotCombo:Select(bData.slotIndex)
        bindContainer.optionNameBox = menu:AddComponent(MenuLib.Textbox("Option Name", bData.optionName))
        bindContainer.optionValueBox = menu:AddComponent(MenuLib.Textbox("Value", bData.optionValue))
        
        bindContainer.removeButton = menu:AddComponent(MenuLib.Button("Remove", function()
            menu:RemoveComponent(bindContainer.enableCheckbox)
            menu:RemoveComponent(bindContainer.classCombo)
            menu:RemoveComponent(bindContainer.slotCombo)
            menu:RemoveComponent(bindContainer.optionNameBox)
            menu:RemoveComponent(bindContainer.optionValueBox)
            menu:RemoveComponent(bindContainer.removeButton)
            for i, id in ipairs(bindOrder) do
                if id == newUUID then
                    table.remove(bindOrder, i)
                    break
                end
            end
            binds[newUUID] = nil
        end, ItemFlags.FullWidth))
        
        binds[newUUID] = bindContainer
        table.insert(bindOrder, newUUID)
    end

    print("Wilslot: Config loaded successfully!")
end

--------------------------------------------------------------------------------
-- Rebuild Binds Function
--------------------------------------------------------------------------------
-- When a bind’s combobox selections change (and thus its dynamic label would change),
-- we remove all bind components and then re‑add them in order so that the new label appears in the proper place.
local function RebuildBinds()
    for _, uuid in ipairs(bindOrder) do
        local bind = binds[uuid]
        -- Store current state from the old components before removal.
        local oldCheckboxValue = bind.enableCheckbox:GetValue()
        local oldClassIndex = bind.classCombo:GetSelectedIndex()
        local oldSlotIndex = bind.slotCombo:GetSelectedIndex()
        local oldOptionName = bind.optionNameBox:GetValue()
        local oldOptionValue = bind.optionValueBox:GetValue()
        -- Remove the old components.
        menu:RemoveComponent(bind.enableCheckbox)
        menu:RemoveComponent(bind.classCombo)
        menu:RemoveComponent(bind.slotCombo)
        menu:RemoveComponent(bind.optionNameBox)
        menu:RemoveComponent(bind.optionValueBox)
        menu:RemoveComponent(bind.removeButton)
        -- Compute the new dynamic label.
        local newLabel = (classOptions[oldClassIndex] or "Any") .. " | " .. (slotOptions[oldSlotIndex] or "Any")
        bind.dynamicLabel = newLabel
        -- Recreate the components in the same order.
        bind.enableCheckbox = menu:AddComponent(MenuLib.Checkbox(newLabel, oldCheckboxValue))
        bind.classCombo = menu:AddComponent(MenuLib.Combo("Class", classOptions, ItemFlags.FullWidth))
        bind.classCombo:Select(oldClassIndex)
        bind.slotCombo = menu:AddComponent(MenuLib.Combo("Weapon Slot", slotOptions, ItemFlags.FullWidth))
        bind.slotCombo:Select(oldSlotIndex)
        bind.optionNameBox = menu:AddComponent(MenuLib.Textbox("Option Name", oldOptionName))
        bind.optionValueBox = menu:AddComponent(MenuLib.Textbox("Value", oldOptionValue))
        bind.removeButton = menu:AddComponent(MenuLib.Button("Remove", function()
            menu:RemoveComponent(bind.enableCheckbox)
            menu:RemoveComponent(bind.classCombo)
            menu:RemoveComponent(bind.slotCombo)
            menu:RemoveComponent(bind.optionNameBox)
            menu:RemoveComponent(bind.optionValueBox)
            menu:RemoveComponent(bind.removeButton)
            for i, id in ipairs(bindOrder) do
                if id == uuid then
                    table.remove(bindOrder, i)
                    break
                end
            end
            binds[uuid] = nil
        end, ItemFlags.FullWidth))
    end
end

--------------------------------------------------------------------------------
-- Menu Component Setup
--------------------------------------------------------------------------------

-- Button to save configuration.
menu:AddComponent(MenuLib.Button("Save Config", SaveSettings, ItemFlags.FullWidth))
-- Button to load configuration.
menu:AddComponent(MenuLib.Button("Load Config", LoadSettings, ItemFlags.FullWidth))
-- Button to add a new bind.
menu:AddComponent(MenuLib.Button("Add New Bind", function()
    local newUUID = GenerateUUID()
    
    local bindContainer = {
        holdOriginalValue = nil,
        lastValue = nil,
        currentValue = nil,
        incrementData = nil,
        dynamicLabel = "Any | Any"  -- default label (both comboboxes start with "Any")
    }
    bindContainer.enableCheckbox = menu:AddComponent(MenuLib.Checkbox("Any | Any", true))
    bindContainer.classCombo = menu:AddComponent(MenuLib.Combo("Class", classOptions, ItemFlags.FullWidth))
    bindContainer.slotCombo = menu:AddComponent(MenuLib.Combo("Weapon Slot", slotOptions, ItemFlags.FullWidth))
    bindContainer.optionNameBox = menu:AddComponent(MenuLib.Textbox("Option Name", ""))
    bindContainer.optionValueBox = menu:AddComponent(MenuLib.Textbox("Value", ""))
    bindContainer.removeButton = menu:AddComponent(MenuLib.Button("Remove", function()
        menu:RemoveComponent(bindContainer.enableCheckbox)
        menu:RemoveComponent(bindContainer.classCombo)
        menu:RemoveComponent(bindContainer.slotCombo)
        menu:RemoveComponent(bindContainer.optionNameBox)
        menu:RemoveComponent(bindContainer.optionValueBox)
        menu:RemoveComponent(bindContainer.removeButton)
        for i, id in ipairs(bindOrder) do
            if id == newUUID then
                table.remove(bindOrder, i)
                break
            end
        end
        binds[newUUID] = nil
    end, ItemFlags.FullWidth))
    
    binds[newUUID] = bindContainer
    table.insert(bindOrder, newUUID)
end, ItemFlags.FullWidth))

-- Global control checkbox.
globalEnableCheckbox = menu:AddComponent(MenuLib.Checkbox("Enable All Binds", true))

--------------------------------------------------------------------------------
-- Main Logic and Callbacks
--------------------------------------------------------------------------------

local function OnDraw()
    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return end

    -- Get current player class (from m_iClass)
    local currentClass = localPlayer:GetPropInt("m_iClass")
    -- Get current weapon slot from active weapon (if available)
    local activeWeapon = localPlayer:GetPropEntity("m_hActiveWeapon")
    local currentSlot = activeWeapon and activeWeapon:GetLoadoutSlot() or nil

    local allowByGlobal = globalEnableCheckbox:IsChecked()

    -- Check whether any bind’s dynamic label is out of date.
    local rebuildNeeded = false
    for _, uuid in ipairs(bindOrder) do
        local bind = binds[uuid]
        local compLabel = (classOptions[bind.classCombo:GetSelectedIndex()] or "Any") .. " | " .. (slotOptions[bind.slotCombo:GetSelectedIndex()] or "Any")
        if bind.dynamicLabel ~= compLabel then
            rebuildNeeded = true
            break
        end
    end
    if rebuildNeeded then
        RebuildBinds()
    end

    -- Process each bind.
    for _, uuid in ipairs(bindOrder) do
        local bind = binds[uuid]
        local optionName = bind.optionNameBox:GetValue()
        if optionName == "" then goto continue end

        -- If global enable is off, restore any active bind.
        if not allowByGlobal then
            if bind.holdOriginalValue then
                gui.SetValue(optionName, bind.holdOriginalValue)
                bind.holdOriginalValue = nil
            end
            goto continue
        end

        -- Get target values from the comboboxes.
        local classIndex = bind.classCombo:GetSelectedIndex()
        local slotIndex = bind.slotCombo:GetSelectedIndex()
        local targetClass = classMap[classIndex]   -- nil means "Any"
        local targetSlot = slotMap[slotIndex]        -- nil means "Any"

        local conditionMet = true
        if targetClass and targetClass ~= currentClass then
            conditionMet = false
        end
        if targetSlot ~= nil then
            if currentSlot == nil or targetSlot ~= currentSlot then
                conditionMet = false
            end
        end

        -- If conditions are met and not yet active, store original and apply new value.
        if conditionMet then
            if not bind.holdOriginalValue then
                bind.holdOriginalValue = gui.GetValue(optionName)
                local finalValue = ConvertValue(bind, bind.optionValueBox:GetValue())
                gui.SetValue(optionName, finalValue)
            end
        else
            if bind.holdOriginalValue then
                gui.SetValue(optionName, bind.holdOriginalValue)
                bind.holdOriginalValue = nil
            end
        end
        ::continue::
    end
end

local function OnUnload()
    print("Wilslot: Unloading...")
    for _, uuid in ipairs(bindOrder) do
        local bind = binds[uuid]
        local optionName = bind.optionNameBox:GetValue()
        if bind.holdOriginalValue then
            gui.SetValue(optionName, bind.holdOriginalValue)
        end
    end
    MenuLib.RemoveMenu(menu)
    print("Wilslot: Unloaded successfully")
end

callbacks.Register("Draw", OnDraw)
callbacks.Register("Unload", OnUnload)

-- Load saved configuration on startup.
LoadSettings()