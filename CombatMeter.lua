local _, ui = ...
local ru = ui.russian
local data = ui.CombatMeterData
local art = "Interface\\AddOns\\ForeverUI\\Art\\DamageMeter"
local sprites = {
    header = { 0, 560, 0, 56 },
    row = { 272, 536, 64, 102 },
    mode = { 272, 326, 150, 204 },
    modePressed = { 328, 382, 150, 204 },
    modeHover = { 384, 438, 150, 204 },
    gear = { 440, 494, 150, 204 },
    gearPressed = { 496, 550, 150, 204 },
    gearHover = { 552, 606, 150, 204 },
    session = { 620, 698, 0, 78 },
    sessionPressed = { 700, 778, 0, 78 },
    sessionHover = { 780, 858, 0, 78 },
    collapse = { 272, 308, 207, 245 },
    collapsePressed = { 310, 346, 207, 245 },
    expand = { 348, 384, 207, 245 },
    expandPressed = { 386, 422, 207, 245 },
    collapseHover = { 424, 460, 207, 245 },
    DEATHKNIGHT = { 272, 400, 248, 376 },
    DRUID = { 402, 530, 248, 376 },
    HUNTER = { 532, 660, 248, 376 },
    MAGE = { 662, 790, 248, 376 },
    PALADIN = { 792, 920, 248, 376 },
    PRIEST = { 0, 128, 378, 506 },
    ROGUE = { 130, 258, 378, 506 },
    SHAMAN = { 260, 388, 378, 506 },
    WARLOCK = { 390, 518, 378, 506 },
    WARRIOR = { 520, 648, 378, 506 },
}
local modes = {
    { 1, ru and "Урона нанесено" or "Damage done" },
    { 1, ru and "Урона в сек." or "Damage per second", true },
    { 2, ru and "Исцелено" or "Healing done" },
    { 2, ru and "Ед. здоровья в сек." or "Healing per second", true },
}
local demoDamage = {
    { name = "Jamato Stormcaller", class = "SHAMAN", total = 2647 },
    { name = "Emillus Ustabilius", class = "HUNTER", total = 1684 },
    { name = "Bift Lance", class = "MAGE", total = 1057 },
    { name = "Zoro Santoryo", class = "PALADIN", total = 886 },
    { name = "Pavlo Vodianiy", class = "PALADIN", total = 60 },
}
local demo = { demoDamage, {
    { name = demoDamage[5].name, class = "PALADIN", total = 2622 },
    { name = demoDamage[4].name, class = "PALADIN", total = 36 },
} }
local headerHeight, rowGap = 29, 3
local rowInset, fillInset = 2, 1
local rowPadding = rowInset * 2
local headerButtonLift = 2
local minWidth, maxWidth, minRows, maxRows = 145, 600, 1, 15
ui.CombatMeterLimits = { minWidth = minWidth, maxWidth = maxWidth, minRows = minRows, maxRows = maxRows }
local minHeight = headerHeight + 18
local snapDistance = 14
local dockPoints = {
    LEFT = { "TOPRIGHT", "TOPLEFT" },
    RIGHT = { "TOPLEFT", "TOPRIGHT" },
    TOP = { "BOTTOMRIGHT", "TOPRIGHT" },
    BOTTOM = { "TOPRIGHT", "BOTTOMRIGHT" },
}
local settings, options, dropdown
local windows = {}
local docked, anchor, dockSide
local editor = ForeverStockUIEditMode

local function sprite(texture, key)
    local rect = sprites[key]
    texture:SetTexture(art)
    texture:SetTexCoord(rect[1] / 1024, rect[2] / 1024, rect[3] / 512, rect[4] / 512)
end

local function button(parent, width, height, texture, action, hint)
    local control = CreateFrame("Button", nil, parent)
    control:SetSize(width, height)
    -- The arrow and gear sprites have more transparent padding below their artwork.
    local y = (texture == "mode" or texture == "gear") and -3.5 or 0
    for _, kind in ipairs({ "Normal", "Pushed", "Highlight" }) do
        local region = control:CreateTexture(nil, "ARTWORK")
        control["Set" .. kind .. "Texture"](control, region)
        region:SetPoint("TOPLEFT", control, "TOPLEFT", 0, y)
        region:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", 0, y)
    end
    sprite(control:GetNormalTexture(), texture)
    sprite(control:GetPushedTexture(), texture .. "Pressed")
    sprite(control:GetHighlightTexture(), texture .. "Hover")
    control:SetScript("OnClick", action)
    control:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(hint)
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", GameTooltip_Hide)
    return control
