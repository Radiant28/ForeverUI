local addonName, ui = ...
local ru = ui.russian
local white = "Interface\\Buttons\\WHITE8X8"
local edge = "Interface\\AddOns\\ForeverUI\\Art\\UnitBar-Edge"
local points = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local pointNames = ru and { "Сверху слева", "Сверху", "Сверху справа", "Слева", "По центру", "Справа",
    "Снизу слева", "Снизу", "Снизу справа" }
    or { "Top left", "Top", "Top right", "Left", "Center", "Right", "Bottom left", "Bottom", "Bottom right" }
local outlines = { "", "OUTLINE", "THICKOUTLINE" }
local outlineNames = ru and { "Без обводки", "Тонкая", "Толстая" } or { "None", "Thin", "Thick" }
local sizes = {}
local bagSizes = { ru and "Авто" or "Auto" }
for size = 9, 24 do
    sizes[#sizes + 1] = size
    bagSizes[#bagSizes + 1] = size
end
local gold = { 1, 0.89, 0.6 }
local green = { 0.35, 1, 0.2 }
local defaults = {
    level = { point = 2, x = 0, y = -2, size = 5, color = gold },
    durability = { point = 8, x = 0, y = 2, size = 3, color = green, durability = true },
    bagsLevel = { point = 2, x = 0, y = -2, size = 1, color = gold, bag = true },
    bagsDurability = { point = 7, x = 2, y = 2, size = 1, color = green, bag = true, durability = true },
}

local function labelColor(settings, key)
    local rgb = settings[key .. "Color"]
    if type(rgb) == "table" then
        for i = 1, 3 do
            local value = rgb[i]
            if type(value) ~= "number" or not (value >= 0 and value <= 1) then return defaults[key].color end
        end
        return rgb
    end
    return defaults[key].color
end

function ui.DurabilityLabelColor(key)
    local settings = ui.Settings()
    if settings[key .. "AutoColor"] == false then return labelColor(settings, key) end
end

function ui.ItemLabelStyle(key, cell)
    local settings, spec = ui.Settings(), defaults[key]
    local choices = spec.bag and bagSizes or sizes
    local size = choices[settings[key .. "Size"]] or choices[spec.size]
    if type(size) ~= "number" then size = math.min(13, math.floor(cell / 3)) end
    local x, y = settings[key .. "X"], settings[key .. "Y"]
    return {
        point = points[settings[key .. "Point"]] or points[spec.point],
        x = type(x) == "number" and x >= -40 and x <= 40 and x or spec.x,
        y = type(y) == "number" and y >= -40 and y <= 40 and y or spec.y,
        font = ui.MediaPath("font", settings[key .. "Font"], true) or STANDARD_TEXT_FONT,
        size = size,
        outline = outlines[settings[key .. "Outline"]] or "OUTLINE",
        color = not spec.durability and labelColor(settings, key) or nil,
    }
end

function ui.ApplyItemLabel(label, button, style)
    label:ClearAllPoints()
    label:SetPoint(style.point, button, style.point, style.x, style.y)
    label:SetFont(style.font, style.size, style.outline)
    if style.color then label:SetTextColor(unpack(style.color)) end
end

function ui.SetDurabilityLabel(label, current, maximum, color)
    if not (current and maximum and maximum > 0) then
        label:SetText("")
        return
    end
    local fraction = math.max(0, math.min(1, current / maximum))
    label:SetFormattedText("%d%%", math.floor(fraction * 100 + 0.5))
    if color then
        label:SetTextColor(unpack(color))
    else
        label:SetTextColor(math.min(1, 2 - 2 * fraction), math.min(1, 2 * fraction), 0.2)
    end
end

local function dropdown(parent, key, values, default, label, x, y, width, apply)
    local settings = ui.Settings()
    if not values[settings[key]] then settings[key] = default end
    local items = {}
    for i, value in ipairs(values) do items[i] = { i, tostring(value) } end
    local row
    row = ui.Widgets.Select(parent, { type = "select", key = key, label = label, values = items }, {
        get = function() return settings[key] end,
        set = function(value) settings[key] = value; row:Refresh(); apply() end,
        reset = function() settings[key] = default; row:Refresh(); apply() end,
        isDefault = function() return settings[key] == default end,
    }, width + 20)
    row:SetPoint("TOPLEFT", x + 16, y)
    return row
end

local function colorButton(pane, key, apply)
    local settings = ui.Settings()
    local row
    row = ui.Widgets.Color(pane, { type = "color", key = key .. "Color", label = ru and "Цвет текста" or "Text color" }, {
        get = function() return labelColor(settings, key) end,
        set = function(value)
            settings[key .. "Color"] = { value[1], value[2], value[3] }
            row:Refresh()
            apply()
        end,
        reset = function()
            settings[key .. "Color"] = nil
            row:Refresh()
            apply()
        end,
        isDefault = function() return ui.SameValue(labelColor(settings, key), defaults[key].color) end,
    }, 130)
    row:SetPoint("TOPLEFT", 16, -111)
    return row
end

local editors = {}
local function createEditor(kind)
    local isBags = kind == "bags"
    local editor = CreateFrame("Frame", "ForeverStockUI_" .. kind .. "LabelEditor", UIParent)
    editor:SetSize(334, 315)
    editor:SetFrameStrata("FULLSCREEN_DIALOG")
    editor:SetClampedToScreen(true)
    editor:EnableMouse(true)
    editor:SetToplevel(true)
    ui.Widgets.Skin(editor, ui.Style.window, ui.Style.borderHover)
    editor:Hide()
    table.insert(UISpecialFrames, editor:GetName())
    local title = ui.Widgets.Text(editor, ui.Widgets.fonts.title)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(isBags and (ru and "Подписи в сумках" or "Bag labels")
        or (ru and "Подписи в окне персонажа" or "Character labels"))
    local close = ui.Widgets.CloseButton(editor, function() editor:Hide() end)
    close:SetPoint("TOPRIGHT", -6, -6)

    local function apply() editor.apply() end
    local panes, tabs = {}, {}
    local keys = isBags and { "bagsLevel", "bagsDurability" } or { "level", "durability" }
    for i, key in ipairs(keys) do
        local spec = defaults[key]
        local pane = CreateFrame("Frame", nil, editor)
        pane:SetPoint("TOPLEFT", editor, "TOPLEFT", 0, -67)
        pane:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT")
        panes[i] = pane
        ui.MediaChoice(pane, key .. "Font", "font", 1, -3, apply, ru and "Шрифт" or "Font", true)
        dropdown(pane, key .. "Size", spec.bag and bagSizes or sizes, spec.size, ru and "Размер" or "Size", 179, -3, 105, apply)
        dropdown(pane, key .. "Point", pointNames, spec.point, ru and "Положение на ячейке" or "Anchor on slot", 1, -55, 145, apply)
        dropdown(pane, key .. "Outline", outlineNames, 2, ru and "Обводка" or "Outline", 179, -55, 105, apply)
        colorButton(pane, key, apply)
        if spec.durability then
            ui.Checkbox(pane, key .. "AutoColor", ru and "Цвет по прочности" or "Color by durability", -109, true, apply)
            local check = _G["ForeverStockUI_" .. key .. "AutoColor"]
            check:ClearAllPoints()
            check:SetPoint("TOPLEFT", 162, -113)
        end
        ui.Slider(pane, key .. "X", ru and "Смещение X" or "Horizontal offset", -166, { -40, 40, 1, spec.x }, apply)
        ui.Slider(pane, key .. "Y", ru and "Смещение Y" or "Vertical offset", -211, { -40, 40, 1, spec.y }, apply)

        local tab = ui.Widgets.Button(editor, "", 145, nil, 22)
        tabs[i] = tab
        tab:SetPoint("TOPLEFT", 16 + (i - 1) * 153, -38)
        tab:SetText(spec.durability and (ru and "Прочность" or "Durability") or (ru and "Уровень предмета" or "Item level"))
    end

    local function selectTab(index)
        for i, pane in ipairs(panes) do
            local style = ui.Style
            if i == index then pane:Show() else pane:Hide() end
            tabs[i].text:SetTextColor(ui.Widgets.rgba(i == index and style.accentText or style.text))
            tabs[i]:SetBackdropBorderColor(ui.Widgets.rgba(i == index and style.accent or style.border))
        end
    end
    tabs[1]:SetScript("OnClick", function() selectTab(1) end)
    tabs[2]:SetScript("OnClick", function() selectTab(2) end)
    selectTab(1)
    return editor
end

function ui.ToggleItemLabelEditor(owner, kind, apply, onLeft)
    local editor = editors[kind]
    if not editor then
        editor = createEditor(kind)
        editors[kind] = editor
    elseif editor:IsVisible() and editor:GetParent() == owner then
        editor:Hide()
        return
    end
    editor.apply = apply
    editor:SetParent(owner)
    editor:ClearAllPoints()
    if onLeft then
        editor:SetPoint("TOPRIGHT", owner, "TOPLEFT", -8, 0)
    else
        editor:SetPoint("TOPLEFT", owner, "TOPRIGHT", 8, 0)
    end
    editor:Show()
    editor:Raise()
end

local slots = {}
local function refresh()
    if not PaperDollFrame:IsVisible() then return end
    local color = ui.DurabilityLabelColor("durability")
    if ui.Settings().equipLabels == false then
        for _, slot in ipairs(slots) do
            slot.level:SetText("")
            slot.durability:SetText("")
        end
        return
    end
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot.id)
        local level = link and select(4, GetItemInfo(link))
        slot.level:SetText(level or "")
        local current, maximum = GetInventoryItemDurability(slot.id)
        ui.SetDurabilityLabel(slot.durability, current, maximum, color)
    end
end

local function applyLabels()
    local level, durability = ui.ItemLabelStyle("level"), ui.ItemLabelStyle("durability")
    for _, slot in ipairs(slots) do
        ui.ApplyItemLabel(slot.level, slot.button, level)
        ui.ApplyItemLabel(slot.durability, slot.button, durability)
    end
    refresh()
end

local function createLabels()
    for _, name in ipairs({ "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "WristSlot",
        "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot",
        "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }) do
        local button = _G["Character" .. name]
        if button then
            slots[#slots + 1] = {
                id = button:GetID(), button = button,
                level = button:CreateFontString(nil, "OVERLAY"), durability = button:CreateFontString(nil, "OVERLAY"),
            }
        end
    end
    applyLabels()
    PaperDollFrame:HookScript("OnShow", refresh)
end

local function createOptions()
    local caption = ru and "Подписи" or "Labels"
    local button = CreateFrame("Button", "ForeverStockUI_CharacterLabels", PaperDollFrame, "UIPanelButtonTemplate")
    local close = CharacterFrame.CloseButton or CharacterFrameCloseButton
    button:SetSize(78, 20)
    button:SetPoint("RIGHT", close, "LEFT", -4, 0)
    button:SetFrameLevel(close:GetFrameLevel() + 1)
    button:SetText(caption)
    button:SetScript("OnClick", function() ui.ToggleItemLabelEditor(PaperDollFrame, "equipment", applyLabels) end)
end

ui.ItemLabels = {
    defaults = defaults, sizes = sizes, bagSizes = bagSizes, points = points, pointNames = pointNames,
    Apply = function()
        applyLabels()
        if ui.Bags then ui.Bags.Relayout() end
    end,
}

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then return end
        self:UnregisterEvent(event)
        createLabels()
        createOptions()
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        self:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
        pcall(self.RegisterEvent, self, "GET_ITEM_INFO_RECEIVED")
    else
        refresh()
    end
end)
