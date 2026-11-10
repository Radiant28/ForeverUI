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
local headerGap = 34
anchor(Minimap, "TOP", header, "BOTTOM", 0, -headerGap)

-- Map-Rim.tga is drawn at 200 px; its opaque band spans 81..89 px from the centre.
local rimRadius = 85.5
local eyeAngle = 215
local eyeX = math.cos(math.rad(eyeAngle)) * rimRadius
local eyeY = math.sin(math.rad(eyeAngle)) * rimRadius
local battlefieldX, battlefieldY = -35, -43
local moonX, moonY = 47, 73.4

local queue = MiniMapLFGFrame
if queue and queue.eye and queue.eye.texture then
    queue:SetSize(35, 35)
    -- Sit on the rim at the lower left, clear of the map and the PvP queue icon.
    anchor(queue, "CENTER", Minimap, "CENTER", eyeX, eyeY)
    if MiniMapLFGFrameBorder then MiniMapLFGFrameBorder:SetAlpha(0) end
    queue.eye:SetSize(35, 35)
    anchor(queue.eye, "CENTER", queue, "CENTER", 0, 0)
    queue.eye.texture:SetTexture(art .. "Map\\uigroupfinderflipbookeye")
    queue.eye.texture:SetTexCoord(0, 0.125, 0, 0.25)
end
if MiniMapBattlefieldFrame then
    anchor(MiniMapBattlefieldFrame, "CENTER", Minimap, "CENTER", battlefieldX, battlefieldY)
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
    moon:SetPoint("CENTER", Minimap, "CENTER", moonX, moonY)
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
-- Named minimap children owned by the client, never gathered as addon buttons.
local stock = {
    Minimap = true, MinimapBackdrop = true, MiniMapTracking = true, MiniMapTrackingButton = true,
    MiniMapMailFrame = true, MiniMapBattlefieldFrame = true, MiniMapLFGFrame = true, MiniMapWorldMapButton = true,
    MinimapZoomIn = true, MinimapZoomOut = true, GameTimeFrame = true, TimeManagerClockButton = true,
    MiniMapVoiceChatFrame = true, MinimapZoneTextButton = true, MiniMapInstanceDifficulty = true,
    MinimapPing = true, MiniMapRecordingButton = true, MinimapToggleButton = true, MiniMapCompassRing = true,
}
-- Map pins and markers of gathering, quest and note addons are children of Minimap too.
local ignored = { "pin", "poi", "note", "node", "blip", "arrow", "ping", "gathermate", "handynotes", "tomtom",
    "routes", "questhelper", "cartographer", "carbonite", "nxmap" }
local firstAngle = 135
local tracked = {}
local skinned = {}
local hooked = {}
local dragUpdates = {}
local libraryHooks = {}
local placing
local scheduleLayout

local function isAddonButton(button, name)
    if legacy[name] or name:match("^LibDBIcon10_") then return true end
    if stock[name] or not button:IsObjectType("Button") then return false end
    local lower = name:lower()
    if not lower:find("minimap", 1, true) and not lower:find("button", 1, true) then return false end
    for _, word in ipairs(ignored) do
        if lower:find(word, 1, true) then return false end
    end
    local width, height = button:GetWidth(), button:GetHeight()
    return width >= 14 and width <= 48 and height >= 14 and height <= 48
end

local function savedAngle(name)
    local angle = ui.Settings().mapButtonAngles[name]
    if type(angle) == "number" and angle == angle and math.abs(angle) ~= math.huge then return angle % 360 end
end

local function ringRadius()
    return Minimap:GetWidth() / 2 + (ui.Settings().mapRingOffset or 2)
end

-- Radius of a ring button in minimap units; a skinned button shows a 27 px rim.
local function buttonRadius(button)
    local size = skinned[button] and 27 or math.max(button:GetWidth(), button:GetHeight())
    return size * button:GetEffectiveScale() / Minimap:GetEffectiveScale() / 2
end

