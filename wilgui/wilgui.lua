--[[
    wilgui - Generic Framework for Lmaobox
    GitHub - https://github.com/GNWilber/lmaobox-luas-public/main/wilgui
    Author - Wilber
    Version - 1.00
--]]

local Version = 1.00
local RepoURL = "https://raw.githubusercontent.com/GNWilber/lmaobox-luas-public/main/wilgui/wilgui.lua"

-- Auto Update Logic (Only updates if Remote Version > Local Version)
local function AutoUpdate()
    local content = http.Get(RepoURL)
    if not content or content == "" then return end
    local remoteVerStr = string.match(content, "Version%s*-%s*([%d%.]+)")
    if not remoteVerStr then return end
    
    local remoteVer = tonumber(remoteVerStr)
    if remoteVer and remoteVer > Version then
        print("[wilgui] Found newer version (" .. remoteVer .. "). Updating...")
        local f = io.open("wilgui.lua", "w")
        if f then
            f:write(content)
            f:close()
            print("[wilgui] Successfully updated! Please reload your lua script.")
        end
    end
end
AutoUpdate()

local UILib = {}
UILib.Windows = {}
UILib.Mouse = { X = 0, Y = 0, Pressed = false, Down = false, Released = false }
UILib.DragInfo = { Window = nil, Dragging = false, OffsetX = 0, OffsetY = 0, DraggingSlider = nil }

local font = draw.CreateFont('Verdana', 12, 400, FONTFLAG_CUSTOM | FONTFLAG_OUTLINE)
local fontTitle = draw.CreateFont('Verdana', 12, 700, FONTFLAG_CUSTOM | FONTFLAG_OUTLINE)

-- Called by the main script to prevent duplication issues on reload
function UILib.Clear()
    UILib.Windows = {}
end

function UILib.UpdateMouse()
    local mx, my = input.GetMousePos()
    local isDown = input.IsButtonDown(107) -- 107 is MOUSE_LEFT in Source engine
    
    UILib.Mouse.Pressed = isDown and not UILib.Mouse.Down
    UILib.Mouse.Released = not isDown and UILib.Mouse.Down
    UILib.Mouse.Down = isDown
    UILib.Mouse.X, UILib.Mouse.Y = mx, my
end

function UILib.CreateWindow(title, x, y, width, height)
    local win = {
        Title = title,
        X = x, Y = y, W = width, H = height,
        Elements = {}, Visible = true
    }

    function win:AddCheckbox(label, id, defaultState)
        table.insert(self.Elements, { Type = "Checkbox", Label = label, ID = id, Value = defaultState or false })
    end

    function win:AddSlider(label, id, min, max, defaultVal)
        table.insert(self.Elements, { Type = "Slider", Label = label, ID = id, Min = min, Max = max, Value = defaultVal or min })
    end

    function win:GetValue(id)
        for _, el in ipairs(self.Elements) do
            if el.ID == id then return el.Value end
        end
        return nil
    end

    function win:SetValue(id, val)
        for _, el in ipairs(self.Elements) do
            if el.ID == id then el.Value = val end
        end
    end
    
    table.insert(UILib.Windows, win)
    return win
end

