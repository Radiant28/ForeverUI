local addonName, ui = ...
local art = "Interface\\AddOns\\ForeverUI\\Art\\"
local white = "Interface\\Buttons\\WHITE8X8"
local portraitArt = art .. "UnitPortrait"
local frameArt = art .. "CharacterFrames"
local function setting(key, fallback)
    local value = ui.Settings()[key]
    if value == nil then return fallback end
    return value
end
local function color(key, fallback)
    local value = setting(key)
    return type(value) == "table" and value or fallback
end
local function chromeColor() return color("ufChromeColor", { 0.93, 0.89, 0.82 }) end
local function aggroColor() return color("ufAggroColor", { 1, 0.18, 0.08 }) end
local function rgb(value) return value[1], value[2], value[3] end

-- Coordinates are measured on the game artwork at half its texture resolution.
local large = {
    portrait = { 157, 35, 53 }, health = { 12, 29, 119, 15 },
    power = { 12, 45, 119, 10 }, name = { 12, 16, 119 }, level = { 176, 56 },
}
local player = {
    chrome = { 0, 178, 71 }, portrait = { 35.5, 35.5, 57 },
    name = { 71.5, 15.5, 115 }, health = { 70.8, 32.4, 117.1, 11.8 },
    power = { 70.8, 46.9, 117.1, 9.1 }, level = { 13, 62 },
    aggro = true,
}
local target = {
    chrome = { 192, 187, 75 }, portrait = { 157, 37.3, 57 },
    name = { 6, 13, 114.5 }, nameFill = { 5, 12, 116, 15.5 },
    health = { 5.2, 30.9, 115.8, 12.9 }, power = { 5.2, 47, 115.8, 12.2 },
    level = { 179, 63.5 }, aggro = true,
}
local arena = {
    portrait = { 24, 23, 34 }, health = { 43, 17, 70, 10 },
    power = { 43, 28, 70, 8 }, name = { 44, 5, 69 },
}
local small = {
    portrait = { 24, 23, 34 }, health = { 43, 16, 70, 10 },
    power = { 43, 27, 70, 8 }, name = { 44, 4, 69 },
}
local secondary = {
    portrait = { 24, 23, 35 }, health = { 44, 16, 71, 8 },
    power = { 44, 25, 71, 8 }, name = { 44, 35, 71 }, nameBelow = true,
}

local dragons = {
    elite = { 1, 1, 200, 200, 5, -2 },
    rare = { 223, 203, 218, 177, 8, -4 },
    worldboss = { 1, 203, 220, 180, 11, -2 },
}
dragons.rareelite = dragons.rare

local skins = {}
local healthBars = {}
local powerBars = {}
local barPanels = {}
local chromeRings, portraitRings, dividers, pvpIcons, restIcons = {}, {}, {}, {}, {}

local function updateHealthColor(bar)
    local state = healthBars[bar]
    if not state then return end
    local unit = bar.unit or state.frame.unit
    local color
    if ui.Settings().healthClassColor and unit and UnitIsPlayer(unit) and UnitIsConnected(unit) then
        local _, class = UnitClass(unit)
        color = RAID_CLASS_COLORS[class]
    end
    if not color and not state.applied then return end
    local r, g, b, a = bar:GetStatusBarColor()
    local previous = state.applied
    local tinted = previous and r == previous[1] and g == previous[2] and b == previous[3]
    if color then
        if not tinted then state.native = { r, g, b, a } end
        if color ~= state.color or not tinted then
            bar:SetStatusBarColor(color.r, color.g, color.b, a)
            state.applied = { bar:GetStatusBarColor() }
        end
    elseif tinted and state.native then
        bar:SetStatusBarColor(unpack(state.native))
    end
    if not color then state.applied, state.native = nil, nil end
    state.color = color
end

local function skinHealth(bar, frame)
    bar:SetStatusBarTexture(ui.UnitBarFill(frame, ui.Settings().unitBarFill))
    healthBars[bar] = { frame = frame }
    updateHealthColor(bar)
end

local function setPowerFill(bar, fill)
    if bar.furyStockTexture then bar.furyStockTexture = fill end
    if not bar.furyActive then bar:SetStatusBarTexture(fill) end
end

