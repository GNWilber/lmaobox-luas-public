--[[
    Wilbind - Keybinds manager for LMAOBOX
    GitHub - https://github.com/GNWilber/lmaobox-luas-public/main/wilbind
    Author - Wilber (https://github.com/GNWilber)
    Version - 1.31
--]]

local Version = 1.31
local RepoURL = "https://raw.githubusercontent.com/GNWilber/lmaobox-luas-public/main/wilbind/wilbind.lua"

pcall(function()
    local content = http.Get(RepoURL)
    if not content or content == "" then return end
    local remoteVerStr = string.match(content, "Version%s*-%s*([%d%.]+)")
    if not remoteVerStr then return end
    local remoteVer = tonumber(remoteVerStr)
    if remoteVer and remoteVer > Version then
        print("[Wilbind] Found newer version (" .. remoteVer .. "). Updating...")
        local f = io.open("wilbind.lua", "w")
        if f then
            f:write(content)
            f:close()
            print("[Wilbind] Successfully updated! Please reload your lua script.")
        end
    end
end)

local success, wilgui = pcall(require, "wilgui")
if not success then
    print("[Wilbind ERROR] wilgui.lua is missing or corrupted! Error: " .. tostring(wilgui))
    return
end

local configFolder = "wilconfigs"
local configPath = configFolder .. "/wilbind.cfg"

-- Remove ONLY Wilbind's menu on script reload, protecting wilcrit's menu
for i = #wilgui.Menus, 1, -1 do
    if wilgui.Menus[i].Title == "Wilbind" then
        table.remove(wilgui.Menus, i)
    end
end

local menu = wilgui.Create("Wilbind", wilgui.MenuFlags.AutoSize)
print("Wilbind: Menu initialized")

menu:SetPosition(400, 100)
menu.Style.Space    = 1
menu.Style.WindowBg = { 30, 30, 30, 240 }
menu.Style.TitleBg  = { 0, 106, 255, 240 }
menu.Style.Item     = { 60, 60, 60, 240 }

local binds = {}         
local uuidCounter = 0    
local globalEnableCheckbox, disableInMenuCheckbox  

local function GenerateUUID()
    uuidCounter = uuidCounter + 1
    return string.format("%X-%X", os.time(), uuidCounter)
end

local function ParseIncrement(value)
    if type(value) ~= "string" then return nil end
    local start, finish, step = value:match("^increment%s+(%d+)%s+(%d+)%s+(%d+)$")
    if start and finish and step then
        return { start = tonumber(start), finish = tonumber(finish), step = tonumber(step) }
    end
    return nil
end

local function SplitOptionNames(str)
    local names = {}
    for chunk in string.gmatch(str, "([^&]+)") do
        local name = chunk:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then table.insert(names, name) end
    end
    return names
end

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
        converted = num % 1 == 0 and math.floor(num) or num
    else
        converted = (value ~= "" and value) or "0"
    end

    bind.incrementData = nil
    bind.lastValue = { original = value, converted = converted }
    return converted
end

local function HandleIncrement(bind)
    if not bind.incrementData then return bind.currentValue end

    bind.currentValue = bind.currentValue + bind.incrementData.step
    if bind.currentValue > bind.incrementData.finish then
        bind.currentValue = bind.incrementData.start
    end
    return bind.currentValue
end

local function ensureConfigDirectoryExists()
    local success, _ = filesystem.CreateDirectory(configFolder)
    if not success then
        local attributes = filesystem.GetFileAttributes(configFolder)
        if not attributes then return false end
    end
    return true
end

local function SaveSettings()
    if not ensureConfigDirectoryExists() then return end

    local config = {
        globalEnable = globalEnableCheckbox:IsChecked(),
        disableInMenu = disableInMenuCheckbox:IsChecked(),
        menuX = menu.X,
        menuY = menu.Y,
        keybinds = {}
    }

    for uuid, bind in pairs(binds) do
        config.keybinds[uuid] = {
            enabled    = bind.enableCheckbox:IsChecked(),
            key        = bind.keybind:GetValue(),
            mode       = bind.modeCombo:GetSelectedIndex(),
            optionName = bind.optionNameBox:GetValue(),
            optionValue= bind.optionValueBox:GetValue()
        }
    end

    local file = io.open(configPath, "w")
    if file then
        file:write("return {\n")
        file:write("globalEnable = " .. tostring(config.globalEnable) .. ",\n")
        file:write("disableInMenu = " .. tostring(config.disableInMenu) .. ",\n")
        file:write("menuX = " .. tostring(config.menuX) .. ",\n")
        file:write("menuY = " .. tostring(config.menuY) .. ",\n")
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
    end
end

local function LoadSettings()
    if not ensureConfigDirectoryExists() then return end

    local file = io.open(configPath, "r")
    if not file then
        print("Wilbind: No saved config found! Using defaults.")
        return
    end

    local content = file:read("*a")
    file:close()
    
    local chunk, err = load(content)
    if not chunk then return end

    local success, config = pcall(chunk)
    if not success then return end

    if config.menuX and config.menuY then
        menu.X = config.menuX
        menu.Y = config.menuY
    end

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

    globalEnableCheckbox = menu:AddComponent(wilgui.Checkbox("Enable All Binds", config.globalEnable))
    disableInMenuCheckbox = menu:AddComponent(wilgui.Checkbox("Disable Binds At Menu", config.disableInMenu))

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

        bindContainer.enableCheckbox = menu:AddComponent(wilgui.Checkbox("Enabled", bindData.enabled))
        bindContainer.keybind = menu:AddComponent(wilgui.Keybind("Key", bindData.key, wilgui.ItemFlags.FullWidth))
        bindContainer.modeCombo = menu:AddComponent(wilgui.Combo("Mode", {"Press", "Hold", "Toggle"}, wilgui.ItemFlags.FullWidth))
        bindContainer.modeCombo:Select(bindData.mode)
        bindContainer.optionNameBox = menu:AddComponent(wilgui.Textbox("Option Name", bindData.optionName))
        bindContainer.optionValueBox = menu:AddComponent(wilgui.Textbox("Value", bindData.optionValue))
        
        bindContainer.removeButton = menu:AddComponent(wilgui.Button("Remove", function()
            menu:RemoveComponent(bindContainer.enableCheckbox)
            menu:RemoveComponent(bindContainer.keybind)
            menu:RemoveComponent(bindContainer.modeCombo)
            menu:RemoveComponent(bindContainer.optionNameBox)
            menu:RemoveComponent(bindContainer.optionValueBox)
            menu:RemoveComponent(bindContainer.removeButton)
            binds[newUUID] = nil
        end, wilgui.ItemFlags.FullWidth))

        binds[newUUID] = bindContainer
    end
    print("Wilbind: Config loaded successfully!")
end

menu:AddComponent(wilgui.Button("Save Config", SaveSettings, wilgui.ItemFlags.FullWidth))
menu:AddComponent(wilgui.Button("Load Config", LoadSettings, wilgui.ItemFlags.FullWidth))

menu:AddComponent(wilgui.Button("Add New Bind", function()
    local newUUID = GenerateUUID()
    local bindContainer = {
        prevKeyState      = false, holdOriginalValue = nil, toggleState       = false,
        toggleOriginalValue = nil, lastValue         = nil, currentValue      = nil, incrementData     = nil
    }

    bindContainer.enableCheckbox = menu:AddComponent(wilgui.Checkbox("Enabled", true))
    bindContainer.keybind = menu:AddComponent(wilgui.Keybind("Key", KEY_INSERT, wilgui.ItemFlags.FullWidth))
    bindContainer.modeCombo = menu:AddComponent(wilgui.Combo("Mode", {"Press", "Hold", "Toggle"}, wilgui.ItemFlags.FullWidth))
    bindContainer.optionNameBox = menu:AddComponent(wilgui.Textbox("Name", ""))
    bindContainer.optionValueBox = menu:AddComponent(wilgui.Textbox("Value", ""))
    
    bindContainer.removeButton = menu:AddComponent(wilgui.Button("Remove", function()
        menu:RemoveComponent(bindContainer.enableCheckbox)
        menu:RemoveComponent(bindContainer.keybind)
        menu:RemoveComponent(bindContainer.modeCombo)
        menu:RemoveComponent(bindContainer.optionNameBox)
        menu:RemoveComponent(bindContainer.optionValueBox)
        menu:RemoveComponent(bindContainer.removeButton)
        binds[newUUID] = nil
    end, wilgui.ItemFlags.FullWidth))

    binds[newUUID] = bindContainer
end, wilgui.ItemFlags.FullWidth))

globalEnableCheckbox = menu:AddComponent(wilgui.Checkbox("Enable All Binds", true))
disableInMenuCheckbox = menu:AddComponent(wilgui.Checkbox("Disable Binds At Menu", true))

local function OnDraw()
    local allowByGlobal = globalEnableCheckbox:IsChecked()
    local allowByMenu = not disableInMenuCheckbox:IsChecked() or not gui.IsMenuOpen()

    for uuid, bind in pairs(binds) do
        if not bind.enableCheckbox:IsChecked() then goto continue end
        if not allowByGlobal then goto continue end
        if not allowByMenu then goto continue end

        local currentKey = bind.keybind:GetValue()
        local currentKeyState = input.IsButtonDown(currentKey)
        local modeIndex = bind.modeCombo:GetSelectedIndex()
        
        local rawNames    = bind.optionNameBox:GetValue()
        local optionNames = SplitOptionNames(rawNames)
        local optionValue = ConvertValue(bind, bind.optionValueBox:GetValue())

        if #optionNames == 0 then goto continue end

        if modeIndex == 1 and not engine.IsChatOpen() then 
            if currentKeyState and not bind.prevKeyState then
                local finalValue = bind.incrementData and HandleIncrement(bind) or optionValue
                for _, optionName in ipairs(optionNames) do
                    gui.SetValue(optionName, finalValue)
                    client.ChatPrintf(optionName..": "..gui.GetValue(optionName))
                end
            end
        elseif modeIndex == 2 then 
            if currentKeyState and not bind.prevKeyState then
                bind.holdOriginalValue = {}
                local finalValue = bind.incrementData and HandleIncrement(bind) or optionValue
                for _, optionName in ipairs(optionNames) do
                    bind.holdOriginalValue[optionName] = gui.GetValue(optionName)
                    gui.SetValue(optionName, finalValue)
                end
            elseif not currentKeyState and bind.prevKeyState and bind.holdOriginalValue then
                for _, optionName in ipairs(optionNames) do
                    if bind.holdOriginalValue[optionName] then
                        gui.SetValue(optionName, bind.holdOriginalValue[optionName])
                    end
                end
                bind.holdOriginalValue = nil
            end
        elseif modeIndex == 3 and not engine.IsChatOpen() then 
            if currentKeyState and not bind.prevKeyState then
                bind.toggleState = not bind.toggleState
                if bind.toggleState then
                    bind.toggleOriginalValue = {}
                    local finalValue = bind.incrementData and HandleIncrement(bind) or optionValue
                    for _, optionName in ipairs(optionNames) do
                        bind.toggleOriginalValue[optionName] = gui.GetValue(optionName)
                        gui.SetValue(optionName, finalValue)
                    end
                else
                    for _, optionName in ipairs(optionNames) do
                        if bind.toggleOriginalValue[optionName] then
                            gui.SetValue(optionName, bind.toggleOriginalValue[optionName])
                        end
                    end
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
        local rawNames = bind.optionNameBox:GetValue()
        local optionNames = SplitOptionNames(rawNames)
        
        if bind.holdOriginalValue then
            for _, optionName in ipairs(optionNames) do
                if bind.holdOriginalValue[optionName] then
                    gui.SetValue(optionName, bind.holdOriginalValue[optionName])
                    client.ChatPrintf(optionName..": "..gui.GetValue(optionName))
                end
            end
        end
        if bind.toggleOriginalValue then
            for _, optionName in ipairs(optionNames) do
                if bind.toggleOriginalValue[optionName] then
                    gui.SetValue(optionName, bind.toggleOriginalValue[optionName])
                    client.ChatPrintf(optionName..": "..gui.GetValue(optionName))
                end
            end
        end
    end
    
    if wilgui and menu then
        wilgui.RemoveMenu(menu)
    end
    print("Wilbind: Unloaded successfully")
end

callbacks.Register("Draw", "wilbind_Draw", OnDraw)
callbacks.Register("Unload", "wilbind_Unload", OnUnload)

LoadSettings()