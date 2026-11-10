local _, ui = ...
local art = "Interface\\AddOns\\ForeverUI\\Art\\"
local timeArt = art .. "Map\\Map-calendar"
local headerTexture = art .. "Map\\Map-top"
local headerIcons = art .. "Map\\Map-HeaderIcons"

MinimapBorder:SetTexture(art .. "Map\\Map-Rim")
MinimapBorder:SetTexCoord(0, 1, 0, 1)
MinimapBorder:SetSize(200, 200)
MinimapBorder:ClearAllPoints()
MinimapBorder:SetPoint("CENTER", Minimap, "CENTER")
MinimapBorderTop:SetAlpha(0)

local function anchor(region, point, relative, relativePoint, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, relative, relativePoint, x, y)
end

local header = CreateFrame("Frame", nil, MinimapCluster)
header:SetSize(166, 20)
header:SetPoint("TOP", MinimapCluster, "TOP", 0, -4)
local headerArt = header:CreateTexture(nil, "BACKGROUND")
headerArt:SetTexture(headerTexture)
headerArt:SetTexCoord(0, 388 / 512, 0, 44 / 64)
headerArt:SetAllPoints(header)
local buffAnchor = CreateFrame("Frame", nil, header)
buffAnchor:SetSize(1, 1)

MinimapCluster:SetSize(200, 240)
Minimap:SetSize(165, 165)
anchor(Minimap, "TOP", header, "BOTTOM", 0, -34)

local queue = MiniMapLFGFrame
if queue and queue.eye and queue.eye.texture then
    queue:SetSize(35, 35)
    anchor(queue, "CENTER", Minimap, "BOTTOM", 0, 35)
    if MiniMapLFGFrameBorder then MiniMapLFGFrameBorder:SetAlpha(0) end
    queue.eye:SetSize(35, 35)
    anchor(queue.eye, "CENTER", queue, "CENTER", 0, 0)
    queue.eye.texture:SetTexture(art .. "Map\\uigroupfinderflipbookeye")
    queue.eye.texture:SetTexCoord(0, 0.125, 0, 0.25)
end
if MiniMapBattlefieldFrame then
    anchor(MiniMapBattlefieldFrame, "CENTER", Minimap, "CENTER", -35, -43)
end

MinimapZoneTextButton:SetSize(90, 13)
anchor(MinimapZoneTextButton, "LEFT", header, "LEFT", 24, 0)
MinimapZoneText:ClearAllPoints()
MinimapZoneText:SetAllPoints(MinimapZoneTextButton)
MinimapZoneText:SetJustifyH("LEFT")
MinimapZoneText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")

if MiniMapTracking then
    MiniMapTracking:SetSize(18, 18)
    MiniMapTrackingButton:ClearAllPoints()
    MiniMapTrackingButton:SetAllPoints(MiniMapTracking)
    MiniMapTrackingIcon:SetAlpha(0)
    if MiniMapTrackingIconOverlay then MiniMapTrackingIconOverlay:SetAlpha(0) end
    MiniMapTrackingButtonShine:SetSize(18, 18)
    anchor(MiniMapTrackingButtonShine, "CENTER", MiniMapTrackingButton, "CENTER", 0, 0)
    MiniMapTrackingBackground:SetAlpha(0)
    MiniMapTrackingButtonBorder:SetAlpha(0)
    local filter = MiniMapTrackingButton:CreateTexture(nil, "ARTWORK")
    filter:SetTexture(headerIcons)
    filter:SetTexCoord(0, 0.5, 0, 1)
    filter:SetSize(15, 15)
    filter:SetPoint("CENTER", MiniMapTrackingButton, "CENTER")