local function updateManaColor(bar)
    if powerBars[bar] and not bar.lockColor and bar.powerType == SPELL_POWER_MANA
        and setting("ufManaRecolor", true) then
        bar:SetStatusBarColor(rgb(color("ufManaColor", { 0.25, 0.57, 1 })))
    end
end

local function skinPower(bar, frame)
    powerBars[bar] = frame
    setPowerFill(bar, ui.UnitBarFill(frame, ui.Settings().unitBarFill))
    updateManaColor(bar)
end

local function applyBarFill()
    local selection = ui.Settings().unitBarFill
    for bar, state in pairs(healthBars) do bar:SetStatusBarTexture(ui.UnitBarFill(state.frame, selection)) end
    for bar, frame in pairs(powerBars) do setPowerFill(bar, ui.UnitBarFill(frame, selection)) end
    local target = skins[TargetFrame]
    if target and target.updateTarget then target.updateTarget() end
end

local function place(region, relative, point, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, relative, "TOPLEFT", x, -y)
end

local function center(region, relative)
    if region then
        region:ClearAllPoints()
        region:SetPoint("CENTER", relative, "CENTER")
    end
end

local function applyPanelMedia(panel, scale)
    local settings = ui.Settings()
    local background = ui.MediaPath("background", settings.unitBarBackground)
    local border = ui.MediaPath("border", settings.unitBarBorder)
    if background == "" and border == "" then
        panel:SetBackdrop(nil)
        return
    end
    local foreverEdge = border == art .. "UnitFrame-Edge"
    local inset = (foreverEdge and 1.5 or 4) * scale
    panel:SetBackdrop({
        bgFile = background ~= "" and background or nil,
        edgeFile = border ~= "" and not (foreverEdge and panel.foreverChrome) and border or nil,
        edgeSize = (foreverEdge and 4 or 8) * scale,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    local tint = color("ufPanelColor", { 0.13, 0.085, 0.048, 0.30 })
    if background == white then
        panel:SetBackdropColor(tint[1], tint[2], tint[3], tint[4] or 0.30)
    else
        panel:SetBackdropColor(1, 1, 1, math.min(1, (tint[4] or 0.30) + 0.10))
    end
end

local function applyBarPanelMedia()
    for panel, scale in pairs(barPanels) do applyPanelMedia(panel, scale) end
end

local function createBarPanel(frame, health, power, scale, hasChrome)
    local panel = CreateFrame("Frame", nil, frame)
    panel.foreverChrome = hasChrome
    panel:SetFrameStrata(health:GetFrameStrata())
    local level = health:GetFrameLevel()
    if power then level = math.min(level, power:GetFrameLevel()) end
    panel:SetFrameLevel(math.max(0, level - 1))
    barPanels[panel] = scale
    applyPanelMedia(panel, scale)
    return panel
end

local function addBarDivider(parent, bar, left, right, scale)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(white)
    local tint = color("ufDividerColor", { 157 / 255, 125 / 255, 84 / 255, 0.9 })
    line:SetVertexColor(tint[1], tint[2], tint[3], tint[4] or 0.9)
    line:SetHeight(scale)
    dividers[line] = true
    line:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", left * scale, 0)
    line:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", right * scale, 0)
end

local function apply(frame, style, originX, originY, scale, flip)
    if not frame or skins[frame] then return end

    local prefix = frame:GetName()
    local isParty = prefix:match("^PartyMemberFrame%d+$")
    local pvpIcon = frame.pvpIcon or _G[prefix .. "PVPIcon"] or (frame == PlayerFrame and PlayerPVPIcon)
    if pvpIcon then
        pvpIcons[pvpIcon] = true
        pvpIcon:SetAlpha(setting("ufShowPvP", false) and 1 or 0)
    end
    if frame == PlayerFrame and PlayerPVPIconHitArea then PlayerPVPIconHitArea:EnableMouse(false) end

    local original = _G[prefix .. "TextureFrameTexture"] or _G[prefix .. "Texture"]
    local portrait = frame.portrait or _G[prefix .. "Portrait"] or _G[prefix .. "ClassPortrait"]
    local health = _G[prefix .. "HealthBar"]
    local power = _G[prefix .. "ManaBar"]
    if not (original and portrait and health) then return end

    local artLayer = original:GetParent()
    local portraitLayer = CreateFrame("Frame", nil, frame)
    portraitLayer:SetFrameStrata(artLayer:GetFrameStrata())
    portraitLayer:SetFrameLevel(math.max(artLayer:GetFrameLevel(), health:GetFrameLevel(),
        power and power:GetFrameLevel() or 0) + 1)
    portraitLayer:SetAllPoints(frame)
    portrait:SetParent(portraitLayer)

    local originalBackground = _G[prefix .. "Background"]
    if originalBackground then originalBackground:SetTexture(nil) end
    local vehicleArt = _G[prefix .. "VehicleTexture"]
    if vehicleArt then vehicleArt:SetAlpha(0) end
    original:SetAlpha(0)

    local function position(region, point, x, y, width, height)
        if flip then
            x = -x
            if point == "TOPLEFT" then point = "TOPRIGHT" end
        end
        place(region, frame, point, originX + x * scale, originY + y * scale)
        region:SetSize(width * scale, height * scale)
    end

    local function positionPortrait()
        local x, y, size = unpack(style.portrait)
        portrait:SetDrawLayer("BORDER")
        position(portrait, "CENTER", x, y, size, size)
    end
    positionPortrait()
    local feedback = frame.feedbackText
    if feedback then
        feedback:SetParent(portraitLayer)
        feedback:SetDrawLayer("OVERLAY", 7)
        center(feedback, portrait)
    end
    local portraitSize = style.portrait[3] * scale
    local ring = portraitLayer:CreateTexture(nil, "ARTWORK", nil, -3)
    if style.chrome then
        local row, height, displayHeight = unpack(style.chrome)
        ring:SetTexture(frameArt)
        ring:SetTexCoord(0, 480 / 512, row / 512, (row + height) / 512)
        ring:SetVertexColor(rgb(chromeColor()))
        chromeRings[ring] = true
        position(ring, "TOPLEFT", 0, 0, 192, displayHeight)
    else
        ring:SetTexture(portraitArt)
        ring:SetTexCoord(0, 0.5, 0, 1)
        ring:SetSize(portraitSize * 1.125, portraitSize * 1.125)
        ring:SetVertexColor(rgb(color("ufRingColor", { 0.92, 0.73, 0.45 })))
        portraitRings[ring] = true
        center(ring, portrait)
    end

    local bottomBar = power and style.power or style.health
    local left = math.min(style.health[1], bottomBar[1]) - 2.5
    local right = math.max(style.health[1] + style.health[3], bottomBar[1] + bottomBar[3],
        style.name[1] + style.name[3]) + 2.5
    local top = style.nameBelow and style.health[2] - 2.5 or style.name[2] - 2
    local bottom = bottomBar[2] + bottomBar[4] + 2.5
    local panel = createBarPanel(frame, health, power, scale, style.chrome ~= nil)
    position(panel, "TOPLEFT", left, top, right - left, bottom - top)

    local function divide(parent, bar, geometry)
        local leftOffset = left + 1 - geometry[1]
        local rightOffset = right - 1 - geometry[1] - geometry[3]
        if flip then leftOffset, rightOffset = -rightOffset, -leftOffset end
        addBarDivider(parent, bar, leftOffset, rightOffset, scale)
    end
    if not style.nameBelow and not style.chrome then divide(panel, health, style.health) end
    skinHealth(health, frame)
    if power then
        if not style.chrome then divide(power, power, style.power) end
        skinPower(power, frame)
    end

    local role = (frame == PlayerFrame or isParty) and _G[prefix .. "RoleIcon"]
    if role then
        role:SetParent(portraitLayer)
        role:SetDrawLayer("OVERLAY", 3)
    end

    local name = frame.name or _G[prefix .. "TextureFrameName"] or _G[prefix .. "Name"]
    if isParty and name then
        name:SetParent(portraitLayer)
        name:SetWordWrap(false)
        if role then
            role:ClearAllPoints()
            role:SetPoint("LEFT", name, "RIGHT", 2, 0)
            role:SetSize(11, 11)
        end
    end
    local function positionBars()
        position(health, "TOPLEFT", unpack(style.health))
        center(health.TextString, health)
        if power then
            position(power, "TOPLEFT", unpack(style.power))
            center(power.TextString, power)
        end
        if name then
            local x, y, width = unpack(style.name)
            local left = flip and -x - width or x
            place(name, frame, "TOPLEFT", originX + left * scale, originY + y * scale)
            local roleSpace = isParty and role and 14 or 0
            name:SetSize(width * scale - roleSpace, isParty and 10 or 12)
            name:SetJustifyH("CENTER")
        end
    end
    positionBars()

    if frame.deadText then center(frame.deadText, health) end
    local nameBackground = frame.nameBackground or _G[prefix .. "NameBackground"]
    if nameBackground then
        nameBackground:SetTexture(nil)
        nameBackground:Hide()
    end

    local skin = { portrait = positionPortrait, bars = positionBars }
    if style.aggro and not isParty then
        skin.aggro = ring
    end
    if frame == TargetFrame then
        local accent = panel:CreateTexture(nil, "ARTWORK", nil, -1)
        accent:SetTexture(white)
        position(accent, "TOPLEFT", unpack(style.nameFill))
        local deathIcon = portraitLayer:CreateTexture(nil, "OVERLAY", nil, 2)
        deathIcon:SetTexture(frameArt)
        deathIcon:SetTexCoord(64 / 512, 128 / 512, 384 / 512, 448 / 512)
        deathIcon:SetSize(26 * scale, 26 * scale)
        deathIcon:SetPoint("CENTER", portrait, "TOP", 0, 6 * scale)
        skin.updateTarget = function()
            local dead = false
            if frame.unit and UnitExists(frame.unit) then
                dead = UnitIsDeadOrGhost(frame.unit)
                local r, g, b = UnitSelectionColor(frame.unit)
                local bottomTint, topTint = 62, 37
                accent:SetGradientAlpha("VERTICAL",
                    (23 + r * bottomTint) / 255, (12 + g * bottomTint) / 255, (7 + b * bottomTint) / 255, 1,
                    (15 + r * topTint) / 255, (8 + g * topTint) / 255, (7 + b * topTint) / 255, 1)
                if setting("ufTargetAccent", true) then accent:Show() else accent:Hide() end
            else
                accent:Hide()
            end
            if dead and setting("ufDeathIcon", true) then deathIcon:Show() else deathIcon:Hide() end
            health:GetStatusBarTexture():SetAlpha(dead and 0 or 1)
            if power then power:GetStatusBarTexture():SetAlpha(dead and 0 or 1) end
            local nameColor = color("ufTargetNameColor", { 1, 0.82, 0.44 })
            if name then name:SetTextColor(rgb(nameColor)) end
            if frame.deadText then frame.deadText:SetTextColor(rgb(nameColor)) end
        end
        skin.updateTarget()
    end
    local level = frame.levelText or (frame == PlayerFrame and PlayerLevelText)
    if isParty then level = portraitLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") end
    if level and style.level then
        local x, y = unpack(style.level)
        local badge = portraitLayer:CreateTexture(nil, "OVERLAY", nil, -1)
        badge:SetTexture(art .. "Level-Badge")
        local badgeSize = isParty and 40 or 32
        position(badge, "CENTER", x, y, badgeSize, badgeSize)
        level:SetParent(portraitLayer)
        center(level, badge)
        level:SetDrawLayer("OVERLAY")
        if frame.highLevelTexture then
            local skull = frame.highLevelTexture
            skull:SetParent(portraitLayer)
            skull:SetTexture(art .. "Level")
            skull:SetTexCoord(80 / 128, 116 / 128, 0, 46 / 128)
            skull:SetSize(10 * scale, 13 * scale)
            skull:SetDrawLayer("OVERLAY")
        end
        if frame == PlayerFrame then
            level:SetTextColor(1, 1, 1)
            skin.badge = badge
            if not level:IsShown() then badge:Hide() end
        elseif isParty then
            level:SetTextColor(1, 1, 1)
            skin.updateLevel = function()
                local unit = frame.overrideName or frame.unit
                local value = unit and UnitLevel(unit)
                local known = value and value > 0
                level:SetText(known and value or "")
                badge:SetShown(known)
            end
            skin.updateLevel()
        end
    end

    local function portraitGlow(region)
        region:SetParent(portraitLayer)
        region:SetDrawLayer("ARTWORK", 1)
        region:SetTexture(portraitArt)
        region:SetTexCoord(0.5, 1, 0, 1)
        region:SetSize(portraitSize * 1.27, portraitSize * 1.27)
        center(region, portrait)
    end
    if frame == PlayerFrame then
        portraitGlow(PlayerFrameFlash)
        portraitGlow(PlayerStatusTexture)
        if PlayerRestIcon then
            PlayerRestIcon:SetAlpha(0)
            if PlayerRestGlow then PlayerRestGlow:SetAlpha(0) end
            local rest = portraitLayer:CreateTexture(nil, "OVERLAY", nil, 2)
            rest:SetTexture(frameArt)
            rest:SetTexCoord(0, 64 / 512, 384 / 512, 448 / 512)
            rest:SetSize(24 * scale, 24 * scale)
            rest:SetPoint("BOTTOMLEFT", portrait, "TOPRIGHT", -18 * scale, -4 * scale)
            local function updateRest()
                if PlayerRestIcon:IsShown() and setting("ufRestIcon", true) then rest:Show() else rest:Hide() end
            end
            restIcons[rest] = updateRest
            hooksecurefunc("PlayerFrame_UpdateStatus", updateRest)
            updateRest()
        end
    elseif isParty then
        if frame.threatIndicator then portraitGlow(frame.threatIndicator) end
        for _, suffix in ipairs({ "Status", "LeaderIcon", "GuideIcon", "MasterIcon", "Disconnect" }) do
            local icon = _G[prefix .. suffix]
            if icon then icon:SetParent(portraitLayer) end
        end
        local ready = _G[prefix .. "ReadyCheck"]
        if ready then ready:SetFrameLevel(portraitLayer:GetFrameLevel() + 1) end
        local debuff = _G[prefix .. "Debuff1"]
        if debuff and power then
            debuff:ClearAllPoints()
            debuff:SetPoint("TOPLEFT", power, "BOTTOMLEFT", 0, -2)
        end
    end
    skins[frame] = skin
    if style == large or frame == TargetFrame then
        if frame.threatIndicator then portraitGlow(frame.threatIndicator) end
        local dragon = portraitLayer:CreateTexture(nil, "ARTWORK", nil, -2)
        dragon:SetTexture(art .. "uiunitframeboss2x")
        skin.dragon = function(kind, refresh)
            if not refresh then skin.dragonKind = kind end
            local cell = dragons[skin.dragonKind]
            if not cell or not setting("ufEliteDragon", true) then dragon:Hide(); return end
            local x, y, width, height, dx, dy = unpack(cell)
            dragon:SetTexCoord(x / 512, (x + width) / 512, y / 512, (y + height) / 512)
            dragon:SetSize(width * scale / 2, height * scale / 2)
            dragon:SetPoint("CENTER", portrait, "CENTER", dx * scale, dy * scale)
            dragon:Show()
        end
        skin.dragon(frame.showClassification and not frame.smallSize and UnitClassification(frame.unit))
    end
    return skin
end

local function reskinPlayer()
    local skin = skins[PlayerFrame]
    if not skin then return end
    skin.bars()
    skin.portrait()
    if skin.badge then
        if PlayerLevelText:IsShown() then skin.badge:Show() else skin.badge:Hide() end
    end
end

local function updatePartyLevel(frame)
    local skin = skins[frame]
    if skin and skin.updateLevel then skin.updateLevel() end
end

local function reskinParty(frame)
    local skin = skins[frame]
    if skin then skin.portrait() end
end

local function reskinRaid(pullout)
    if not pullout or not pullout.buttons then return end
    for _, member in ipairs(pullout.buttons) do
        if not skins[member] then
            local prefix = member:GetName()
            local health, power = _G[prefix .. "HealthBar"], _G[prefix .. "ManaBar"]
            local plate = createBarPanel(member, health, power, 1)
            plate:SetPoint("TOPLEFT", member, "TOPLEFT", -2.5, 6)
            plate:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 2.5, -2.5)
            addBarDivider(plate, health, -2.5, 1.5, 1)
            addBarDivider(power, power, -2.5, 1.5, 1)
            for _, suffix in ipairs({ "HealthBar", "ManaBar", "Target", "TargetTarget" }) do
                local bar = _G[prefix .. suffix]
                local usesPlate = bar == health or bar == power
                for _, region in ipairs({ bar:GetRegions() }) do
                    local texture = region.GetTexture and region:GetTexture()
                    if type(texture) == "string" and texture:lower():find("ui-raidframe-healthbar", 1, true) then
                        if usesPlate then
                            region:SetAlpha(0)
                        else
                            region:SetTexture(white)
                            region:SetTexCoord(0, 1, 0, 1)
                            region:SetDrawLayer("BACKGROUND", -2)
                            region:SetVertexColor(0.31, 0.23, 0.14)
                        end
                    end
                end
                local background = _G[bar:GetName() .. "Background"]
                if usesPlate then
                    background:SetAlpha(0)
                else
                    background:SetAllPoints(bar)
                    background:SetTexture(white)
                    background:SetVertexColor(0.06, 0.05, 0.04)
                end
                if bar.SetStatusBarTexture then
                    if suffix == "HealthBar" then skinHealth(bar, member) end
                    if suffix == "ManaBar" then skinPower(bar, member) end
                end
            end
            skins[member] = true
        end
    end
end

local function applyArena()
    for i = 1, 5 do
        local prefix = "ArenaEnemyFrame" .. i
        apply(_G[prefix], arena, 102, 0, 0.85, true)
        apply(_G[prefix .. "PetFrame"], small, 78, 0, 0.64, true)
    end
end

local function lowerTargetAuras(frame, prefix, index)
    if frame ~= TargetFrame then return end
    local aura = _G[prefix .. index]
    local point, relative, relativePoint, x, y = aura:GetPoint()
    if point == "TOPLEFT" and relative == frame and relativePoint == "BOTTOMLEFT" then
        aura:SetPoint(point, relative, relativePoint, x, y - setting("ufTargetAuraOffset", 10))
    end
end

local function updateAggro(indicator)
    if not indicator then return end
    local frame
    if indicator == PlayerFrameFlash then
        frame = PlayerFrame
    elseif indicator == TargetFrame.threatIndicator then
        frame = TargetFrame
    end
    local skin = frame and skins[frame]
    if not (skin and skin.aggro) then return end

    local status
    if frame == PlayerFrame then
        status = UnitThreatSituation("player")
    elseif UnitExists("target") then
        status = UnitThreatSituation("player", "target")
    end
    local active = status and status >= 2
    skin.aggro:SetVertexColor(rgb(active and aggroColor() or chromeColor()))
    indicator:SetAlpha(active and 0 or 1)
end

local function applyStock()
    apply(PlayerFrame, player, 36, 8, 1)
    apply(TargetFrame, target, 4, 6, 1)
    apply(FocusFrame, large, 1, 9, 1)
    apply(TargetFrameToT, secondary, 2, 3, 0.79)
    apply(FocusFrameToT, secondary, 2, 3, 0.79)
    apply(PetFrame, small, 1, 5, 1)
    for i = 1, 4 do
        local prefix = "PartyMemberFrame" .. i
        apply(_G[prefix], player, 2, 1, 0.625)
        apply(_G[prefix .. "PetFrame"], small, 1, 1, 0.53)

        local boss = _G["Boss" .. i .. "TargetFrame"]
        local skin = apply(boss, large, 0, 12, 0.8)
        if skin then
            skin.dragon("worldboss")
            skin.bossPortrait = _G[boss:GetName() .. "Portrait"]
        end
    end

    hooksecurefunc("UnitFrame_UpdateThreatIndicator", updateAggro)
    updateAggro(PlayerFrameFlash)
    updateAggro(TargetFrame.threatIndicator)
    hooksecurefunc("PlayerFrame_ToPlayerArt", reskinPlayer)
    hooksecurefunc("UnitFrameHealthBar_Update", updateHealthColor)
    hooksecurefunc("HealthBar_OnValueChanged", updateHealthColor)
    hooksecurefunc("UnitFrameManaBar_UpdateType", updateManaColor)
    hooksecurefunc("PlayerFrame_ToVehicleArt", reskinPlayer)
    hooksecurefunc("PartyMemberFrame_ToPlayerArt", reskinParty)
    hooksecurefunc("PartyMemberFrame_ToVehicleArt", reskinParty)
    hooksecurefunc("PartyMemberFrame_UpdateMember", updatePartyLevel)
    hooksecurefunc("TargetFrame_UpdateBuffAnchor", lowerTargetAuras)
    hooksecurefunc("TargetFrame_UpdateDebuffAnchor", lowerTargetAuras)
    hooksecurefunc("TargetFrame_CheckClassification", function(frame, forceNormal)
        local skin = skins[frame]
        if skin and skin.dragon then
            skin.dragon(not forceNormal and UnitClassification(frame.unit))
        end
    end)
    hooksecurefunc("TargetFrame_Update", function(frame)
        local skin = skins[frame]
        if skin and skin.updateTarget then skin.updateTarget() end
        if skin and skin.bossPortrait and UnitExists(frame.unit) then
            SetPortraitTexture(skin.bossPortrait, frame.unit)
        end
    end)
    hooksecurefunc("FocusFrame_SetSmallSize", function()
        local skin = skins[FocusFrame]
        if skin then skin.bars() end
    end)
end

local raidHooked
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:RegisterEvent("UNIT_HEALTH")
loader:RegisterEvent("UNIT_LEVEL")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")
loader:RegisterEvent("UNIT_FACTION")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "UNIT_LEVEL" then
        local index = name and name:match("^party([1-4])$")
        if index then updatePartyLevel(_G["PartyMemberFrame" .. index]) end
        return
    end
    if event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_FACTION" and name == "target") then
        local skin = skins[TargetFrame]
        if skin and skin.updateTarget then skin.updateTarget() end
        updateAggro(TargetFrame.threatIndicator)
        return
    end
    if event == "UNIT_HEALTH" then
        local skin = name == "target" and skins[TargetFrame]
        if skin and skin.updateTarget then skin.updateTarget() end
        return
    end
    local enabled = setting("unitFramesEnabled", true)
    if name == addonName and enabled then applyStock() end
    if event == "PLAYER_LOGIN" then
        if ui.RegisterEditFrame then
            for _, frame in ipairs({ PlayerFrame, TargetFrame, FocusFrame, PetFrame }) do
                ui.RegisterEditFrame(frame, nil, "unitframes")
            end
        end
        for bar in pairs(healthBars) do updateHealthColor(bar) end
    end
    if not enabled then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if name == addonName or name == "Blizzard_RaidUI" then
        if not raidHooked and RaidPullout_Update then
            raidHooked = true
            hooksecurefunc("RaidPullout_Update", reskinRaid)
            for i = 1, NUM_RAID_PULLOUT_FRAMES do
                reskinRaid(_G["RaidPullout" .. i])
            end
        end
    end
    if ArenaEnemyFrame1 and not InCombatLockdown()
        and (name == addonName or name == "Blizzard_ArenaUI" or event == "PLAYER_REGEN_ENABLED") then
        applyArena()
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end)

