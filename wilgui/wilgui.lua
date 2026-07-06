--[[
    wilgui - Generic Framework for Lmaobox
    GitHub - https://github.com/GNWilber/lmaobox-luas-public/main/wilgui
    Author - Wilber (Forked from LNX)
    Version - 1.02
]]

local Version = 1.02
local RepoURL = "https://raw.githubusercontent.com/GNWilber/lmaobox-luas-public/main/wilgui/wilgui.lua"

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

local wilgui = {
    CurrentID = 1,
    Menus = {},
    Font = draw.CreateFont("Verdana", 14, 510),
    Version = Version,
    DebugInfo = false
}

-- Embedded Flags to prevent nil index errors across files
wilgui.MenuFlags = {
    None = 0,
    NoTitle = 1 << 0,
    NoBackground = 1 << 1,
    NoDrag = 1 << 2,
    AutoSize = 1 << 3,
    ShowAlways = 1 << 4,
    Popup = 1 << 5
}

wilgui.ItemFlags = {
    None = 0,
    FullWidth = 1 << 0,
    Active = 1 << 1
}

local MouseReleased = false
local DragID = 0
local DragOffset = { 0, 0 }

local function MouseInBounds(pX, pY, pX2, pY2)
    local mX = input.GetMousePos()[1]
    local mY = input.GetMousePos()[2]
    return (mX > pX and mX < pX2 and mY > pY and mY < pY2)
end

local LastMouseState = false
local function UpdateMouseState()
    local mouseState = input.IsButtonDown(MOUSE_LEFT or 107)
    MouseReleased = (mouseState == false and LastMouseState)
    LastMouseState = mouseState
end

local function Clamp(n, low, high) return math.min(math.max(n, low), high) end

local function SetColorStyle(color)
    local alpha = color[4] or 255
    draw.Color(color[1], color[2], color[3], alpha)
end

--[[ Component Class ]]
local Component = { ID = 0, Visible = true, Flags = wilgui.ItemFlags.None }
Component.__index = Component
function Component.New() return setmetatable({ Visible = true, Flags = wilgui.ItemFlags.None }, Component) end
function Component:SetVisible(state) self.Visible = state end

--[[ Checkbox ]]
local Checkbox = { Label = "Checkbox", Value = false }
Checkbox.__index = Checkbox
setmetatable(Checkbox, Component)
function Checkbox.New(label, value, flags)
    local self = setmetatable({}, Checkbox)
    self.ID = wilgui.CurrentID; self.Label = label; self.Value = value or false; self.Flags = flags or wilgui.ItemFlags.None
    wilgui.CurrentID = wilgui.CurrentID + 1
    return self
end
function Checkbox:GetValue() return self.Value end
function Checkbox:Render(menu)
    local lblWidth, lblHeight = draw.GetTextSize(self.Label)
    local chkSize = math.floor(lblHeight * 1.4)
    if MouseReleased and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + chkSize + menu.Style.Space + lblWidth, menu.Y + menu.Cursor.Y + chkSize) then
        self.Value = not self.Value
    end
    if self.Value then draw.Color(70, 190, 50, 255) else draw.Color(180, 60, 60, 250) end
    draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + chkSize, menu.Y + menu.Cursor.Y + chkSize)
    draw.SetFont(wilgui.Font)
    SetColorStyle(menu.Style.Text)
    draw.Text(menu.X + menu.Cursor.X + chkSize + menu.Style.Space, math.floor(menu.Y + menu.Cursor.Y + (chkSize / 2) - (lblHeight / 2)), self.Label)
    menu.Cursor.Y = menu.Cursor.Y + chkSize + menu.Style.Space
end

--[[ Slider ]]
local Slider = { Label = "Slider", Min = 0, Max = 100, Value = 0 }
Slider.__index = Slider
setmetatable(Slider, Component)
function Slider.New(label, min, max, value, flags)
    local self = setmetatable({}, Slider)
    self.ID = wilgui.CurrentID; self.Label = label; self.Min = min; self.Max = max; self.Value = value or min; self.Flags = flags or wilgui.ItemFlags.None
    wilgui.CurrentID = wilgui.CurrentID + 1
    return self