end
if GameTimeFrame then
    GameTimeFrame:SetSize(18, 18)
    GameTimeFrame:SetHitRectInsets(0, 0, 0, 0)
    GameTimeFrame:GetNormalTexture():SetAlpha(0)
    GameTimeFrame:GetPushedTexture():SetAlpha(0)

    local calendar = GameTimeFrame:CreateTexture(nil, "ARTWORK")
    calendar:SetTexture(headerIcons)
    calendar:SetTexCoord(0.5, 1, 0, 1)
    calendar:SetSize(15, 15)
    calendar:SetPoint("CENTER", GameTimeFrame, "CENTER")

    local dateBadge = header:CreateTexture(nil, "BACKGROUND")
    dateBadge:SetTexture(headerTexture)
    dateBadge:SetTexCoord(344 / 512, 387 / 512, 1 / 64, 43 / 64)
    dateBadge:SetSize(16, 16)
    dateBadge:SetPoint("TOP", header, "BOTTOMRIGHT", -9.4, -2)
    local dateText = GameTimeFrame:GetFontString()
    dateText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    anchor(dateText, "CENTER", dateBadge, "CENTER", 0, 0)
end
local moon
if GameTimeTexture then
    GameTimeTexture:Hide()
    moon = MinimapBorder:GetParent():CreateTexture(nil, "OVERLAY")
    moon:SetTexture(timeArt)
    moon:SetTexCoord(188 / 256, 1, 0, 68 / 128)
    moon:SetSize(28, 28)
    moon:SetPoint("CENTER", Minimap, "CENTER", 47, 73.4)
    moon:Hide()
end
if MiniMapMailFrame then
    MiniMapMailFrame:SetScale(0.65)
    anchor(MiniMapMailFrame, "TOPLEFT", header, "BOTTOMLEFT", 10, 0)
    if MiniMapMailIcon then
        MiniMapMailIcon:SetTexture(art .. "Map\\Mail-Envelope")
        MiniMapMailIcon:SetTexCoord(0, 1, 0, 1)
        MiniMapMailIcon:SetSize(30, 30)
        anchor(MiniMapMailIcon, "CENTER", MiniMapMailFrame, "CENTER", 0, 0)
    end
    if MiniMapMailBorder then MiniMapMailBorder:SetAlpha(0) end
end

if MinimapNorthTag then MinimapNorthTag:SetAlpha(0) end
if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(0) end
if MiniMapWorldMapButton then MiniMapWorldMapButton:Hide() end
MinimapZoomIn:Hide()
MinimapZoomOut:Hide()
Minimap:EnableMouseWheel(true)
Minimap:SetScript("OnMouseWheel", function(_, delta)
    if delta > 0 then MinimapZoomIn:Click() end
    if delta < 0 then MinimapZoomOut:Click() end
end)

local coordinates = Minimap:CreateFontString(nil, "OVERLAY")
coordinates:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
coordinates:SetPoint("TOP", Minimap, "BOTTOM", 0, -10)
local clock = header:CreateFontString(nil, "OVERLAY")
clock:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
clock:SetPoint("RIGHT", header, "RIGHT", -23, 0)

local function placeClock()
    if not TimeManagerClockButton or not TimeManagerClockTicker then return end
    clock:Hide()
    TimeManagerClockButton:SetSize(29, 13)
    anchor(TimeManagerClockButton, "RIGHT", header, "RIGHT", -23, 0)
    TimeManagerClockTicker:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    for _, region in ipairs({ TimeManagerClockButton:GetRegions() }) do
        if region:GetObjectType() == "Texture" and region ~= TimeManagerAlarmFiredTexture then
            region:SetAlpha(0)
        end
    end
end

local refreshZone = true
local elapsed = 0.25
header:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.25 then return end
    elapsed = 0
    if clock:IsShown() then clock:SetFormattedText("%02d:%02d", GetGameTime()) end
    if moon then
        -- The stock calendar still updates its hidden day/night texture.
        if GameTimeTexture:GetTexCoord() >= 0.5 then moon:Show() else moon:Hide() end
    end
    if WorldMapFrame and WorldMapFrame:IsShown() then
        refreshZone = true
        return
    end
    if refreshZone then
        refreshZone = false
        SetMapToCurrentZone()
    end
    local x, y = GetPlayerMapPosition("player")
    if x and y and (x ~= 0 or y ~= 0) then
        coordinates:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
    else
        coordinates:SetText("")
    end
end)

local row = CreateFrame("Frame", nil, Minimap)
row:SetFrameLevel(Minimap:GetFrameLevel())
row:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
})
row:Hide()

