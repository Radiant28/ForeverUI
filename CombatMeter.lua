local _, ui = ...
local ru = ui.russian
local data = ui.CombatMeterData
local art = "Interface\\AddOns\\ForeverUI\\Art\\DamageMeter"
local sprites = {
    -- rows 47-55 of the sheet are a fading shadow: cut off so the bars start right under the header
    header = { 0, 560, 0, 47 },
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
-- { data kind (1 damage, 2 healing, 3 threat), title, show the rate first }
local THREAT = 3
local modes = {
    { 1, ru and "Урона нанесено" or "Damage done" },
    { 1, ru and "Урона в сек." or "Damage per second", true },
    { 2, ru and "Исцелено" or "Healing done" },
    { 2, ru and "Ед. здоровья в сек." or "Healing per second", true },
    { THREAT, ru and "Угроза" or "Threat" },
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
}, {
    { name = demoDamage[4].name, class = "PALADIN", total = 18420, percent = 100, tanking = true },
    { name = demoDamage[1].name, class = "SHAMAN", total = 15110, percent = 82 },
    { name = demoDamage[3].name, class = "MAGE", total = 9870, percent = 54 },
} }
local headerHeight = 29
local function rowGap() return settings and settings.meterRowGap or 1 end
local rowInset, fillInset = 2, 1
local rowPadding = rowInset * 2
local headerButtonLift = 2
local minWidth, maxWidth, minRows, maxRows = 145, 600, 1, 15
ui.CombatMeterLimits = { minWidth = minWidth, maxWidth = maxWidth, minRows = minRows, maxRows = maxRows }
local minHeight = headerHeight + 18
local snapDistance = 14
local maxWindows = 10
local dockPoints = {
    LEFT = { "TOPRIGHT", "TOPLEFT" },
    RIGHT = { "TOPLEFT", "TOPRIGHT" },
    TOP = { "BOTTOMRIGHT", "TOPRIGHT" },
    BOTTOM = { "TOPRIGHT", "BOTTOMRIGHT" },
}
local settings, options, dropdown
-- Active windows in creation order; removed ones wait in the pool so a new window can reuse the frame.
local windows, pool, byKey = {}, {}, {}
local editor = ForeverStockUIEditMode
local listeners = {}

local function shown(region, visible)
    if visible then region:Show() else region:Hide() end
end

local function notify()
    for _, listener in ipairs(listeners) do listener() end
end

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

-- Number style (settings): meterNumberFormat = full | tens | hundreds | short, meterDecimals 0-2 for
-- rates and short values, meterTrimZeros drops ",0", meterSeparator groups thousands ("12 345").
local suffixes = ru and { "к", "м", "млрд" } or { "k", "m", "b" }

local function fixed(value, decimals)
    local text = ("%." .. decimals .. "f"):format(value)
    local options = settings or {}
    if decimals > 0 and options.meterTrimZeros ~= false then text = text:gsub("%.?0+$", "") end
    local sign, int, fraction = text:match("^(%-?)(%d+)(.*)$")
    if not int then return text end
    if options.meterSeparator then
        int = int:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    end
    if ru then fraction = fraction:gsub("%.", ",") end
    return sign .. int .. fraction
end

local function numberText(amount, rate)
    amount = amount or 0
    local style = settings and settings.meterNumberFormat or "full"
    local decimals = math.max(0, math.min(2, settings and settings.meterDecimals or 1))
    if style == "short" then
        local magnitude, value, suffix = math.abs(amount), amount, ""
        if magnitude >= 1e9 then
            value, suffix = amount / 1e9, suffixes[3]
        elseif magnitude >= 1e6 then
            value, suffix = amount / 1e6, suffixes[2]
        elseif magnitude >= 1e3 then
            value, suffix = amount / 1e3, suffixes[1]
        end
        return fixed(value, (suffix ~= "" or rate) and decimals or 0) .. suffix
    end
    local step = style == "tens" and 10 or style == "hundreds" and 100 or 1
    if step > 1 then return fixed(math.floor(amount / step + 0.5) * step, 0) end
    return fixed(amount, rate and decimals or 0)
end
ui.CombatMeterNumber = numberText

local function formatValues(total, duration, rateFirst)
    local amount = numberText(total)
    local rate = numberText(total / math.max(1, duration), true)
    local second = settings and settings.meterSecondary
    if second == "none" then return rateFirst and rate or amount end
    if rateFirst then return rate .. " (" .. amount .. ")" end
    return amount .. " (" .. rate .. ")"
