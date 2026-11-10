local _, ui = ...
local wfn = ui.wfn
local CreateFrame, GetTime, GetQuestDifficultyColor = CreateFrame, GetTime, GetQuestDifficultyColor
local UnitGUID, UnitName, UnitLevel, UnitClassification = UnitGUID, UnitName, UnitLevel, UnitClassification
local UnitBuff, UnitDebuff = UnitBuff, UnitDebuff
local UnitAffectingCombat, UnitThreatSituation = UnitAffectingCombat, UnitThreatSituation
local pairs, select, tonumber, tostring = pairs, select, tonumber, tostring
local ceil, floor, min, max, exp, abs = math.ceil, math.floor, math.min, math.max, math.exp, math.abs

local art = [[Interface\AddOns\ForeverUI\Art\]]
local font = [[Fonts\FRIZQT__.TTF]]
local plateBorder = [[Interface\Tooltips\Nameplate-Border]]
local eliteIcon = [[Interface\Tooltips\elitenameplateicon]]
local WIDTH, HEIGHT, INSET = 120, 14, 2
local NAME_INSET, NAME_HEIGHT = 2, 16
local AURA_COUNT = 4
local INTERVAL = 0.05
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
local elapsed, childCount = 0, -1
local pixelToUI = 1
local cfg, pendingCVars
local defaults = {
    barTexture = art .. "UnitBar-Fill", castTexture = ui.foreverCastFill or art .. "CastBar-Fill", showEliteDragon = true,
    targetScale = 1.15, nonTargetScale = 0.80, targetAlpha = 1,
    nonTargetAlpha = 0.65, outOfCombatAlpha = 0.5, fadeDistance = true,
    nearDepth = 20, farDepth = 75,
    headlineOutOfCombat = false, hideFullHealthOutOfCombat = false,
    hideFriendlyInDungeons = true, hideTotems = false, hideMinions = true,
    stacking = true, verticalSpacing = 1.10, maxDistance = 41,
    plateOffsetX = 0, plateOffsetY = 8,
    widthEnemy = WIDTH, widthFriend = WIDTH, heightEnemy = HEIGHT, heightFriend = HEIGHT,
    outerLine = 0.25, frameThickness = 1, targetGlow = true, targetGlowStrength = 0.85,
    sideGlow = false, sideGlowFriend = {0.30, 1, 0.42}, sideGlowStrength = 0.55,
    glowSize = 1, glowBlend = "light", level = true,
    cast = true, castWidthEnemy = 120, castWidthFriend = 120, castHeightEnemy = 15, castHeightFriend = 15,
    castX = 15, castY = 4, castTextSize = 8, castTextPlace = "inside", castTextAlign = "left",
    castIcon = true, castIconSize = 15, castColour = true, previewCast = true,
    castColourOpen = {0.29, 0.85, 0.38}, castColourBusy = {0.98, 0.58, 0.16}, castColourShut = {0.56, 0.56, 0.62},
    nameFont = "", castFont = "", nameSizeEnemy = 14, nameSizeFriend = 14,
    nameColour = "white", nameOutline = "soft", namePlace = "above", nameAlign = "center", nameLift = 6, nameX = 0,
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
    cfg.outOfCombatAlpha = Clamp(cfg.outOfCombatAlpha, 0.1, 1, defaults.outOfCombatAlpha)
    cfg.nearDepth = Clamp(cfg.nearDepth, 0, 500, defaults.nearDepth)
    cfg.farDepth = Clamp(cfg.farDepth, cfg.nearDepth + 1, 501, max(defaults.farDepth, cfg.nearDepth + 1))
    cfg.verticalSpacing = Clamp(cfg.verticalSpacing, 0.5, 2, defaults.verticalSpacing)
    cfg.maxDistance = Clamp(cfg.maxDistance, 30, 41, defaults.maxDistance)
    cfg.plateOffsetX = Clamp(cfg.plateOffsetX, -60, 60, defaults.plateOffsetX)
    cfg.plateOffsetY = Clamp(cfg.plateOffsetY, -60, 60, defaults.plateOffsetY)
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
    SetSupportedCVar("nameplateAllowOverlap", cfg.stacking and 0 or 1)
    if cfg.stacking then SetSupportedCVar("nameplateOverlapV", cfg.verticalSpacing) end
    local distanceCVar = GetCVar("nameplateMaxDistance") ~= nil and "nameplateMaxDistance" or "nameplateDistance"
    SetSupportedCVar(distanceCVar, cfg.maxDistance)
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

local function SetName(view, name)
    view.fullName = name
    measure:SetFont(view.nameFont, view.nameSize, view.nameFlags)
    measure:SetText(name)
    if measure:GetStringWidth() > view.nameWidth then
        local last = #name
        repeat
            -- Back up to the first byte of the final UTF-8 character before cutting it.
            while name:byte(last) >= 128 and name:byte(last) < 192 do last = last - 1 end
            last = last - 1
            measure:SetText(name:sub(1, last) .. "...")
        until last == 0 or measure:GetStringWidth() <= view.nameWidth
        name = measure:GetText()
    end
    view.name:SetText(name)
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

    local native = view.nativeHealth
    -- Convert offsets from the native scale so the gap stays steady as the overlay shrinks.
    local ratio = native:GetEffectiveScale() / scale
    local dx, dy = cfg.plateOffsetX * ratio, cfg.plateOffsetY * ratio
    local x, y = native:GetCenter(), native:GetTop()
    if x and y then
        local left = x * ratio + dx - width / 2
        local bottom = y * ratio + dy
        dx, dy = dx + Snap(left, pixel) - left, dy + Snap(bottom, pixel) - bottom
    end
    if dx ~= view.snapX or dy ~= view.snapY then
        view.snapX, view.snapY = dx, dy
        view:SetPoint("BOTTOM", native, "TOP", dx, dy)
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

local function LayoutAuras(view)
    local size, gap, x, y = cfg.auraSize, cfg.auraGap, cfg.auraOffsetX, cfg.auraOffsetY
    if size == view.auraSize and gap == view.auraGap and x == view.auraX and y == view.auraY then return end
    view.auraSize, view.auraGap, view.auraX, view.auraY = size, gap, x, y
    local row = view.auraRow
    row:SetSize(AURA_COUNT * (size + gap) - gap, size)
    row:SetPoint("BOTTOMLEFT", view.name, "TOPLEFT", x, y)
    for i = 1, AURA_COUNT do
        local slot = view[i]
        slot:SetSize(size, size)
        slot:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", (i - 1) * (size + gap), 0)
        slot.time:SetFont(font, max(7, floor(size * 11 / 16 + 0.5)), "OUTLINE")
        slot.count:SetFont(font, max(6, floor(size / 2 + 0.5)), "OUTLINE")
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

local function UpdateAuras(view, unit, now)
    local readAura, index, used = UnitDebuff, 1, 0
    while unit and used < AURA_COUNT do
        local name, _, icon, count, _, duration, expires = readAura(unit, index)
        if not name then
            if readAura == UnitBuff then break end
            readAura, index = UnitBuff, 1
        else
            index = index + 1
            if icon and (not expires or expires == 0 or expires > now) then
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
        UpdateAuraPulse(slot, 0, false)
        slot:Hide()
    end
end

local function UpdateTimers(view, now)
    local mode = cfg.auraTimerAnimation
    local sweep, pulse = mode == "sweep" or mode == "both", mode == "pulse" or mode == "both"
    for i = 1, AURA_COUNT do
        local slot = view[i]
        if slot:IsShown() then
            local remaining = slot.expires > 0 and slot.expires - now or 0
            local seconds = ceil(remaining)
            if slot.expires > 0 and seconds <= 0 then
                return true
            end
            UpdateAuraSweep(slot, sweep)
            UpdateAuraPulse(slot, remaining, pulse)
            if slot.seconds ~= seconds then
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
        text:SetFrameLevel(slot:GetFrameLevel() + 2)
        slot.time = MakeText(text, 11)
        slot.time:SetPoint("CENTER", text, "CENTER")
        slot.count = MakeText(text, 8)
        slot.count:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", -1, 1)
        view[i] = slot
    end
    LayoutAuras(view)

    known[plate] = view
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

local function UpdateIdentity(view, plate, name, unit, guid)
    if view.identityName ~= name or (guid and guid ~= view.identityGUID) then
        view.identityName, view.identityGUID = name, guid
        view.kind, view.classification = nil, nil
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

local function UpdatePerspective(view, plate, target, engaged, blend)
    local depth = view:GetEffectiveDepth()
    local t = depth and depth > 0 and min(1, max(0, (depth - cfg.nearDepth) / (cfg.farDepth - cfg.nearDepth))) or 0
    t = t * t * (3 - 2 * t)
    local scale = target and cfg.targetScale or 1 + (cfg.nonTargetScale - 1) * t
    local alpha = target and cfg.targetAlpha or (cfg.fadeDistance and 1 + (cfg.nonTargetAlpha - 1) * t or 1)
    if not target and not engaged then alpha = min(alpha, cfg.outOfCombatAlpha) end
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

local function StyleName(view, unit, friendly, castShown)
    local under = castShown and cfg.namePlace == "undercast"
    local size = friendly and cfg.nameSizeFriend or cfg.nameSizeEnemy
    if view.nameRevision ~= wfn.revision or view.nameSize ~= size or view.nameUnder ~= under then
        local name, outline = view.name, cfg.nameOutline
        view.nameRevision, view.nameSize, view.nameUnder = wfn.revision, size, under
        view.nameFont = wfn.Font(cfg.nameFont)
        view.nameFlags = outline == "thick" and "THICKOUTLINE" or outline == "thin" and "OUTLINE" or ""
        name:SetFont(view.nameFont, size, view.nameFlags)
        name:SetHeight(size + 4)
        name:SetJustifyH(cfg.nameAlign:upper())
        name:SetShadowColor(0, 0, 0, outline == "softer" and 0.6 or 0.95)
        name:SetShadowOffset(1, -1)
        name:ClearAllPoints()
        if under then
            name:SetPoint("TOPLEFT", view, "BOTTOMLEFT", NAME_INSET + cfg.nameX, -cfg.castY - view.cast.height - cfg.nameLift)
            name:SetPoint("TOPRIGHT", view, "BOTTOMRIGHT", -NAME_INSET + cfg.nameX, -cfg.castY - view.cast.height - cfg.nameLift)
        else
            name:SetPoint("BOTTOMLEFT", view.health, "TOPLEFT", NAME_INSET + cfg.nameX, cfg.nameLift)
            name:SetPoint("BOTTOMRIGHT", view.health, "TOPRIGHT", -NAME_INSET + cfg.nameX, cfg.nameLift)
        end
        view.fullName = nil
    end
    local color
    if cfg.nameColour == "class" and unit and UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        color = class and RAID_CLASS_COLORS[class]
    end
    view.name:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
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
    if not preview and not target and ((cfg.hideTotems and kind == "totem") or (cfg.hideMinions and kind == "minion")
        or (cfg.hideFriendlyInDungeons and inDungeon and friendlyNPC)
        or (cfg.hideFullHealthOutOfCombat and npc and idle)) then
        MuteNativeDetails(view, true)
        view.infoActive, view.boxAt = nil, nil
        view:Hide()
        return
    end

    UpdatePerspective(view, plate, target, engaged, blend)
    SnapChrome(view, friendly)
    view.infoActive, view.infoUnit, view.infoFriendly, view.infoTarget = true, unit, friendly, target
    local headline = not preview and not target and idle and (neutral or secondary or (cfg.headlineOutOfCombat and npc and not elite))
    SetBarMode(view, not headline)
    local castShown = not headline and wfn.DrawCast(view, unit, friendly, now)
    MuteNativeDetails(view, headline or castShown)
    StyleName(view, unit, friendly, castShown)
    if view.fullName ~= name then SetName(view, name) end
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
    local team = friendly and (kind == "player" or (not unit and kind == "unknown" and r < 0.01 and g < 0.01 and b > 0.99))
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

local function ScanWorldFrame(_, delta)
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
    local target, hover, targetCount, hoverCount = nil, nil, 0, 0
    for plate, view in pairs(visible) do
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

    local now, playerLevel, inCombat = GetTime(), UnitLevel("player"), UnitAffectingCombat("player")
    local _, instanceType = IsInInstance()
    wfn.place = wfn.Place(instanceType)
    local inDungeon = instanceType == "party" or instanceType == "raid"
    local styled = 0
    for plate, view in pairs(visible) do
        local unit = view == target and "target" or view == hover and "mouseover" or nil
        local guid = unit == "target" and targetGUID or unit == "mouseover" and hoverGUID or nil
        SyncPlate(view, plate, unit, guid, playerLevel, inCombat, inDungeon, now, blend)
        if view.infoActive then styled = styled + 1 end
    end
    if profileStart then wfn.RecordPerf(profileStart, styled) end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self, event, unit)
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
        self:SetScript("OnUpdate", ScanWorldFrame)
    elseif event == "DISPLAY_SIZE_CHANGED" then
        RefreshPixelSize()
        wfn.Changed()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingCVars then ApplyCVars() end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        wfn.ResetInterrupt()
    elseif unit and auraRevision[unit] then
        auraRevision[unit] = auraRevision[unit] + 1
    end
end)