local events = CreateFrame("Frame")
local legacy = { Gatherer_MinimapOptionsButton = true, XPerl_MinimapButton_Frame = true }
local tracked = {}
local dragUpdates = {}
local hookedLibrary
local scheduleLayout

local function placeOnRing(button, angle)
    local offset = ui.Settings().mapRingOffset or 2
    local radius = (Minimap:GetWidth() / 2 + offset) * Minimap:GetEffectiveScale() / button:GetEffectiveScale()
    local radians = math.rad(angle)
    anchor(button, "CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

local function updateRingDrag(button, elapsed)
    local native = dragUpdates[button]
    if native then native(button, elapsed) end
    local settings = ui.Settings()
    if not settings.mapButtonsCircle or InCombatLockdown() then return end
    local x, y = GetCursorPosition()
    local mx, my = Minimap:GetCenter()
    if not mx or not my then return end
    local scale = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(y / scale - my, x / scale - mx)) % 360
    settings.mapButtonAngles[button:GetName()] = angle
    placeOnRing(button, angle)
end

local function stopRingDrag(button)
    if dragUpdates[button] ~= nil and button:GetScript("OnUpdate") == updateRingDrag then
        button:SetScript("OnUpdate", legacy[button:GetName()] and dragUpdates[button] or nil)
    end
    dragUpdates[button] = nil
    scheduleLayout()
end

local function skinAddonButton(button)
    local icon = button.icon or (button == XPerl_MinimapButton_Frame and XPerl_MinitmapButton_Icon)
    if not icon then return end
    for _, region in ipairs({button:GetRegions()}) do
        local texture = region.GetTexture and region:GetTexture()
        if type(texture) == "string" then
            local path = texture:lower()
            if path:find("minimap-trackingborder", 1, true) or path:find("ui-minimap-background", 1, true) then
                region:SetAlpha(0)
            end
        end
    end
    local rim = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    rim:SetTexture(art .. "Level")
    rim:SetTexCoord(0, 78 / 128, 0, 78 / 128)
    rim:SetPoint("CENTER", button, "CENTER")
    rim:SetSize(27, 27)
    icon:SetSize(12, 12)
    anchor(icon, "CENTER", button, "CENTER", 0, 0)
end