end

local function threatText(actor)
    return numberText(actor.total) .. " (" .. math.floor((actor.percent or 0) + 0.5) .. "%)"
end

local function rowTooltip(row)
    local actor = row.actor
    if not actor then return end
    GameTooltip:SetOwner(row, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(actor.name, 1, 0.82, 0)
    GameTooltip:AddLine(row.value:GetText(), 1, 1, 1)
    if actor.tanking then GameTooltip:AddLine(ru and "Удерживает цель" or "Holding aggro", 1, 0.3, 0.2) end
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
    -- Solid track (the old sprite had a translucent gradient and a transparent strip below it).
    row.track = row:CreateTexture(nil, "BACKGROUND")
    row.track:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.track:SetAllPoints(row)
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
    local threat = mode[1] == THREAT
    local rows, actors = window.rows, window.actors
    local limit = window.visibleRows
    window.offset = math.min(math.max(0, #actors - limit), math.max(0, window.offset))
    local max = actors[1] and actors[1].total or 1
    if max <= 0 then max = 1 end
    local fillWidth = window:GetWidth() - 2 * (rowInset + fillInset)
    for i, row in ipairs(rows) do
        local rank = i + window.offset
        local actor = i <= limit and actors[rank]
        row.actor = actor or nil
        if actor then
            local color = RAID_CLASS_COLORS[actor.class]
            local r, g, b = color and color.r or 0.72, color and color.g or 0.64, color and color.b or 0.43
            row.name:SetText(("%d. %s"):format(rank, actor.name))
            if threat then
                row.value:SetText(threatText(actor))
                if actor.tanking then row.value:SetTextColor(1, 0.35, 0.25) else row.value:SetTextColor(1, 1, 1) end
            else
                row.value:SetText(formatValues(actor.total, window.duration, mode[3]))
                row.value:SetTextColor(1, 1, 1)
            end
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
    shown(window.empty, window.visibleRows > 0 and #window.actors == 0)
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
    shown(window.clock, showClock)
    shown(window.title, width >= 180)
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

---------------------------------------------------------------------------------------------------
-- Threat: read live from the client for the hostile target (or focus) against every group member.
---------------------------------------------------------------------------------------------------
local threatSeen = {}
local function threatUnit(actors, pool, unit, mob)
    if not UnitExists(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or threatSeen[guid] then return end
    threatSeen[guid] = true
    local tanking, _, scaled, _, value = UnitDetailedThreatSituation(unit, mob)
    if type(value) ~= "number" or value <= 0 then return end
    local _, class = UnitClass(unit)
    local index = #actors + 1
    local actor = pool[index] or {}
    pool[index] = actor
    actor.name, actor.class = UnitName(unit) or "?", UnitIsPlayer(unit) and class or nil
    actor.total, actor.percent, actor.tanking = value / 100, scaled or 0, tanking and true or nil
    actors[index] = actor
end

local function collectThreat(actors, pool)
    local mob
    for _, unit in ipairs({ "target", "focus" }) do
        if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDead(unit) then mob = unit break end
    end
    if not mob then return end
    wipe(threatSeen)
    local raid = GetNumRaidMembers()
    if raid > 0 then
        for i = 1, raid do
            threatUnit(actors, pool, "raid" .. i, mob)
            threatUnit(actors, pool, "raidpet" .. i, mob)
        end
    else
        threatUnit(actors, pool, "player", mob)
        threatUnit(actors, pool, "pet", mob)
        for i = 1, GetNumPartyMembers() do
            threatUnit(actors, pool, "party" .. i, mob)
            threatUnit(actors, pool, "partypet" .. i, mob)
        end
    end
    return UnitName(mob)
end

local function sortActors(a, b)
    if a.total == b.total then return a.name < b.name end
    return a.total > b.total
end

local function refresh(window)
    if not window:IsShown() then return end
    updateHeader(window)
    if window.config.collapsed then return end
    local mode = modes[window.config.mode]
    local actors = window.actors
    wipe(actors)
    if mode[1] == THREAT then
        window.threatPool = window.threatPool or {}
        local mob = collectThreat(actors, window.threatPool)
        local title = mob and (mode[2] .. ": " .. mob) or mode[2]
        if window.titleText ~= title then
            window.titleText = title
            window.title:SetText(title)
        end
        window.empty:SetText(mob and (ru and "Нет угрозы" or "No threat")
            or (ru and "Нет враждебной цели" or "No hostile target"))
    else
        local combat = currentSegment(window)
        if combat ~= window.combat then window.combat, window.offset = combat, 0 end
        window.duration = data.GetDuration(combat)
        if combat then
            for _, actor in pairs(combat[mode[1]]) do actors[#actors + 1] = actor end
        end
        window.empty:SetText(ru and "Нет данных о бое" or "No combat data")
    end
    table.sort(actors, sortActors)
    if #actors == 0 and editor and editor:IsShown() then
        window.duration = 29
        for i, actor in ipairs(demo[mode[1]]) do actors[i] = actor end
    end
    render(window)
end

local function rowStep()
    return math.max(settings.meterRowHeight, settings.meterTextSize) + rowGap()
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
        local y = -rowInset - (index - 1) * step - (step - rowGap() - height) / 2
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", window.content, "TOPLEFT", rowInset, y)
        row:SetPoint("TOPRIGHT", window.content, "TOPRIGHT", -rowInset, y)
        row:SetHeight(height)
        -- Class sprites are square: the icon follows the row height in both directions.
        local iconSize = math.min(26, height)
        row.icon:SetSize(iconSize, iconSize)
        row.fill:SetHeight(height - 2 * fillInset)
        row.fill:SetTexture(fill)
        local track = settings.meterRowColor or { 0.06, 0.06, 0.07, 1 }
        row.track:SetVertexColor(track[1], track[2], track[3], track[4] or 1)
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

---------------------------------------------------------------------------------------------------
-- Docking: any two free windows can snap together into a pair; the docked one follows its anchor.
---------------------------------------------------------------------------------------------------
local function horizontalDock(pair)
    return pair and (pair.side == "LEFT" or pair.side == "RIGHT")
end

local function peerOf(window)
    local pair = window.pair
    if not pair then return end
    return pair.docked == window and pair.anchor or pair.docked
end

local function updateDockClamp(pair)
    if not pair then return end
    local width, height = pair.docked:GetSize()
    local side = pair.side
    pair.anchor:SetClampRectInsets(side == "LEFT" and -width or 0, side == "RIGHT" and width or 0,
        side == "TOP" and height or 0, side == "BOTTOM" and -height or 0)
end

local function layout(window)
    local config = window.config
    local width = bounded(config.width, minWidth, maxWidth, settings.meterWidth)
    window:SetMaxResize(maxWidth, heightForRows(maxRows))
    window:SetSize(width, config.collapsed and headerHeight or expandedHeight(window))
    shown(window.content, not config.collapsed)
    local collapse = config.collapsed and "expand" or "collapse"
    sprite(window.collapse:GetNormalTexture(), collapse)
    sprite(window.collapse:GetPushedTexture(), collapse .. "Pressed")
    updateBackground(window.background)
    updateHeader(window)
    updateRows(window)
    shown(window, settings.meterEnabled)
    refresh(window)
    updateDockClamp(window.pair)
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

local function undock(window)
    local pair = window and window.pair
    if not pair then return end
    local docked, anchor = pair.docked, pair.anchor
    docked.placement.position = windowPosition(docked) or docked.placement.position
    anchor.placement.position = windowPosition(anchor) or anchor.placement.position
    anchor:SetClampRectInsets(0, 0, 0, 0)
    docked:SetClampedToScreen(true)
    if docked.editEntry then docked.editEntry.docked = nil end
    docked.pair, anchor.pair = nil, nil
    placeWindow(anchor)
    placeWindow(docked)
    settings.combatMeters.docks[docked.key] = nil
end

local function attach(window, anchor, side)
    local pair = { docked = window, anchor = anchor, side = side }
    window.pair, anchor.pair = pair, pair
    settings.combatMeters.docks[window.key] = { anchor.key, side }
    if horizontalDock(pair) then
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
    if window.pair or not window:IsVisible() then return end
    local left, right, top, bottom = edges(window)
    if not left then return end
    local side, target, nearest = nil, nil, snapDistance
    for _, peer in ipairs(windows) do
        if peer ~= window and not peer.pair and peer:IsVisible() and not peer.interaction then
            local peerLeft, peerRight, peerTop, peerBottom = edges(peer)
            if peerLeft then
                local function consider(candidate, distance)
                    distance = math.abs(distance)
                    if distance <= nearest then side, target, nearest = candidate, peer, distance end
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
            end
        end
    end
    if side then attach(window, target, side) end
end

local function resizeDock(window)
    local drag, pair = window.dockResize, window.pair
    if not pair then return end
    local anchor, docked, dockSide = pair.anchor, pair.docked, pair.side
    local x, y = GetCursorPosition()
    local scale = window:GetEffectiveScale()
    local width = bounded(drag.width + (x - drag.x) / scale, minWidth, maxWidth)
    local height = bounded(drag.height - (y - drag.y) / scale, minHeight, heightForRows(maxRows))
    if math.abs(width - window:GetWidth()) < 0.01 and math.abs(height - window:GetHeight()) < 0.01 then return end
    local horizontal = horizontalDock(pair)
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
    updateDockClamp(pair)
    anchor.placement.position = { right, top }
    placeWindow(anchor)
end

local function startInteraction(window, sizing)
    local peer = peerOf(window)
    if window.interaction or (peer and peer.interaction) or (sizing and window.config.collapsed) then return end
    local pair = window.pair
    local position = sizing and pair and windowPosition(pair.anchor)
    if sizing and pair and not position then return end
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
        undock(window)
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
        local anchor = window.pair and window.pair.anchor
        if anchor then
            anchor.placement.position = windowPosition(anchor) or anchor.placement.position
            placeWindow(anchor)
        end
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
    local pair = window.pair
    window = pair and pair.anchor or window
    preserveDefaultPosition(window)
    window.placement.position = windowPosition(window) or window.placement.position
    window.placement.scale = value
    window:SetScale(value)
    if pair then
        pair.docked.placement.scale = value
        pair.docked:SetScale(value)
    end
    placeWindow(window)
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
end

local function changeMode(window, index)
    window.config.mode, window.offset = index, 0
    window.titleText = modes[index][2]
    window.title:SetText(window.titleText)
    refresh(window)
    notify()
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

---------------------------------------------------------------------------------------------------
-- Window lifecycle
---------------------------------------------------------------------------------------------------
local createMeter, removeMeter

local function windowLabel(key)
    if key == "Damage" then return ru and "Измеритель урона" or "Damage meter" end
    if key == "Healing" then return ru and "Измеритель лечения" or "Healing meter" end
    return (ru and "Измеритель " or "Meter ") .. (key:match("%d+") or key)
end

local function buildFrame(key)
    local name = "ForeverStockUI" .. key .. "Meter"
    local window = CreateFrame("Frame", name, UIParent)
    window:SetFrameStrata("LOW")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetResizable(true)
    window:SetMinResize(minWidth, minHeight)
    window:EnableMouseWheel(true)
    window:Hide()
    window.key = key
    window.rows, window.actors, window.offset, window.duration = {}, {}, 0, 0

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
            { text = ru and "Новое окно" or "New window", notCheckable = true, disabled = #windows >= maxWindows,
                func = function() createMeter(window.config.mode) end },
            { text = ru and "Удалить это окно" or "Delete this window", notCheckable = true, func = function()
                removeMeter(window.key)
            end },
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

    window:SetScript("OnMouseWheel", function(self, delta)
        if self.config.collapsed then return end
        self.offset = self.offset - delta
        render(self)
    end)
    window:SetScript("OnSizeChanged", function(self)
        local pair = self.pair
        if self.interaction ~= "size" and not (pair and (pair.docked.dockResize or pair.anchor.dockResize)) then return end
        updateHeader(self)
        updateRows(self)
        render(self)
    end)
    window:HookScript("OnHide", stopInteraction)
    return window
end

-- Binds a frame to its saved config and placement (creating fresh ones for a new window).
local function setupWindow(window, mode, fresh, slot)
    local key, name = window.key, window:GetName()
    if fresh or type(settings.editLayout[name]) ~= "table" then settings.editLayout[name] = {} end
    window.placement = settings.editLayout[name]
    if fresh or type(settings.combatMeters[key]) ~= "table" then settings.combatMeters[key] = {} end
    local config = settings.combatMeters[key]
    window.config = config
    if not modes[config.mode] then config.mode = mode end
    if config.session ~= -1 then config.session = 0 end
    config.collapsed = config.collapsed == true
    if key == "Damage" then
        config.rowsKey = "meterDamageRows"
    elseif key == "Healing" then
        config.rowsKey = "meterHealingRows"
    elseif config.rowsKey ~= "meterDamageRows" and config.rowsKey ~= "meterHealingRows" then
        config.rowsKey = modes[config.mode][1] == 2 and "meterHealingRows" or "meterDamageRows"
    end
    window.rowsKey = config.rowsKey
    window.segment, window.combat, window.offset, window.removed = nil, nil, 0, nil
    window.sessionText:SetText(sessionLabel(config.session))
    window.titleText = modes[config.mode][2]
    window.title:SetText(window.titleText)
    window.headerWidth = nil

    window:SetScale(1)
    window:ClearAllPoints()
    if key == "Damage" then
        window:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", -27, 492)
    elseif key == "Healing" then
        window:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", -27, 332)
    else
        -- New windows open near the screen centre, staggered so they never cover each other exactly.
        local step = ((slot or 0) % 6) * 24
        window:SetPoint("TOPRIGHT", UIParent, "CENTER", 190 + step, 120 - step)
    end
    if ui.RegisterEditFrame then
        local entry = window.editEntry
        if entry then entry.points, entry.removed, entry.docked, entry.moving = nil, nil, nil, nil end
        entry = ui.RegisterEditFrame(window, windowLabel(key), options)
        window.editEntry = entry
        if entry then
            entry.onDragStart = function() undock(window) end
            entry.onDragStop = function() snapWindow(window) end
            entry.beforeResetPosition = function() undock(window) end
            entry.changeScale = function(value)
                if not window.pair then return end
                setWindowScale(window, value)
                return true
            end
            preserveDefaultPosition(window)
        end
    end
    window:SetScale(bounded(window.placement.scale, 0.4, 2, 1))
    placeWindow(window)
    windows[#windows + 1] = window
    byKey[key] = window
end

local function saveOrder()
    local order = {}
    for i, window in ipairs(windows) do order[i] = window.key end
    settings.combatMeters.order = order
end

local function nextKey()
    local used = {}
    for key in pairs(byKey) do used[key] = true end
    for key in pairs(settings.combatMeters) do used[key] = true end
    local id = 1
    while used["Window" .. id] do id = id + 1 end
    return "Window" .. id
end

-- mode: an index into modes; the new window copies the shared size defaults.
function createMeter(mode)
    if #windows >= maxWindows then return end
    mode = modes[mode] and mode or 1
    local window = table.remove(pool)
    if not window then window = buildFrame(nextKey()) end
    setupWindow(window, mode, true, #windows)
    saveOrder()
    layout(window)
    notify()
    return window.key
end

function removeMeter(key)
    local window = byKey[key]
    if not window then return end
    stopInteraction(window)
    undock(window)
    window:Hide()
    window.removed = true
    if window.editEntry then
        window.editEntry.removed = true
        if window.editEntry.overlay then window.editEntry.overlay:Hide() end
    end
    for i, active in ipairs(windows) do
        if active == window then table.remove(windows, i) break end
    end
    byKey[key] = nil
    settings.combatMeters[key] = nil
    settings.editLayout[window:GetName()] = nil
    pool[#pool + 1] = window
    saveOrder()
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
    notify()
end

local function removeAll()
    for i = #windows, 1, -1 do removeMeter(windows[i].key) end
end

---------------------------------------------------------------------------------------------------
-- Options: the list of windows with add and delete buttons, rebuilt whenever the set changes.
---------------------------------------------------------------------------------------------------
local function confirmRemoveAll()
    StaticPopupDialogs.FOREVERUI_METER_REMOVE_ALL = StaticPopupDialogs.FOREVERUI_METER_REMOVE_ALL or {
        text = ru and "Удалить все окна измерителя? Новые окна можно добавить в настройках."
            or "Delete every meter window? New ones can be added in the settings.",
        button1 = YES, button2 = NO, timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnAccept = function() removeAll() end,
    }
    StaticPopup_Show("FOREVERUI_METER_REMOVE_ALL")
end

local function buildWindowList(parent, width)
    local W, S = ui.Widgets, ui.Style
    local lineHeight = 30
    local addDamage = W.Button(parent, ru and "+ Окно урона" or "+ Damage window", 150, function() createMeter(1) end)
    addDamage:SetPoint("TOPLEFT", 0, 0)
    local addHealing = W.Button(parent, ru and "+ Окно лечения" or "+ Healing window", 150, function() createMeter(3) end)
    addHealing:SetPoint("LEFT", addDamage, "RIGHT", 8, 0)
    local addThreat = W.Button(parent, ru and "+ Окно угрозы" or "+ Threat window", 150, function() createMeter(5) end)
    addThreat:SetPoint("LEFT", addHealing, "RIGHT", 8, 0)
    local clear = W.Button(parent, ru and "Удалить все" or "Delete all", 120, confirmRemoveAll)
    clear:SetPoint("TOPRIGHT", 0, 0)
    clear.text:SetTextColor(W.rgba(S.danger))
    local empty = W.Text(parent, W.fonts.small)
    empty:SetPoint("TOPLEFT", 0, -34)
    empty:SetText(ru and "Окон нет. Добавьте новое кнопками выше." or "No windows. Add one with the buttons above.")
    local lines = {}
    local height

    local function line(index)
        local row = lines[index]
        if row then return row end
        row = CreateFrame("Frame", nil, parent)
        row:SetSize(width, lineHeight - 4)
        row:SetPoint("TOPLEFT", 0, -34 - (index - 1) * lineHeight)
        W.Skin(row, S.surface, S.border)
        row.label = W.Text(row, W.fonts.label)
        row.label:SetPoint("LEFT", 10, 0)
        row.mode = W.Text(row, W.fonts.small)
        row.mode:SetPoint("LEFT", row, "LEFT", 220, 0)
        row.delete = W.Button(row, ru and "Удалить" or "Delete", 90, function(self)
            if self.key then removeMeter(self.key) end
        end, 20)
        row.delete:SetPoint("RIGHT", -3, 0)
        lines[index] = row
        return row
    end

    local function update()
        for i, window in ipairs(windows) do
            local row = line(i)
            row.label:SetText(i .. ". " .. windowLabel(window.key))
            row.mode:SetText(modes[window.config.mode][2])
            row.delete.key = window.key
            row:Show()
        end
        for i = #windows + 1, #lines do lines[i]:Hide() end
        shown(empty, #windows == 0)
        if #windows >= maxWindows then
            addDamage:Disable() addHealing:Disable() addThreat:Disable()
        else
            addDamage:Enable() addHealing:Enable() addThreat:Enable()
        end
        if #windows > 0 then clear:Enable() else clear:Disable() end
        local newHeight = 34 + math.max(1, #windows) * lineHeight
        if height and newHeight ~= height then
            -- Grow the page with the list; the section sits last so nothing below has to move.
            parent:SetHeight(newHeight)
            local scroll = parent:GetParent() and parent:GetParent():GetParent()
            if scroll and scroll.SetContentHeight and scroll.contentHeight then
                scroll:SetContentHeight(scroll.contentHeight + newHeight - height)
            end
        end
        height = newHeight
        return newHeight
    end
    listeners[#listeners + 1] = update
    return update()
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
                    if field == "height" and horizontalDock(window.pair) then
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
        BuildWindowList = buildWindowList,
        Create = createMeter,
        Remove = removeMeter,
        RemoveAll = removeAll,
        Count = function() return #windows end,
    }
    if type(settings.combatMeters) ~= "table" then settings.combatMeters = {} end
    if type(settings.editLayout) ~= "table" then settings.editLayout = {} end
    local meters = settings.combatMeters
    if type(meters.docks) ~= "table" then meters.docks = {} end
    -- Profiles from before windows could be added kept a single dock between the damage and healing meters.
    if type(meters.dock) == "table" and dockPoints[meters.dock[2]] then
        local key = meters.dock[1]
        meters.docks[key] = { key == "Damage" and "Healing" or "Damage", meters.dock[2] }
    end
    meters.dock = nil
    local order = type(meters.order) == "table" and meters.order or { "Damage", "Healing" }
    for _, key in ipairs(order) do
        if type(key) == "string" and key:match("^%w+$") and not byKey[key] and #windows < maxWindows then
            local mode = key == "Healing" and 4 or 1
            setupWindow(buildFrame(key), mode, false, #windows)
        end
    end
    saveOrder()
    for key, record in pairs(meters.docks) do
        local window = byKey[key]
        local anchor = type(record) == "table" and byKey[record[1]]
        if window and anchor and window ~= anchor and not window.pair and not anchor.pair
            and dockPoints[record[2]] then
            attach(window, anchor, record[2])
        else
            meters.docks[key] = nil
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