function UILib.Render()
    if not gui.IsMenuOpen() then return end
    
    UILib.UpdateMouse()
    
    for _, win in ipairs(UILib.Windows) do
        if win.Visible then
            local titleHeight = 20
            
            -- Handle Dragging
            if UILib.Mouse.Pressed and UILib.Mouse.X >= win.X and UILib.Mouse.X <= win.X + win.W and UILib.Mouse.Y >= win.Y and UILib.Mouse.Y <= win.Y + titleHeight then
                UILib.DragInfo.Dragging = true
                UILib.DragInfo.Window = win
                UILib.DragInfo.OffsetX = UILib.Mouse.X - win.X
                UILib.DragInfo.OffsetY = UILib.Mouse.Y - win.Y
            end

            if UILib.DragInfo.Dragging and UILib.DragInfo.Window == win then
                if UILib.Mouse.Down then
                    win.X = UILib.Mouse.X - UILib.DragInfo.OffsetX
                    win.Y = UILib.Mouse.Y - UILib.DragInfo.OffsetY
                else
                    UILib.DragInfo.Dragging = false
                    UILib.DragInfo.Window = nil
                end
            end

            -- Background & Title Bar
            draw.Color(35, 35, 35, 255)
            draw.FilledRect(win.X, win.Y, win.X + win.W, win.Y + win.H)
            draw.Color(20, 20, 20, 255)
            draw.FilledRect(win.X, win.Y, win.X + win.W, win.Y + titleHeight)
            draw.Color(60, 60, 60, 255)
            draw.OutlinedRect(win.X, win.Y, win.X + win.W, win.Y + win.H)
            draw.OutlinedRect(win.X, win.Y, win.X + win.W, win.Y + titleHeight)

            -- Window Title
            draw.SetFont(fontTitle)
            draw.Color(255, 255, 255, 255)
            draw.Text(win.X + 8, win.Y + 3, win.Title)

            -- Render UI Elements
            local offsetY = win.Y + titleHeight + 10
            for _, el in ipairs(win.Elements) do
                if el.Type == "Checkbox" then
                    local boxSize = 12
                    local hovered = UILib.Mouse.X >= win.X + 10 and UILib.Mouse.X <= win.X + win.W and UILib.Mouse.Y >= offsetY and UILib.Mouse.Y <= offsetY + boxSize
                    
                    if hovered and UILib.Mouse.Pressed then
                        el.Value = not el.Value
                    end

                    draw.Color(hovered and 70 or 50, hovered and 70 or 50, hovered and 70 or 50, 255)
                    draw.FilledRect(win.X + 10, offsetY, win.X + 10 + boxSize, offsetY + boxSize)
                    draw.Color(100, 100, 100, 255)
                    draw.OutlinedRect(win.X + 10, offsetY, win.X + 10 + boxSize, offsetY + boxSize)

                    if el.Value then
                        draw.Color(120, 255, 120, 255)
                        draw.FilledRect(win.X + 12, offsetY + 2, win.X + 8 + boxSize, offsetY - 2 + boxSize)
                    end

                    draw.SetFont(font)
                    draw.Color(255, 255, 255, 255)
                    draw.Text(win.X + 30, offsetY - 1, el.Label)
                    offsetY = offsetY + 22

                elseif el.Type == "Slider" then
                    local sliderW = win.W - 20
                    local sliderH = 8
                    local hovered = UILib.Mouse.X >= win.X + 10 and UILib.Mouse.X <= win.X + 10 + sliderW and UILib.Mouse.Y >= offsetY + 15 and UILib.Mouse.Y <= offsetY + 15 + sliderH
                    
                    if hovered and UILib.Mouse.Pressed then
                        UILib.DragInfo.DraggingSlider = el
                    end
                    
                    if UILib.DragInfo.DraggingSlider == el then
                        if UILib.Mouse.Down then
                            local pct = (UILib.Mouse.X - (win.X + 10)) / sliderW
                            pct = math.max(0, math.min(1, pct))
                            el.Value = math.floor((el.Min + pct * (el.Max - el.Min)) + 0.5)
                        else
                            UILib.DragInfo.DraggingSlider = nil
                        end
                    end

                    draw.SetFont(font)
                    draw.Color(255, 255, 255, 255)
                    draw.Text(win.X + 10, offsetY, el.Label .. ": " .. tostring(el.Value))

                    draw.Color(50, 50, 50, 255)
                    draw.FilledRect(win.X + 10, offsetY + 15, win.X + 10 + sliderW, offsetY + 15 + sliderH)
                    
                    local fillW = ((el.Value - el.Min) / (el.Max - el.Min)) * sliderW
                    draw.Color(100, 150, 255, 255)
                    draw.FilledRect(win.X + 10, offsetY + 15, win.X + 10 + fillW, offsetY + 15 + sliderH)
                    draw.Color(100, 100, 100, 255)
                    draw.OutlinedRect(win.X + 10, offsetY + 15, win.X + 10 + sliderW, offsetY + 15 + sliderH)
                    
                    offsetY = offsetY + 35
                end
            end
        end
    end
end

return UILib