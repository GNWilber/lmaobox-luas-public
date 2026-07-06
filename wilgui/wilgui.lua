--[[
    wilgui - Generic Framework for Lmaobox
    GitHub - https://github.com/GNWilber/lmaobox-luas-public/main/wilgui
    Author - Wilber (Forked from LNX)
    Version - 1.07
]]

local Version = 1.07
local RepoURL = "https://raw.githubusercontent.com/GNWilber/lmaobox-luas-public/main/wilgui/wilgui.lua"

pcall(function()
    local content = http.Get(RepoURL)
    if not content or content == "" then return end
    local remoteVerStr = string.match(content, "Version%s*-%s*([%d%.]+)")
    if not remoteVerStr then return end
    local remoteVer = tonumber(remoteVerStr)
    if remoteVer and remoteVer > Version then
        print("[wilgui] Found newer version (" .. remoteVer .. "). Updating...")
        local f = io.open("wilgui.lua", "w")
        if f then f:write(content); f:close(); print("[wilgui] Successfully updated! Please reload your lua scripts.") end
    end
end)

local wilgui = {
    CurrentID = 1, Menus = {},
    Font = draw.CreateFont("Verdana", 14, 510),
    Version = Version, DebugInfo = false
}

wilgui.MenuFlags = {
    None = 0, NoTitle = 1 << 0, NoBackground = 1 << 1, NoDrag = 1 << 2,
    AutoSize = 1 << 3, ShowAlways = 1 << 4, Popup = 1 << 5
}

wilgui.ItemFlags = { None = 0, FullWidth = 1 << 0, Active = 1 << 1 }

local MouseReleased, DragID, DragOffset, PopupOpen = false, 0, {0, 0}, false

local InputMap = {}
for i = 0, 9 do InputMap[i + 1] = tostring(i) end
for i = 65, 90 do InputMap[i - 54] = string.char(i) end

local function GetCurrentKey()
    for i = 0, 106 do if input.IsButtonDown(i) then return i end end
    return nil
end

local function GetKeyName(key, specialKeys)
    if key == nil then return nil end
    if InputMap[key] then return InputMap[key]
    elseif key == KEY_SPACE then return "SPACE"
    elseif key == KEY_BACKSPACE then return "BACKSPACE"
    elseif key == KEY_COMMA then return ","
    elseif key == KEY_PERIOD then return "."
    elseif key == KEY_MINUS then return "-" end
    if specialKeys == false then return nil end

    if key == KEY_LCONTROL then return "LCTRL" elseif key == KEY_RCONTROL then return "RCTRL"
    elseif key == KEY_LALT then return "LALT" elseif key == KEY_RALT then return "RALT"
    elseif key == KEY_LSHIFT then return "LSHIFT" elseif key == KEY_RSHIFT then return "RSHIFT"
    elseif key == KEY_ENTER then return "ENTER" elseif key == KEY_UP then return "UP"
    elseif key == KEY_LEFT then return "LEFT" elseif key == KEY_DOWN then return "DOWN"
    elseif key == KEY_RIGHT then return "RIGHT"
    elseif key >= 37 and key <= 46 then return "KP" .. (key - 37)
    elseif key >= 92 and key <= 103 then return "F" .. (key - 91) end
    return nil
end

local function MouseInBounds(pX, pY, pX2, pY2)
    local mX, mY = input.GetMousePos()[1], input.GetMousePos()[2]
    return (mX > pX and mX < pX2 and mY > pY and mY < pY2)
end

local LastMouseState = false
local function UpdateMouseState()
    local mouseState = input.IsButtonDown(MOUSE_LEFT or 107)
    MouseReleased = (mouseState == false and LastMouseState)
    LastMouseState = mouseState
end

local function Clamp(n, low, high) return math.min(math.max(n, low), high) end
local function SetColorStyle(color) draw.Color(color[1], color[2], color[3], color[4] or 255) end