local function applyColors()
    for ring in pairs(chromeRings) do ring:SetVertexColor(rgb(chromeColor())) end
    for ring in pairs(portraitRings) do ring:SetVertexColor(rgb(color("ufRingColor", { 0.92, 0.73, 0.45 }))) end
    local tint = color("ufDividerColor", { 157 / 255, 125 / 255, 84 / 255, 0.9 })
    for line in pairs(dividers) do line:SetVertexColor(tint[1], tint[2], tint[3], tint[4] or 0.9) end
    for bar in pairs(powerBars) do
        if bar.powerType == SPELL_POWER_MANA and not bar.lockColor then
            if setting("ufManaRecolor", true) then
                updateManaColor(bar)
            else
                local info = PowerBarColor and PowerBarColor.MANA
                if info then bar:SetStatusBarColor(info.r, info.g, info.b) end
            end
        end
    end
    applyBarPanelMedia()
    updateAggro(PlayerFrameFlash)
    if TargetFrame then updateAggro(TargetFrame.threatIndicator) end
end

local function applyVisibility()
    local pvp = setting("ufShowPvP", false) and 1 or 0
    for icon in pairs(pvpIcons) do icon:SetAlpha(pvp) end
    for _, update in pairs(restIcons) do update() end
    for _, skin in pairs(skins) do
        if type(skin) == "table" then
            if skin.updateTarget then skin.updateTarget() end
            if skin.dragon then skin.dragon(nil, true) end
        end
    end
    if TargetFrame_UpdateAuras and TargetFrame and UnitExists("target") then TargetFrame_UpdateAuras(TargetFrame) end
end

ui.UnitFrames = {
    ApplyHealthColor = function() for bar in pairs(healthBars) do updateHealthColor(bar) end end,
    ApplyBarFill = applyBarFill,
    ApplyPanelMedia = applyBarPanelMedia,
    ApplyColors = applyColors,
    ApplyVisibility = applyVisibility,
}
