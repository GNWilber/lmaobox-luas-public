local indicator = draw.CreateFont('Verdana', 16, 700, FONTFLAG_CUSTOM | FONTFLAG_OUTLINE)
local panelX, panelY = 10, 350  -- Adjust these values for top-left offset

callbacks.Register("Draw", function()
    local width, height = draw.GetScreenSize()
    -- Use the panelX and panelY for positioning
    draw.SetFont(indicator)

    -- Fetch the local player and active weapon
    local me = entities.GetLocalPlayer()
    if not me then
        return
    end

    local wpn = me:GetPropEntity('m_hActiveWeapon')
    if not wpn or not me:IsAlive() then
        return
    end

    -- Fetching necessary crit-related info
    local critTokenBucket = wpn:GetCritTokenBucket()
    local critCheckCount = wpn:GetCritCheckCount()  -- Fetching actual crit check count
    local critSeedRequestCount = wpn:GetCritSeedRequestCount()  -- Fetching actual crit seed request count
    local critChance = wpn:GetCritChance()
    local critCost = wpn:GetCritCost(critTokenBucket, critSeedRequestCount, critCheckCount)  -- Using real data
    local weaponBaseDamage = wpn:GetWeaponBaseDamage()  -- Added weapon base damage
    local dmgStats = wpn:GetWeaponDamageStats()
    local totalDmg = dmgStats["total"]
    local criticalDmg = dmgStats["critical"]
    local cmpCritChance = critChance + 0.1  -- Add 0.1 to crit chance, as in the provided code
    local requiredDamage = 0

    -- Calculate how many shots we need to fill the crit token bucket
    local shotsNeededForTokens = 0
    if critTokenBucket < critCost then
        local missingToken = critCost - critTokenBucket
        shotsNeededForTokens = math.ceil(missingToken / weaponBaseDamage)  -- Shots needed to fill the bucket
    end

    -- Calculate how much more damage we need for crit
    local requiredTotalDamage = (criticalDmg * (2.0 * cmpCritChance + 1.0)) / cmpCritChance / 3.0
    requiredDamage = math.floor(requiredTotalDamage - totalDmg)

    -- Ensure the damage isn't negative (show zero if no more damage is required)
    if requiredDamage < 0 then
        requiredDamage = 0
    end

    -- Construct the text to show
    local data = {}

    -- If we need to fire more shots for crit token
    if critTokenBucket < critCost then
        table.insert(data, "Shots needed for crit: " .. shotsNeededForTokens)
    end

    -- Always display damage needed for crit
    if requiredDamage > 0 then
        table.insert(data, "Damage needed for crit: " .. requiredDamage)
    end

    -- Display the info text using panelX, panelY for top-left position
    local offsetY = panelY  -- Start from the top left offset

    for _, line in ipairs(data) do
        -- Different colors based on what we're displaying
        if string.find(line, "Shots needed for crit") then
            draw.Color(219, 255, 199, 255)  -- Color for shots needed (light greenrgb(198, 255, 167))
        elseif string.find(line, "Damage needed for crit") then
            draw.Color(255, 217, 217, 255)  -- Color for damage needed (light redrgb(255, 164, 164))
        end

        local txtWidth, txtHeight = draw.GetTextSize(line)
        draw.Text(panelX, offsetY, line)  -- Draw at the specified position
        offsetY = offsetY + txtHeight + 5  -- Move down for next line
    end
end)
