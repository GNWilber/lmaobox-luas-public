--[[
    CritInfo - Shows you detailed info of your CritHack
    GitHub - https://github.com/GNWilber/lmaobox-luas-public/critinfo/README.md
    Author - Wilber (https://github.com/GNWilber)
    Version - 1.00
--]]

local VERSION = 1.00
local RAW_GITHUB_URL = "https://raw.githubusercontent.com/GNWilber/lmaobox-luas-public/main/critinfo/critinfo.lua"

local indicator = draw.CreateFont('Verdana', 16, 700, FONTFLAG_CUSTOM | FONTFLAG_OUTLINE)
local panelX, panelY = 10, 350  -- Adjust these values for top-left offset

-- ==========================================
-- Auto-Updater System
-- ==========================================
local function CheckForUpdates()
    http.Get(RAW_GITHUB_URL, function(success, response)
        if not success or not response then return end
        
        -- Parse the version number from the fetched remote code
        local remote_version_str = string.match(response, "Version%s*-%s*([%d%.]+)")
        if not remote_version_str then return end
        
        local remote_version = tonumber(remote_version_str)
        if remote_version and remote_version > VERSION then
            print("[CritInfo] Update found! Downloading version " .. remote_version .. "...")
            
            -- GetScriptName() gets the current relative path (e.g., "critinfo\critinfo.lua")
            local file = io.open(GetScriptName(), "w")
            if file then
                file:write(response)
                file:close()
                print("[CritInfo] Successfully updated! Please Unload and Reload the script.")
                client.Command('play "ui/buttonclick.wav"', true) -- Play notification sound
            else
                print("[CritInfo] Error: Failed to open file for writing the update.")
            end
        end
    end)
end

-- Run update check once on load
CheckForUpdates()

-- ==========================================
-- Main Drawing Callback
-- ==========================================
callbacks.Register("Draw", function()
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then
        return
    end

    local wpn = me:GetPropEntity('m_hActiveWeapon')
    if not wpn then
        return
    end

    local weaponBaseDamage = wpn:GetWeaponBaseDamage()
    
    -- Safety check: Prevent errors/division by zero on weapons that deal 0 damage (Medigun, PDA, etc.)
    if not weaponBaseDamage or weaponBaseDamage <= 0 then
        return
    end

    -- Fetching necessary crit-related info
    local critTokenBucket = wpn:GetCritTokenBucket()
    local critCheckCount = wpn:GetCritCheckCount()
    local critSeedRequestCount = wpn:GetCritSeedRequestCount()
    local critChance = wpn:GetCritChance()
    local critCost = wpn:GetCritCost(critTokenBucket, critSeedRequestCount, critCheckCount)
    local dmgStats = wpn:GetWeaponDamageStats()
    local totalDmg = dmgStats["total"]
    local criticalDmg = dmgStats["critical"]
    
    local cmpCritChance = critChance + 0.1
    local requiredDamage = 0
    local shotsNeededForTokens = 0

    -- Calculate how many shots we need to fill the crit token bucket
    if critTokenBucket < critCost then
        local missingToken = critCost - critTokenBucket
        shotsNeededForTokens = math.ceil(missingToken / weaponBaseDamage) 
    end

    -- Calculate how much more damage we need for crit safely
    if cmpCritChance > 0 then
        local requiredTotalDamage = (criticalDmg * (2.0 * cmpCritChance + 1.0)) / cmpCritChance / 3.0
        requiredDamage = math.floor(requiredTotalDamage - totalDmg)
    end

    -- Ensure the damage isn't negative
    if requiredDamage < 0 then
        requiredDamage = 0
    end

    -- Construct the text to show
    local data = {}

    -- If we need to fire more shots for crit token
    if critTokenBucket < critCost then
        table.insert(data, { text = "Shots needed for crit: " .. shotsNeededForTokens, color = {198, 255, 167, 255} }) -- Light green
    end

    -- Always display damage needed for crit (if above 0)
    if requiredDamage > 0 then
        table.insert(data, { text = "Damage needed for crit: " .. requiredDamage, color = {255, 164, 164, 255} }) -- Light red
    end

    -- Only draw if we have something to display
    if #data > 0 then
        draw.SetFont(indicator)

        -- Pre-calculate background box sizes for aesthetic visuals
        local maxWidth = 0
        local totalHeight = 0
        for _, item in ipairs(data) do
            local txtWidth, txtHeight = draw.GetTextSize(item.text)
            if txtWidth > maxWidth then maxWidth = txtWidth end
            totalHeight = totalHeight + txtHeight + 5
        end

        -- Draw semi-transparent background box
        draw.Color(0, 0, 0, 160)
        draw.FilledRect(panelX - 5, panelY - 5, panelX + maxWidth + 5, panelY + totalHeight)

        -- Draw text lines
        local offsetY = panelY
        for _, item in ipairs(data) do
            draw.Color(item.color[1], item.color[2], item.color[3], item.color[4])
            draw.Text(panelX, offsetY, item.text)
            
            local _, txtHeight = draw.GetTextSize(item.text)
            offsetY = offsetY + txtHeight + 5  -- Move down for next line
        end
    end
end)