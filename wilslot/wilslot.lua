--[[
    Wilslot - Weapon slot and class bind manager for LMAOBOX
    GitHub - (https://github.com/GNWilber/lmaobox-luas-public/main/wilslot)
    Author - Wilber (https://github.com/GNWilber)
    Version - 1.02
--]]

local Version = 1.02
local RepoURL = "https://raw.githubusercontent.com/GNWilber/lmaobox-luas-public/main/wilslot/wilslot.lua"

-- =======================
-- Auto Update Logic
-- =======================
pcall(function()
    local content = http.Get(RepoURL)
    if not content or content == "" then return end
    local remoteVerStr = string.match(content, "Version%s*-%s*([%d%.]+)")
    if not remoteVerStr then return end
    local remoteVer = tonumber(remoteVerStr)
    if remoteVer and remoteVer > Version then
        print("[Wilslot] Found newer version (" .. remoteVer .. "). Updating...")
        local f = io.open("wilslot.lua", "w")
        if f then f:write(content); f:close(); print("[Wilslot] Successfully updated! Please reload your lua script.") end
    end
end)

-- =======================
-- Load wilgui framework
-- =======================
local success, wilgui = pcall(require, "wilgui")
if not success then
    print("[Wilslot ERROR] wilgui.lua is missing or corrupted! Please place it in your lua folder.")
    return
end

local configFolder = "wilconfigs"
local configPath = configFolder .. "/wilslot.cfg"

-- Remove ONLY Wilslot's menu on script reload, protecting wilcrit and wilbind
for i = #wilgui.Menus, 1, -1 do
    if wilgui.Menus[i].Title == "Wilslot" then table.remove(wilgui.Menus, i) end
end

local menu = wilgui.Create("Wilslot", wilgui.MenuFlags.AutoSize)
print("Wilslot: Menu initialized")
menu:SetPosition(600, 100)
menu.Style.Space = 1
menu.Style.WindowBg = { 30, 30, 30, 240 }
menu.Style.TitleBg  = { 0, 106, 255, 240 }
menu.Style.Item     = { 60, 60, 60, 240 }

-- State Variables
local binds = {}
local bindOrder = {}
local uuidCounter = 0
local lastMenuX, lastMenuY = menu.X, menu.Y

local saveBtn, loadBtn, addBtn
local globalEnableCheckbox, bindsPerColSlider
local lastBindsPerCol = 3

-- Mapping Tables
local classOptions = { "Any", "Scout", "Soldier", "Pyro", "Demoman", "Heavy", "Engineer", "Medic", "Sniper", "Spy" }
local classMap = { [1] = nil, [2] = 1, [3] = 3, [4] = 7, [5] = 4, [6] = 6, [7] = 9, [8] = 5, [9] = 2, [10] = 8 }

local slotOptions = { "Any", "1", "2", "3", "4", "5" }
local slotMap = { [1] = nil, [2] = 0, [3] = 1, [4] = 2, [5] = 3, [6] = 4 }

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------
local function GenerateUUID()
    uuidCounter = uuidCounter + 1
    return string.format("%X-%X", os.time(), uuidCounter)
end

local function SplitOptionNames(str)
    local names = {}
    for chunk in string.gmatch(str, "([^&]+)") do
        local name = chunk:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then table.insert(names, name) end
    end
    return names
end

local function ParseIncrement(value)
    if type(value) ~= "string" then return nil end
    local start, finish, step = value:match("^increment%s+(%d+)%s+(%d+)%s+(%d+)$")
    if start and finish and step then return { start = tonumber(start), finish = tonumber(finish), step = tonumber(step) } end
    return nil
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
    
    menu:AddComponent(saveBtn)
    menu:AddComponent(loadBtn)
    menu:AddComponent(addBtn)
    menu:AddComponent(globalEnableCheckbox)
    menu:AddComponent(bindsPerColSlider)
    
    local perCol = bindsPerColSlider:GetValue()
    
    for i, uuid in ipairs(bindOrder) do
        local bind = binds[uuid]
        
        if i > 1 and (i - 1) % perCol == 0 then
            menu:AddComponent(wilgui.ColumnBreak())
        end
        
        -- Dynamically set the title for the checkbox based on active combo selections
        local cIdx = bind.classCombo:GetSelectedIndex()
        local sIdx = bind.slotCombo:GetSelectedIndex()
        bind.enableCheckbox.Label = (classOptions[cIdx] or "Any") .. " | " .. (slotOptions[sIdx] or "Any")
        
        menu:AddComponent(bind.enableCheckbox)
        menu:AddComponent(bind.classCombo)
        menu:AddComponent(bind.slotCombo)
        menu:AddComponent(bind.optionNameBox)
        menu:AddComponent(bind.optionValueBox)
        menu:AddComponent(bind.removeButton)
    end
end

local function SaveSettings()
    if not ensureConfigDirectoryExists() then return end

    local config = {
        globalEnable = globalEnableCheckbox:IsChecked(),
        bindsPerCol = bindsPerColSlider:GetValue(),
        menuX = menu.X, menuY = menu.Y, keybinds = {}
    }

    for _, uuid in ipairs(bindOrder) do
        local bind = binds[uuid]
        config.keybinds[uuid] = {
            enabled    = bind.enableCheckbox:IsChecked(),
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
        file:write("bindsPerCol = " .. tostring(config.bindsPerCol) .. ",\n")
        file:write("menuX = " .. tostring(config.menuX) .. ",\n")
        file:write("menuY = " .. tostring(config.menuY) .. ",\n")
        file:write("keybinds = {\n")
        for uuid, bData in pairs(config.keybinds) do
            file:write(string.format([[
    [%q] = { enabled = %s, classIndex = %d, slotIndex = %d, optionName = %q, optionValue = %q },]], 
            uuid, tostring(bData.enabled), bData.classIndex, bData.slotIndex, bData.optionName, tostring(bData.optionValue)))
        end
        file:write("\n}\n}")
        file:close()
        print("Wilslot: Config saved successfully!")
    end
end

local function CreateBind(bindData, specificUUID)
    local bind = {
        uuid = specificUUID or GenerateUUID(),
        holdOriginalValue = nil, lastValue = nil, currentValue = nil, incrementData = nil
    }

    bindData = bindData or {}
    local isEnabled = bindData.enabled ~= nil and bindData.enabled or true
    local cIdx = bindData.classIndex or 1
    local sIdx = bindData.slotIndex or 1
    local label = (classOptions[cIdx] or "Any") .. " | " .. (slotOptions[sIdx] or "Any")
    
    bind.enableCheckbox = wilgui.Checkbox(label, isEnabled)
    bind.classCombo = wilgui.Combo("Class", classOptions, wilgui.ItemFlags.FullWidth)
    bind.classCombo:Select(cIdx)
    bind.slotCombo = wilgui.Combo("Weapon Slot", slotOptions, wilgui.ItemFlags.FullWidth)
    bind.slotCombo:Select(sIdx)
    bind.optionNameBox = wilgui.Textbox("Option Name", bindData.optionName or "")
    bind.optionValueBox = wilgui.Textbox("Value", bindData.optionValue or "")
    
    bind.removeButton = wilgui.Button("Remove", function()
        for i, id in ipairs(bindOrder) do
            if id == bind.uuid then table.remove(bindOrder, i); break end
        end
        binds[bind.uuid] = nil
        RebuildMenuLayout()
        SaveSettings()
    end, wilgui.ItemFlags.FullWidth)
    
    return bind
end

local function AddNewBind()
    local bind = CreateBind()
    binds[bind.uuid] = bind
    table.insert(bindOrder, bind.uuid)
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
    if config.bindsPerCol ~= nil then bindsPerColSlider.Value = config.bindsPerCol end

    binds = {}
    bindOrder = {}
    
    for uuid, bindData in pairs(config.keybinds or {}) do
        local newBind = CreateBind(bindData, uuid)
        binds[uuid] = newBind
        table.insert(bindOrder, uuid)
    end
    RebuildMenuLayout()
    print("Wilslot: Config loaded successfully!")
end

--------------------------------------------------------------------------------
-- Initialize Top Menu Components
--------------------------------------------------------------------------------
saveBtn = wilgui.Button("Save Config", SaveSettings, wilgui.ItemFlags.FullWidth)
loadBtn = wilgui.Button("Load Config", LoadSettings, wilgui.ItemFlags.FullWidth)
addBtn  = wilgui.Button("Add New Bind", AddNewBind, wilgui.ItemFlags.FullWidth)
globalEnableCheckbox  = wilgui.Checkbox("Enable All Binds", true)
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

    -- Dynamically update label names based on selected combos without full UI redraws
    for _, uuid in ipairs(bindOrder) do
        local bind = binds[uuid]
        local compLabel = (classOptions[bind.classCombo:GetSelectedIndex()] or "Any") .. " | " .. (slotOptions[bind.slotCombo:GetSelectedIndex()] or "Any")
        if bind.enableCheckbox.Label ~= compLabel then
            bind.enableCheckbox.Label = compLabel
        end
    end

    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return end

    local currentClass = localPlayer:GetPropInt("m_iClass")
    local activeWeapon = localPlayer:GetPropEntity("m_hActiveWeapon")
    local currentSlot = activeWeapon and activeWeapon:GetLoadoutSlot() or nil
    local allowByGlobal = globalEnableCheckbox:IsChecked()

    for _, uuid in ipairs(bindOrder) do
        local bind = binds[uuid]
        local rawNames = bind.optionNameBox:GetValue()
        local optionNames = SplitOptionNames(rawNames)
        
        if #optionNames == 0 then goto continue end

        if not allowByGlobal or not bind.enableCheckbox:IsChecked() then
            if bind.holdOriginalValue then
                for _, optionName in ipairs(optionNames) do
                    if bind.holdOriginalValue[optionName] then
                        gui.SetValue(optionName, bind.holdOriginalValue[optionName])
                    end
                end
                bind.holdOriginalValue = nil
            end
            goto continue
        end

        local targetClass = classMap[bind.classCombo:GetSelectedIndex()]
        local targetSlot = slotMap[bind.slotCombo:GetSelectedIndex()]
        local conditionMet = true

        if targetClass and targetClass ~= currentClass then conditionMet = false end
        if targetSlot ~= nil and (currentSlot == nil or targetSlot ~= currentSlot) then conditionMet = false end

        if conditionMet then
            if not bind.holdOriginalValue then
                bind.holdOriginalValue = {}
                local finalValue = ConvertValue(bind, bind.optionValueBox:GetValue())
                for _, optionName in ipairs(optionNames) do
                    bind.holdOriginalValue[optionName] = gui.GetValue(optionName)
                    gui.SetValue(optionName, finalValue)
                end
            end
        else
            if bind.holdOriginalValue then
                for _, optionName in ipairs(optionNames) do
                    if bind.holdOriginalValue[optionName] then
                        gui.SetValue(optionName, bind.holdOriginalValue[optionName])
                    end
                end
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
        local rawNames = bind.optionNameBox:GetValue()
        local optionNames = SplitOptionNames(rawNames)
        
        if bind.holdOriginalValue then
            for _, optionName in ipairs(optionNames) do
                if bind.holdOriginalValue[optionName] then
                    gui.SetValue(optionName, bind.holdOriginalValue[optionName])
                end
            end
        end
    end
    if wilgui and menu then wilgui.RemoveMenu(menu) end
    print("Wilslot: Unloaded successfully")
end

callbacks.Register("Draw", "wilslot_Draw", OnDraw)
callbacks.Register("Unload", "wilslot_Unload", OnUnload)