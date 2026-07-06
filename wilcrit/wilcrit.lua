--[[
    wilcrit - Shows you detailed info of your CritHack
    GitHub - https://github.com/GNWilber/lmaobox-luas-public/main/wilcrit
    Author - Wilber (https://github.com/GNWilber)
    Version - 1.04
--]]

local Version = 1.04
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
    print("[wilcrit WARNING] wilgui.lua missing! Cannot draw the config menu. Ensure it's in the same folder.")
end

local ConfigFile = "wilconfigs/wilcrit.cfg"
local function LoadConfig()
    local f = io.open(ConfigFile, "r")
    if f then
        local en = f:read("*l")
        local x = tonumber(f:read("*l"))
        local y = tonumber(f:read("*l"))
        f:close()
        return (en == "true"), x, y
    end
    return true, 10, 350 -- Default backward compatibility
end

local function SaveConfig(en, x, y)
    local f = io.open(ConfigFile, "w")
    if f then
        f:write(tostring(en) .. "\n")
        f:write(tostring(x) .. "\n")
        f:write(tostring(y) .. "\n")
        f:close()
    end
end

local savedEn, savedX, savedY = LoadConfig()

local chkEnable, sldX, sldY = nil, nil, nil
if success and wilgui then
    wilgui.Clear() -- Clears existing menus on script reload
    
    -- Notice we now use wilgui.MenuFlags to securely get the flag
    local menu = wilgui.Create("wilcrit Settings", wilgui.MenuFlags.AutoSize)
    menu.X = 100
    menu.Y = 100
    
    chkEnable = menu:AddComponent(wilgui.Checkbox("Enable wilcrit Info", savedEn))
    sldX = menu:AddComponent(wilgui.Slider("Panel X Offset", 0, 2560, savedX))
    sldY = menu:AddComponent(wilgui.Slider("Panel Y Offset", 0, 1440, savedY))
end

local lastEn, lastX, lastY = savedEn, savedX, savedY

-- =======================
-- HUD Draw Logic
-- =======================
local indicator = draw.CreateFont('Verdana', 16, 700, FONTFLAG_CUSTOM | FONTFLAG_OUTLINE)

callbacks.Register("Draw", "wilcrit_Draw", function()
    -- Dynamically fetch configs and autosave if changed
    local curEn, curX, curY = lastEn, lastX, lastY
    if chkEnable and sldX and sldY then
        curEn = chkEnable:GetValue()
        curX = sldX:GetValue()
        curY = sldY:GetValue()
        
        if curEn ~= lastEn or curX ~= lastX or curY ~= lastY then
            SaveConfig(curEn, curX, curY)
            lastEn, lastX, lastY = curEn, curX, curY
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