local MenuLib = require("Menu")

-- Version check
assert(MenuLib.Version >= 1.35, "Wilbind: MenuLib version is too old! Current version: " .. MenuLib.Version)

-- Configuration constants
local configFolder = "wilconfigs"
local configPath = configFolder .. "/wilbind.cfg"

-- Create the menu
local menu = MenuLib.Create("Wilbind", MenuFlags.AutoSize)
print("Wilbind: Menu initialized")

-- State management
local binds = {}
local uuidCounter = 0
local globalEnableCheckbox, disableInMenuCheckbox

-- Helper functions
local function GenerateUUID()
    uuidCounter = uuidCounter + 1
    return string.format("%X-%X", os.time(), uuidCounter)
end

-- Value conversion with caching
local function ConvertValue(bind, value)
    if bind.lastValue and bind.lastValue.original == value then
        return bind.lastValue.converted
    end

    local num = tonumber(value)
    local converted
    if num then
        converted = num % 1 == 0 and math.floor(num) or num
        print(("Wilbind: Converted value '%s' to %s"):format(value, math.type(converted) or "float"))
    else
        converted = value
        print("Wilbind: Keeping value as string: "..value)
    end

    bind.lastValue = { original = value, converted = converted }
    return converted
end

-- Configuration handling
local function SaveSettings()
    -- Ensure config directory exists
    local dirCheck = io.popen("mkdir " .. configFolder)
    if dirCheck then dirCheck:close() end

    local config = {
        globalEnable = globalEnableCheckbox:IsChecked(),
        disableInMenu = disableInMenuCheckbox:IsChecked(),
        keybinds = {}
    }

    for uuid, bind in pairs(binds) do
        config.keybinds[uuid] = {
            enabled = bind.enableCheckbox:IsChecked(),
            key = bind.keybind:GetValue(),
            mode = bind.modeCombo:GetSelectedIndex(),
            optionName = bind.optionNameBox:GetValue(),
            optionValue = bind.optionValueBox:GetValue()
        }
    end

    local file = io.open(configPath, "w")
    if file then
        file:write("return {\n")
        file:write("globalEnable = "..tostring(config.globalEnable)..",\n")
        file:write("disableInMenu = "..tostring(config.disableInMenu)..",\n")
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