local function collect(container, visible)
    for _, button in ipairs({ container:GetChildren() }) do
        local name = button:GetName()
        if name and button:IsObjectType("Button") and (name:match("^LibDBIcon10_") or legacy[name]) then
            if not tracked[button] then
                tracked[button] = button:GetScale()
                skinAddonButton(button)
                button:HookScript("OnShow", scheduleLayout)
                button:HookScript("OnHide", stopRingDrag)
                if legacy[name] then button:RegisterForDrag("LeftButton") end
                button:HookScript("OnDragStart", function(self)
                    if not ui.Settings().mapButtonsCircle or InCombatLockdown() or (self.db and self.db.lock) then return end
                    dragUpdates[self] = self:GetScript("OnUpdate") or false
                    self:SetScript("OnUpdate", updateRingDrag)
                    updateRingDrag(self, 0)
                end)
                button:HookScript("OnDragStop", stopRingDrag)
            end
            if button:IsShown() then visible[#visible + 1] = button end
        end
    end
end

local function layout()
    if InCombatLockdown() then return end
    local settings = ui.Settings()
    if type(settings.mapButtonAngles) ~= "table" then settings.mapButtonAngles = {} end
    local mapScale = (settings.mapScale or 100) / 100
    local panelScale = (settings.mapButtonsScale or 100) / 100
    MinimapCluster:SetScale(mapScale)
    if MiniMapTracking then
        -- The client can restore an old position on the minimap ring when entering the world.
        anchor(MiniMapTracking, "CENTER", header, "LEFT", 9.4, 0)
        MiniMapTrackingButton:RegisterForDrag()
    end
    if GameTimeFrame then
        GameTimeFrame:SetScale(header:GetEffectiveScale() / GameTimeFrame:GetParent():GetEffectiveScale())
        anchor(GameTimeFrame, "CENTER", header, "RIGHT", -9.4, 0)
        GameTimeFrame:RegisterForDrag()
    end
    if ConsolidatedBuffs and TemporaryEnchantFrame and BuffFrame then
        local gap = (settings.mapBuffGap or 10) / mapScale
        local y = (settings.mapBuffY or 0) / mapScale
        anchor(buffAnchor, "TOPRIGHT", header, "TOPLEFT", -18 - gap, y)
        anchor(ConsolidatedBuffs, "TOPRIGHT", buffAnchor, "TOPRIGHT", 0, 0)
        anchor(TemporaryEnchantFrame, "TOPRIGHT", ConsolidatedBuffs, "TOPRIGHT", 0, 0)
        anchor(BuffFrame, "TOPRIGHT", ConsolidatedBuffs, "TOPRIGHT", 0, 0)
    end
    -- Keep the panel attached to the minimap without inheriting its size setting.
    row:SetScale(panelScale / mapScale)
    row:ClearAllPoints()
    row:SetPoint("RIGHT", Minimap, "LEFT", (settings.mapButtonsX or -14) / panelScale,
        (settings.mapButtonsY or -34) / panelScale)
    local background = settings.mapButtonsBackground ~= false
    local fill = type(settings.mapButtonsBgColor) == "table" and settings.mapButtonsBgColor or { 0.08, 0.065, 0.05, 0.88 }
    local edge = type(settings.mapButtonsBorderColor) == "table" and settings.mapButtonsBorderColor
        or { 0.48, 0.34, 0.17, 0.95 }
    row:SetBackdropColor(fill[1], fill[2], fill[3], background and (fill[4] or 0.88) or 0)
    row:SetBackdropBorderColor(edge[1], edge[2], edge[3], background and (edge[4] or 0.95) or 0)
    if settings.mapButtonsEnabled == false then
        row:Hide()
        return
    end
    local spacing = settings.mapButtonsSpacing or 2

    local library = LibStub and LibStub("LibDBIcon-1.0", true)
    if library and library.Refresh and not hookedLibrary then
        hooksecurefunc(library, "Refresh", scheduleLayout)
        hooksecurefunc(library, "Register", scheduleLayout)
        hookedLibrary = true
    end

    local buttons = {}
    collect(Minimap, buttons)
    collect(MinimapCluster, buttons)
    table.sort(buttons, function(a, b) return a:GetName() < b:GetName() end)

    local length, breadth = 3, 0
    local vertical = settings.mapButtonsVertical
    local effectiveScale = row:GetEffectiveScale()
    for index, button in ipairs(buttons) do
        local scale = tracked[button]
        button:SetScale(scale * effectiveScale / button:GetParent():GetEffectiveScale())
        button:ClearAllPoints()
        if settings.mapButtonsCircle then
            local angle = settings.mapButtonAngles[button:GetName()]
            if type(angle) ~= "number" or angle ~= angle or math.abs(angle) == math.huge then
                angle = 120 + (index - 1) * 320 / #buttons
            end
            placeOnRing(button, angle)
        elseif vertical then
            button:SetPoint("TOP", row, "TOP", 0, -length / scale)
            length = length + button:GetHeight() * scale + spacing
            breadth = math.max(breadth, button:GetWidth() * scale)
        else
            button:SetPoint("LEFT", row, "LEFT", length / scale, 0)
            length = length + button:GetWidth() * scale + spacing
            breadth = math.max(breadth, button:GetHeight() * scale)
        end
    end
    if #buttons > 0 and not settings.mapButtonsCircle then
        if vertical then row:SetSize(breadth + 4, length + 1) else row:SetSize(length + 1, breadth + 4) end
        row:Show()
    else
        row:Hide()
    end
end

scheduleLayout = function()
    events:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        layout()
        if ui.RefreshEditLayout then ui.RefreshEditLayout() end
    end)
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
if MinimapRingButtons_Reset then hooksecurefunc("MinimapRingButtons_Reset", scheduleLayout) end
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        refreshZone = true
    end
    if event == "PLAYER_LOGIN" or name == "Blizzard_TimeManager" then placeClock() end
    if event == "PLAYER_LOGIN" and ui.RegisterEditFrame then
        ui.RegisterEditFrame(MinimapCluster, nil, "minimap", ui.OptionBinding("minimap", "mapScale"))
    end
    scheduleLayout()
end)

ui.Minimap = { Layout = function() scheduleLayout() end }
