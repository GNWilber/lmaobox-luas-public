--[[
    wilcrit - Shows you detailed info of your CritHack
    GitHub - https://github.com/GNWilber/lmaobox-luas-public/main/wilcrit
    Author - Wilber (https://github.com/GNWilber)
    Version - 1.02
--]]

local Version = 1.02
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
    -- Only update if github version is strictly greater
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
    print("[wilcrit] wilgui.lua missing! Cannot draw the config menu. Ensure it's in the same folder.")
end

local ConfigFile = "./wilconfigs/wilcrit.cfg"
local function LoadConfig()
    local f = io.open(ConfigFile, "r")
    if f then
        local x = tonumber(f:read("*l"))
        local y = tonumber(f:read("*l"))
        local en = f:read("*l")
        f:close()
        return x, y, (en == "true")
    end
    return nil, nil, nil
end

local function SaveConfig(x, y, en)
    local f = io.open(ConfigFile, "w")
    if f then
        f:write(tostring(x) .. "\n")
        f:write(tostring(y) .. "\n")
        f:write(tostring(en) .. "\n")
        f:close()
    else
        print("[wilcrit WARNING] Could not save config! Make sure you created a folder named 'wilconfigs' in your lmaobox folder.")
    end
end

-- Backward Compatibility Default Layout
local defaultX, defaultY = 10, 350
local savedX, savedY, savedEn = LoadConfig()

local menuWin = nil
if success and wilgui then
    wilgui.Clear() -- Fixes the "black box" / duplicate menu overlap bug on script reload!
    menuWin = wilgui.CreateWindow("wilcrit Settings", 100, 100, 260, 150)
    menuWin:AddCheckbox("Enable wilcrit Info", "enabled", savedEn ~= nil and savedEn or true)
    menuWin:AddSlider("Panel X Offset", "panel_x", 0, 2560, savedX or defaultX)
    menuWin:AddSlider("Panel Y Offset", "panel_y", 0, 1440, savedY or defaultY)
end

local lastX, lastY, lastEn = savedX, savedY, savedEn
local function GetCurrentConfig()
    if not menuWin then return (savedX or defaultX), (savedY or defaultY), (savedEn ~= nil and savedEn or true) end
    
    local curX = menuWin:GetValue("panel_x")
    local curY = menuWin:GetValue("panel_y")
    local curEn = menuWin:GetValue("enabled")
    
    if curX ~= lastX or curY ~= lastY or curEn ~= lastEn then
        SaveConfig(curX, curY, curEn)
        lastX, lastY, lastEn = curX, curY, curEn
    end
    return curX, curY, curEn
end

-- =======================
-- HUD Draw Logic
-- =======================
local indicator = draw.CreateFont('Verdana', 16, 700, FONTFLAG_CUSTOM | FONTFLAG_OUTLINE)

callbacks.Register("Draw", "wilcrit_Draw", function()
    -- Render the GUI Elements First (Must be handled within Draw callback here to prevent ghost menus)
    if success and wilgui then
        wilgui.Render()
    end

    local panelX, panelY, enabled = GetCurrentConfig()
    if not enabled then return end

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

    local offsetY = panelY

    draw.SetFont(indicator)
    for _, line in ipairs(data) do
        if string.find(line, "Shots needed for crit") then
            draw.Color(219, 255, 199, 255)
        elseif string.find(line, "Damage needed for crit") then
            draw.Color(255, 217, 217, 255)
        end

        local txtWidth, txtHeight = draw.GetTextSize(line)
        draw.Text(panelX, offsetY, line)
        offsetY = offsetY + txtHeight + 5
    end
end)