--[[ Component Base Class ]]
local Component = { ID = 0, Visible = true, Flags = wilgui.ItemFlags.None }
Component.__index = Component
function Component.New() return setmetatable({ Visible = true, Flags = wilgui.ItemFlags.None }, Component) end
function Component:SetVisible(state) self.Visible = state end

--[[ ColumnBreak (NEW) ]]
local ColumnBreak = { IsColumnBreak = true }
ColumnBreak.__index = ColumnBreak
setmetatable(ColumnBreak, Component)
function ColumnBreak.New()
    local self = setmetatable({}, ColumnBreak)
    self.ID = wilgui.CurrentID; wilgui.CurrentID = wilgui.CurrentID + 1; self.IsColumnBreak = true
    return self
end
function wilgui.ColumnBreak() return ColumnBreak.New() end

--[[ Label ]]
local Label = { Text = "Label" }
Label.__index = Label
setmetatable(Label, Component)
function Label.New(label, flags)
    local self = setmetatable({}, Label)
    self.ID = wilgui.CurrentID; self.Text = label; self.Flags = flags or wilgui.ItemFlags.None
    wilgui.CurrentID = wilgui.CurrentID + 1; return self
end
function Label:Render(menu)
    SetColorStyle(menu.Style.Text); draw.SetFont(wilgui.Font)
    draw.Text(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, self.Text)
    menu.Cursor.Y = menu.Cursor.Y + draw.GetTextSize(self.Text) + menu.Style.Space
end

--[[ Checkbox ]]
local Checkbox = { Label = "Checkbox", Value = false }
Checkbox.__index = Checkbox
setmetatable(Checkbox, Component)
function Checkbox.New(label, value, flags)
    local self = setmetatable({}, Checkbox)
    self.ID = wilgui.CurrentID; self.Label = label; self.Value = value or false; self.Flags = flags or wilgui.ItemFlags.None
    wilgui.CurrentID = wilgui.CurrentID + 1; return self
end
function Checkbox:GetValue() return self.Value end
function Checkbox:IsChecked() return self.Value == true end
function Checkbox:Render(menu)
    local lblWidth, lblHeight = draw.GetTextSize(self.Label)
    local chkSize = math.floor(lblHeight * 1.4)
    if (PopupOpen == false or menu:IsPopup()) and MouseReleased and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + chkSize + menu.Style.Space + lblWidth, menu.Y + menu.Cursor.Y + chkSize) then
        self.Value = not self.Value
    end
    if self.Value then draw.Color(70, 190, 50, 255) else draw.Color(180, 60, 60, 250) end
    draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + chkSize, menu.Y + menu.Cursor.Y + chkSize)
    draw.SetFont(wilgui.Font); SetColorStyle(menu.Style.Text)
    draw.Text(menu.X + menu.Cursor.X + chkSize + menu.Style.Space, math.floor(menu.Y + menu.Cursor.Y + (chkSize / 2) - (lblHeight / 2)), self.Label)
    menu.Cursor.Y = menu.Cursor.Y + chkSize + menu.Style.Space
end

--[[ Button ]]
local Button = { Label = "Button", Callback = nil }
Button.__index = Button
setmetatable(Button, Component)
function Button.New(label, callback, flags)
    local self = setmetatable({}, Button)
    self.ID = wilgui.CurrentID; self.Label = label; self.Callback = callback; self.Flags = flags or wilgui.ItemFlags.None
    wilgui.CurrentID = wilgui.CurrentID + 1; return self
