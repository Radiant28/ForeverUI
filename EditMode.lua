local _, ui = ...
if not GameMenuFrame_AddButton then return end

local ru = ui.russian
local settings, layout, selected, dragging
local entries, byName = {}, {}
local nativeUnits = { PlayerFrame = true, TargetFrame = true, FocusFrame = true }
local windows = NozdorWindowState
local editor = CreateFrame("Frame", "ForeverStockUIEditMode", UIParent)
local driver = CreateFrame("Frame")
local grid = CreateFrame("Frame", nil, UIParent)
grid:SetAllPoints(UIParent)
grid:SetFrameStrata("LOW")
grid:Hide()
local gridLines = {}
local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\AddOns\\ForeverUI\\Art\\UnitBar-Edge",
    edgeSize = 8,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local overlayBackdrop = { bgFile = backdrop.bgFile, edgeFile = backdrop.bgFile, edgeSize = 1 }

local function panel(frame, width, height)
    frame:SetSize(width, height)
    if ui.Widgets then
        ui.Widgets.Skin(frame, ui.Style.window, ui.Style.borderHover)
    else
        frame:SetBackdrop(backdrop)
        frame:SetBackdropColor(0.10, 0.071, 0.045, 0.96)
    end
    frame:EnableMouse(true)
end

editor:SetFrameStrata("DIALOG")
editor:SetFrameLevel(5)
editor:SetPoint("TOP", UIParent, "TOP", 0, -26)
panel(editor, 408, 164)
editor:Hide()
tinsert(UISpecialFrames, editor:GetName())

local instructions = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
instructions:SetPoint("TOP", 0, -13)
instructions:SetText(ru and "ЛКМ — перетащить · ПКМ — настройки элемента"
    or "Left drag to move · Right click for settings")

local function button(parent, width, text, action)
    if ui.Widgets then return ui.Widgets.Button(parent, text, width, action, 24) end
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 24)
    control:SetText(text)
    control:SetScript("OnClick", action)
    return control
end

local done = button(editor, 105, ru and "Готово" or "Done", function() editor:Hide() end)
done:SetPoint("BOTTOMRIGHT", -16, 10)

local function settingColor(key, fallback)
    local value = settings and settings[key]
    if type(value) ~= "table" then value = fallback end
    return value[1], value[2], value[3], value[4] or fallback[4] or 1
end

local function redrawGrid()
    if editor:IsShown() and settings and settings.editGrid then grid:Show() else grid:Hide() end
    if not grid:IsShown() then return end
    local used, step = 0, settings.editGridSpacing
    local r, g, b, alpha = settingColor("editGridColor", { 0.92, 0.75, 0.48, 0.23 })
    local function draw(point, opposite, span, vertical)
        for i = -math.floor(span / (2 * step)), math.floor(span / (2 * step)) do
            used = used + 1
            local line = gridLines[used]
            if not line then
                line = grid:CreateTexture(nil, "ARTWORK")
                line:SetTexture("Interface\\Buttons\\WHITE8X8")
                gridLines[used] = line
            end
            local x, y = vertical and i * step or 0, vertical and 0 or i * step
            line:ClearAllPoints()
            line:SetPoint(point, grid, point, x, y)
            line:SetPoint(opposite, grid, opposite, x, y)
            if vertical then line:SetWidth(1) else line:SetHeight(1) end
            line:SetVertexColor(r, g, b, i == 0 and math.min(1, alpha * 2.4) or alpha)
            line:Show()
        end
    end
    draw("TOP", "BOTTOM", UIParent:GetWidth(), true)
    draw("LEFT", "RIGHT", UIParent:GetHeight(), false)
    for i = used + 1, #gridLines do gridLines[i]:Hide() end
end

local options = CreateFrame("Frame", nil, editor)
options:SetPoint("TOP", editor, "BOTTOM", 0, -6)
panel(options, 282, 128)
options:Hide()

local title = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -13)