end

local function numberText(amount, rate)
    if not rate then return ("%.0f"):format(amount) end
    local value = ("%.1f"):format(amount):gsub("%.0$", "")
    if ru then value = value:gsub("%.", ",") end
    return value
end

local function formatValues(total, duration, rateFirst)
    local amount = numberText(total)
    local rate = numberText(total / math.max(1, duration), true)
    if rateFirst then return rate .. " (" .. amount .. ")" end
    return amount .. " (" .. rate .. ")"
end

local function rowTooltip(row)
    local actor = row.actor
    if not actor then return end
    GameTooltip:SetOwner(row, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(actor.name, 1, 0.82, 0)
    GameTooltip:AddLine(row.value:GetText(), 1, 1, 1)
    if actor.spells then
        local spells = {}
        for _, spell in pairs(actor.spells) do spells[#spells + 1] = spell end
        table.sort(spells, function(a, b) return a.total > b.total end)
        for i = 1, math.min(6, #spells) do
            local spell = spells[i]
            GameTooltip:AddDoubleLine(spell.name, numberText(spell.total), 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function makeRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetWidth(26)
    row.icon:SetPoint("LEFT")
    local track = row:CreateTexture(nil, "BACKGROUND")
    sprite(track, "row")
    track:SetAllPoints(row)
    row.fill = row:CreateTexture(nil, "ARTWORK")
    row.fill:SetPoint("TOPLEFT", row, "TOPLEFT", fillInset, -fillInset)
    row.value = row:CreateFontString(nil, "OVERLAY")
    row.value:SetPoint("RIGHT", -5, 0)
    row.value:SetJustifyH("RIGHT")
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnEnter", rowTooltip)
    row:SetScript("OnClick", rowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:Hide()
    return row
end

local function playerIcon(texture, class)
    if sprites[class] then
        sprite(texture, class)
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    end
end

local function renderRows(window)
    local mode = modes[window.config.mode]
    local rows, actors = window.rows, window.actors
    local limit = window.visibleRows
    window.offset = math.min(math.max(0, #actors - limit), math.max(0, window.offset))
    local max = actors[1] and actors[1].total or 1
    local fillWidth = window:GetWidth() - 2 * (rowInset + fillInset)
    for i, row in ipairs(rows) do
        local rank = i + window.offset
        local actor = i <= limit and actors[rank]
        row.actor = actor or nil
        if actor then
            local color = RAID_CLASS_COLORS[actor.class]
            local r, g, b = color and color.r or 0.72, color and color.g or 0.64, color and color.b or 0.43
            row.name:SetText(("%d. %s"):format(rank, actor.name))
            row.value:SetText(formatValues(actor.total, window.duration, mode[3]))
            playerIcon(row.icon, actor.class)
            row.fill:SetVertexColor(r, g, b)
            row.fill:SetWidth(math.max(1, fillWidth * actor.total / max))
            row:Show()
        else
            row:Hide()
        end
    end
end

local function render(window)
    renderRows(window)
    window.empty:SetShown(window.visibleRows > 0 and #window.actors == 0)
end

local function updateHeader(window)
    local width = window:GetWidth()
    local live = data.GetLiveDuration()
    local showClock = width >= 225 and live ~= nil
    if showClock then
        local seconds = math.floor(live)
        window.clock:SetFormattedText("[%02d:%02d]", math.floor(seconds / 60), seconds % 60)
    end
    if window.headerWidth == width and window.headerClock == showClock then return end
    window.headerWidth, window.headerClock = width, showClock
    window.clock:SetShown(showClock)
    window.title:SetShown(width >= 180)
    window.sessionButton:SetWidth(width < 180 and 36 or 50)
    window.modeButton:ClearAllPoints()
    if showClock then
        window.modeButton:SetPoint("LEFT", window.clock, "RIGHT", 4, headerButtonLift)
    else
        window.modeButton:SetPoint("LEFT", window.header, "LEFT", 4, headerButtonLift)
    end
end

local function sessionLabel(id)
    if id == -1 then return ru and "В" or "O" end
    return ru and "Т" or "C"
end

local function currentSegment(window)
    if window.segment then
        for _, segment in ipairs(data.history) do
            if segment == window.segment then return segment end
        end
        window.segment, window.offset = nil, 0
        window.sessionText:SetText(sessionLabel(window.config.session))
    end
    return data.GetSegment(window.config.session)
end

local function refresh(window)
    if not window:IsShown() then return end
    updateHeader(window)
    if window.config.collapsed then return end
    local mode = modes[window.config.mode]
    local combat = currentSegment(window)
    if combat ~= window.combat then window.combat, window.offset = combat, 0 end
    local actors = window.actors
    wipe(actors)
    window.duration = data.GetDuration(combat)
    if combat then
        for _, actor in pairs(combat[mode[1]]) do actors[#actors + 1] = actor end
        table.sort(actors, function(a, b)
            if a.total == b.total then return a.name < b.name end
            return a.total > b.total
        end)
    end
    if #actors == 0 and editor and editor:IsShown() then
        window.duration = 29
        for i, actor in ipairs(demo[mode[1]]) do actors[i] = actor end
    end
    render(window)
end

local function rowStep()
    return math.max(settings.meterRowHeight, settings.meterTextSize) + rowGap
end

local function heightForRows(rows)
    return headerHeight + rows * rowStep() + rowPadding
end

local function updateRows(window, previewRows)
    local step, height = rowStep(), settings.meterRowHeight
    local limit = previewRows or math.max(0,
        math.min(maxRows, math.floor((window:GetHeight() - headerHeight - rowPadding + 0.001) / step)))
    window.visibleRows = limit
    for i = #window.rows + 1, limit do
        local row = makeRow(window.content)
        if previewRows then row:EnableMouse(false) end
        window.rows[i] = row
    end
    local font = type(NUMBERFONT) == "string" and NUMBERFONT or STANDARD_TEXT_FONT
    local fill = ui.MediaPath("meterbar", settings.meterBarTexture, true) or ui.MediaPath("meterbar", 1, true)
    for index, row in ipairs(window.rows) do
        local y = -rowInset - (index - 1) * step - (step - rowGap - height) / 2
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", window.content, "TOPLEFT", rowInset, y)
        row:SetPoint("TOPRIGHT", window.content, "TOPRIGHT", -rowInset, y)
        row:SetHeight(height)
        row.icon:SetHeight(math.min(26, height))
        row.fill:SetHeight(height - 2 * fillInset)
        row.fill:SetTexture(fill)
        row.name:SetFont(font, settings.meterTextSize, "OUTLINE")
        row.value:SetFont(font, settings.meterTextSize, "OUTLINE")
    end
end

local function updateBackground(texture)
    texture:SetTexture(ui.MediaPath("meterbackground", settings.meterBackgroundTexture, true)
        or ui.MediaPath("meterbackground", 1, true))
    texture:SetAlpha(settings.meterBackground / 100)
end

local function bounded(value, low, high, fallback)
    if type(value) ~= "number" or value ~= value then return fallback end
    return math.max(low, math.min(high, value))
end

local function expandedHeight(window)
    return bounded(window.config.height, minHeight, heightForRows(maxRows), heightForRows(settings[window.rowsKey]))
end

local function updateDockClamp()
    if not docked then return end
    local width, height = docked:GetSize()
    anchor:SetClampRectInsets(dockSide == "LEFT" and -width or 0, dockSide == "RIGHT" and width or 0,
        dockSide == "TOP" and height or 0, dockSide == "BOTTOM" and -height or 0)
end

local function layout(window)
    local config = window.config
    local width = bounded(config.width, minWidth, maxWidth, settings.meterWidth)
    window:SetMaxResize(maxWidth, heightForRows(maxRows))
    window:SetSize(width, config.collapsed and headerHeight or expandedHeight(window))
    window.content:SetShown(not config.collapsed)
    local collapse = config.collapsed and "expand" or "collapse"
    sprite(window.collapse:GetNormalTexture(), collapse)
    sprite(window.collapse:GetPushedTexture(), collapse .. "Pressed")
    updateBackground(window.background)
    updateHeader(window)
    updateRows(window)
    window:SetShown(settings.meterEnabled)
    refresh(window)
    updateDockClamp()
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
end

local function ratioToParent(window)
    return window:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function windowPosition(window)
    local right, top = window:GetRight(), window:GetTop()
    if not right or not top then return end
    local ratio = ratioToParent(window)
    return { right * ratio - UIParent:GetRight(), top * ratio - UIParent:GetTop() }
end

local function placeWindow(window)
    local position = window.placement.position
    if type(position) ~= "table" or type(position[1]) ~= "number" or type(position[2]) ~= "number"
        or math.abs(position[1]) == math.huge or math.abs(position[2]) == math.huge
        or position[1] ~= position[1] or position[2] ~= position[2] then return end
    local ratio = ratioToParent(window)
    window:ClearAllPoints()
    window:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", position[1] / ratio, position[2] / ratio)
end

local function preserveDefaultPosition(window)
    local entry = window.editEntry
    if entry and not entry.points then entry.points = { { window:GetPoint() } } end
end

local function peerOf(window)
    return windows[1] == window and windows[2] or windows[1]
end

local function horizontalDock()
    return dockSide == "LEFT" or dockSide == "RIGHT"
end

local function undock()
    if not docked then return end
    docked.placement.position = windowPosition(docked) or docked.placement.position
    anchor.placement.position = windowPosition(anchor) or anchor.placement.position
    anchor:SetClampRectInsets(0, 0, 0, 0)
    docked:SetClampedToScreen(true)
    if docked.editEntry then docked.editEntry.docked = nil end
    placeWindow(anchor)
    placeWindow(docked)
    settings.combatMeters.dock = nil
    docked, anchor, dockSide = nil, nil, nil
end

local function attach(window, side)
    docked, anchor, dockSide = window, peerOf(window), side
    settings.combatMeters.dock = { window.key, side }
    if horizontalDock() then
        local height = expandedHeight(anchor)
        window.config.height, anchor.config.height = height, height
    else
        local width = bounded(anchor.config.width, minWidth, maxWidth, settings.meterWidth)
        window.config.width, anchor.config.width = width, width
    end
    window.placement.scale = anchor:GetScale()
    window:SetScale(window.placement.scale)
    if window.editEntry then window.editEntry.docked = true end
    window:SetClampedToScreen(false)
    window:ClearAllPoints()
    local points = dockPoints[side]
    window:SetPoint(points[1], anchor, points[2], 0, 0)
    layout(anchor)
    layout(window)
end

local function edges(window)
    local left, right, top, bottom = window:GetLeft(), window:GetRight(), window:GetTop(), window:GetBottom()
    if not left or not right or not top or not bottom then return end
    local ratio = ratioToParent(window)
    return left * ratio, right * ratio, top * ratio, bottom * ratio
end

local function snapWindow(window)
    local peer = peerOf(window)
    if not peer or not window:IsVisible() or not peer:IsVisible() or peer.interaction then return end
    local left, right, top, bottom = edges(window)
    local peerLeft, peerRight, peerTop, peerBottom = edges(peer)
    if not left or not peerLeft then return end
    local side, nearest = nil, snapDistance
    local function consider(candidate, distance)
        distance = math.abs(distance)
        if distance <= nearest then side, nearest = candidate, distance end
    end
    local overlapY = math.min(snapDistance, (top - bottom) / 2, (peerTop - peerBottom) / 2)
    if math.min(top, peerTop) - math.max(bottom, peerBottom) >= overlapY then
        consider("LEFT", right - peerLeft)
        consider("RIGHT", left - peerRight)
    end
    if math.min(right, peerRight) - math.max(left, peerLeft) >= snapDistance then
        consider("TOP", bottom - peerTop)
        consider("BOTTOM", top - peerBottom)
    end
    if side then attach(window, side) end
end

local function resizeDock(window)
    local drag = window.dockResize
    local x, y = GetCursorPosition()
    local scale = window:GetEffectiveScale()
    local width = bounded(drag.width + (x - drag.x) / scale, minWidth, maxWidth)
    local height = bounded(drag.height - (y - drag.y) / scale, minHeight, heightForRows(maxRows))
    if math.abs(width - window:GetWidth()) < 0.01 and math.abs(height - window:GetHeight()) < 0.01 then return end
    local horizontal = horizontalDock()
    local peer = peerOf(window)
    window.config.width, window.config.height = width, height
    if horizontal then
        peer.config.height = height
        if not peer.config.collapsed then peer:SetHeight(height) end
    else
        peer.config.width = width
        peer:SetWidth(width)
    end
    window:SetSize(width, height)
    local ratio = ratioToParent(anchor)
    local right, top = drag.position[1], drag.position[2]
    -- Keep the top-left of the resized window fixed while its neighbor follows.
    if not horizontal or window == anchor or dockSide == "LEFT" then
        right = right + (width - drag.width) * ratio
    end
    if window == docked and dockSide == "TOP" then top = top - (height - drag.height) * ratio end
    updateDockClamp()
    anchor.placement.position = { right, top }
    placeWindow(anchor)
end

local function startInteraction(window, sizing)
    if window.interaction or peerOf(window).interaction or (sizing and window.config.collapsed) then return end
    local position = sizing and docked and windowPosition(anchor)
    if sizing and docked and not position then return end
    preserveDefaultPosition(window)
    if window.editEntry then window.editEntry.moving = true end
    window.interaction = sizing and "size" or "move"
    if position then
        local x, y = GetCursorPosition()
        window.dockResize = { x = x, y = y, width = window:GetWidth(), height = window:GetHeight(),
            position = position }
        window:SetScript("OnUpdate", resizeDock)
    elseif sizing then
        window:StartSizing("BOTTOMRIGHT")
    else
        undock()
        window:StartMoving()
    end
end

local function stopInteraction(window)
    local interaction = window.interaction
    if not interaction then return end
    local resizedDock = window.dockResize
    if resizedDock then
        if window:IsVisible() then resizeDock(window) end
        window:SetScript("OnUpdate", nil)
        window.dockResize = nil
        anchor.placement.position = windowPosition(anchor) or anchor.placement.position
        placeWindow(anchor)
    else
        window:StopMovingOrSizing()
        window:SetUserPlaced(false)
        if interaction == "size" then
            window.config.width, window.config.height = window:GetWidth(), window:GetHeight()
        end
        window.placement.position = windowPosition(window) or window.placement.position
        placeWindow(window)
        if interaction == "move" then snapWindow(window) end
    end
    window.interaction = nil
    if window.editEntry then window.editEntry.moving = nil end
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
end

local function setWindowScale(window, value)
    window = anchor or window
    preserveDefaultPosition(window)
    window.placement.position = windowPosition(window) or window.placement.position
    window.placement.scale = value
    window:SetScale(value)
    if docked then
        docked.placement.scale = value
        docked:SetScale(value)
    end
    placeWindow(window)
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
end

local function changeMode(window, index)
    window.config.mode, window.offset = index, 0
    window.title:SetText(modes[index][2])
    refresh(window)
end

local function modeMenu(window, anchor)
    local items = {}
    for i, mode in ipairs(modes) do
        items[i] = { text = mode[2], checked = i == window.config.mode,
            func = function() changeMode(window, i) end }
    end
    EasyMenu(items, dropdown, anchor, 0, 0, "MENU")
end

local function sessionMenu(window, anchor)
    local function item(label, short, id, segment)
        return { text = label, checked = segment and window.segment == segment
            or not segment and not window.segment and window.config.session == id,
            func = function()
                window.segment, window.offset = segment, 0
                if not segment then window.config.session = id end
                window.sessionText:SetText(short)
                refresh(window)
            end }
    end
    local items = {
        item(ru and "Текущий бой" or "Current fight", sessionLabel(0), 0),
        item(ru and "Все бои" or "Overall", sessionLabel(-1), -1),
    }
    for i, combat in ipairs(data.history) do
        local label = combat.name or (ru and "Бой" or "Fight")
        items[#items + 1] = item(i .. ". " .. label, tostring(i), nil, combat)
    end
    EasyMenu(items, dropdown, anchor, 0, 0, "MENU")
end

local function createWindow(key, label, mode, y)
    local name = "ForeverStockUI" .. key .. "Meter"
    local window = CreateFrame("Frame", name, UIParent)
    window:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", -27, y)
    window:SetFrameStrata("LOW")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetResizable(true)
    window:SetMinResize(minWidth, minHeight)
    window:EnableMouseWheel(true)
    window:Hide()
    window.key = key
    window.rowsKey = "meter" .. key .. "Rows"
    window.rows, window.actors, window.offset, window.duration = {}, {}, 0, 0
    if type(settings.editLayout[name]) ~= "table" then settings.editLayout[name] = {} end
    window.placement = settings.editLayout[name]
    if type(settings.combatMeters[key]) ~= "table" then settings.combatMeters[key] = {} end
    window.config = settings.combatMeters[key]
    if not modes[window.config.mode] then window.config.mode = mode end
    if window.config.session ~= -1 then window.config.session = 0 end
    window.config.collapsed = window.config.collapsed == true

    local header = CreateFrame("Frame", nil, window)
    window.header = header
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(headerHeight)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() startInteraction(window, false) end)
    header:SetScript("OnDragStop", function() stopInteraction(window) end)
    local headerArt = header:CreateTexture(nil, "ARTWORK")
    sprite(headerArt, "header")
    headerArt:SetAllPoints(header)
    local content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    content:SetPoint("BOTTOMRIGHT")
    window.content = content
    window.background = content:CreateTexture(nil, "BACKGROUND")
    window.background:SetAllPoints(content)
    window.empty = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.empty:SetPoint("CENTER")
    window.empty:SetText(ru and "Нет данных о бое" or "No combat data")

    local grip = CreateFrame("Button", nil, content)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(content:GetFrameLevel() + 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() startInteraction(window, true) end)
    grip:SetScript("OnDragStop", function() stopInteraction(window) end)

    window.collapse = button(header, 22, 23, "collapse", function()
        window.config.collapsed = not window.config.collapsed
        layout(window)
    end, ru and "Свернуть или развернуть" or "Collapse or expand")
    window.collapse:SetPoint("RIGHT", header, "RIGHT", -4, headerButtonLift)
    local gear = button(header, 28, 28, "gear", function(self)
        local scales = {}
        for _, percent in ipairs({ 60, 75, 90, 100, 110, 125, 150, 175, 200 }) do
            scales[#scales + 1] = { text = percent .. "%", checked = window:GetScale() == percent / 100,
                func = function() setWindowScale(window, percent / 100) end }
        end
        EasyMenu({
            { text = ru and "Настройки" or "Settings", notCheckable = true, func = function()
                ui.OpenOptions(options)
            end },
            { text = ru and "Масштаб окна" or "Window scale", hasArrow = true, notCheckable = true, menuList = scales },
            { text = ru and "Сбросить статистику" or "Reset statistics", notCheckable = true, func = function()
                data.Reset()
                for _, meter in ipairs(windows) do refresh(meter) end
            end },
        }, dropdown, self, 0, 0, "MENU")
    end, ru and "Настройки измерителя" or "Meter settings")
    gear:SetPoint("RIGHT", window.collapse, "LEFT", -1, 0)
    local session = button(header, 50, 32, "session", function(self) sessionMenu(window, self) end,
        ru and "Выбрать бой" or "Select a fight")
    window.sessionButton = session
    session:SetPoint("RIGHT", gear, "LEFT", -1, 0)
    window.sessionText = session:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.sessionText:SetPoint("CENTER")
    window.sessionText:SetText(sessionLabel(window.config.session))

    window.clock = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.clock:SetPoint("LEFT", header, "LEFT", 4, 0)
    window.clock:SetWordWrap(false)
    window.clock:SetText("[00:00]")
    local selectMode = button(header, 29, 29, "mode", function(self) modeMenu(window, self) end,
        ru and "Выбрать показатель" or "Select a metric")
    window.modeButton = selectMode
    window.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.title:SetPoint("LEFT", selectMode, "RIGHT", 2, -headerButtonLift)
    window.title:SetPoint("RIGHT", session, "LEFT", -2, -headerButtonLift)
    window.title:SetJustifyH("LEFT")
    window.title:SetWordWrap(false)
    window.title:SetText(modes[window.config.mode][2])

    window:SetScript("OnMouseWheel", function(self, delta)
        if self.config.collapsed then return end
        self.offset = self.offset - delta
        render(self)
    end)
    window:SetScript("OnSizeChanged", function(self)
        if self.interaction ~= "size" and not (docked and (docked.dockResize or anchor.dockResize)) then return end
        updateHeader(self)
        updateRows(self)
        render(self)
    end)
    window:HookScript("OnHide", stopInteraction)
    windows[#windows + 1] = window
    if ui.RegisterEditFrame then
        local entry = ui.RegisterEditFrame(window, label, options)
        window.editEntry = entry
        entry.onDragStart = undock
        entry.onDragStop = function() snapWindow(window) end
        entry.beforeResetPosition = undock
        entry.changeScale = function(value)
            if not docked then return end
            setWindowScale(window, value)
            return true
        end
        preserveDefaultPosition(window)
    end
    window:SetScale(bounded(window.placement.scale, 0.4, 2, 1))
    placeWindow(window)
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    settings = ui.Settings()
    options = "meter"
    dropdown = CreateFrame("Frame", "ForeverStockUIMeterDropdown", UIParent, "UIDropDownMenuTemplate")
    local preview
    local function apply()
        for _, window in ipairs(windows) do layout(window) end
        if preview then
            preview:SetHeight(heightForRows(#preview.actors) - headerHeight)
            updateBackground(preview.background)
            updateRows(preview, #preview.actors)
            renderRows(preview)
        end
    end
    local function resetDimension(field, key)
        return function()
            for _, window in ipairs(windows) do
                if not key or window.rowsKey == key then
                    window.config[field] = nil
                    if field == "height" and horizontalDock() then
                        local height = expandedHeight(window)
                        window.config.height, peerOf(window).config.height = height, height
                    end
                end
            end
            apply()
        end
    end
    -- Built lazily by the options window: a three-row sample that follows every setting live.
    local function buildPreview(parent)
        preview = CreateFrame("Frame", nil, parent)
        preview:SetPoint("TOPLEFT", 0, 0)
        preview:SetWidth(260)
        preview.content, preview.rows = preview, {}
        preview.config, preview.offset, preview.duration = { mode = 1 }, 0, 29
        preview.actors = {
            { name = ru and "Шаман" or "Shaman", class = "SHAMAN", total = 2647 },
            { name = ru and "Охотник" or "Hunter", class = "HUNTER", total = 1684 },
            { name = ru and "Маг" or "Mage", class = "MAGE", total = 1057 },
        }
        preview.background = preview:CreateTexture(nil, "BACKGROUND")
        preview.background:SetAllPoints(preview)
        apply()
        return preview:GetHeight()
    end
    ui.CombatMeter = {
        Apply = apply,
        ResetWidth = resetDimension("width"),
        ResetDamageRows = resetDimension("height", "meterDamageRows"),
        ResetHealingRows = resetDimension("height", "meterHealingRows"),
        BuildPreview = buildPreview,
    }
    if type(settings.combatMeters) ~= "table" then settings.combatMeters = {} end
    if type(settings.editLayout) ~= "table" then settings.editLayout = {} end
    createWindow("Damage", ru and "Измеритель урона" or "Damage meter", 1, 492)
    createWindow("Healing", ru and "Измеритель лечения" or "Healing meter", 4, 332)
    local savedDock = settings.combatMeters.dock
    if type(savedDock) == "table" and dockPoints[savedDock[2]] then
        for _, window in ipairs(windows) do
            if window.key == savedDock[1] then attach(window, savedDock[2]) end
        end
    end
    apply()

    local function refreshWindows()
        for _, window in ipairs(windows) do refresh(window) end
    end
    if editor then
        editor:HookScript("OnShow", refreshWindows)
        editor:HookScript("OnHide", refreshWindows)
    end
    local elapsed = 0
    self:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < (settings.meterInterval or 0.25) then return end
        elapsed = 0
        data.Update()
        if settings.meterEnabled then refreshWindows() end
    end)
end)