end
function Button:Render(menu)
    local lblWidth, lblHeight = draw.GetTextSize(self.Label)
    local btnWidth = (self.Flags & wilgui.ItemFlags.FullWidth ~= 0) and (menu.ColumnWidth - menu.Style.Space * 2) or (lblWidth + menu.Style.Space * 4)
    local btnHeight = lblHeight + (menu.Style.Space * 2)
    
    if self.Flags & wilgui.ItemFlags.Active == 0 then SetColorStyle(menu.Style.Item) else SetColorStyle(menu.Style.ItemActive) end
    if (PopupOpen == false or menu:IsPopup()) and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + btnWidth, menu.Y + menu.Cursor.Y + btnHeight) then
        SetColorStyle(input.IsButtonDown(MOUSE_LEFT or 107) and menu.Style.ItemActive or menu.Style.ItemHover)
        if MouseReleased and self.Callback then self.Callback() end
    end
    draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + btnWidth, menu.Y + menu.Cursor.Y + btnHeight)
    SetColorStyle(menu.Style.Text)
    draw.Text(math.floor(menu.X + menu.Cursor.X + (btnWidth / 2) - (lblWidth / 2)), math.floor(menu.Y + menu.Cursor.Y + (btnHeight / 2) - (lblHeight / 2)), self.Label)
    menu.Cursor.Y = menu.Cursor.Y + btnHeight + menu.Style.Space
end

--[[ Slider ]]
local Slider = { Label = "Slider", Min = 0, Max = 100, Value = 0 }
Slider.__index = Slider
setmetatable(Slider, Component)
function Slider.New(label, min, max, value, flags)
    local self = setmetatable({}, Slider)
    self.ID = wilgui.CurrentID; self.Label = label; self.Min = min; self.Max = max; self.Value = value or min; self.Flags = flags or wilgui.ItemFlags.None
    wilgui.CurrentID = wilgui.CurrentID + 1; return self
end
function Slider:GetValue() return self.Value end
function Slider:Render(menu)
    local lblWidth, lblHeight = draw.GetTextSize(self.Label .. ": " .. self.Value)
    local sliderWidth = menu.ColumnWidth - (menu.Style.Space * 2)
    local sliderHeight = lblHeight + (menu.Style.Space * 2)
    local dragX = math.floor(((self.Value - self.Min) / math.abs(self.Max - self.Min)) * sliderWidth)

    SetColorStyle(menu.Style.Item)
    if (PopupOpen == false or menu:IsPopup()) and DragID == 0 and MouseInBounds(menu.X + menu.Cursor.X - 4, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + sliderWidth + 8, menu.Y + menu.Cursor.Y + sliderHeight) then
        SetColorStyle(menu.Style.ItemHover)
        if input.IsButtonDown(MOUSE_LEFT or 107) then
            dragX = Clamp(input.GetMousePos()[1] - (menu.X + menu.Cursor.X), 0, sliderWidth)
            self.Value = (math.floor((dragX / sliderWidth) * math.abs(self.Max - self.Min))) + self.Min
        end
    end

    draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + sliderWidth, menu.Y + menu.Cursor.Y + sliderHeight)
    SetColorStyle(menu.Style.Highlight)
    draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + dragX, menu.Y + menu.Cursor.Y + sliderHeight)
    draw.SetFont(wilgui.Font); SetColorStyle(menu.Style.Text)
    draw.Text(math.floor(menu.X + menu.Cursor.X + (sliderWidth / 2) - (lblWidth / 2)), math.floor(menu.Y + menu.Cursor.Y + (sliderHeight / 2) - (lblHeight / 2)), self.Label .. ": " .. self.Value)
    menu.Cursor.Y = menu.Cursor.Y + sliderHeight + menu.Style.Space
end

--[[ Textbox ]]
local Textbox = { Label = "Textbox", Value = "", _LastKey = nil }
Textbox.__index = Textbox
setmetatable(Textbox, Component)
function Textbox.New(label, value, flags)
    local self = setmetatable({}, Textbox)
    self.ID = wilgui.CurrentID; self.Label = label; self.Value = value or ""; self.Flags = flags or wilgui.ItemFlags.None
    wilgui.CurrentID = wilgui.CurrentID + 1; return self