local detach = CreateFrame("CheckButton", "ForeverStockUIEditDetached", options, "InterfaceOptionsCheckButtonTemplate")
detach:SetPoint("TOPLEFT", 12, -77)
ForeverStockUIEditDetachedText:SetText(ru and "Отделить полосу заклинаний" or "Detach cast bar")
detach:Hide()

local scale = CreateFrame("Slider", "ForeverStockUIEditScale", options, "OptionsSliderTemplate")
scale:SetPoint("TOP", 0, -54)
scale:SetWidth(232)
scale:SetValueStep(1)

local function number(value)
    return type(value) == "number" and math.abs(value) < math.huge
end

local function points(frame)
    local saved = {}
    for i = 1, frame:GetNumPoints() do saved[i] = { frame:GetPoint(i) } end
    return saved
end

local function restorePoints(entry)
    if not entry.points then return end
    entry.frame:ClearAllPoints()
    for _, point in ipairs(entry.points) do entry.frame:SetPoint(unpack(point, 1, 5)) end
    entry.points = nil
end

local function held(entry)
    return entry.holder and UnitFrameMove_GetHolder and UnitFrameMove_GetHolder(entry.holder)
end

local function resetPosition(entry)
    if entry.beforeResetPosition then entry.beforeResetPosition() end
    entry.config.position = nil
    if entry.legacy then settings[entry.legacy] = nil end
    if held(entry) then
        entry.points = nil
        return
    end
    restorePoints(entry)
    if entry.resetPosition then entry.resetPosition() end
    return true
end

local function screenScale(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function displayedScale(entry)
    return entry.castOwner and screenScale(entry.frame) or entry.frame:GetScale()
end

local function rect(frame)
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom then return end
    local ratio = screenScale(frame)
    return left * ratio, bottom * ratio, frame:GetWidth() * ratio, frame:GetHeight() * ratio
end

local function getPosition(entry)
    local position = entry.config.position
    if entry.legacy then position = settings[entry.legacy] end
    if type(position) == "table" and number(position[1]) and number(position[2]) then return position end
end

local function move(entry, x, y)
    local frame = entry.frame
    local ratio = screenScale(frame)
    x, y = x / ratio, y / ratio
    local point, relative, relativePoint, currentX, currentY = frame:GetPoint()
    if frame:GetNumPoints() == 1 and point == "TOPRIGHT" and relative == UIParent and relativePoint == "TOPRIGHT"
        and math.abs((currentX or 0) - x) < 0.001 and math.abs((currentY or 0) - y) < 0.001 then return end
    if not entry.points then entry.points = points(frame) end
    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
end

local function groupMembers(names, visit)
    for _, name in ipairs(names or {}) do
        local member = _G[name]
        if member then visit(member) end
    end
end

local function setScale(entry, value)
    local frame = entry.frame
    if entry.castOwner then value = value / screenScale(entry.castOwner.frame) end
    if frame:GetScale() ~= value then frame:SetScale(value) end
    groupMembers(entry.members, function(member)
        if member:GetScale() ~= value then member:SetScale(value) end
    end)
end

local function apply(entry)
    if entry.removed or entry.docked or held(entry) then return end
    if entry.castOwner and entry.config.detached ~= true then return end
    local saved = entry.config.scale
    if entry.castOwner and not number(saved) then
        saved = displayedScale(entry)
        entry.config.scale = saved
    end
    if not entry.slider and number(saved) and saved >= 0.4 and saved <= 2 then setScale(entry, saved) end
    local position = getPosition(entry)
    if entry.castOwner and not position then
        local left, bottom, width, height = rect(entry.frame)
        if not left then
            left, bottom = rect(entry.castOwner.frame)
            if not left then return end
            left, height = left + 25, 7
            width = entry.frame:GetWidth() * screenScale(entry.frame)
        end
        position = { left + width - UIParent:GetRight(), bottom + height - UIParent:GetTop() }
        entry.config.position = position
    end
    if position then move(entry, position[1], position[2]) end
end

local function refreshOverlay(entry)
    local overlay = entry.overlay
    if not overlay or dragging == entry then return end
    if entry.removed then
        overlay:Hide()
        return
    end
    local left, bottom, width, height = rect(entry.frame)
    if not left or held(entry) or (entry.castOwner and entry.config.detached ~= true) then
        overlay:Hide()
        return
    end
    local right, top = left + width, bottom + height
    local visible = entry.frame:IsVisible()
    local function include(member)
        if not member:IsShown() then return end
        local x, y, w, h = rect(member)
        if not x then return end
        left, bottom = math.min(left, x), math.min(bottom, y)
        right, top = math.max(right, x + w), math.max(top, y + h)
        visible = visible or member:IsVisible()
    end
    groupMembers(entry.members, include)
    groupMembers(entry.bounds, include)
    overlay:SetFrameLevel((visible and 80 or 40) + ((right - left) * (top - bottom) < 6500 and 10 or 0))
    overlay:ClearAllPoints()
    overlay:SetSize(math.max(26, right - left), math.max(19, top - bottom))
    overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (left + right) / 2, (bottom + top) / 2)
    overlay:Show()
