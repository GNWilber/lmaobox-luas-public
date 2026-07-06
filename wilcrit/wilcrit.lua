--[[
    wilcrit - Shows you detailed info of your CritHack
    GitHub - https://github.com/GNWilber/lmaobox-luas-public/main/wilcrit
    Author - Wilber (https://github.com/GNWilber)
    Version - 1.06
--]]

local Version = 1.06
local RepoURL = "https://raw.githubusercontent.com/GNWilber/lmaobox-luas-public/main/wilcrit/wilcrit.lua"

-- =======================
-- Auto Update Logic
-- =======================
local function AutoUpdate()
    local content = http.Get(RepoURL)
    if not content or content == "" then return end

    local remoteVerStr = string.match(content, "Version%s*-%s*([%d%.]+)")
    if not remoteVerStr then return end

    local remoteVer = tonumber(remoteVerStr)
    if remoteVer and remoteVer > Version then
        print("[wilcrit] Found newer version (" .. remoteVer .. "). Updating...")
        local f = io.open("wilcrit.lua", "w")
        if f then
            f:write(content)
            f:close()
            print("[wilcrit] Successfully updated! Please reload your lua script.")
        end
    end
end
AutoUpdate()

-- =======================
-- wilgui & Config Loader
-- =======================
local success, wilgui = pcall(require, "wilgui")
if not success then
    print("[wilcrit WARNING] wilgui.lua missing! Cannot draw the config menu. Ensure it's correctly placed in the same folder.")
end

local ConfigFile = "wilconfigs/wilcrit.cfg"
local function LoadConfig()
    local f = io.open(ConfigFile, "r")
    if f then
        local en = f:read("*l")
        local x = tonumber(f:read("*l"))
        local y = tonumber(f:read("*l"))
        local mx = tonumber(f:read("*l"))
        local my = tonumber(f:read("*l"))
        f:close()
        return (en == "true"), x, y, mx, my
    end
    -- Returns Enabled=True, PanelX=10, PanelY=350, MenuX=100, MenuY=100
    return true, 10, 350, 100, 100 
end

local function SaveConfig(en, x, y, mx, my)
    local f = io.open(ConfigFile, "w")
    if f then
        f:write(tostring(en) .. "\n")
        f:write(tostring(x) .. "\n")
        f:write(tostring(y) .. "\n")
        f:write(tostring(mx) .. "\n")
        f:write(tostring(my) .. "\n")
        f:close()
    end
end

local savedEn, savedX, savedY, savedMx, savedMy = LoadConfig()

-- Safety fallbacks if the config file was from an older version
savedMx = savedMx or 100
savedMy = savedMy or 100

local chkEnable, sldX, sldY = nil, nil, nil
local menu = nil

if success and wilgui then
    -- Clean up any "ghost" menu from previous reloads to make it a safe shared UI library
    for i = #wilgui.Menus, 1, -1 do
        if wilgui.Menus[i].Title == "wilcrit Settings" then
            table.remove(wilgui.Menus, i)
        end
    end
    
    menu = wilgui.Create("wilcrit Settings", wilgui.MenuFlags.AutoSize)
    menu.X = savedMx
    menu.Y = savedMy
    
    chkEnable = menu:AddComponent(wilgui.Checkbox("Enable wilcrit Info", savedEn))
    sldX = menu:AddComponent(wilgui.Slider("Panel X Offset", 0, 2560, savedX))
    sldY = menu:AddComponent(wilgui.Slider("Panel Y Offset", 0, 1440, savedY))
end

local lastEn, lastX, lastY, lastMx, lastMy = savedEn, savedX, savedY, savedMx, savedMy

-- =======================
-- HUD Draw Logic
-- =======================
local indicator = draw.CreateFont('Verdana', 16, 700, FONTFLAG_CUSTOM | FONTFLAG_OUTLINE)

callbacks.Register("Draw", "wilcrit_Draw", function()
    -- Dynamically fetch configs (including menu drag positions) and autosave if changed
    local curEn, curX, curY = lastEn, lastX, lastY
    local curMx, curMy = lastMx, lastMy
    
    if chkEnable and sldX and sldY and menu then
        curEn = chkEnable:GetValue()
        curX = sldX:GetValue()
        curY = sldY:GetValue()
        curMx = menu.X
        curMy = menu.Y
        
        if curEn ~= lastEn or curX ~= lastX or curY ~= lastY or curMx ~= lastMx or curMy ~= lastMy then
            SaveConfig(curEn, curX, curY, curMx, curMy)
            lastEn, lastX, lastY, lastMx, lastMy = curEn, curX, curY, curMx, curMy
        end
    end

    if not curEn then return end

    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end

    local wpn = me:GetPropEntity('m_hActiveWeapon')
    if not wpn then return end

    local successCrit, critTokenBucket = pcall(function() return wpn:GetCritTokenBucket() end)
    if not successCrit then return end

    local critCheckCount = wpn:GetCritCheckCount()
    local critSeedRequestCount = wpn:GetCritSeedRequestCount()
    local critChance = wpn:GetCritChance()
    local critCost = wpn:GetCritCost(critTokenBucket, critSeedRequestCount, critCheckCount)
    local weaponBaseDamage = wpn:GetWeaponBaseDamage()
    
    local dmgStats = wpn:GetWeaponDamageStats()
    if type(dmgStats) ~= "table" then return end 
    
    local totalDmg = dmgStats["total"] or 0
    local criticalDmg = dmgStats["critical"] or 0
    local cmpCritChance = critChance + 0.1
    local requiredDamage = 0

    local shotsNeededForTokens = 0
    if critTokenBucket < critCost then
        local missingToken = critCost - critTokenBucket
        shotsNeededForTokens = math.ceil(missingToken / math.max(weaponBaseDamage, 1))
    end

    local requiredTotalDamage = (criticalDmg * (2.0 * cmpCritChance + 1.0)) / cmpCritChance / 3.0
    requiredDamage = math.floor(requiredTotalDamage - totalDmg)

    if requiredDamage < 0 then
        requiredDamage = 0
    end

    local data = {}
    if critTokenBucket < critCost then
        table.insert(data, "Shots needed for crit: " .. shotsNeededForTokens)
    end

    if requiredDamage > 0 then
        table.insert(data, "Damage needed for crit: " .. requiredDamage)
    end

    local offsetY = curY

    draw.SetFont(indicator)
    for _, line in ipairs(data) do
        if string.find(line, "Shots needed for crit") then
            draw.Color(219, 255, 199, 255)
        elseif string.find(line, "Damage needed for crit") then
            draw.Color(255, 217, 217, 255)
        end

        local txtWidth, txtHeight = draw.GetTextSize(line)
        draw.Text(curX, offsetY, line)
        offsetY = offsetY + txtHeight + 5
    end
end)

-- Removes the settings menu gracefully if you Unload the script from Lmaobox
callbacks.Register("Unload", "wilcrit_Unload", function()
    if success and wilgui and menu then
        wilgui.RemoveMenu(menu)
    end
end)