end
function Textbox:GetValue() return self.Value end
function Textbox:Render(menu)
    local lblWidth, lblHeight = draw.GetTextSize(self.Value)
    local boxWidth = menu.ColumnWidth - (menu.Style.Space * 2)
    local boxHeight = 20

    SetColorStyle(menu.Style.Item)
    if (PopupOpen == false or menu:IsPopup()) and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + boxWidth, menu.Y + menu.Cursor.Y + boxHeight) then
        SetColorStyle(menu.Style.ItemHover)
        local key = GetKeyName(GetCurrentKey(), false)
        if not key and self._LastKey then
            if self._LastKey == "SPACE" then self.Value = self.Value .. " "
            elseif self._LastKey == "BACKSPACE" then self.Value = self.Value:sub(1, -2)
            elseif (#self._LastKey == 1) and (lblWidth < boxWidth - (menu.Style.Space * 2)) then
                if input.IsButtonDown(KEY_LSHIFT) or input.IsButtonDown(KEY_RSHIFT) then
                    if self._LastKey == "9" then self.Value = self.Value .. "("
                    elseif self._LastKey == "0" then self.Value = self.Value .. ")"
                    elseif self._LastKey == "7" then self.Value = self.Value .. "&"
                    else self.Value = self.Value .. string.upper(self._LastKey) end
                else
                    self.Value = self.Value .. string.lower(self._LastKey)
                end
            end
            self._LastKey = nil
        end
        self._LastKey = key
    end

    draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + boxWidth, menu.Y + menu.Cursor.Y + boxHeight)
    draw.SetFont(wilgui.Font)
    if self.Value == "" then
        draw.Color(180, 180, 180, 255)
        draw.Text(menu.X + menu.Cursor.X + menu.Style.Space, math.floor(menu.Y + menu.Cursor.Y + (boxHeight / 2) - (lblHeight / 2)), self.Label)
    else
        SetColorStyle(menu.Style.Text)
        draw.Text(menu.X + menu.Cursor.X + menu.Style.Space, math.floor(menu.Y + menu.Cursor.Y + (boxHeight / 2) - (lblHeight / 2)), self.Value)
    end
    menu.Cursor.Y = menu.Cursor.Y + boxHeight + menu.Style.Space
end

--[[ Keybind ]]
local Keybind = { Label = "Keybind", Key = KEY_NONE, KeyName = "NONE", _IsEditing = false }
Keybind.__index = Keybind
setmetatable(Keybind, Component)
function Keybind.New(label, key, flags)
    local self = setmetatable({}, Keybind)
    self.ID = wilgui.CurrentID; self.Label = label; self.Key = key; self.KeyName = GetKeyName(key, true) or "NONE"; self.Flags = flags or wilgui.ItemFlags.None
    wilgui.CurrentID = wilgui.CurrentID + 1; return self
end
function Keybind:GetValue() return self.Key end
function Keybind:Render(menu)
    local btnLabel = self.Label .. ": " .. self.KeyName
    if self._IsEditing then
        SetColorStyle(menu.Style.ItemActive); btnLabel = self.Label .. ": [...]"
        local currentKey = GetCurrentKey()
        if currentKey ~= nil then
            if currentKey == KEY_ESCAPE then self.Key = KEY_NONE; self.KeyName = "NONE"
            else self.Key = currentKey; self.KeyName = GetKeyName(currentKey, true) or currentKey end
            self._IsEditing = false
        end
    end

    local lblWidth, lblHeight = draw.GetTextSize(btnLabel)
    local btnWidth = (self.Flags & wilgui.ItemFlags.FullWidth ~= 0) and (menu.ColumnWidth - menu.Style.Space * 2) or (lblWidth + menu.Style.Space * 4)
    local btnHeight = lblHeight + (menu.Style.Space * 2)

    if self.Flags & wilgui.ItemFlags.Active == 0 then SetColorStyle(menu.Style.Item) else SetColorStyle(menu.Style.ItemActive) end
    if (PopupOpen == false or menu:IsPopup()) and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + btnWidth, menu.Y + menu.Cursor.Y + btnHeight) then
        SetColorStyle(input.IsButtonDown(MOUSE_LEFT or 107) and menu.Style.ItemActive or menu.Style.ItemHover)
        if MouseReleased then self._IsEditing = not self._IsEditing end
    end

    draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + btnWidth, menu.Y + menu.Cursor.Y + btnHeight)
    SetColorStyle(menu.Style.Text)
    draw.Text(math.floor(menu.X + menu.Cursor.X + (btnWidth / 2) - (lblWidth / 2)), math.floor(menu.Y + menu.Cursor.Y + (btnHeight / 2) - (lblHeight / 2)), btnLabel)
    menu.Cursor.Y = menu.Cursor.Y + btnHeight + menu.Style.Space