end

local function schedule()
    if not settings then return end
    driver:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        if InCombatLockdown() then return end
        for _, entry in ipairs(entries) do
            if entry ~= dragging and not entry.moving then apply(entry) end
        end
        if editor:IsShown() then
            for _, entry in ipairs(entries) do refreshOverlay(entry) end
        end
    end)
end
ui.RefreshEditLayout = schedule

local function showValue(value)
    ForeverStockUIEditScaleText:SetText((ru and "Масштаб" or "Scale") .. "  " .. value .. "%")
end

local function configureScale(entry)
    selected = nil
    local low, high, step = 40, 200, 1
    local value = math.floor(displayedScale(entry) * 100 + 0.5)
    if entry.slider then
        low, high = entry.slider:GetMinMaxValues()
        step = entry.slider:GetValueStep()
        value = entry.slider:GetValue()
    end
    scale:SetMinMaxValues(low, high)
    scale:SetValueStep(step)
    ForeverStockUIEditScaleLow:SetText(low .. "%")
    ForeverStockUIEditScaleHigh:SetText(high .. "%")
    scale:SetValue(value)
    showValue(value)
    selected = entry
end

scale:SetScript("OnValueChanged", function(_, value)
    if not selected or InCombatLockdown() or held(selected) then return end
    value = math.floor(value + 0.5)
    if selected.slider then
        selected.slider:SetValue(value)
        value = selected.slider:GetValue()
    elseif not selected.changeScale or not selected.changeScale(value / 100) then
        selected.config.scale = value / 100
        setScale(selected, value / 100)
        if selected.native and not getPosition(selected) then windows.Apply(selected.frame) end
    end
    showValue(value)
    schedule()
end)

local reset = button(options, 104, ru and "Сбросить" or "Reset", function()
    if not selected or InCombatLockdown() or held(selected) then return end
    local entry = selected
    entry.config.scale = nil
    resetPosition(entry)
    if entry.slider then
        entry.slider:SetValue(entry.slider.foreverDefault)
    elseif entry.castOwner then
        entry.frame:SetScale(entry.nativeScale)
        if Target_Spellbar_AdjustPosition then Target_Spellbar_AdjustPosition(entry.frame) end
    else
        setScale(entry, entry.defaultScale)
    end
    if entry.native then windows.Apply(entry.frame) end
    if UIParent_ManageFramePositions then UIParent_ManageFramePositions() end
    configureScale(entry)
    schedule()
end)
reset:SetPoint("BOTTOMLEFT", 12, 10)

local function openCategory(category)
    ui.OpenOptions(category)
end

local extra = button(options, 142, ru and "Все настройки" or "More settings", function()
    local category = selected and selected.panel
    if not category or InCombatLockdown() then return end
    editor:Hide()
    openCategory(category)
end)
extra:SetPoint("BOTTOMRIGHT", -12, 10)

