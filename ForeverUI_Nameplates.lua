local _, ui = ...
local wfn = ui.wfn
local CreateFrame, GetTime, GetQuestDifficultyColor = CreateFrame, GetTime, GetQuestDifficultyColor
local UnitGUID, UnitName, UnitLevel, UnitClassification = UnitGUID, UnitName, UnitLevel, UnitClassification
local UnitBuff, UnitDebuff = UnitBuff, UnitDebuff
local UnitAffectingCombat, UnitThreatSituation = UnitAffectingCombat, UnitThreatSituation
local pairs, select, tonumber, tostring = pairs, select, tonumber, tostring
local ceil, floor, min, max, exp, abs = math.ceil, math.floor, math.min, math.max, math.exp, math.abs
local cos, sin, pi, sqrt = math.cos, math.sin, math.pi, math.sqrt

local art = [[Interface\AddOns\ForeverUI\Art\]]
local font = [[Fonts\FRIZQT__.TTF]]
local plateBorder = [[Interface\Tooltips\Nameplate-Border]]
local eliteIcon = [[Interface\Tooltips\elitenameplateicon]]
-- Radial aura timer: a half-plane rotated through texture coordinates and clipped by scroll frames,
-- plus a bright ray on the sweep edge (the 3.3.5 Cooldown model cannot draw an edge line).
local radialHalf, radialEdge = art .. [[Nameplates\Aura-Half]], art .. [[Nameplates\Aura-Edge]]
local WIDTH, HEIGHT, INSET = 120, 14, 2
local NAME_INSET, NAME_HEIGHT = 2, 16
local AURA_COUNT = 4
local INTERVAL = 0.05
local CROWD_INTERVAL = 0.2
local random = math.random
local THREAT_GRACE = 0.15

local world = WorldFrame
local driver = CreateFrame("Frame")
local known, visible = {}, {}
wfn.releasePreviewMouse = function()
    for _, view in pairs(visible) do
        for _, box in pairs(view.boxes) do
            box:EnableMouse(false)
            box:SetScript("OnUpdate", nil)
        end
    end
end
local auraRevision = { target = 0, mouseover = 0 }
local plateCount = 0
local elapsed, childCount = 0, -1
local pixelToUI = 1
local cfg, pendingCVars
local defaults = {
    barTexture = art .. "UnitBar-Fill", castTexture = ui.foreverCastFill or art .. "CastBar-Fill", showEliteDragon = true,
    targetScale = 1.15, nonTargetScale = 0.80, targetAlpha = 1,
    nonTargetAlpha = 0.65, outOfCombatAlpha = 0.5, fadeDistance = true,
    nearDepth = 20, farDepth = 75,
    headlineOutOfCombat = false, hideFullHealthOutOfCombat = false, combatOnlyEngaged = true, combatKeepFriends = false,
    crowdSaver = true, crowdThreshold = 15,
    hideFriendlyInDungeons = true, hideTotems = false, hideMinions = true,
    stacking = true, stackForever = true, stackNearestFirst = true, stackBehindAlpha = 0.7, verticalSpacing = 0.90, maxDistance = 41,
    edgeFade = true, edgeFadeInner = 100, edgeFadeOuter = 160,
    plateOffsetX = 0, plateOffsetY = 8,
    widthEnemy = WIDTH, widthFriend = WIDTH, heightEnemy = HEIGHT, heightFriend = HEIGHT,
    outerLine = 0.25, frameThickness = 1, targetGlow = true, targetGlowStrength = 0.85,
    sideGlow = false, sideGlowFriend = {0.30, 1, 0.42}, sideGlowStrength = 0.55,
    glowSize = 1, glowBlend = "light", level = true,
    cast = true, castWidthEnemy = 120, castWidthFriend = 120, castHeightEnemy = 15, castHeightFriend = 15,
    castX = 15, castY = 4, castTextSize = 8, castTextPlace = "inside", castTextAlign = "left",
    castIcon = true, castIconSize = 15, castColour = true, previewCast = true,
    castColourOpen = {0.29, 0.85, 0.38}, castColourBusy = {0.98, 0.58, 0.16}, castColourShut = {0.56, 0.56, 0.62},
    nameTextColour = {1, 1, 1},
    nameFont = "", castFont = "", nameSizeEnemy = 14, nameSizeFriend = 14,
    nameColour = "white", nameOutline = "soft", namePlace = "above", nameAlign = "center", nameLift = 6, nameX = 0,
    auraDebuffs = true, auraBuffs = true, auraMine = true, auraOthers = true, auraOthersClass = false,
    auraTimerText = true, auraTimerFont = "", auraTimerSize = 0, auraTimerOutline = "thin", auraTimerColour = {1, 1, 1},
    classColourEnemy = true, classColourFriend = true, friendlyNameOnly = false, friendlyNPCNameOnly = true, clickFollowsPlate = true,
    npcTitles = true, playerGuilds = true, subtitleSize = 10,
}

local function Clamp(value, low, high, fallback)
    if type(value) ~= "number" or value ~= value then return fallback end
    return max(low, min(high, value))
end

local function LoadConfig()
    local previous = WoWForeverNameplatesDB
    if type(ForeverUI_NameplatesDB) ~= "table" then ForeverUI_NameplatesDB = {} end
    cfg = ForeverUI_NameplatesDB
    if type(previous) == "table" and previous ~= cfg then
        for key, value in pairs(previous) do if cfg[key] == nil then cfg[key] = value end end
    end
    WoWForeverNameplatesDB = cfg
    if not cfg.castSplit then
        cfg.castWidthEnemy, cfg.castWidthFriend = cfg.castWidthEnemy or cfg.castWidth, cfg.castWidthFriend or cfg.castWidth
        cfg.castHeightEnemy, cfg.castHeightFriend = cfg.castHeightEnemy or cfg.castHeight, cfg.castHeightFriend or cfg.castHeight
        cfg.castSplit = true
    end
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(cfg[key]) ~= "table" then cfg[key] = {} end
            for i = 1, #value do cfg[key][i] = Clamp(cfg[key][i], 0, 1, value[i]) end
        elseif type(cfg[key]) ~= type(value) then
            cfg[key] = value
        end
    end
    if cfg.barTexture == "" then cfg.barTexture = defaults.barTexture end
    if cfg.castTexture == "" then cfg.castTexture = defaults.castTexture end
    cfg.targetScale = Clamp(cfg.targetScale, 1, 1.5, defaults.targetScale)
    cfg.nonTargetScale = Clamp(cfg.nonTargetScale, 0.75, 1, defaults.nonTargetScale)
    cfg.targetAlpha = defaults.targetAlpha
    cfg.nonTargetAlpha = Clamp(cfg.nonTargetAlpha, 0.1, 1, defaults.nonTargetAlpha)
    cfg.stackBehindAlpha = Clamp(cfg.stackBehindAlpha, 0.1, 1, defaults.stackBehindAlpha)
    cfg.outOfCombatAlpha = Clamp(cfg.outOfCombatAlpha, 0.1, 1, defaults.outOfCombatAlpha)
    cfg.nearDepth = Clamp(cfg.nearDepth, 0, 500, defaults.nearDepth)
    cfg.farDepth = Clamp(cfg.farDepth, cfg.nearDepth + 1, 501, max(defaults.farDepth, cfg.nearDepth + 1))
    cfg.verticalSpacing = Clamp(cfg.verticalSpacing, 0.5, 2, defaults.verticalSpacing)
    if type(cfg.classCache) ~= "table" then cfg.classCache = {} end
    if type(cfg.npcTitleCache) ~= "table" then cfg.npcTitleCache = {} end
    if type(cfg.guildCache) ~= "table" then cfg.guildCache = {} end
    cfg.crowdThreshold = Clamp(cfg.crowdThreshold, 5, 60, defaults.crowdThreshold)
    cfg.subtitleSize = Clamp(cfg.subtitleSize, 6, 18, defaults.subtitleSize)
    cfg.edgeFadeInner = Clamp(cfg.edgeFadeInner, 10, 190, defaults.edgeFadeInner)
    cfg.edgeFadeOuter = Clamp(cfg.edgeFadeOuter, 20, 200, defaults.edgeFadeOuter)
    -- The edge-fade defaults moved from 60/120 to 100/160; profiles still on the old defaults follow them once.
    if not cfg.edgeFadeDefault100 then
        if cfg.edgeFadeInner == 60 and cfg.edgeFadeOuter == 120 then
            cfg.edgeFadeInner, cfg.edgeFadeOuter = defaults.edgeFadeInner, defaults.edgeFadeOuter
        end
        cfg.edgeFadeDefault100 = true
    end
    -- The default spacing moved from 1.10 to 0.90; profiles still on the old default follow it once.
    if not cfg.spacingDefault090 then
        if abs(cfg.verticalSpacing - 1.10) < 0.001 then cfg.verticalSpacing = defaults.verticalSpacing end
        cfg.spacingDefault090 = true
    end
    -- The clickbox that follows the drawn plate is built in.
    cfg.clickFollowsPlate = true
    cfg.maxDistance = Clamp(cfg.maxDistance, 30, 41, defaults.maxDistance)
    cfg.plateOffsetX = Clamp(cfg.plateOffsetX, -60, 60, defaults.plateOffsetX)
    cfg.plateOffsetY = Clamp(cfg.plateOffsetY, -60, 60, defaults.plateOffsetY)
    cfg.auraTimerSize = Clamp(cfg.auraTimerSize, 0, 24, defaults.auraTimerSize)
    if cfg.auraTimerOutline ~= "none" and cfg.auraTimerOutline ~= "thick" then cfg.auraTimerOutline = "thin" end
    wfn.LoadBoxes(cfg)
    wfn.NormalizeStyle()
end

local function SetSupportedCVar(name, value)
    local current = GetCVar(name)
    if current ~= nil and tonumber(current) ~= value then
        pcall(SetCVar, name, tostring(value))
    end
end