end

--[[ Combobox ]]
local Combobox = { Label = "Combo", Options = nil, Selected = nil, SelectedIndex = 1, _Child = nil }
Combobox.__index = Combobox
setmetatable(Combobox, Component)
function Combobox.New(label, options, flags)
    local self = setmetatable({}, Combobox)
    self.ID = wilgui.CurrentID; self.Label = label .. " | V"; self.Options = options; self.Selected = options[1]; self.Flags = flags or wilgui.ItemFlags.None
    
    self._Child = wilgui.CreatePopup(self)
    self._Child:SetVisible(false)
    self._Child.Style.Space = 3
    for i, vLabel in ipairs(self.Options) do
        local actFlag = (self.SelectedIndex == i) and wilgui.ItemFlags.Active or wilgui.ItemFlags.None
        self._Child:AddComponent(Button.New(vLabel, function()
            self.Selected = vLabel; self.SelectedIndex = i; self:UpdateButtons(); self:SetOpen(false)
        end, wilgui.ItemFlags.FullWidth | actFlag))
    end
    wilgui.CurrentID = wilgui.CurrentID + 1; return self
end
function Combobox:UpdateButtons()
    for i, vComponent in ipairs(self._Child.Components) do
        vComponent.Flags = (vComponent.Label == self.Selected) and (wilgui.ItemFlags.FullWidth | wilgui.ItemFlags.Active) or wilgui.ItemFlags.FullWidth
    end
end
function Combobox:GetSelectedIndex() return self.SelectedIndex end
function Combobox:Select(index) self.SelectedIndex = index; self.Selected = self.Options[index]; self:UpdateButtons() end
function Combobox:IsOpen() return self._Child.Visible end
function Combobox:SetOpen(state) if state == false and not self:IsOpen() then return end; self._Child:SetVisible(state); PopupOpen = state end
function Combobox:Render(menu)
    local lblWidth, lblHeight = draw.GetTextSize(self.Label)
    local cmbWidth = (self.Flags & wilgui.ItemFlags.FullWidth ~= 0) and (menu.ColumnWidth - menu.Style.Space * 2) or (lblWidth + menu.Style.Space * 4)
    local cmbHeight = lblHeight + (menu.Style.Space * 2)

    SetColorStyle(menu.Style.Item)
    if (self:IsOpen() or PopupOpen == false or menu:IsPopup()) and MouseInBounds(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + cmbWidth, menu.Y + menu.Cursor.Y + cmbHeight) then
        SetColorStyle(input.IsButtonDown(MOUSE_LEFT or 107) and menu.Style.ItemActive or menu.Style.ItemHover)
        if MouseReleased then self:SetOpen(not self:IsOpen()) end
    end

    if self:IsOpen() then
        self._Child.Width = cmbWidth; self._Child.X = menu.X + menu.Cursor.X; self._Child.Y = menu.Y + menu.Cursor.Y + cmbHeight
        SetColorStyle(menu.Style.ItemActive)
    end

    draw.FilledRect(menu.X + menu.Cursor.X, menu.Y + menu.Cursor.Y, menu.X + menu.Cursor.X + cmbWidth, menu.Y + menu.Cursor.Y + cmbHeight)
    SetColorStyle(menu.Style.Text)
    draw.Text(math.floor(menu.X + menu.Cursor.X + (cmbWidth / 2) - (lblWidth / 2)), math.floor(menu.Y + menu.Cursor.Y + (cmbHeight / 2) - (lblHeight / 2)), self.Label)
    menu.Cursor.Y = menu.Cursor.Y + cmbHeight + menu.Style.Space