local close = ui.Widgets and ui.Widgets.CloseButton(options, function() options:Hide() end)
    or CreateFrame("Button", nil, options, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)
close:SetScript("OnClick", function() options:Hide() end)

detach:SetScript("OnClick", function(self)
    local entry = selected and selected.castBar
    if not entry or InCombatLockdown() then return end
    entry.config.detached = self:GetChecked() and true or false
    if entry.config.detached then
        apply(entry)
    else
        restorePoints(entry)
        entry.frame:SetScale(entry.nativeScale)
        if Target_Spellbar_AdjustPosition then Target_Spellbar_AdjustPosition(entry.frame) end
    end
    schedule()
end)

local function snap(value, origin, low, high)
    local step = settings.editGridSpacing
    local first = math.ceil((low - origin) / step)
    local last = math.floor((high - origin) / step)
    if first > last then return value end
    local nearest = math.floor((value - origin) / step + 0.5)
    return origin + math.max(first, math.min(last, nearest)) * step
end

local function preview(entry)
    local left, bottom = entry.overlay:GetCenter()
    if not left or not bottom or InCombatLockdown() then return end
    entry.x = entry.startX + left - entry.handleX
    entry.y = entry.startY + bottom - entry.handleY
    if settings.editSnap then
        local width, height = entry.overlay:GetSize()
        local x, y = UIParent:GetCenter()
        local edgeX, edgeY = left - width / 2, bottom + height / 2
        entry.x = entry.x + snap(edgeX, x, UIParent:GetLeft(), UIParent:GetRight() - width) - edgeX
        entry.y = entry.y + snap(edgeY, y, UIParent:GetBottom() + height, UIParent:GetTop()) - edgeY
    end
    move(entry, entry.x, entry.y)
end

local function stopDrag(commit)
    local entry = dragging
    if not entry then return end
    entry.overlay:StopMovingOrSizing()
    entry.overlay:SetScript("OnUpdate", nil)
    if commit and not InCombatLockdown() then
        preview(entry)
        if entry.x then
            local position = { entry.x, entry.y }
            if entry.legacy then
                settings[entry.legacy] = position
            else
                entry.config.position = position
            end
            if entry.onDragStop then entry.onDragStop() end
        end
    else
        entry.cancelled = true
    end
    dragging = nil
    schedule()
end

local resetAll = button(editor, 172, ru and "Сбросить все позиции" or "Reset all positions", function()
    if InCombatLockdown() then return end
    stopDrag(true)
    for name, config in pairs(layout) do
        if not byName[name] and type(config) == "table" then config.position = nil end
    end
    for _, entry in ipairs(entries) do
        if resetPosition(entry) then
            if entry.native then windows.Apply(entry.frame) end
            if entry.castOwner and Target_Spellbar_AdjustPosition then Target_Spellbar_AdjustPosition(entry.frame) end
        end
    end
    if UIParent_ManageFramePositions then UIParent_ManageFramePositions() end
    schedule()
end)
resetAll:SetPoint("BOTTOMLEFT", 16, 10)

