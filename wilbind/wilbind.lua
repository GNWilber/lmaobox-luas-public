--[[
    Wilbind - Keybinds manager for LMAOBOX
    GitHub - https://github.com/GNWilber/lmaobox-luas-public/main/wilbind
    Author - Wilber (https://github.com/GNWilber)
    Version - 1.32
--]]

local Version = 1.32
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
        if f then f:write(content); f:close(); print("[Wilbind] Successfully updated! Please reload your lua script.") end
    end
end)

local success, wilgui = pcall(require, "wilgui")
if not success then
    print("[Wilbind ERROR] wilgui.lua is missing or corrupted! Error: " .. tostring(wilgui))
    return
end

local configFolder = "wilconfigs"
local configPath = configFolder .. "/wilbind.cfg"

for i = #wilgui.Menus, 1, -1 do
    if wilgui.Menus[i].Title == "Wilbind" then table.remove(wilgui.Menus, i) end
end

local menu = wilgui.Create("Wilbind", wilgui.MenuFlags.AutoSize)
print("Wilbind: Menu initialized")
menu:SetPosition(400, 100)
menu.Style.Space = 1
menu.Style.WindowBg = { 30, 30, 30, 240 }
menu.Style.TitleBg  = { 0, 106, 255, 240 }
menu.Style.Item     = { 60, 60, 60, 240 }

-- State Variables
local bindList = {}
local uuidCounter = 0
local lastMenuX, lastMenuY = menu.X, menu.Y

-- Base Top Menu Components
local saveBtn, loadBtn, addBtn
local globalEnableCheckbox, disableInMenuCheckbox, bindsPerColSlider
local lastBindsPerCol = 4

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------
local function GenerateUUID()
    uuidCounter = uuidCounter + 1
    return string.format("%X-%X", os.time(), uuidCounter)
end

local function ParseIncrement(value)
    if type(value) ~= "string" then return nil end
    local start, finish, step = value:match("^increment%s+(%d+)%s+(%d+)%s+(%d+)$")
    if start and finish and step then return { start = tonumber(start), finish = tonumber(finish), step = tonumber(step) } end
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
    if bind.lastValue and bind.lastValue.original == value then return bind.lastValue.converted end
    local incrementData = ParseIncrement(value)
    if incrementData then
        bind.incrementData = incrementData; bind.currentValue = incrementData.start
        bind.lastValue = { original = value, converted = incrementData.start }; return incrementData.start
    end
    local num = tonumber(value)
    local converted = num and (num % 1 == 0 and math.floor(num) or num) or ((value ~= "" and value) or "0")
    bind.incrementData = nil; bind.lastValue = { original = value, converted = converted }; return converted
end

local function HandleIncrement(bind)
    if not bind.incrementData then return bind.currentValue end
    bind.currentValue = bind.currentValue + bind.incrementData.step
    if bind.currentValue > bind.incrementData.finish then bind.currentValue = bind.incrementData.start end
    return bind.currentValue
end

local function ensureConfigDirectoryExists()
    local success, _ = filesystem.CreateDirectory(configFolder)
    if not success then
        if not filesystem.GetFileAttributes(configFolder) then return false end
    end
    return true
end

--------------------------------------------------------------------------------
-- Menu Layout Builder
--------------------------------------------------------------------------------
local function RebuildMenuLayout()
    menu.Components = {}
    
    -- Load persistent top controls
    menu:AddComponent(saveBtn)
    menu:AddComponent(loadBtn)
    menu:AddComponent(addBtn)
    menu:AddComponent(globalEnableCheckbox)
    menu:AddComponent(disableInMenuCheckbox)
    menu:AddComponent(bindsPerColSlider)
    
    local perCol = bindsPerColSlider:GetValue()
    
    for i, bind in ipairs(bindList) do
        -- Triggers a new column shift if we exceed the Binds/Col threshold
        if i > 1 and (i - 1) % perCol == 0 then
            menu:AddComponent(wilgui.ColumnBreak())
        end
        menu:AddComponent(bind.enableCheckbox)
        menu:AddComponent(bind.keybind)
        menu:AddComponent(bind.modeCombo)
        menu:AddComponent(bind.optionNameBox)
        menu:AddComponent(bind.optionValueBox)
        menu:AddComponent(bind.removeButton)
    end
end