end
function Combobox:Remove() self:SetOpen(false); wilgui.RemoveMenu(self._Child) end

--[[ Menu Class ]]
local Menu = {}
local MetaMenu = { __index = Menu }
function Menu.New(title, flags)
    local self = setmetatable({}, MetaMenu)
    self.ID = wilgui.CurrentID; self.Title = title; self.Components = {}; self.Visible = true
    self.X = 100; self.Y = 100; self.Width = 220; self.ColumnWidth = 220; self.Height = 200; self.Cursor = { X = 0, Y = 0 }
    self.Style = {
        Space = 4, Outline = true, WindowBg = { 30, 30, 30, 255 }, TitleBg = { 55, 100, 215, 255 },
        Text = { 255, 255, 255, 255 }, Item = { 50, 50, 50, 255 }, ItemHover = { 65, 65, 65, 255 },
        ItemActive = { 80, 80, 80, 255 }, Highlight = { 180, 180, 180, 100 }
    }
    self.Flags = flags or 0; wilgui.CurrentID = wilgui.CurrentID + 1; return self
end
function Menu:SetVisible(state) self.Visible = state end
function Menu:IsPopup() return self.Flags & wilgui.MenuFlags.Popup ~= 0 end
function Menu:SetPosition(x, y) self.X = x; self.Y = y end
function Menu:AddComponent(component) table.insert(self.Components, component); return component end
function Menu:RemoveComponent(component)
    for k, vComp in pairs(self.Components) do
        if vComp.ID == component.ID then
            if vComp.Remove then vComp:Remove() end
            table.remove(self.Components, k); return
        end
    end
end
function Menu:Remove()
    for k, vComp in pairs(self.Components) do
        if vComp.Remove then vComp:Remove() end
        self.Components[k] = nil
    end
end

--[[ wilgui Core ]]
function wilgui.Clear() wilgui.Menus = {}; PopupOpen = false end 
function wilgui.RemoveMenu(menu)
    for i, vMenu in ipairs(wilgui.Menus) do
        if vMenu.ID == menu.ID then vMenu:Remove(); table.remove(wilgui.Menus, i); DragID = 0; return end
    end
end
function wilgui.Create(title, flags)
    local menu = Menu.New(title, flags)
    table.insert(wilgui.Menus, menu); return menu
end
function wilgui.CreatePopup(owner, flags)
    flags = (flags or wilgui.MenuFlags.None) | wilgui.MenuFlags.Popup | wilgui.MenuFlags.NoTitle | wilgui.MenuFlags.NoDrag | wilgui.MenuFlags.AutoSize
    local popup = Menu.New("Popup", flags)
    popup:SetVisible(false); popup.Style.TitleBg = popup.Style.ItemActive; popup._Owner = owner
    table.insert(wilgui.Menus, popup); return popup
end

function wilgui.Label(text, flags) return Label.New(text, flags) end
function wilgui.Checkbox(label, value, flags) return Checkbox.New(label, value, flags) end
function wilgui.Button(label, cb, flags) return Button.New(label, cb, flags) end
function wilgui.Slider(label, min, max, value, flags) return Slider.New(label, min, max, value, flags) end
function wilgui.Textbox(label, value, flags) return Textbox.New(label, value, flags) end
function wilgui.Keybind(label, key, flags) return Keybind.New(label, key, flags) end
function wilgui.Combo(label, options, flags) return Combobox.New(label, options, flags) end