local function createOverlay(entry)
    local overlay = CreateFrame("Button", nil, editor)
    overlay:SetFrameStrata("HIGH")
    overlay:SetMovable(true)
    overlay:SetClampedToScreen(true)
    overlay:EnableMouse(true)
    overlay:RegisterForDrag("LeftButton")
    overlay:RegisterForClicks("RightButtonUp")
    overlay:SetBackdrop(overlayBackdrop)
    local function paint(hover)
        local r, g, b, a = settingColor("editOverlayColor", { 0.26, 0.64, 0.95, 0.36 })
        overlay:SetBackdropColor(r, g, b, hover and math.min(1, a + 0.14) or a)
        overlay:SetBackdropBorderColor(math.min(1, r + 0.3), math.min(1, g + 0.18), math.min(1, b + 0.05), 0.60)
    end
    overlay.paint = paint
    paint(false)
    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText(entry.label)
    overlay:SetScript("OnEnter", function() paint(true) end)
    overlay:SetScript("OnLeave", function() paint(false) end)
    overlay:SetScript("OnClick", function()
        if InCombatLockdown() or held(entry) then return end
        configureScale(entry)
        title:SetText(entry.label)
        options:SetHeight(entry.castBar and 156 or 128)
        if entry.castBar then
            detach:Show()
            detach:SetChecked(entry.castBar.config.detached == true)
        else
            detach:Hide()
        end
        if entry.panel ~= nil then extra:Show() else extra:Hide() end
        options:Show()
    end)
    overlay:SetScript("OnDragStart", function(self)
        if InCombatLockdown() or held(entry) then return end
        local left, bottom, width, height = rect(entry.frame)
        if not left then return end
        entry.startX = left + width - UIParent:GetRight()
        entry.startY = bottom + height - UIParent:GetTop()
        entry.handleX, entry.handleY = self:GetCenter()
        if not entry.handleX then return end
        entry.x, entry.y = nil, nil
        if entry.onDragStart then entry.onDragStart() end
        dragging = entry
        self:StartMoving()
        self:SetScript("OnUpdate", function() preview(entry) end)
    end)
    overlay:SetScript("OnDragStop", function() stopDrag(true) end)
    entry.overlay = overlay
end