local function ApplyCVars()
    pendingCVars = InCombatLockdown()
    if pendingCVars then return end
    -- Our own vertical stacking needs the native plates at their real positions: if the client spread
    -- them too, every plate would move twice and jump between the two layouts.
    local native = cfg.stacking and not cfg.stackForever
    SetSupportedCVar("nameplateAllowOverlap", native and 0 or 1)
    if native then SetSupportedCVar("nameplateOverlapV", cfg.verticalSpacing) end
    local distanceCVar = GetCVar("nameplateMaxDistance") ~= nil and "nameplateMaxDistance" or "nameplateDistance"
    SetSupportedCVar(distanceCVar, cfg.maxDistance)
    -- The client then paints enemy player bars in class colours, even on plates without a unit token.
    SetSupportedCVar("ShowClassColorInNameplate", cfg.classColourEnemy and 1 or 0)
end

local function MakeText(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(font, size, "OUTLINE")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    text:SetTextColor(1, 1, 1)
    return text
end

local measure = MakeText(driver, 12)
measure:Hide()

-- Keeps the first `limit` UTF-8 letters of a name (0 keeps all).
local function CutLetters(name, limit)
    if not limit or limit <= 0 then return name end
    local count, i = 0, 1
    while i <= #name do
        count = count + 1
        if count > limit then return name:sub(1, i - 1) .. "..." end
        local byte = name:byte(i)
        i = i + (byte >= 240 and 4 or byte >= 224 and 3 or byte >= 192 and 2 or 1)
    end
    return name
end

-- Fitted names are cached by name, font and width: a pack of namesakes is measured once, not per plate.
local fitted, fittedCount = {}, 0

local function SetName(view, name)
    view.fullName = name
    local key = name .. "\1" .. tostring(view.nameFont) .. "\1" .. tostring(view.nameSize) .. "\1"
        .. tostring(view.nameFlags) .. "\1" .. view.nameWidth .. "\1" .. (cfg.nameMaxLetters or 0)
    local text = fitted[key]
    if not text then
        text = CutLetters(name, cfg.nameMaxLetters)
        measure:SetFont(view.nameFont, view.nameSize, view.nameFlags)
        measure:SetText(text)
        if measure:GetStringWidth() > view.nameWidth then
            local last = #text
            repeat
                -- Back up to the first byte of the final UTF-8 character before cutting it.
                while text:byte(last) >= 128 and text:byte(last) < 192 do last = last - 1 end
                last = last - 1
                measure:SetText(text:sub(1, last) .. "...")
            until last == 0 or measure:GetStringWidth() <= view.nameWidth
            text = measure:GetText()
        end
        if fittedCount >= 500 then wipe(fitted); fittedCount = 0 end
        fitted[key], fittedCount = text, fittedCount + 1
    end
    if view.name:GetText() ~= text then view.name:SetText(text) end
end

local function Chrome(parent, x, y, width, height, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    texture:SetTexture(art .. "Nameplate-Chrome")
    texture:SetTexCoord(x / 512, (x + width) / 512, y / 128, (y + height) / 128)
    texture:SetSize(width / 2, height / 2)
    return texture
end

local function RefreshPixelSize()
    local height = tonumber((GetCVar("gxResolution") or ""):match("[xX](%d+)"))
    pixelToUI = height and height > 0 and 768 / height or 1
end

local function Snap(value, pixel)
    return floor(value / pixel + 0.5) * pixel
end

local function SnapChrome(view, friendly)
    local scale = view:GetEffectiveScale()
    if scale <= 0 then return end
    local pixel = pixelToUI / scale
    local width = Snap(friendly and cfg.widthFriend or cfg.widthEnemy, pixel)
    local height = Snap(friendly and cfg.heightFriend or cfg.heightEnemy, pixel)
    if pixel ~= view.pixel or width ~= view.chromeWidth or height ~= view.chromeHeight or view.layoutRevision ~= wfn.revision then
        view.pixel, view.chromeWidth, view.chromeHeight, view.layoutRevision = pixel, width, height, wfn.revision
        view:SetSize(width, height)
        local haloWidth, haloHeight = wfn.LayoutRim(view.chrome, view, width, height, pixel)
        view.threatGlow:SetSize(haloWidth, haloHeight)
        view.threatGlow:SetBlendMode(cfg.glowBlend == "colour" and "BLEND" or "ADD")
        view.nameWidth = width - 2 * (INSET + NAME_INSET)
        view.fullName = nil
    end

    -- Clickbox mode: the real frame carries offsets and the column, the drawn plate sits on its bottom.
    local clickbox = cfg.clickFollowsPlate and view.plate
    local native = clickbox or view.nativeHealth
    local point = clickbox and "BOTTOM" or "TOP"
    -- Convert offsets from the native scale so the gap stays steady as the overlay shrinks.
    local ratio = native:GetEffectiveScale() / scale
    local dx, dy = 0, 0
    if not clickbox then dx, dy = cfg.plateOffsetX * ratio, cfg.plateOffsetY * ratio + (view.stackOffset or 0) end
    local x, y = native:GetCenter(), clickbox and native:GetBottom() or native:GetTop()
    if x and y then
        local left = x * ratio + dx - width / 2
        local bottom = y * ratio + dy
        dx, dy = dx + Snap(left, pixel) - left, dy + Snap(bottom, pixel) - bottom
    end
    if dx ~= view.snapX or dy ~= view.snapY or native ~= view.snapAnchor then
        view.snapX, view.snapY, view.snapAnchor = dx, dy, native
        view:ClearAllPoints()
        view:SetPoint("BOTTOM", native, point, dx, dy)
    end
end

local function ReadThreat(view, unit, inCombat, now)
    if not inCombat then view.threatUntil = nil; return end
    local status = unit and UnitThreatSituation("player", unit)
    local native = view.nativeThreat
    if status == nil and native:IsShown() then
        local r, g, b = native:GetVertexColor()
        -- WotLK paints the first region yellow, orange or red as threat rises.
        if r > 0.5 and b < 0.5 then status = g >= 0.9 and 1 or 2 end
    end
    if status ~= nil then
        view.threatUntil = status > 0 and now + THREAT_GRACE or nil
        return status
    end
    -- The native indicator can disappear for one scan while the client updates it.
    if view.threatStatus > 0 and view.threatUntil and now < view.threatUntil then
        return view.threatStatus
    end
end

local function UpdateBorderGlow(view, status)
    status = status or 0
    if view.threatStatus == status then return end
    view.threatStatus = status
    local glow = view.threatGlow
    if status == 1 then
        glow:SetVertexColor(1, 0.8, 0, 0.8)
        glow:Show()
    elseif status == 2 or status == 3 then
        glow:SetVertexColor(1, 0.1, 0.1, 0.85)
        glow:Show()
    else
        glow:Hide()
    end
end

-- Maps the icon sub-rectangle x0..x1 (icon units: centre at 0, edges at +-0.5, y down) onto the texture
-- turned clockwise by angle. The texture spans the icon diagonal, so every icon pixel samples inside it
-- and no clipping frame is needed: each half is an ordinary texture covering exactly that half.
local SPAN = 1 / 1.42
local function MapRotated(texture, angle, x0, x1)
    local c, s = cos(angle) * SPAN, sin(angle) * SPAN
    texture:SetTexCoord(
        0.5 + x0 * c - 0.5 * s, 0.5 - x0 * s - 0.5 * c,
        0.5 + x0 * c + 0.5 * s, 0.5 - x0 * s + 0.5 * c,
        0.5 + x1 * c - 0.5 * s, 0.5 - x1 * s - 0.5 * c,
        0.5 + x1 * c + 0.5 * s, 0.5 - x1 * s + 0.5 * c)
end

local function MakeRadial(slot)
    local radial = CreateFrame("Frame", nil, slot)
    radial:SetFrameLevel(slot:GetFrameLevel() + 1)
    radial:SetAllPoints(slot.icon)
    local function Shade(left)
        local texture = radial:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(radialHalf)
        texture:SetVertexColor(0, 0, 0, 0.62)
        texture:SetPoint("TOPLEFT", radial, left and "TOPLEFT" or "TOP")
        texture:SetPoint("BOTTOMRIGHT", radial, left and "BOTTOM" or "BOTTOMRIGHT")
        return texture
    end
    radial.right, radial.left = Shade(false), Shade(true)
    local ray = radial:CreateTexture(nil, "OVERLAY")
    ray:SetTexture(radialEdge)
    ray:SetBlendMode("ADD")
    ray:SetVertexColor(1, 0.92, 0.62, 1)
    ray:SetAllPoints(radial)
    radial.edge = ray
    slot.radial = radial
    return radial
end

local function HideRadial(slot)
    local radial = slot.radial
    if radial and radial:IsShown() then radial:Hide() end
end

-- The elapsed part darkens clockwise from twelve, led by a bright ray.
local function UpdateRadial(slot, now, enabled)
    if not enabled or slot.expires <= 0 or slot.duration <= 0 then
        HideRadial(slot)
        return
    end
    local radial = slot.radial or MakeRadial(slot)
    local progress = min(1, max(0, 1 - (slot.expires - now) / slot.duration))
    local angle = floor(progress * 720 + 0.5) / 720 * 2 * pi
    if radial.angle ~= angle then
        radial.angle = angle
        if angle > 0 then
            MapRotated(radial.right, min(angle, pi), 0, 0.5)
            radial.right:Show()
        else
            radial.right:Hide()
        end
        if angle > pi then
            MapRotated(radial.left, angle, -0.5, 0)
            radial.left:Show()
        else
            radial.left:Hide()
        end
        MapRotated(radial.edge, angle, -0.5, 0.5)
    end
    if not radial:IsShown() then radial:Show() end
end

local function LayoutAuras(view)
    local size, gap, x, y = cfg.auraSize, cfg.auraGap, cfg.auraOffsetX, cfg.auraOffsetY
    if size == view.auraSize and gap == view.auraGap and x == view.auraX and y == view.auraY
        and view.auraRevision == wfn.revision then return end
    view.auraSize, view.auraGap, view.auraX, view.auraY, view.auraRevision = size, gap, x, y, wfn.revision
    local timerFont = wfn.Font(cfg.auraTimerFont)
    local outline = cfg.auraTimerOutline
    local flags = outline == "thick" and "THICKOUTLINE" or outline == "none" and "" or "OUTLINE"
    local timerSize = cfg.auraTimerSize > 0 and cfg.auraTimerSize or max(7, floor(size * 11 / 16 + 0.5))
    local tint = cfg.auraTimerColour
    local row = view.auraRow
    row:SetSize(AURA_COUNT * (size + gap) - gap, size)
    row:SetPoint("BOTTOMLEFT", view.name, "TOPLEFT", x, y)
    for i = 1, AURA_COUNT do
        local slot = view[i]
        slot:SetSize(size, size)
        slot:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", (i - 1) * (size + gap), 0)
        slot.time:SetFont(timerFont, timerSize, flags)
        slot.time:SetTextColor(tint[1], tint[2], tint[3])
        slot.count:SetFont(timerFont, max(6, floor(size / 2 + 0.5)), flags)
        slot.seconds = nil
    end
end

local function ClearAuraSweep(slot)
    if slot.sweepStart == nil then return end
    slot.sweepStart, slot.sweepDuration = nil, nil
    slot.cooldown:SetCooldown(0, 0)
    slot.cooldown:Hide()
end

local function UpdateAuraSweep(slot, enabled)
    if not enabled or slot.expires <= 0 or slot.duration <= 0 then
        ClearAuraSweep(slot)
        return
    end
    local start = slot.expires - slot.duration
    if slot.sweepStart == start and slot.sweepDuration == slot.duration then return end
    local cooldown = slot.cooldown
    if not cooldown then
        cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        cooldown:SetAllPoints(slot.icon)
        cooldown:SetFrameLevel(slot:GetFrameLevel() + 1)
        cooldown:EnableMouse(false)
        cooldown.noCooldownCount = true
        if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
        if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
        slot.cooldown = cooldown
    end
    slot.sweepStart, slot.sweepDuration = start, slot.duration
    cooldown:SetCooldown(start, slot.duration)
    cooldown:Show()
end

local function UpdateAuraPulse(slot, remaining, enabled)
    if enabled and slot.expires > 0 and remaining <= 3 then
        slot.pulsing = true
        slot.time:SetAlpha(0.5 + 0.5 * abs((remaining * 2) % 2 - 1))
    elseif slot.pulsing then
        slot.pulsing = nil
        slot.time:SetAlpha(1)
    end
end

local playerClass
-- Debuffs: mine (player, pet or vehicle) and other casters, optionally only those of my class. A caster
-- without a unit token falls back to the spellbook: a debuff I can cast myself counts as my class.
local function AuraAllowed(debuff, name, caster)
    if not debuff then return cfg.auraBuffs end
    if not cfg.auraDebuffs then return false end
    if caster == "player" or caster == "pet" or caster == "vehicle" then return cfg.auraMine end
    if not cfg.auraOthers then return false end
    if not cfg.auraOthersClass then return true end
    if caster and UnitIsPlayer(caster) then
        if not playerClass then playerClass = select(2, UnitClass("player")) end
        return select(2, UnitClass(caster)) == playerClass
    end
    return GetSpellInfo(name) ~= nil
end

local function UpdateAuras(view, unit, now)
    local readAura, index, used = UnitDebuff, 1, 0
    if unit and not (cfg.auraDebuffs and (cfg.auraMine or cfg.auraOthers)) then readAura = UnitBuff end
    if not cfg.auraBuffs and readAura == UnitBuff then unit = nil end
    while unit and used < AURA_COUNT do
        local name, _, icon, count, _, duration, expires, caster = readAura(unit, index)
        if not name then
            if readAura == UnitBuff or not cfg.auraBuffs then break end
            readAura, index = UnitBuff, 1
        else
            index = index + 1
            if icon and (not expires or expires == 0 or expires > now)
                and AuraAllowed(readAura == UnitDebuff, name, caster) then
                used = used + 1
                local slot = view[used]
                slot.icon:SetTexture(icon)
                slot.count:SetText(count and count > 1 and count or "")
                slot.expires, slot.duration = expires or 0, duration or 0
                slot:Show()
            end
        end
    end
    for i = used + 1, AURA_COUNT do
        local slot = view[i]
        ClearAuraSweep(slot)
        HideRadial(slot)
        UpdateAuraPulse(slot, 0, false)
        slot:Hide()
    end
end

local function UpdateTimers(view, now)
    local mode = cfg.auraTimerAnimation
    local sweep, pulse = mode == "sweep" or mode == "both", mode == "pulse" or mode == "both" or mode == "foreverPulse"
    local radial = mode == "forever" or mode == "foreverPulse"
    for i = 1, AURA_COUNT do
        local slot = view[i]
        if slot:IsShown() then
            local remaining = slot.expires > 0 and slot.expires - now or 0
            local seconds = ceil(remaining)
            if slot.expires > 0 and seconds <= 0 then
                return true
            end
            UpdateAuraSweep(slot, sweep)
            UpdateRadial(slot, now, radial)
            UpdateAuraPulse(slot, remaining, pulse)
            if not cfg.auraTimerText then
                if slot.seconds ~= false then
                    slot.seconds = false
                    slot.time:SetText("")
                end
            elseif slot.seconds ~= seconds then
                slot.seconds = seconds
                if slot.expires == 0 then
                    slot.time:SetText("")
                elseif seconds >= 60 then
                    slot.time:SetText(ceil(seconds / 60) .. "m")
                else
                    slot.time:SetText(seconds)
                end
            end
        end
    end
end

local function CollectNativeLabels(...)
    local labels = {}
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region:GetObjectType() == "FontString" then labels[#labels + 1] = region end
    end
    return labels
end

local function SuppressRegion(region, keepShown)
    if region:GetAlpha() ~= 0 then region:SetAlpha(0) end
    if not keepShown and region:IsShown() then region:Hide() end
end

local function SuppressNative(view)
    local labels = view.nativeLabels
    for i = 1, #labels do
        SuppressRegion(labels[i])
    end

    local border = view.nativeBorder
    if border:GetTexture() then border:SetTexture(nil) end
    SuppressRegion(border)

    -- These regions still report native health, threat, hover and classification.
    SuppressRegion(view.nativeHealth, true)
    local threat = view.nativeThreat
    -- The client can restore opacity between scans. Keep its visibility and colour as signals only.
    if threat:GetTexture() then threat:SetTexture(nil) end
    SuppressRegion(threat, true)
    SuppressRegion(view.nativeHover, true)
    SuppressRegion(view.nativeBoss, true)
    SuppressRegion(view.nativeElite, true)
    if view.nativeRaid then SuppressRegion(view.nativeRaid, true) end
end

local function MuteNativeDetails(view, muted)
    if not muted and not view.nativeDetailsMuted then return end
    view.nativeDetailsMuted = muted
    local saved = view.nativeDetailAlpha
    for i, region in pairs(view.nativeDetails) do
        local alpha = region:GetAlpha()
        if muted then
            if saved[i] == nil or alpha ~= 0 then saved[i] = alpha end
            if alpha ~= 0 then region:SetAlpha(0) end
        elseif saved[i] ~= nil then
            if alpha == 0 then region:SetAlpha(saved[i]) end
            saved[i] = nil
        end
    end
end

local function ShowPlate(plate)
    local view = known[plate]
    SuppressNative(view)
    visible[plate] = view
end

---------------------------------------------------------------------------------------------------
-- Click area: the native plate takes clicks and drives mouseover, but the client keeps it at the
-- unit. Its hit rectangle is stretched over the drawn plate (bar and name), so offsets, scaling and
-- vertical stacking keep targeting and mouseover where the plate is seen.
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Clickbox, after RefinedBlizzPlates: the native plate frame is the click and mouseover area.
--  * Size: the frame is resized to the drawn plate (bar and name). Out of combat directly; in combat
--    plates are protected, so a secure handler resizes new plates (shown through the UI panel manager,
--    which may run secure code in combat).
--  * Position: the client places the frame every frame; offsets and the vertical column push the real
--    frame with clamp-to-screen insets, so the click area moves with what is drawn.
--  * The drawn plate is anchored to the bottom of the frame, so resizing never shifts it.
---------------------------------------------------------------------------------------------------
local BIG = 10000
local clickPending, clickRevision, resizer

local function PointOf(point, left, right, top, bottom)
    local x = point:find("LEFT") and left or point:find("RIGHT") and right or (left + right) / 2
    local y = point:find("TOP") and top or point:find("BOTTOM") and bottom or (top + bottom) / 2
    return x, y
end

local function ClickSize()
    return max(cfg.widthEnemy, cfg.widthFriend),
        max(cfg.heightEnemy, cfg.heightFriend) + cfg.nameLift + max(cfg.nameSizeEnemy, cfg.nameSizeFriend) + 4
end

local function CreateResizer()
    if resizer or not SecureHandlerWrapScript or type(UIPanelWindows) ~= "table" then return end
    local name = "ForeverUINameplateClickbox"
    resizer = CreateFrame("Frame", name, UIParent, "SecureHandlerShowHideTemplate")
    resizer:SetFrameRef("WorldFrame", world)
    SecureHandlerWrapScript(resizer, "OnShow", resizer, [[
        local width, height = self:GetAttribute("plateWidth"), self:GetAttribute("plateHeight")
        if not width or not height then return end
        for _, plate in pairs(newtable(self:GetFrameRef("WorldFrame"):GetChildren())) do
            if plate:IsShown() and plate:IsProtected() then
                plate:SetWidth(width)
                plate:SetHeight(height)
            end
        end
    ]])
    UIPanelWindows[name] = { area = "left", pushable = 8, whileDead = 1 }
    resizer:SetAttribute("UIPanelLayout-defined", true)
    for key, value in pairs(UIPanelWindows[name]) do resizer:SetAttribute("UIPanelLayout-" .. key, value) end
    resizer:SetAttribute("UIPanelLayout-enabled", true)
end

-- Resizes protected plates in combat through the secure handler.
local function ResizeInCombat()
    if not resizer or not ToggleFrame or not resizer:GetAttribute("plateWidth") then return end
    ToggleFrame(resizer)
    ToggleFrame(resizer)
end

local function SizePlate(view, plate)
    view.plateWidth0 = view.plateWidth0 or plate:GetWidth()
    view.plateHeight0 = view.plateHeight0 or plate:GetHeight()
    local width, height = view.plateWidth0, view.plateHeight0
    if cfg.clickFollowsPlate then width, height = ClickSize() end
    plate:SetSize(width, height)
    if not cfg.clickFollowsPlate then
        plate:SetClampRectInsets(0, 0, 0, 0)
        if view.plateClamped0 ~= nil then plate:SetClampedToScreen(view.plateClamped0) end
        view.clampSet = nil
    end
end

-- Applies the clickbox size to every plate; deferred to the end of combat when plates are protected.
local function ApplyClickSize()
    clickRevision = wfn.revision
    if InCombatLockdown() then
        clickPending = true
        if cfg.clickFollowsPlate then ResizeInCombat() end
        return
    end
    clickPending = nil
    if resizer then
        if cfg.clickFollowsPlate then
            local width, height = ClickSize()
            resizer:SetAttribute("plateWidth", width)
            resizer:SetAttribute("plateHeight", height)
        else
            resizer:SetAttribute("plateWidth", nil)
            resizer:SetAttribute("plateHeight", nil)
        end
    end
    for plate, view in pairs(known) do SizePlate(view, plate) end
end

-- Where the client put the frame this frame, before clamping (plate units).
local function NativeRect(plate, width, height)
    if not plate.GetPoint then return end
    local point, relative, relativePoint, x, y = plate:GetPoint(1)
    if type(point) ~= "string" or not relative or type(x) ~= "number" then return end
    local plateScale = plate:GetEffectiveScale()
    local left, right, top, bottom = relative:GetLeft(), relative:GetRight(), relative:GetTop(), relative:GetBottom()
    if not left or plateScale <= 0 then return end
    local ratio = relative:GetEffectiveScale() / plateScale
    local ax, ay = PointOf(relativePoint or point, left * ratio, right * ratio, top * ratio, bottom * ratio)
    ax, ay = ax + x, ay + y
    left = point:find("LEFT") and ax or point:find("RIGHT") and ax - width or ax - width / 2
    bottom = point:find("BOTTOM") and ay or point:find("TOP") and ay - height or ay - height / 2
    return left, bottom
end

-- Pushes the real frame by the X/Y offset and the column lift with clamp insets (every frame).
local function PlacePlate(view, plate)
    if not plate.SetClampRectInsets then return end
    if not view.infoActive then
        if view.clampSet then
            view.clampSet = nil
            plate:SetClampRectInsets(0, 0, 0, 0)
        end
        return
    end
    local width, height = plate:GetWidth(), plate:GetHeight()
    local left, bottom = NativeRect(plate, width, height)
    if not left then return end
    local plateScale = plate:GetEffectiveScale()
    local screenScale = world:GetEffectiveScale() / plateScale
    local screenRight, screenTop = (world:GetRight() or 0) * screenScale, (world:GetTop() or 0) * screenScale
    local dx = cfg.plateOffsetX
    local dy = cfg.plateOffsetY + (view.stackRaise or 0) / plateScale
    local insetLeft, insetRight, insetTop, insetBottom = BIG, -BIG, -BIG, BIG
    if dx > 0 then insetLeft = -(left + dx) elseif dx < 0 then insetRight = screenRight - (left + width + dx) end
    if dy > 0 then insetBottom = -(bottom + dy) elseif dy < 0 then insetTop = screenTop - (bottom + height + dy) end
    if view.plateClamped0 == nil then view.plateClamped0 = plate:IsClampedToScreen() and true or false end
    if not view.clampSet then
        view.clampSet = true
        plate:SetClampedToScreen(true)
    end
    plate:SetClampRectInsets(insetLeft, insetRight, insetTop, insetBottom)
end

local function HidePlate(plate)
    local view = visible[plate]
    if view then
        view:Hide()
        MuteNativeDetails(view, false)
        view.infoActive, view.boxAt = nil, nil
        view.threatGlow:Hide()
        view.threatStatus, view.threatUntil = 0, nil
        view.guid, view.auraUnit, view.revision = nil, nil, nil
        view.identityName, view.identityGUID, view.kind, view.classification = nil, nil, nil, nil
        view.drawScale, view.drawAlpha = nil, nil
        view.stackOffset, view.stackY, view.stackRaise = nil, nil, nil
        UpdateAuras(view)
        visible[plate] = nil
    end
end

local function AddPlate(plate)
    local nativeHealth, nativeCast = plate:GetChildren()
    if not nativeHealth or nativeHealth:GetObjectType() ~= "StatusBar"
        or not nativeCast or nativeCast:GetObjectType() ~= "StatusBar" then return end

    -- The WotLK border identifies the native frame among other WorldFrame children.
    local threat, border, castBorder, castShield, castIcon, hover, name, level, boss, raid, elite = plate:GetRegions()
    if not border or border:GetObjectType() ~= "Texture" or border:GetTexture() ~= plateBorder
        or not name or name:GetObjectType() ~= "FontString"
        or not level or level:GetObjectType() ~= "FontString"
        or not threat or threat:GetObjectType() ~= "Texture" or not hover or not boss or not elite then return end

    local view = CreateFrame("Frame", nil, plate)
    plateCount = plateCount + 1
    view.stackId = plateCount
    view:Hide()
    -- Native nameplates can report UNKNOWN, which SetFrameStrata rejects.
    view:SetFrameStrata("BACKGROUND")
    view:SetFrameLevel(plate:GetFrameLevel() + 1)
    view:SetSize(WIDTH, HEIGHT)
    view.nameWidth = WIDTH - 2 * (INSET + NAME_INSET)
    view:SetPoint("BOTTOM", nativeHealth, "TOP")
    view:EnableMouse(false)
    view.nativeHealth, view.nativeName, view.nativeLevel = nativeHealth, name, level
    view.nativeCast, view.nativeCastIcon, view.nativeCastShield = nativeCast, castIcon, castShield
    view.nativeCastText = CollectNativeLabels(nativeCast:GetRegions())[1]
    view.nativeDetails, view.nativeDetailAlpha = {castBorder, castShield, castIcon, nativeCast}, {}
    view.nativeRaid = raid
    view.nativeHover, view.nativeBoss, view.nativeElite = hover, boss, elite
    view.nativeThreat, view.nativeBorder = threat, border
    view.nativeLabels = CollectNativeLabels(plate:GetRegions())

    local health = CreateFrame("StatusBar", nil, view)
    health:SetFrameLevel(view:GetFrameLevel() + 1)
    health:SetPoint("TOPLEFT", view, "TOPLEFT", INSET, -INSET)
    health:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -INSET, INSET)
    health:SetStatusBarTexture(cfg.barTexture)
    view.barTexture = cfg.barTexture
    local background = health:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(health)
    background:SetTexture(0.08, 0.08, 0.08, 1)
    view.health = health

    local top = CreateFrame("Frame", nil, view)
    top:SetAllPoints(view)
    top:SetFrameLevel(health:GetFrameLevel() + 1)
    view.chrome = wfn.MakeRim(top, health, "bar")
    -- The opaque chamfered foundation masks the centre of the donor halo.
    local glow = wfn.Sprite(health, "PlateGlow", "BACKGROUND", -8)
    glow:SetPoint("CENTER", view.chrome.rim, "CENTER")
    glow:SetBlendMode("ADD")
    glow:Hide()
    view.threatGlow, view.threatStatus = glow, 0

    view.boxRow = CreateFrame("Frame", nil, top)
    view.boxes = {}
    view.cast = wfn.MakeCast(view)

    local dragon = top:CreateTexture(nil, "OVERLAY")
    dragon:SetTexture(eliteIcon)
    dragon:SetTexCoord(0.578125, 0, 0, 0.84375)
    dragon:SetSize(18, 15)
    dragon:SetPoint("RIGHT", top, "LEFT", 5, 0)
    view.dragon = dragon

    local raidIcon = top:CreateTexture(nil, "OVERLAY")
    raidIcon:SetSize(14, 14)
    raidIcon:SetPoint("RIGHT", view, "LEFT", -13, 0)
    raidIcon:Hide()
    view.raid = raidIcon

    local customName = MakeText(top, 12)
    customName:SetHeight(NAME_HEIGHT)
    customName:SetJustifyH("LEFT")
    customName:SetJustifyV("MIDDLE")
    customName:SetWordWrap(false)
    customName:SetPoint("BOTTOMLEFT", health, "TOPLEFT", NAME_INSET, 4)
    customName:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", -NAME_INSET, 4)
    view.name = customName

    -- NPC title or player guild under the name, as on the stock plates of later clients.
    local subtitle = MakeText(top, 10)
    subtitle:SetJustifyH("CENTER")
    subtitle:SetWordWrap(false)
    subtitle:Hide()
    view.subtitle = subtitle

    local auraRow = CreateFrame("Frame", nil, top)
    view.auraRow = auraRow

    for i = 1, AURA_COUNT do
        local slot = CreateFrame("Frame", nil, auraRow)
        slot:Hide()
        slot.icon = slot:CreateTexture(nil, "BACKGROUND")
        slot.icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
        slot.icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
        slot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        Chrome(slot, 56, 40, 32, 32):SetAllPoints(slot)
        -- Keep both numbers above the cooldown sweep.
        local text = CreateFrame("Frame", nil, slot)
        text:SetAllPoints(slot)
        text:SetFrameLevel(slot:GetFrameLevel() + 5)
        slot.time = MakeText(text, 11)
        slot.time:SetPoint("CENTER", text, "CENTER")
        slot.count = MakeText(text, 8)
        slot.count:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", -1, 1)
        view[i] = slot
    end
    LayoutAuras(view)

    known[plate] = view
    view.plate = plate
    if cfg.clickFollowsPlate then
        if InCombatLockdown() then ResizeInCombat() else SizePlate(view, plate) end
    end
    plate:HookScript("OnShow", ShowPlate)
    plate:HookScript("OnHide", HidePlate)
    if plate:IsVisible() then ShowPlate(plate) else SuppressNative(view) end
end

local function DiscoverPlates(...)
    for i = 1, select("#", ...) do
        local frame = select(i, ...)
        if not known[frame] then AddPlate(frame) end
    end
end

local function IsPetGUID(guid)
    return guid and guid:find("^0[xX][Ff]140") ~= nil
end

local function NativePlateGUID(plate)
    if type(NozdorActionNative) ~= "function" then return end
    local ok, id = pcall(NozdorActionNative, "plateguid", plate)
    if ok and type(id) == "string" and id ~= "" then return id end
end

---------------------------------------------------------------------------------------------------
-- Player classes. A 3.3.5 plate has no unit token, so a friendly player's class is learnt wherever
-- the client reveals it (group, guild, mouseover in the world, target of target, focus, combat log and
-- chat GUIDs) and remembered by name in the saved variables, so it is known on the next login too.
---------------------------------------------------------------------------------------------------
local classByName = {}
local playerFlag = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400

local function Learn(name, class)
    if type(name) ~= "string" or not class or not RAID_CLASS_COLORS[class] then return end
    name = name:match("^[^%-]+") or name
    classByName[name] = class
end

-- Player guilds by name ("<Guild>"), saved between sessions as cfg.guildCache. Only a found guild is
-- stored: GetGuildInfo returns nothing until the client has the data, so "no guild" is never cached.
local guildByName = {}

local function LearnGuild(name, guild)
    if type(name) ~= "string" or type(guild) ~= "string" or guild == "" then return end
    name = name:match("^[^%-]+") or name
    guildByName[name] = "<" .. guild .. ">"
end

local function LearnUnit(unit)
    if UnitExists(unit) and UnitIsPlayer(unit) then
        local name = UnitName(unit)
        Learn(name, select(2, UnitClass(unit)))
        if GetGuildInfo then LearnGuild(name, (GetGuildInfo(unit))) end
    end
end

local function LearnGUID(guid, name)
    if type(name) ~= "string" or type(guid) ~= "string" or guid == "" or classByName[name] or not GetPlayerInfoByGUID then
        return
    end
    local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
    if ok then Learn(name, class) end
end

local function RememberRoster()
    for i = 1, GetNumRaidMembers() do LearnUnit("raid" .. i) end
    for i = 1, GetNumPartyMembers() do LearnUnit("party" .. i) end
end

local function RememberGuild()
    if not GetNumGuildMembers or not GetGuildRosterInfo then return end
    local guild = GetGuildInfo and GetGuildInfo("player")
    for i = 1, GetNumGuildMembers(true) do
        local name, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
        Learn(name, class)
        LearnGuild(name, guild)
    end
end

-- Chat events whose twelfth argument is the sender GUID on 3.3.5.
local chatEvents = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_WHISPER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER", "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER" }
local isChat = {}
for _, event in ipairs(chatEvents) do isChat[event] = true end

---------------------------------------------------------------------------------------------------
-- Combat log memory. Plates have no unit token, so two things are read from the combat log:
--  * who fights us: units that hit or were hit by me, my pet, party or raid (until combat ends);
--  * what is being cast: the native 3.3.5 cast bar has no spell text, only an icon.
---------------------------------------------------------------------------------------------------
local ours = bit.bor(COMBATLOG_OBJECT_AFFILIATION_MINE or 1, COMBATLOG_OBJECT_AFFILIATION_PARTY or 2,
    COMBATLOG_OBJECT_AFFILIATION_RAID or 4)
local friendlyFlag = COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x10
local engagedGUID, engagedName = {}, {}
local castByGUID, castByName, spellByIcon = {}, {}, {}
local CAST_MEMORY = 15
local endings = { UNIT_DIED = true, UNIT_DESTROYED = true, PARTY_KILL = true }

local function Ours(flags) return type(flags) == "number" and bit.band(flags, ours) ~= 0 end
local function Foe(flags) return type(flags) == "number" and bit.band(flags, ours) == 0 and bit.band(flags, friendlyFlag) == 0 end

local function Forget(guid, name)
    if guid then engagedGUID[guid], castByGUID[guid] = nil, nil end
    if name then castByName[name] = nil end
end

local function TrackCast(subevent, guid, name, spellId, spellName)
    if subevent == "SPELL_CAST_START" or subevent == "SPELL_CAST_SUCCESS" then
        if type(spellName) ~= "string" then return end
        local record = guid and castByGUID[guid]
        -- A finished cast clears its record; a success without a start is most likely a channel.
        if subevent == "SPELL_CAST_SUCCESS" and record and record.start and record.spell == spellName then
            Forget(nil, name); castByGUID[guid] = nil
            return
        end
        local icon = spellId and select(3, GetSpellInfo(spellId))
        if type(icon) == "string" then icon = icon:lower(); spellByIcon[icon] = spellName end
        record = { spell = spellName, icon = icon, at = GetTime(), start = subevent == "SPELL_CAST_START" }
        if guid then castByGUID[guid] = record end
        if name then castByName[name] = record end
    elseif subevent == "SPELL_CAST_FAILED" then
        Forget(nil, name); if guid then castByGUID[guid] = nil end
    end
end

local function TrackCombat(subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    if endings[subevent] then
        Forget(destGUID, nil)
        if destName then engagedName[destName] = nil end
        return
    end
    if not UnitAffectingCombat("player") then return end
    local foeGUID, foeName
    if Ours(sourceFlags) and Foe(destFlags) then foeGUID, foeName = destGUID, destName
    elseif Ours(destFlags) and Foe(sourceFlags) then foeGUID, foeName = sourceGUID, sourceName end
    if foeGUID then engagedGUID[foeGUID] = true end
    if foeName then engagedName[foeName] = true end
end

-- The spell a plate without a unit token is casting: by GUID, then by name, then by the native icon.
function wfn.CastLabel(view, icon)
    local now = GetTime()
    icon = type(icon) == "string" and icon:lower() or nil
    local guid, name = view.identityGUID, view.identityName
    local record = guid and castByGUID[guid]
    if not record or now - record.at > CAST_MEMORY or icon and record.icon and record.icon ~= icon then
        record = name and castByName[name]
    end
    if record and now - record.at <= CAST_MEMORY and not (icon and record.icon and record.icon ~= icon) then
        return record.spell
    end
    return icon and spellByIcon[icon]
end

-- Whether a plate belongs to a unit fighting me or my group.
local function Engaged(view, unit, threat, value, high)
    if threat ~= nil then return true end
    if unit and UnitExists(unit .. "target") and (UnitIsUnit(unit .. "target", "player")
        or UnitInParty(unit .. "target") or UnitInRaid(unit .. "target")) then return true end
    local guid = view.identityGUID
    if guid and engagedGUID[guid] then return true end
    -- By name only for wounded units: a whole pack of namesakes must not light up after one pull.
    return view.identityName ~= nil and engagedName[view.identityName] and value < high or false
end

local function LearnFromEvent(event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName = ...
        TrackCombat(subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
        if subevent == "SPELL_INTERRUPT" then TrackCast("SPELL_CAST_FAILED", destGUID, destName)
        else TrackCast(subevent, sourceGUID, sourceName, spellId, spellName) end
        if type(sourceFlags) == "number" and bit.band(sourceFlags, playerFlag) ~= 0 then LearnGUID(sourceGUID, sourceName) end
        if type(destFlags) == "number" and bit.band(destFlags, playerFlag) ~= 0 then LearnGUID(destGUID, destName) end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        LearnUnit("mouseover")
    elseif event == "GUILD_ROSTER_UPDATE" then
        RememberGuild()
    elseif isChat[event] then
        local _, author = ...
        LearnGUID(select(12, ...), author)
    else
        return false
    end
    return true
end

-- Class of a player plate: from the unit token, the native plate GUID, or names seen in the group,
-- as target or as mouseover.
local classTokens = { [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST",
    [6] = "DEATHKNIGHT", [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID" }

-- Nozdor client: class of any unit the client sees, straight from the plate (as RefinedBlizzPlates does).
-- Works without targeting, unlike GetPlayerInfoByGUID, which knows only players already cached.
local function NativeClass(plate, guid)
    if NozdorAction and NozdorAction.GetNameplateClass then
        local ok, class = pcall(NozdorAction.GetNameplateClass, plate)
        if ok and type(class) == "string" then return class end
    end
    guid = guid or NativePlateGUID(plate)
    if guid and type(NozdorActionNative) == "function" then
        local ok, id = pcall(NozdorActionNative, "unitinfo", guid)
        if ok and type(id) == "number" then return classTokens[id] end
    end
end

local function PlayerClass(view, unit, plate)
    if view.playerClass then return view.playerClass end
    local class
    if unit and UnitIsPlayer(unit) then class = select(2, UnitClass(unit)) end
    local guid = view.identityGUID
    class = class or NativeClass(plate, guid)
    if not class and guid and GetPlayerInfoByGUID and guid:find("^0[xX]0000") then
        local ok, _, english = pcall(GetPlayerInfoByGUID, guid)
        if ok then class = english end
    end
    if class and view.identityName then classByName[view.identityName] = class end
    class = class or classByName[view.identityName]
    view.playerClass = class
    return class
end

---------------------------------------------------------------------------------------------------
-- Subtitles: an NPC title (merchant goods, trainer profession, flight master...) or a player's guild.
-- With a unit token they come from the tooltip and GetGuildInfo; otherwise a hidden tooltip reads the
-- creature cache through a "unit:<GUID>" link. Results are kept per GUID and per name.
---------------------------------------------------------------------------------------------------
local titleByGUID = {}
local scanner
local levelWord = LEVEL or "Level"

local function ScanLine()
    local line = _G.ForeverUINameplateScanTextLeft2
    local text = line and scanner:NumLines() >= 2 and line:GetText()
    if not text or text == "" or text:find(levelWord, 1, true) then return "" end
    return text
end

local function ScanTooltip(unit, guid)
    if not scanner then
        scanner = CreateFrame("GameTooltip", "ForeverUINameplateScan", nil, "GameTooltipTemplate")
    end
    if not scanner.SetOwner then return end
    scanner:SetOwner(world, "ANCHOR_NONE")
    scanner:ClearLines()
    local ok
    if unit then
        ok = pcall(scanner.SetUnit, scanner, unit)
    else
        ok = pcall(scanner.SetHyperlink, scanner, "unit:" .. guid)
    end
    local first = _G.ForeverUINameplateScanTextLeft1
    -- An empty first line means the client has not cached this creature yet: try again later.
    local result = ok and first and (first:GetText() or "") ~= "" and ScanLine() or nil
    scanner:Hide()
    return result
end

-- NPC titles by name, saved between sessions (cfg.npcTitleCache); "" means "no title".
local npcTitleByName = {}

-- Tooltip scans are expensive: at most `SCAN_BUDGET` per plate scan, retries back off, and a GUID that
-- never resolves (no creature cache entry, or a client without "unit:" links) is given up on.
local SCAN_BUDGET, SCAN_TRIES = 2, 5
local scanBudget, scanTries, learnRetry = SCAN_BUDGET, {}, {}

-- Reads the title of an NPC unit (mouseover in the world, target, focus) once per name.
local function LearnTitle(unit, now)
    if not cfg.npcTitles or scanBudget <= 0 or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local name = UnitName(unit)
    if not name or npcTitleByName[name] or now < (learnRetry[name] or 0) then return end
    scanBudget = scanBudget - 1
    local line = ScanTooltip(unit)
    if line then
        npcTitleByName[name], learnRetry[name] = line ~= "" and ("<" .. line .. ">") or "", nil
    else
        learnRetry[name] = now + 1
    end
end

local function Subtitle(view, unit, kind, now)
    local player = kind == "player"
    if player and not cfg.playerGuilds or not player and (not cfg.npcTitles or kind ~= "npc" and kind ~= "unknown") then
        return
    end
    local guid, name = view.identityGUID, view.identityName
    if player then
        -- Guilds are learnt from every player unit the client shows (LearnUnit) and saved by name.
        if unit and GetGuildInfo then LearnGuild(name, (GetGuildInfo(unit))) end
        return name and guildByName[name]
    end
    local cached = guid and titleByGUID[guid] or name and npcTitleByName[name]
    if cached then return cached end
    local line
    if unit then
        if now < (view.titleRetry or 0) or scanBudget <= 0 then return end
        scanBudget = scanBudget - 1
        line = ScanTooltip(unit)
        if not line then view.titleRetry = now + 0.5 end
    elseif guid and now >= (view.titleRetry or 0) and scanBudget > 0 then
        scanBudget = scanBudget - 1
        local tries = (scanTries[guid] or 0) + 1
        scanTries[guid] = tries
        view.titleRetry = now + min(tries, 10)
        line = ScanTooltip(nil, guid)
        if not line and tries >= SCAN_TRIES then titleByGUID[guid] = "" end
    end
    local title = line and (line ~= "" and ("<" .. line .. ">") or "") or nil
    if title then
        if guid then titleByGUID[guid] = title end
        if name then npcTitleByName[name] = title end
    end
    return title
end

local function DrawSubtitle(view, title, headline, castShown)
    local subtitle = view.subtitle
    if not title or title == "" or castShown then
        if subtitle:IsShown() then subtitle:Hide() end
        return
    end
    if view.subtitleRevision ~= wfn.revision or view.subtitleHeadline ~= headline then
        view.subtitleRevision, view.subtitleHeadline = wfn.revision, headline
        subtitle:SetFont(view.nameFont or font, cfg.subtitleSize, view.nameFlags or "OUTLINE")
        subtitle:ClearAllPoints()
        -- Under the name when only the name shows, otherwise under the bar.
        if headline then
            subtitle:SetPoint("TOP", view.name, "BOTTOM", 0, 1)
        else
            subtitle:SetPoint("TOP", view, "BOTTOM", cfg.nameX, -2)
        end
    end
    if subtitle:GetText() ~= title then subtitle:SetText(title) end
    subtitle:SetTextColor(0.86, 0.86, 0.86)
    if not subtitle:IsShown() then subtitle:Show() end
end

-- /wfn class: what the client reports for each visible friendly player plate.
function wfn.DebugClasses()
    local found = false
    for plate, view in pairs(visible) do
        local r, g, b = view.nativeHealth:GetStatusBarColor()
        if view.infoActive and r < 0.01 and g < 0.01 and b > 0.99 then
            found = true
            local guid = NativePlateGUID(plate)
            local api = NozdorAction and NozdorAction.GetNameplateClass and select(2, pcall(NozdorAction.GetNameplateClass, plate))
            local native = guid and type(NozdorActionNative) == "function" and select(2, pcall(NozdorActionNative, "unitinfo", guid))
            wfn.Print(("%s · guid %s · kind %s · NozdorAction %s · unitinfo %s · class %s"):format(view.identityName or "?",
                tostring(guid), tostring(view.kind), tostring(api), tostring(native), tostring(view.playerClass)))
        end
    end
    if not found then wfn.Print(ui.russian and "Нет видимых плашек союзных игроков" or "No friendly player plates visible") end
end

local function UpdateIdentity(view, plate, name, unit, guid)
    if view.identityName ~= name or (guid and guid ~= view.identityGUID) then
        view.identityName, view.identityGUID = name, guid
        view.titleRetry = nil
        view.kind, view.classification, view.playerClass = nil, nil, nil
        view.boxAt = nil
        view.threatUntil = nil
    end
    if unit then
        local creature = UnitCreatureType(unit)
        if UnitIsPlayer(unit) then
            view.kind = "player"
        elseif creature == "Totem" or creature == "Тотем" or (creature and creature == CREATURE_TYPE_TOTEM) then
            view.kind = "totem"
        elseif IsPetGUID(guid) or (not guid or not guid:find("^0[xX][Ff]150")) and UnitPlayerControlled(unit) then
            view.kind = "minion"
        else
            view.kind = "npc"
        end
        view.classification = UnitClassification(unit)
    elseif not view.kind then
        local id = NativePlateGUID(plate)
        view.identityGUID = id
        -- shortcut: off-target totems use enUS/ruRU names when no unit token is available.
        if name:find("%f[%a]Totem%f[%A]") or name:find("Тотем ", 1, true) or name:find(" тотем", 1, true) then
            view.kind = "totem"
        elseif IsPetGUID(id) then
            view.kind = "minion"
        elseif id and id:find("^0[xX]0000") then
            view.kind = "player"
        else
            view.kind = id and "npc" or "unknown"
        end
    end
end

-- Screen-edge fade, as in WoW: Forever: plates near the centre stay solid and fade out towards the
-- periphery. Radii are percentages of half the screen height, measured from the screen centre.
local function EdgeFade(view)
    local x, y = view.nativeHealth:GetCenter()
    local centreX, centreY = world:GetCenter()
    local height = world:GetHeight()
    if not x or not centreX or not height or height <= 0 then return 1 end
    local scale, worldScale = view.nativeHealth:GetEffectiveScale(), world:GetEffectiveScale()
    local dx, dy = x * scale - centreX * worldScale, y * scale - centreY * worldScale
    local radius = sqrt(dx * dx + dy * dy) / (height * worldScale / 2) * 100
    local inner = cfg.edgeFadeInner
    local outer = max(cfg.edgeFadeOuter, inner + 1)
    if radius <= inner then return 1 end
    if radius >= outer then return 0 end
    local t = (radius - inner) / (outer - inner)
    return 1 - t * t * (3 - 2 * t)
end

local function UpdatePerspective(view, plate, target, engaged, blend)
    local depth = view:GetEffectiveDepth()
    local t = depth and depth > 0 and min(1, max(0, (depth - cfg.nearDepth) / (cfg.farDepth - cfg.nearDepth))) or 0
    t = t * t * (3 - 2 * t)
    local scale = target and cfg.targetScale or 1 + (cfg.nonTargetScale - 1) * t
    local alpha = target and cfg.targetAlpha or (cfg.fadeDistance and 1 + (cfg.nonTargetAlpha - 1) * t or 1)
    if not target and not engaged then alpha = min(alpha, cfg.outOfCombatAlpha) end
    if cfg.edgeFade and not target then alpha = alpha * EdgeFade(view) end
    -- Plates lifted over a nearer one in the column (see StackPlates) are drawn fainter.
    if view.stackBehind and not target then alpha = alpha * cfg.stackBehindAlpha end
    if not target and view.drawScale then
        scale = view.drawScale + (scale - view.drawScale) * blend
        alpha = view.drawAlpha + (alpha - view.drawAlpha) * blend
    end
    if view.drawScale ~= scale then view:SetScale(scale) end
    view.drawScale, view.drawAlpha = scale, alpha

    -- The native alpha remains available for target identification and caps inherited opacity.
    local parentAlpha = plate:GetEffectiveAlpha()
    local localAlpha = parentAlpha > 0 and min(1, alpha / parentAlpha) or 0
    if view:GetAlpha() ~= localAlpha then view:SetAlpha(localAlpha) end
    if view.priority ~= target then
        view.priority = target
        view:SetFrameStrata(target and "MEDIUM" or "BACKGROUND")
    end
end

local function SetVisible(region, shown)
    if shown then region:Show() else region:Hide() end
end

local function SetBarMode(view, full)
    if view.fullBar == full then return end
    view.fullBar = full
    SetVisible(view.health, full)
    SetVisible(view.chrome.rim, full)
    SetVisible(view.boxRow, full)
    SetVisible(view.auraRow, full)
    if not full then view.dragon:Hide(); view.raid:Hide(); view.cast:Hide(); view.boxAt = nil end
end

local function StyleName(view, friendly, castShown, class)
    local under = castShown and cfg.namePlace == "undercast"
    local size = friendly and cfg.nameSizeFriend or cfg.nameSizeEnemy
    local name = view.name
    if view.nameRevision ~= wfn.revision or view.nameSize ~= size then
        local outline = cfg.nameOutline
        view.nameRevision, view.nameSize, view.nameUnder = wfn.revision, size, nil
        view.nameFont = wfn.Font(cfg.nameFont)
        view.nameFlags = outline == "thick" and "THICKOUTLINE" or outline == "thin" and "OUTLINE" or ""
        name:SetFont(view.nameFont, size, view.nameFlags)
        name:SetHeight(size + 4)
        name:SetJustifyH(cfg.nameAlign:upper())
        name:SetShadowColor(0, 0, 0, outline == "softer" and 0.6 or 0.95)
        name:SetShadowOffset(1, -1)
        view.fullName, view.nameR = nil, nil
    end
    -- A cast moving the name under the bar only re-anchors it; the text keeps its measured cut.
    if view.nameUnder ~= under then
        view.nameUnder = under
        name:ClearAllPoints()
        if under then
            name:SetPoint("TOPLEFT", view, "BOTTOMLEFT", NAME_INSET + cfg.nameX, -cfg.castY - view.cast.height - cfg.nameLift)
            name:SetPoint("TOPRIGHT", view, "BOTTOMRIGHT", -NAME_INSET + cfg.nameX, -cfg.castY - view.cast.height - cfg.nameLift)
        else
            name:SetPoint("BOTTOMLEFT", view.health, "TOPLEFT", NAME_INSET + cfg.nameX, cfg.nameLift)
            name:SetPoint("BOTTOMRIGHT", view.health, "TOPRIGHT", -NAME_INSET + cfg.nameX, cfg.nameLift)
        end
    end
    local color = class and RAID_CLASS_COLORS[class]
    local r, g, b
    if color then
        r, g, b = color.r, color.g, color.b
    else
        local tint = cfg.nameTextColour
        r, g, b = tint[1], tint[2], tint[3]
    end
    if view.nameR ~= r or view.nameG ~= g or view.nameB ~= b then
        view.nameR, view.nameG, view.nameB = r, g, b
        name:SetTextColor(r, g, b)
    end
end

local function DrawRaid(view)
    local native = view.nativeRaid
    local texture = native and native:IsShown() and native:GetTexture()
    if texture then
        view.raid:SetTexture(texture)
        view.raid:SetTexCoord(native:GetTexCoord())
        view.raid:Show()
    else
        view.raid:Hide()
    end
end

wfn.infoFor = function(plate)
    local view = known[plate]
    if not view or not view.infoActive then return end
    return { unit = view.infoUnit, bar = view.health, width = view.health:GetWidth(), height = view.health:GetHeight(),
        friendly = view.infoFriendly, target = view.infoTarget, previewing = not not view.previewing }
end

function wfn.FindCombatTextAnchor(guid, name)
    local match
    for _, view in pairs(visible) do
        if view.infoActive and view:IsVisible() then
            if guid and guid == view.identityGUID then return view end
            if name and name == view.identityName and not (guid and view.identityGUID) then
                if match == nil then match = view else match = false end
            end
        end
    end
    return match or nil
end

local function SyncPlate(view, plate, unit, guid, playerLevel, inCombat, inDungeon, now, blend)
    SuppressNative(view)
    local name = view.nativeName:GetText()
    if not name or name == "" then view.infoActive = nil; view:Hide(); return end
    local native = view.nativeHealth
    local low, high = native:GetMinMaxValues()
    local value = native:GetValue()
    local r, g, b = native:GetStatusBarColor()
    local target = unit == "target"
    UpdateIdentity(view, plate, name, unit, guid)
    local threat = ReadThreat(view, unit, inCombat, now)
    local engaged = threat ~= nil or (unit and UnitAffectingCombat(unit)) or (view.nativeCast and view.nativeCast:IsShown())
    local idle = not engaged and value >= high
    local kind, classification = view.kind, view.classification
    -- A blue native bar only ever belongs to a friendly player (RefinedBlizzPlates relies on the same rule),
    -- so the plate counts as a player even when the plate GUID does not look like one.
    local blue = r < 0.01 and g < 0.01 and b > 0.99
    if blue and not unit and kind ~= "player" then kind, view.kind = "player", "player" end
    local neutral = unit and UnitReaction(unit, "player") == 4 or (not unit and r > 0.99 and g > 0.99 and b < 0.01)
    local friendly
    if unit then
        friendly = not not UnitIsFriend("player", unit)
    elseif r < 0.01 and ((g > 0.99 and b < 0.01) or (g < 0.01 and b > 0.99)) then
        friendly = true
    elseif neutral or (r > 0.99 and g < 0.01 and b < 0.01) then
        friendly = false
    end
    local friendlyNPC = kind == "npc" and unit and UnitIsFriend("player", unit)
        or (not unit and kind ~= "player" and r < 0.01 and g > 0.99 and b < 0.01)
    local npc = kind ~= "player" and (kind ~= "unknown" or neutral or friendlyNPC or (r > 0.99 and g < 0.01 and b < 0.01))
    local secondary = kind == "totem" or kind == "minion" or classification == "minus"
    local elite = view.nativeBoss:IsShown() or view.nativeElite:IsShown() or classification == "elite"
        or classification == "worldboss" or classification == "rare" or classification == "rareelite"
    local preview = wfn.previewing == "all" or (wfn.previewing == "friend" and friendly)
        or (wfn.previewing == "enemy" and not friendly)
    view.previewing = not not preview
    local team = friendly and (kind == "player" or blue)
    local class = (kind == "player" or team) and PlayerClass(view, unit, plate) or nil
    if not preview and not target and ((cfg.hideTotems and kind == "totem") or (cfg.hideMinions and kind == "minion")
        or (cfg.hideFriendlyInDungeons and inDungeon and friendlyNPC)
        or (cfg.hideFullHealthOutOfCombat and npc and idle)
        -- In combat only the units fighting me or my group stay; allies optionally.
        or (cfg.combatOnlyEngaged and inCombat and not (friendly and cfg.combatKeepFriends)
            and not Engaged(view, unit, threat, value, high))) then
        MuteNativeDetails(view, true)
        view.infoActive, view.boxAt = nil, nil
        view:Hide()
        return
    end

    UpdatePerspective(view, plate, target, engaged, blend)
    SnapChrome(view, friendly)
    view.infoActive, view.infoUnit, view.infoFriendly, view.infoTarget = true, unit, friendly, target
    -- Friendly players can show the name alone, coloured by class when class colours are on.
    local nameOnly = (cfg.friendlyNameOnly and team or cfg.friendlyNPCNameOnly and friendlyNPC) and not preview
    local headline = nameOnly or not preview and not target and idle
        and (neutral or secondary or (cfg.headlineOutOfCombat and npc and not elite))
    SetBarMode(view, not headline)
    local castShown = not headline and wfn.DrawCast(view, unit, friendly, now)
    MuteNativeDetails(view, headline or castShown)
    local nameClass = (cfg.nameColour == "class" or (nameOnly and cfg.classColourFriend)) and class or nil
    StyleName(view, friendly, castShown, nameClass)
    if view.fullName ~= name then SetName(view, name) end
    DrawSubtitle(view, Subtitle(view, unit, kind, now), headline, castShown)
    if headline then
        UpdateBorderGlow(view)
        view:Show()
        return
    end
    LayoutAuras(view)

    if low ~= view.low or high ~= view.high then
        view.low, view.high, view.value = low, high, nil
        view.health:SetMinMaxValues(low, high)
    end
    if value ~= view.value then
        view.value = value
        view.health:SetValue(value)
    end

    if view.barTexture ~= cfg.barTexture then
        view.health:SetStatusBarTexture(cfg.barTexture)
        view.barTexture, view.r = cfg.barTexture, nil
    end
    local classColour = class and cfg[friendly and "classColourFriend" or "classColourEnemy"] and RAID_CLASS_COLORS[class]
    if classColour then r, g, b = classColour.r, classColour.g, classColour.b end
    if r ~= view.r or g ~= view.g or b ~= view.b then
        view.r, view.g, view.b = r, g, b
        if r == 1 and g == 0 and b == 0 then r, g, b = 0.82, 0.07, 0.05 end
        view.health:SetStatusBarColor(r, g, b)
    end

    local boss = view.nativeBoss:IsShown()
    local level = unit and UnitLevel(unit) or (not boss and tonumber(view.nativeLevel:GetText()) or -1)
    if level ~= view.levelNumber or playerLevel ~= view.playerLevel then
        view.levelNumber, view.playerLevel, view.boxAt = level, playerLevel, nil
    end
    view.displayLevel = level or (preview and playerLevel)
    SetVisible(view.dragon, cfg.showEliteDragon and elite)
    DrawRaid(view)
    if view.rimTarget ~= target or view.rimTeam ~= team or view.rimRevision ~= wfn.revision then
        view.rimTarget, view.rimTeam, view.rimRevision = target, team, wfn.revision
        wfn.StyleRim(view.chrome, target, team)
    end
    wfn.DrawBoxes(view, plate, unit, target, team, now)
    UpdateBorderGlow(view, threat)

    local revision = unit and auraRevision[unit]
    -- Mouseover is transient and does not reliably receive UNIT_AURA on legacy clients.
    local refreshHover = unit == "mouseover" and now >= (view.nextAuraRefresh or 0)
    if view.guid ~= guid or view.auraUnit ~= unit or view.revision ~= revision or refreshHover then
        view.guid, view.auraUnit, view.revision = guid, unit, revision
        view.nextAuraRefresh = now + 0.2
        UpdateAuras(view, unit, now)
    end
    if unit and UpdateTimers(view, now) then
        UpdateAuras(view, unit, now)
        UpdateTimers(view, now)
    end
    view:Show()
end

---------------------------------------------------------------------------------------------------
-- Vertical stacking: plates gathered at one spot are lifted into a column, lowest first, so names,
-- bars and casts never cover each other. Works in screen pixels and eases each plate to its slot.
---------------------------------------------------------------------------------------------------
local stackList, stackPlaced, stacked = {}, {}, false

-- With `stackNearestFirst` the nearest unit (smallest depth) is placed first and keeps its spot; plates behind
-- it that overlap are lifted above it. Without a usable depth the order falls back to the screen height.
local function StackOrder(a, b)
    local da, db = a.stackDepth, b.stackDepth
    if da and db and abs(da - db) > 0.01 then return da < db end
    if a.stackBase ~= b.stackBase then return a.stackBase < b.stackBase end
    if a.stackX ~= b.stackX then return a.stackX < b.stackX end
    return a.stackId < b.stackId
end

local function StackPlates(blend)
    local count = 0
    local clickbox = cfg.clickFollowsPlate
    for plate, view in pairs(visible) do
        local native = clickbox and plate or view.nativeHealth
        local nativeScale = native:GetEffectiveScale()
        local x, top = native:GetCenter(), native:GetTop()
        if clickbox then
            local width = plate:GetWidth()
            local left, bottom = NativeRect(plate, width, plate:GetHeight())
            x, top = left and left + width / 2, bottom
        end
        local scale = view:GetEffectiveScale()
        if view.infoActive and view:IsShown() and x and top and scale > 0 then
            count = count + 1
            stackList[count] = view
            view.stackX = x * nativeScale
            view.stackBase = (top + cfg.plateOffsetY) * nativeScale
            local depth = cfg.stackNearestFirst and view.GetEffectiveDepth and view:GetEffectiveDepth()
            view.stackDepth = depth and depth > 0 and depth or nil
            view.stackWidth = (view.chromeWidth or WIDTH) * scale
            -- The bar plus the name above it; a name-only plate keeps the same footprint.
            view.stackHeight = ((view.chromeHeight or HEIGHT) + cfg.nameLift + (view.nameSize or 14) + 4)
                * scale * cfg.verticalSpacing
        else
            view.stackOffset, view.stackY, view.stackRaise, view.stackBehind = nil, nil, nil, nil
        end
    end
    for i = #stackList, count + 1, -1 do stackList[i] = nil end
    table.sort(stackList, StackOrder)
    -- One pass per plate: placed plates are kept sorted by their slot, so climbing over them in order
    -- finds the first free slot without re-scanning the column (quadratic instead of cubic in a crowd).
    local placed, placedCount = stackPlaced, 0
    for i = 1, count do
        local view = stackList[i]
        local y = view.stackBase
        for k = 1, placedCount do
            local other = placed[k]
            if abs(other.stackX - view.stackX) < (other.stackWidth + view.stackWidth) / 2
                and y < other.stackY + other.stackHeight and y + view.stackHeight > other.stackY then
                y = other.stackY + other.stackHeight
            end
        end
        view.stackY = y
        view.stackBehind = y > view.stackBase + 0.5 or nil
        local k = placedCount
        while k > 0 and placed[k].stackY > y do placed[k + 1] = placed[k]; k = k - 1 end
        placed[k + 1], placedCount = view, placedCount + 1
        -- In screen pixels; the real frame is lifted in clickbox mode, otherwise only the drawn plate.
        local raise = view.stackRaise or 0
        raise = raise + (y - view.stackBase - raise) * blend
        if abs(y - view.stackBase - raise) < 0.1 then raise = y - view.stackBase end
        view.stackRaise = raise
        view.stackOffset = not clickbox and raise / view:GetEffectiveScale() or nil
    end
    for i = #placed, placedCount + 1, -1 do placed[i] = nil end
    stacked = true
end

local function ClearStack()
    if not stacked then return end
    stacked = false
    for _, view in pairs(visible) do view.stackOffset, view.stackY, view.stackRaise, view.stackBehind = nil, nil, nil, nil end
end

local learnTokens = { "target", "mouseover", "focus", "targettarget", "focustarget", "mouseovertarget" }

local function ScanWorldFrame(_, delta)
    -- The client moves plates every frame, so the clamp that carries offsets runs every frame too.
    if clickRevision ~= wfn.revision and not clickPending then ApplyClickSize() end
    if cfg.clickFollowsPlate then
        for plate, view in pairs(visible) do PlacePlate(view, plate) end
    end
    elapsed = elapsed + delta
    if elapsed < INTERVAL then return end
    local profileStart = wfn.profile and wfn.Clock()
    local blend = 1 - exp(-12 * elapsed)
    elapsed = 0
    local count = world:GetNumChildren()
    if count ~= childCount then
        childCount = count
        DiscoverPlates(world:GetChildren())
    end

    local targetGUID, hoverGUID = UnitGUID("target"), UnitGUID("mouseover")
    local targetName = targetGUID and UnitName("target")
    local hoverName = hoverGUID and UnitName("mouseover")
    local target, hover, targetCount, hoverCount, shown = nil, nil, 0, 0, 0
    for plate, view in pairs(visible) do
        if view.infoActive then shown = shown + 1 end
        local name = view.nativeName:GetText()
        -- WotLK has no plate unit token. Match the native target alpha or mouseover region, plus the name.
        local targetCandidate = targetName and name == targetName
        local hoverCandidate = hoverName and name == hoverName and view.nativeHover:IsShown()
        local nativeGUID = (targetCandidate or hoverCandidate) and NativePlateGUID(plate)
        if targetCandidate and (nativeGUID == targetGUID or (not nativeGUID and plate:GetAlpha() == 1)) then
            target, targetCount = view, targetCount + 1
        end
        if hoverCandidate and (not nativeGUID or nativeGUID == hoverGUID) then
            hover, hoverCount = view, hoverCount + 1
        end
    end
    if targetCount ~= 1 then target = nil end
    if hoverCount ~= 1 then hover = nil end
    if hover and targetGUID == hoverGUID then
        target, hover = hover, nil
    elseif hover and target == hover then
        target = nil
    end

    for _, token in ipairs(learnTokens) do LearnUnit(token) end
    local now, playerLevel, inCombat = GetTime(), UnitLevel("player"), UnitAffectingCombat("player")
    scanBudget = SCAN_BUDGET
    LearnTitle("target", now); LearnTitle("mouseover", now); LearnTitle("focus", now)
    local _, instanceType = IsInInstance()
    wfn.place = wfn.Place(instanceType)
    local inDungeon = instanceType == "party" or instanceType == "raid"
    if cfg.stackForever then StackPlates(blend) else ClearStack() end
    -- Crowd saver: with many plates on screen, quiet ones (no unit, no cast, no threat, not the old
    -- target) refresh every CROWD_INTERVAL instead of every scan, spread over time so no frame spikes.
    local crowded = cfg.crowdSaver and shown > cfg.crowdThreshold
    local styled = 0
    for plate, view in pairs(visible) do
        local unit = view == target and "target" or view == hover and "mouseover" or nil
        local guid = unit == "target" and targetGUID or unit == "mouseover" and hoverGUID or nil
        local quiet = crowded and not unit and view.infoActive and not view.infoUnit and now < (view.nextSync or 0)
            and (view.threatStatus or 0) == 0 and not view.nativeCast:IsShown()
        if not quiet then
            local last = view.syncedAt
            view.syncedAt = now
            view.nextSync = crowded and now + CROWD_INTERVAL * (0.75 + random() * 0.5) or nil
            local viewBlend = last and now - last > INTERVAL * 1.5 and 1 - exp(-12 * (now - last)) or blend
            SyncPlate(view, plate, unit, guid, playerLevel, inCombat, inDungeon, now, viewBlend)
        end
        if view.infoActive then styled = styled + 1 end
    end
    if profileStart then wfn.RecordPerf(profileStart, styled) end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self, event, unit, ...)
    if LearnFromEvent(event, unit, ...) then return end
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        if IsAddOnLoaded("!!RefinedBlizzPlates") then return end
        LoadConfig()
        wfn.CreateOptions(ApplyCVars, defaults)
        wfn.RegisterSlash()
        ApplyCVars()
        RefreshPixelSize()
        self:RegisterEvent("DISPLAY_SIZE_CHANGED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("PLAYER_TALENT_UPDATE")
        self:RegisterEvent("PARTY_MEMBERS_CHANGED")
        self:RegisterEvent("RAID_ROSTER_UPDATE")
        -- Learnt classes persist between sessions; the cache table becomes the live lookup.
        for name, class in pairs(cfg.classCache) do if RAID_CLASS_COLORS[class] then classByName[name] = class end end
        cfg.classCache = classByName
        for name, title in pairs(cfg.npcTitleCache) do
            if type(title) == "string" then npcTitleByName[name] = title end
        end
        cfg.npcTitleCache = npcTitleByName
        for name, guild in pairs(cfg.guildCache) do
            if type(guild) == "string" then guildByName[name] = guild end
        end
        cfg.guildCache = guildByName
        for _, event in ipairs(chatEvents) do self:RegisterEvent(event) end
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        self:RegisterEvent("GUILD_ROSTER_UPDATE")
        if IsInGuild and IsInGuild() and GuildRoster then GuildRoster() end
        RememberRoster()
        CreateResizer()
        self:SetScript("OnUpdate", ScanWorldFrame)
    elseif event == "DISPLAY_SIZE_CHANGED" then
        RefreshPixelSize()
        wfn.Changed()
    elseif event == "PLAYER_REGEN_ENABLED" then
        wipe(engagedGUID); wipe(engagedName)
        if pendingCVars then ApplyCVars() end
        if clickPending then ApplyClickSize() end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        wfn.ResetInterrupt()
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        RememberRoster()
    elseif unit and auraRevision[unit] then
        auraRevision[unit] = auraRevision[unit] + 1
    end
end)