function wilgui.Draw()
    if gui.GetValue("clean screenshots") == 1 and engine.IsTakingScreenshot() then return end
    UpdateMouseState()

    for _, vMenu in pairs(wilgui.Menus) do
        if not vMenu.Visible then goto continue end
        if gui.IsMenuOpen() == false and (vMenu.Flags & wilgui.MenuFlags.ShowAlways == 0) then return end

        local tbHeight = 20
        
        -- Screen Boundaries Pre-Calculation
        local columns = 1
        for _, vComp in pairs(vMenu.Components) do
            if vComp.Visible and vComp.IsColumnBreak then columns = columns + 1 end
        end
        if vMenu.Flags & wilgui.MenuFlags.AutoSize ~= 0 then
            vMenu.Width = (vMenu.ColumnWidth * columns) + (vMenu.Style.Space * (columns + 1))
        end

        -- Clamping and Dragging
        if vMenu.Flags & wilgui.MenuFlags.NoDrag == 0 then
            local mX, mY = input.GetMousePos()[1], input.GetMousePos()[2]
            if DragID == vMenu.ID then
                if input.IsButtonDown(MOUSE_LEFT or 107) then vMenu.X, vMenu.Y = mX - DragOffset[1], mY - DragOffset[2] else DragID = 0 end
            elseif DragID == 0 then
                if input.IsButtonDown(MOUSE_LEFT or 107) and MouseInBounds(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + tbHeight) then
                    DragOffset = { mX - vMenu.X, mY - vMenu.Y }; DragID = vMenu.ID
                end
            end
        end

        local screenW, screenH = draw.GetScreenSize()
        if screenW and screenH then
            vMenu.X = math.max(0, math.min(vMenu.X, screenW - vMenu.Width))
            vMenu.Y = math.max(0, math.min(vMenu.Y, screenH - tbHeight))
        end

        if vMenu.Flags & wilgui.MenuFlags.NoBackground == 0 then
            SetColorStyle(vMenu.Style.WindowBg)
            draw.FilledRect(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + vMenu.Height)
            if vMenu.Style.Outline then SetColorStyle(vMenu.Style.TitleBg); draw.OutlinedRect(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + vMenu.Height) end
        end

        if vMenu.Flags & wilgui.MenuFlags.NoTitle == 0 then
            SetColorStyle(vMenu.Style.TitleBg)
            draw.FilledRect(vMenu.X, vMenu.Y, vMenu.X + vMenu.Width, vMenu.Y + tbHeight)
            draw.SetFont(wilgui.Font); SetColorStyle(vMenu.Style.Text)
            local titleWidth, titleHeight = draw.GetTextSize(vMenu.Title)
            draw.Text(math.floor(vMenu.X + (vMenu.Width / 2) - (titleWidth / 2)), vMenu.Y + math.floor((tbHeight / 2) - (titleHeight / 2)), vMenu.Title)
            vMenu.Cursor.Y = tbHeight
        end

        vMenu.Cursor.Y = vMenu.Cursor.Y + vMenu.Style.Space
        vMenu.Cursor.X = vMenu.Style.Space
        local startY = vMenu.Cursor.Y
        local maxCursorY = startY

        for _, vComp in pairs(vMenu.Components) do
            if vComp.Visible then 
                if vComp.IsColumnBreak then
                    vMenu.Cursor.Y = startY
                    vMenu.Cursor.X = vMenu.Cursor.X + vMenu.ColumnWidth + vMenu.Style.Space
                else
                    vComp:Render(vMenu)
                    if vMenu.Cursor.Y > maxCursorY then maxCursorY = vMenu.Cursor.Y end
                end
            end
        end

        if vMenu.Flags & wilgui.MenuFlags.AutoSize ~= 0 then vMenu.Height = maxCursorY end
        vMenu.Cursor = { X = 0, Y = 0 }
        ::continue::
    end
end

callbacks.Register("Draw", "Draw_WilGUI", wilgui.Draw)
return wilgui