local function LoadSettings()
    -- Ensure config directory exists
    local dirCheck = io.popen("mkdir " .. configFolder)
    if dirCheck then dirCheck:close() end

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

    -- Clear existing components
    menu:RemoveComponent(globalEnableCheckbox)
    menu:RemoveComponent(disableInMenuCheckbox)
    for uuid, bind in pairs(binds) do
        menu:RemoveComponent(bind.enableCheckbox)
        menu:RemoveComponent(bind.keybind)
        menu:RemoveComponent(bind.modeCombo)
        menu:RemoveComponent(bind.optionNameBox)
        menu:RemoveComponent(bind.optionValueBox)
        menu:RemoveComponent(bind.removeButton)
    end
    binds = {}

    -- Create global checkboxes with loaded values
    globalEnableCheckbox = menu:AddComponent(MenuLib.Checkbox("Enable All Binds", config.globalEnable or true))
    disableInMenuCheckbox = menu:AddComponent(MenuLib.Checkbox("Disable Binds At Menu", config.disableInMenu or true))

    -- Recreate saved binds
    for uuid, bindData in pairs(config.keybinds or {}) do
        local newUUID = GenerateUUID()
        local bindContainer = {
            prevKeyState = false,
            holdOriginalValue = nil,
            toggleState = false,
            toggleOriginalValue = nil,
            lastValue = nil
        }

        -- Create components with saved values
        bindContainer.enableCheckbox = menu:AddComponent(MenuLib.Checkbox(newUUID.." Enabled", bindData.enabled))
        bindContainer.keybind = menu:AddComponent(MenuLib.Keybind(newUUID.." Key", bindData.key))
        bindContainer.modeCombo = menu:AddComponent(MenuLib.Combo(newUUID.." Mode", {"Press", "Hold", "Toggle"}))
        bindContainer.modeCombo:Select(bindData.mode)
        bindContainer.optionNameBox = menu:AddComponent(MenuLib.Textbox(newUUID.." Name", bindData.optionName))
        bindContainer.optionValueBox = menu:AddComponent(MenuLib.Textbox(newUUID.." Value", bindData.optionValue))
        
        -- Removal button
        bindContainer.removeButton = menu:AddComponent(MenuLib.Button(newUUID.." Remove", function()
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

-- Menu components
menu:AddComponent(MenuLib.Button("Save Config", SaveSettings, ItemFlags.FullWidth))
menu:AddComponent(MenuLib.Button("Load Config", LoadSettings, ItemFlags.FullWidth))

-- Add new bind button
menu:AddComponent(MenuLib.Button("Add New Bind", function()
    local newUUID = GenerateUUID()
    
    local bindContainer = {
        prevKeyState = false,
        holdOriginalValue = nil,
        toggleState = false,
        toggleOriginalValue = nil,
        lastValue = nil
    }

    -- Create components with default values
    bindContainer.enableCheckbox = menu:AddComponent(MenuLib.Checkbox(newUUID.." Enabled", true))
    bindContainer.keybind = menu:AddComponent(MenuLib.Keybind(newUUID.." Key", KEY_INSERT))
    bindContainer.modeCombo = menu:AddComponent(MenuLib.Combo(newUUID.." Mode", {"Press", "Hold", "Toggle"}))
    bindContainer.optionNameBox = menu:AddComponent(MenuLib.Textbox(newUUID.." Name", "aim bot"))
    bindContainer.optionValueBox = menu:AddComponent(MenuLib.Textbox(newUUID.." Value", "1"))
    
    -- Removal button
    bindContainer.removeButton = menu:AddComponent(MenuLib.Button(newUUID.." Remove", function()
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

-- Add global control checkboxes (positioned after Add New Bind button)
globalEnableCheckbox = menu:AddComponent(MenuLib.Checkbox("Enable All Binds", true))
disableInMenuCheckbox = menu:AddComponent(MenuLib.Checkbox("Disable Binds At Menu", true))

-- Main logic
local function OnDraw()
    -- Check global activation conditions
    local allowByGlobal = globalEnableCheckbox:IsChecked()
    local allowByMenu = not disableInMenuCheckbox:IsChecked() or not gui.IsMenuOpen()

    for uuid, bind in pairs(binds) do
        -- Check individual bind enable state
        if not bind.enableCheckbox:IsChecked() then goto continue end

        -- Check global activation rules
        if not allowByGlobal then goto continue end
        if not allowByMenu then goto continue end

        local currentKeyState = input.IsButtonDown(bind.keybind:GetValue())
        local modeIndex = bind.modeCombo:GetSelectedIndex()
        local optionName = bind.optionNameBox:GetValue()
        local optionValue = ConvertValue(bind, bind.optionValueBox:GetValue())

        if optionName == "" then goto continue end

        -- Mode handling
        if modeIndex == 1 then -- Press
            if currentKeyState then
                gui.SetValue(optionName, optionValue)
            end
        elseif modeIndex == 2 then -- Hold
            if currentKeyState and not bind.prevKeyState then
                bind.holdOriginalValue = gui.GetValue(optionName)
                gui.SetValue(optionName, optionValue)
            elseif not currentKeyState and bind.prevKeyState and bind.holdOriginalValue then
                gui.SetValue(optionName, bind.holdOriginalValue)
                bind.holdOriginalValue = nil
            end
        elseif modeIndex == 3 then -- Toggle
            if currentKeyState and not bind.prevKeyState then
                bind.toggleState = not bind.toggleState
                if bind.toggleState then
                    bind.toggleOriginalValue = gui.GetValue(optionName)
                    gui.SetValue(optionName, optionValue)
                else
                    gui.SetValue(optionName, bind.toggleOriginalValue)
                    bind.toggleOriginalValue = nil
                end
            end
        end

        bind.prevKeyState = currentKeyState
        ::continue::
    end
end

local function OnUnload()
    print("Wilbind: Unloading...")
    for _, bind in pairs(binds) do
        local optionName = bind.optionNameBox:GetValue()
        if bind.holdOriginalValue then
            gui.SetValue(optionName, bind.holdOriginalValue)
        end
        if bind.toggleOriginalValue then
            gui.SetValue(optionName, bind.toggleOriginalValue)
        end
    end
    MenuLib.RemoveMenu(menu)
    print("Wilbind: Unloaded successfully")
end

callbacks.Register("Draw", OnDraw)
callbacks.Register("Unload", OnUnload)

-- Initial config load
LoadSettings()