function ui.RegisterEditFrame(frame, label, category, slider, legacyPosition)
    local name = frame and frame:GetName()
    if not name then return end
    local entry = byName[name]
    if not entry then
        entry = { frame = frame, label = label, name = name, defaultScale = frame:GetScale() }
        byName[name] = entry
        entries[#entries + 1] = entry
        frame:HookScript("OnShow", schedule)
    end
    entry.label = label or entry.label
    entry.panel, entry.slider, entry.legacy = category, slider, legacyPosition
    if layout then
        if type(layout[name]) ~= "table" then layout[name] = {} end
        entry.config = layout[name]
        schedule()
    end
    -- Frames registered while the editor is open (a newly added meter window) get their overlay at once.
    if editor:IsShown() and not entry.overlay then createOverlay(entry) end
    return entry
end

local function add(name, russian, english, members)
    local entry = ui.RegisterEditFrame(_G[name], ru and russian or english)
    if not entry then return end
    entry.members = members
    entry.native = nativeUnits[name] and windows and windows.Apply
    entry.holder = nativeUnits[name] and name or name == "CastingBarFrame" and "castbar"
    if entry.native then
        entry.frame:HookScript("OnDragStop", function()
            if entry.config then entry.config.position, entry.points = nil, nil end
        end)
    end
    return entry
end

add("MainMenuBar", "Главная панель", "Main action bar")
add("MultiBarBottomLeft", "Нижняя левая панель", "Bottom left bar")
add("MultiBarBottomRight", "Нижняя правая панель", "Bottom right bar")
add("MultiBarLeft", "Левая боковая панель", "Left side bar")
add("MultiBarRight", "Правая боковая панель", "Right side bar")
add("ShapeshiftBarFrame", "Стойки и формы", "Stances and forms")
add("PetActionBarFrame", "Панель питомца", "Pet action bar")
add("PossessBarFrame", "Управление", "Possess bar")
add("MultiCastActionBarFrame", "Панель тотемов", "Totem bar")
add("MainMenuExpBar", "Опыт", "Experience")
add("MainMenuBarMaxLevelBar", "Полоса статуса", "Status bar")
add("ReputationWatchBar", "Репутация", "Reputation")
add("VehicleMenuBar", "Панель транспорта", "Vehicle bar")
add("VehicleMenuBarLeaveButton", "Выход из транспорта", "Leave vehicle")
add("MainMenuBarVehicleLeaveButton", "Покинуть транспорт", "Exit vehicle")
add("CharacterMicroButton", "Микроменю", "Micro menu", {
    "SpellbookMicroButton", "TalentMicroButton", "AchievementMicroButton", "QuestLogMicroButton",
    "SocialsMicroButton", "PVPMicroButton", "LFDMicroButton", "MainMenuMicroButton", "HelpMicroButton",
})
add("MainMenuBarBackpackButton", "Кнопки сумок", "Bag buttons", {
    "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
})
add("PlayerFrame", "Игрок", "Player")
add("TargetFrame", "Цель", "Target")
add("TargetFrameToT", "Цель цели", "Target of target")
add("FocusFrame", "Фокус", "Focus")
add("FocusFrameToT", "Цель фокуса", "Focus target")
add("PetFrame", "Питомец", "Pet")
add("CastingBarFrame", "Полоса заклинаний", "Cast bar")
add("MinimapCluster", "Миникарта", "Minimap")
local buffs = add("ConsolidatedBuffs", "Бафы", "Buffs", { "TemporaryEnchantFrame", "BuffFrame" })
if buffs then
    buffs.bounds = { "TempEnchant1", "TempEnchant2", "TempEnchant3" }
    for i = 1, BUFF_MAX_DISPLAY or 32 do buffs.bounds[#buffs.bounds + 1] = "BuffButton" .. i end
end
add("WatchFrame", "Отслеживание заданий", "Quest tracker")
add("DurabilityFrame", "Прочность", "Durability")

local function pinCastBar(bar)
    local entry = byName[bar:GetName()]
    if not entry or not entry.castOwner or not entry.config or entry.config.detached ~= true then return end
    if InCombatLockdown() and bar:IsProtected() then return end
    local position = getPosition(entry)
    if entry == dragging and entry.x then
        move(entry, entry.x, entry.y)
    elseif position then
        move(entry, position[1], position[2])
    end
end

local function registerCastBar(frame)
    if not frame or (frame ~= TargetFrame and frame ~= FocusFrame) then return end
    local owner = byName[frame:GetName()]
    local bar = frame.spellbar or _G[owner.name .. "SpellBar"]
    if not bar or owner.castBar then return end
    local label = frame == TargetFrame and (ru and "Полоса заклинаний цели" or "Target cast bar")
        or (ru and "Полоса заклинаний фокуса" or "Focus cast bar")
    local entry = ui.RegisterEditFrame(bar, label)
    -- Stock cast and aura handling still reads the original unit frame via GetParent().
    entry.castOwner, entry.nativeScale = owner, bar:GetScale()
    owner.castBar = entry
    -- The XML OnShow script holds a direct reference to the stock positioning function.
    bar:HookScript("OnShow", pinCastBar)
    if editor:IsShown() then createOverlay(entry) end
end

registerCastBar(TargetFrame)
registerCastBar(FocusFrame)
if TargetFrame_CreateSpellbar then hooksecurefunc("TargetFrame_CreateSpellbar", registerCastBar) end
if Target_Spellbar_AdjustPosition then hooksecurefunc("Target_Spellbar_AdjustPosition", pinCastBar) end
if FocusFrame_SetSmallSize and FocusFrame then
    local small = FocusFrame.smallSize and true or false
    hooksecurefunc("FocusFrame_SetSmallSize", function()
        local nextSmall = FocusFrame.smallSize and true or false
        local entry = byName.FocusFrame.castBar
        if entry and nextSmall ~= small then entry.nativeScale = entry.frame:GetScale() end
        small = nextSmall
        schedule()
    end)
end

local debuffs = {}
for i = 2, DEBUFF_MAX_DISPLAY or 16 do debuffs[#debuffs + 1] = "DebuffButton" .. i end
local function registerDebuffs()
    if DebuffButton1 and not byName.DebuffButton1 then
        add("DebuffButton1", "Дебафы", "Debuffs", debuffs)
        if editor:IsShown() then createOverlay(byName.DebuffButton1) end
    end
end
registerDebuffs()
if DebuffButton_UpdateAnchors then
    hooksecurefunc("DebuffButton_UpdateAnchors", function(_, index)
        if index ~= 1 then return end
        registerDebuffs()
        schedule()
    end)
end

editor:SetScript("OnShow", function()
    redrawGrid()
    for _, entry in ipairs(entries) do
        if not entry.overlay then createOverlay(entry) end
        refreshOverlay(entry)
    end
end)
editor:SetScript("OnHide", function()
    stopDrag(not InCombatLockdown())
    options:Hide()
    grid:Hide()
end)

local function openEditor()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(ru and "Редактирование доступно вне боя." or "Edit Mode is available out of combat.", 1, 0.2, 0.2)
        return
    end
    editor:Show()
end

ui.EditMode = {
    Open = openEditor,
    Apply = function()
        redrawGrid()
        for _, entry in ipairs(entries) do
            if entry.overlay then entry.overlay.paint(false) end
        end
    end,
}

local menu = CreateFrame("Button", "ForeverStockUIEditModeButton", GameMenuFrame, "GameMenuButtonTemplate")
menu:SetText(ru and "Редактирование" or "Edit Mode")
menu:SetScript("OnClick", function()
    PlaySound("igMainMenuOption")
    if not InCombatLockdown() then HideUIPanel(GameMenuFrame) end
    openEditor()
end)
GameMenuFrame_AddButton(menu:GetName(), "GameMenuButtonOptions")

local settingsMenu = CreateFrame("Button", "ForeverStockUISettingsButton", GameMenuFrame, "GameMenuButtonTemplate")
settingsMenu:SetText("ForeverUI")
settingsMenu:SetScript("OnClick", function()
    PlaySound("igMainMenuOption")
    HideUIPanel(GameMenuFrame)
    ui.OpenOptions()
end)
GameMenuFrame_AddButton(settingsMenu:GetName(), menu:GetName())

for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        settings = ui.Settings()
        if type(settings.editLayout) ~= "table" then settings.editLayout = {} end
        layout = settings.editLayout
        for _, entry in ipairs(entries) do
            if type(layout[entry.name]) ~= "table" then layout[entry.name] = {} end
            entry.config = layout[entry.name]
        end
        ui.Checkbox(editor, "editGrid", ru and "Показывать сетку" or "Show grid", -34, false, redrawGrid)
        local snapControl = ui.Checkbox(editor, "editSnap", ru and "Прилипание к сетке" or "Snap to grid",
            -34, false, function() end)
        snapControl:ClearAllPoints()
        snapControl:SetPoint("TOPLEFT", 184, -34)
        ui.Slider(editor, "editGridSpacing", ru and "Шаг сетки" or "Grid spacing", -81,
            { 8, 64, 4, 24 }, redrawGrid)
        ui.Checkbox(editor, "showGryphons", ru and "Показывать грифонов" or "Show gryphons", -105,
            true, ui.ApplyGryphons)
    elseif event == "PLAYER_REGEN_DISABLED" then
        stopDrag(false)
        editor:Hide()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        for _, entry in ipairs(entries) do
            if entry.cancelled then
                restorePoints(entry)
                entry.cancelled = nil
            end
        end
    elseif event == "DISPLAY_SIZE_CHANGED" then
        redrawGrid()
    end
    schedule()
end)

for _, name in ipairs({ "UIParent_ManageFramePositions", "MainMenuBar_UnlockAB", "MainMenuBar_ToPlayerArt",
    "MainMenuBarVehicleLeaveButton_Update", "VehicleMenuBar_MoveMicroButtons",
    "MultiActionBar_Update", "BuffFrame_UpdateAllBuffAnchors" }) do
    if _G[name] then hooksecurefunc(name, schedule) end
end
if UnitFrameMove_Do then
    hooksecurefunc("UnitFrameMove_Do", function(name, command)
        local entry = byName[name]
        if command == "reset" and entry and entry.config then entry.config.position, entry.points = nil, nil end
    end)
end