local function SaveSettings()
    if not ensureConfigDirectoryExists() then return end

    local config = {
        globalEnable = globalEnableCheckbox:IsChecked(),
        disableInMenu = disableInMenuCheckbox:IsChecked(),
        bindsPerCol = bindsPerColSlider:GetValue(),
        menuX = menu.X, menuY = menu.Y, keybinds = {}
    }

    for _, bind in ipairs(bindList) do
        config.keybinds[bind.uuid] = {
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
        file:write("bindsPerCol = " .. tostring(config.bindsPerCol) .. ",\n")
        file:write("menuX = " .. tostring(config.menuX) .. ",\n")
        file:write("menuY = " .. tostring(config.menuY) .. ",\n")
        file:write("keybinds = {\n")
        for uuid, bData in pairs(config.keybinds) do
            file:write(string.format([[
    [%q] = { enabled = %s, key = %d, mode = %d, optionName = %q, optionValue = %q },]], 
            uuid, tostring(bData.enabled), bData.key, bData.mode, bData.optionName, tostring(bData.optionValue)))
        end
        file:write("\n}\n}")
        file:close()
        print("Wilbind: Config saved successfully!")
    end
end

local function CreateBind(bindData, specificUUID)
    local bind = {
        uuid = specificUUID or GenerateUUID(), prevKeyState = false, holdOriginalValue = nil,
        toggleState = false, toggleOriginalValue = nil, lastValue = nil, currentValue = nil, incrementData = nil
    }

    bindData = bindData or {}
    local isEnabled = bindData.enabled ~= nil and bindData.enabled or true
    
    bind.enableCheckbox = wilgui.Checkbox("Enabled", isEnabled)
    bind.keybind = wilgui.Keybind("Key", bindData.key or KEY_INSERT, wilgui.ItemFlags.FullWidth)
    bind.modeCombo = wilgui.Combo("Mode", {"Press", "Hold", "Toggle"}, wilgui.ItemFlags.FullWidth)
    bind.modeCombo:Select(bindData.mode or 1)
    bind.optionNameBox = wilgui.Textbox("Name", bindData.optionName or "")
    bind.optionValueBox = wilgui.Textbox("Value", bindData.optionValue or "")
    
    bind.removeButton = wilgui.Button("Remove", function()
        for i, b in ipairs(bindList) do
            if b.uuid == bind.uuid then table.remove(bindList, i); break end
        end
        RebuildMenuLayout()
        SaveSettings()
    end, wilgui.ItemFlags.FullWidth)
    
    return bind
end

local function AddNewBind()
    table.insert(bindList, CreateBind())
    RebuildMenuLayout()
end

local function LoadSettings()
    if not ensureConfigDirectoryExists() then return end
    local file = io.open(configPath, "r")
    if not file then RebuildMenuLayout(); return end

    local content = file:read("*a"); file:close()
    local chunk, err = load(content)
    if not chunk then return end
    local success, config = pcall(chunk)
    if not success then return end

    if config.menuX and config.menuY then menu.X, menu.Y = config.menuX, config.menuY; lastMenuX, lastMenuY = menu.X, menu.Y end
    if config.globalEnable ~= nil then globalEnableCheckbox.Value = config.globalEnable end
    if config.disableInMenu ~= nil then disableInMenuCheckbox.Value = config.disableInMenu end
    if config.bindsPerCol ~= nil then bindsPerColSlider.Value = config.bindsPerCol end

    bindList = {}
    for uuid, bindData in pairs(config.keybinds or {}) do
        table.insert(bindList, CreateBind(bindData, uuid))
    end
    RebuildMenuLayout()
    print("Wilbind: Config loaded successfully!")
end

--------------------------------------------------------------------------------
-- Initialize Top Menu Components
--------------------------------------------------------------------------------
saveBtn = wilgui.Button("Save Config", SaveSettings, wilgui.ItemFlags.FullWidth)
loadBtn = wilgui.Button("Load Config", LoadSettings, wilgui.ItemFlags.FullWidth)
addBtn  = wilgui.Button("Add New Bind", AddNewBind, wilgui.ItemFlags.FullWidth)
globalEnableCheckbox  = wilgui.Checkbox("Enable All Binds", true)
disableInMenuCheckbox = wilgui.Checkbox("Disable Binds At Menu", true)
bindsPerColSlider = wilgui.Slider("Binds per Column", 1, 15, 3)

LoadSettings()

--------------------------------------------------------------------------------
-- Main Logic and Callbacks
--------------------------------------------------------------------------------
local function OnDraw()
    -- Dynamically update columns if the slider changed
    local currentBindsPerCol = bindsPerColSlider:GetValue()
    if currentBindsPerCol ~= lastBindsPerCol then
        lastBindsPerCol = currentBindsPerCol
        RebuildMenuLayout()
        SaveSettings()
    end

    -- Auto Save window drag positions securely
    if (menu.X ~= lastMenuX or menu.Y ~= lastMenuY) and not input.IsButtonDown(MOUSE_LEFT or 107) then
        lastMenuX, lastMenuY = menu.X, menu.Y
        SaveSettings()
    end

    local allowByGlobal = globalEnableCheckbox:IsChecked()
    local allowByMenu = not disableInMenuCheckbox:IsChecked() or not gui.IsMenuOpen()

    for _, bind in ipairs(bindList) do
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
    for _, bind in ipairs(bindList) do
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
    
    if wilgui and menu then wilgui.RemoveMenu(menu) end
    print("Wilbind: Unloaded successfully")
end

callbacks.Register("Draw", "wilbind_Draw", OnDraw)
callbacks.Register("Unload", "wilbind_Unload", OnUnload)