-- Stock elements around the rim as {x, y, halfWidth, halfHeight} from the minimap centre.
local function stockBlocks()
    local half = Minimap:GetWidth() / 2
    local top = half + headerGap
    local blocks = {
        { 0, top + 10, 83, 10 },             -- header: tracking, zone, clock, calendar
        { 73.6, top - 10, 8, 8 },            -- date badge
        { -65.8, top - 10.7, 10.7, 10.7 },   -- mail at 0.65 scale
        { moonX, moonY, 12, 12 },
        { battlefieldX, battlefieldY, 18, 18 },
        { 0, -half - 14.5, 24, 5 },          -- coordinates
    }
    if queue then blocks[#blocks + 1] = { eyeX, eyeY, 17.5, 17.5 } end
    return blocks
end

-- Smallest gap between a button at this angle and everything around it; negative means overlap.
local function clearance(angle, radius, size, blocks, placed)
    local x, y = math.cos(math.rad(angle)) * radius, math.sin(math.rad(angle)) * radius
    local worst = math.huge
    for _, block in ipairs(blocks) do
        local dx = math.max(math.abs(x - block[1]) - block[3], 0)
        local dy = math.max(math.abs(y - block[2]) - block[4], 0)
        worst = math.min(worst, math.sqrt(dx * dx + dy * dy) - size)
    end
    for _, other in ipairs(placed) do
        local dx, dy = x - other[1], y - other[2]
        worst = math.min(worst, math.sqrt(dx * dx + dy * dy) - size - other[3] - 1)
    end
    return worst
end

-- Nearest free angle from start (counter-clockwise only unless both), or the roomiest one on a full ring.
local function findAngle(start, radius, size, blocks, placed, both)
    local best, bestGap = start, -math.huge
    for step = 0, 359 do
        for sign = 1, both and -1 or 1, -2 do
            local angle = (start + sign * step) % 360
            local gap = clearance(angle, radius, size, blocks, placed)
            if gap >= 0 then return angle end
            if gap > bestGap then best, bestGap = angle, gap end
        end
    end
    return best
end

local function occupy(placed, button, angle, radius)
    local radians = math.rad(angle)
    placed[#placed + 1] = { math.cos(radians) * radius, math.sin(radians) * radius, buttonRadius(button) }
end

local function placeOnRing(button, angle)
    local radius = ringRadius() * Minimap:GetEffectiveScale() / button:GetEffectiveScale()
    local radians = math.rad(angle)
    placing = true
    anchor(button, "CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
    placing = nil
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

-- A dropped button slides to the nearest spot that covers no stock element and no pinned button.
local function settleDropped(button)
    local settings = ui.Settings()
    local angle = savedAngle(button:GetName())
    if not settings.mapButtonsCircle or not angle or InCombatLockdown() then return end
    local radius, placed = ringRadius(), {}
    for other in pairs(tracked) do
        local otherAngle = other ~= button and other:IsShown() and savedAngle(other:GetName())
        if otherAngle then occupy(placed, other, otherAngle, radius) end
    end
    settings.mapButtonAngles[button:GetName()] =
        findAngle(angle, radius, buttonRadius(button), stockBlocks(), placed, true)
end

local function stopRingDrag(button)
    local dragging = dragUpdates[button] ~= nil
    if dragging and button:GetScript("OnUpdate") == updateRingDrag then
        button:SetScript("OnUpdate", dragUpdates[button] or nil)
    end
    dragUpdates[button] = nil
    if dragging then settleDropped(button) end
    scheduleLayout()
end

local function startRingDrag(button)
    if not ui.Settings().mapButtonsCircle or InCombatLockdown() or (button.db and button.db.lock) then return end
    dragUpdates[button] = button:GetScript("OnUpdate") or false
    button:SetScript("OnUpdate", updateRingDrag)
    updateRingDrag(button, 0)
end

-- LibDBIcon:Refresh and other addons move buttons back with SetPoint; put them back on the next frame.
local function onMoved(button)
    if not placing and dragUpdates[button] == nil then scheduleLayout() end
end

-- SetScript (LibDBIcon Lock, Unlock and Refresh) drops earlier hooks, so they are checked on every layout.
local function hookScript(button, script, handler)
    local marks = hooked[button]
    local current = button:GetScript(script)
    if current and marks[script] == current then return end
    button:HookScript(script, handler)
    marks[script] = button:GetScript(script)
end

local function findIcon(button)
    if button.icon then return button.icon end
    if button == XPerl_MinimapButton_Frame then return XPerl_MinitmapButton_Icon end
    -- A plain button in the stock style: tracking border plus an icon on the ARTWORK layer.
    local border, icon
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local texture = region:GetTexture()
            local path = type(texture) == "string" and texture:lower() or ""
            if path:find("minimap-trackingborder", 1, true) then
                border = true
            elseif not icon and region:GetDrawLayer() == "ARTWORK" and region ~= button:GetHighlightTexture()
                and not path:find("ui-minimap-background", 1, true) then
                icon = region
            end
        end
    end
    return border and icon
end

local function skinAddonButton(button)
    local icon = findIcon(button)
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
    skinned[button] = true
end

local function collect(container, visible)
    if not container then return end
    for _, button in ipairs({ container:GetChildren() }) do
        local name = button:GetName()
        if name and (tracked[button] or isAddonButton(button, name)) then
            if not tracked[button] then
                tracked[button] = button:GetScale()
                hooked[button] = {}
                skinAddonButton(button)
                hooksecurefunc(button, "SetPoint", onMoved)
                if not name:match("^LibDBIcon10_") then button:RegisterForDrag("LeftButton") end
            end
            hookScript(button, "OnShow", scheduleLayout)
            hookScript(button, "OnHide", stopRingDrag)
            hookScript(button, "OnDragStart", startRingDrag)
            hookScript(button, "OnDragStop", stopRingDrag)
            if button:IsShown() then visible[#visible + 1] = button end
        end
    end
end

-- Later LibDBIcon versions replace these methods, so the hooks are renewed when the function changes.
local function hookLibrary()
    local library = LibStub and LibStub("LibDBIcon-1.0", true)
    if not library then return end
    for _, method in ipairs({ "Register", "Refresh", "Show", "EnableLibrary" }) do
        if type(library[method]) == "function" and libraryHooks[method] ~= library[method] then
            hooksecurefunc(library, method, scheduleLayout)
            libraryHooks[method] = library[method]
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
    hookLibrary()

    local buttons = {}
    collect(Minimap, buttons)
    collect(MinimapBackdrop, buttons)
    collect(MinimapCluster, buttons)
    table.sort(buttons, function(a, b) return a:GetName() < b:GetName() end)

    local ring = settings.mapButtonsCircle
    -- On the ring buttons follow the minimap scale; in the bar they follow the bar scale.
    local effectiveScale = ring and Minimap:GetEffectiveScale() or row:GetEffectiveScale()
    for _, button in ipairs(buttons) do
        button:SetScale(tracked[button] * effectiveScale / button:GetParent():GetEffectiveScale())
        button:ClearAllPoints()
    end

    if ring then
        local radius, blocks, placed, free = ringRadius(), stockBlocks(), {}, {}
        for _, button in ipairs(buttons) do
            local angle = savedAngle(button:GetName())
            if angle then
                -- A saved spot can end up covered after the ring offset changes; use the nearest free one.
                angle = findAngle(angle, radius, buttonRadius(button), blocks, placed, true)
                placeOnRing(button, angle)
                occupy(placed, button, angle, radius)
            else
                free[#free + 1] = button
            end
        end
        for _, button in ipairs(free) do
            local angle = findAngle(firstAngle, radius, buttonRadius(button), blocks, placed)
            placeOnRing(button, angle)
            occupy(placed, button, angle, radius)
        end
        row:Hide()
        return
    end

    local length, breadth = 3, 0
    local vertical = settings.mapButtonsVertical
    placing = true
    for _, button in ipairs(buttons) do
        local scale = tracked[button]
        if vertical then
            button:SetPoint("TOP", row, "TOP", 0, -length / scale)
            length = length + button:GetHeight() * scale + spacing
            breadth = math.max(breadth, button:GetWidth() * scale)
        else
            button:SetPoint("LEFT", row, "LEFT", length / scale, 0)
            length = length + button:GetWidth() * scale + spacing
            breadth = math.max(breadth, button:GetHeight() * scale)
        end
    end
    placing = nil
    if #buttons > 0 then
        if vertical then row:SetSize(breadth + 4, length + 1) else row:SetSize(length + 1, breadth + 4) end
        row:Show()
    else
        row:Hide()
    end
end

-- Buttons created later by timers or load-on-demand addons show up as new minimap children.
local watcher = CreateFrame("Frame")
local watchElapsed, childCount = 0, -1
watcher:SetScript("OnUpdate", function(_, delta)
    watchElapsed = watchElapsed + delta
    if watchElapsed < 1 then return end
    watchElapsed = 0
    local count = Minimap:GetNumChildren() + MinimapCluster:GetNumChildren()
        + (MinimapBackdrop and MinimapBackdrop:GetNumChildren() or 0)
    if count ~= childCount then
        childCount = count
        scheduleLayout()
    end
end)

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