end
function Slider:GetValue() return self.Value end
function Slider:Render(menu)
    local lblWidth, lblHeight = draw.GetTextSize(self.Label .. ": " .. self.Value)
    local sliderWidth = menu.Width - (menu.Style.Space * 2)
    local sliderHeight = lblHeight + (menu.Style.Space * 2)
    local dragX = math.floor(((self.Value - self.Min) / math.abs(self.Max - self.Min)) * sliderWidth)

    SetColorStyle(menu.Style.Item)
    if DragID == 0 and MouseInBounds(menu.X + menu.Cursor.X - 4, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + sliderWidth + 8, menu.Y + menu.Cursor.Y + sliderHeight) then
        SetColorStyle(menu.Style.ItemHover)
        if input.IsButtonDown(MOUSE_LEFT or 107) then
            dragX = Clamp(input.GetMousePos()[1] - (menu.X + menu.Cursor.X), 0, sliderWidth)
            self.Value = (math.floor((dragX / sliderWidth) * math.abs(self.Max - self.Min))) + self.Min
        end
    end

    draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + sliderWidth, menu.Y + menu.Cursor.Y + sliderHeight)
    SetColorStyle(menu.Style.Highlight)
    draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + dragX, menu.Y + menu.Cursor.Y + sliderHeight)
    draw.SetFont(wilgui.Font)
    SetColorStyle(menu.Style.Text)
    draw.Text(math.floor(menu.X + menu.Cursor.X + (sliderWidth / 2) - (lblWidth / 2)), math.floor(menu.Y + menu.Cursor.Y + (sliderHeight / 2) - (lblHeight / 2)), self.Label .. ": " .. self.Value)
    menu.Cursor.Y = menu.Cursor.Y + sliderHeight + menu.Style.Space
end

--[[ Menu Class ]]
local Menu = {}
local MetaMenu = { __index = Menu }
function Menu.New(title, flags)
    local self = setmetatable({}, MetaMenu)
    self.ID = wilgui.CurrentID; self.Title = title; self.Components = {}; self.Visible = true
    self.X = 100; self.Y = 100; self.Width = 220; self.Height = 200; self.Cursor = { X = 0, Y = 0 }
    self.Style = {
        Space = 4, Outline = true, WindowBg = { 30, 30, 30, 255 }, TitleBg = { 55, 100, 215, 255 },
        Text = { 255, 255, 255, 255 }, Item = { 50, 50, 50, 255 }, ItemHover = { 65, 65, 65, 255 },
        ItemActive = { 80, 80, 80, 255 }, Highlight = { 180, 180, 180, 100 }
    }
    self.Flags = flags or 0
    wilgui.CurrentID = wilgui.CurrentID + 1
    return self
end
function Menu:AddComponent(component) table.insert(self.Components, component); return component end

--[[ wilgui Core ]]
function wilgui.Clear() wilgui.Menus = {} end 
function wilgui.Create(title, flags)
    local menu = Menu.New(title, flags)
    table.insert(wilgui.Menus, menu)
    return menu
end
function wilgui.Checkbox(label, value, flags) return Checkbox.New(label, value, flags) end
function wilgui.Slider(label, min, max, value, flags) return Slider.New(label, min, max, value, flags) end

function wilgui.Draw()
    if gui.GetValue("clean screenshots") == 1 and engine.IsTakingScreenshot() then return end
    UpdateMouseState()

    for _, vMenu in pairs(wilgui.Menus) do
        if not vMenu.Visible then goto continue end
        if gui.IsMenuOpen() == false and (vMenu.Flags & wilgui.MenuFlags.ShowAlways == 0) then return end

        local tbHeight = 20
        if vMenu.Flags & wilgui.MenuFlags.NoDrag == 0 then
            local mX, mY = input.GetMousePos()[1], input.GetMousePos()[2]
            if DragID == vMenu.ID then
                if input.IsButtonDown(MOUSE_LEFT or 107) then
                    vMenu.X, vMenu.Y = mX - DragOffset[1], mY - DragOffset[2]
                else DragID = 0 end
            elseif DragID == 0 then
                if input.IsButtonDown(MOUSE_LEFT or 107) and MouseInBounds(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + tbHeight) then
                    DragOffset = { mX - vMenu.X, mY - vMenu.Y }; DragID = vMenu.ID
                end
            end
        end

        SetColorStyle(vMenu.Style.WindowBg)
        draw.FilledRect(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + vMenu.Height)
        if vMenu.Style.Outline then
            SetColorStyle(vMenu.Style.TitleBg)
            draw.OutlinedRect(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + vMenu.Height)
        end

        SetColorStyle(vMenu.Style.TitleBg)
        draw.FilledRect(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + tbHeight)
        draw.SetFont(wilgui.Font)
        SetColorStyle(vMenu.Style.Text)
        local titleWidth, titleHeight = draw.GetTextSize(vMenu.Title)
        draw.Text(math.floor(vMenu.X + (vMenu.Width / 2) - (titleWidth / 2)), vMenu.Y + math.floor((tbHeight / 2) - (titleHeight / 2)), vMenu.Title)
        vMenu.Cursor.Y = tbHeight

        vMenu.Cursor.Y = vMenu.Cursor.Y + vMenu.Style.Space
        vMenu.Cursor.X = vMenu.Style.Space
        for _, vComp in pairs(vMenu.Components) do
            if vComp.Visible then vComp:Render(vMenu) end
        end

        if vMenu.Flags & wilgui.MenuFlags.AutoSize ~= 0 then vMenu.Height = vMenu.Cursor.Y end
        ::continue::
    end
end

callbacks.Register("Draw", "Draw_WilGUI", wilgui.Draw)
return wilgui