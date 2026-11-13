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

-- WoW Forever badges (Art/Forever/UnitBadges.tga, 256 x 64): left, right, top, bottom pixels.
local badgeArt = art .. "Forever\\UnitBadges"
local badgeCells = {
    level = { 1, 38, 1, 41 }, alliance = { 40, 62, 1, 28 }, horde = { 64, 85, 1, 26 },
    master = { 87, 103, 1, 17 }, leader = { 105, 119, 1, 11 },
    tank = { 121, 137, 1, 17 }, healer = { 139, 155, 1, 17 }, damager = { 157, 173, 1, 17 },
}
local function setBadge(texture, key)
    local cell = badgeCells[key]
    texture:SetTexture(badgeArt)
    texture:SetTexCoord(cell[1] / 256, cell[2] / 256, cell[3] / 64, cell[4] / 64)
end
-- Fits a badge into a box of `size` keeping its own proportions.
local function badgeSize(key, size)
    local cell = badgeCells[key]
    local w, h = cell[2] - cell[1], cell[4] - cell[3]
    local k = size / math.max(w, h)
    return w * k, h * k
end

-- The stock code sets these icons itself (faction on PvP flag changes, role from the LFG assignment):
-- the hook swaps in the Forever art each time and leaves anything else (FFA flag) to the client.
local swapping = {}
local function hookFaction(icon, size)
    if not icon or swapping[icon] ~= nil then return end
    swapping[icon] = false
    local stockW, stockH = icon:GetSize()
    hooksecurefunc(icon, "SetTexture", function(self, path)
        if swapping[self] then return end
        local key = type(path) == "string" and (path:find("PVP%-Alliance") and "alliance" or path:find("PVP%-Horde") and "horde")
        swapping[self] = true
        if key then
            setBadge(self, key)
            self:SetSize(badgeSize(key, size))
        else
            self:SetTexCoord(0, 1, 0, 1)
            self:SetSize(stockW, stockH)
        end
        swapping[self] = false
    end)
    local current = icon:GetTexture()
    if current then icon:SetTexture(current) end
end
-- GetTexCoordsForRoleSmallCircle: tank starts at the left edge, healer at the top.
local function hookRole(icon, size)
    if not icon or swapping[icon] ~= nil then return end
    swapping[icon] = false
    local function swap(self, left, right, top)
        if swapping[self] or type(left) ~= "number" or type(top) ~= "number" then return end
        local key = left < 0.1 and "tank" or (top < 0.1 and "healer" or "damager")
        swapping[self] = true
        setBadge(self, key)
        self:SetSize(size, size)
        swapping[self] = false
    end
    hooksecurefunc(icon, "SetTexCoord", swap)
    -- A role assigned before the skin: GetTexCoord gives the corners, upper-left first.
    local texture = icon:GetTexture()
    if type(texture) == "string" and texture:lower():find("portraitroles") then
        local left, top = icon:GetTexCoord()
        swap(icon, left, nil, top)
    end
end
local function aggroColor() return color("ufAggroColor", { 1, 0.18, 0.08 }) end
local function rgb(value) return value[1], value[2], value[3] end

-- Coordinates are measured on the game artwork at half its texture resolution.
local large = {
    portrait = { 157, 35, 53 }, health = { 12, 29, 119, 15 },
    power = { 12, 45, 119, 10 }, name = { 12, 16, 119 }, level = { 176, 56 },
}
-- Chrome: the WoW Forever player and target frames (uiunitframec60, 195 px wide) scaled to 480 px in
-- CharacterFrames.tga and shown 192 px wide, so one source pixel is 192 / 195 display units. Slot interiors
-- were measured on the source and are transparent in the atlas. Fills reach 1.5 px under the opaque chrome
-- so its anti-aliased inner edge leaves no gap.
local player = {
    chrome = { 0, 170, 67.9 }, portrait = { 34, 34, 55.5 },
    name = { 69.9, 14.2, 116.2 }, nameSlot = { 12.8, 14.8 }, health = { 67.4, 29, 122.1, 15.8 },
    power = { 67.4, 44.8, 122.1, 10.9 }, level = { 12, 60.5 },
    aggro = true,
}
local target = {
    chrome = { 192, 172, 68.9 }, portrait = { 158.5, 34, 55 },
    name = { 7.9, 13.2, 116.2 }, nameSlot = { 11.8, 14.8 }, nameFill = { 5.4, 10.3, 121.2, 17.8 },
    health = { 4.4, 28, 122.1, 15.8 }, power = { 4.4, 43.8, 122.1, 10.9 },
    level = { 180.5, 60 }, aggro = true,
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

-- Retail look (DragonUI art, MIT): geometry from DragonUI modules/unitframes/uf_skins.lua. Offsets are +y up and
-- relative to the named region ("frame", "portrait", "health", "bg"); the art is 512x256 shown at 256x128.
local retailArt = art .. "UnitFrames\\Retail-"
local retailKinds = {
    PlayerFrame = "player", TargetFrame = "target", FocusFrame = "target",
    TargetFrameToT = "small", FocusFrameToT = "small",
}
local retailSpecs = {
    player = {
        portrait = { "TOPLEFT", "frame", "TOPLEFT", 42, -15, 56 },
        health = { "LEFT", "portrait", "RIGHT", 2, -1, 125, 20 },
        power = { "LEFT", "portrait", "RIGHT", 2, -17, 125, 9 },
        bg = { retailArt .. "Player-BACKGROUND", retailArt .. "Player-BORDER", 256, 128, "LEFT", "health", "LEFT", -67, -28 },
        name = { "LEFT", "health", "TOPLEFT", 4, 7.5, 96 },
        level = { 15.5, -59 },
        glows = {
            status = { retailArt .. "Player-Status", 196, 71, { 0, 392 / 512, 0, 142 / 256 }, "bg", 0, 0.5 },
            combat = { retailArt .. "Player-InCombat", 192, 71, { 0, 384 / 512, 0, 142 / 256 }, "bg", 1.5, 1 },
        },
    },
    target = {
        portrait = { "TOPRIGHT", "frame", "TOPRIGHT", -48.75, -14.75, 54 },
        health = { "RIGHT", "portrait", "LEFT", -1.25, -2.25, 126, 20 },
        power = { "RIGHT", "portrait", "LEFT", 6.25, -18.75, 133, 9.5 },
        bg = { retailArt .. "Target-BACKGROUND", retailArt .. "Target-BORDER", 256, 128, "TOPLEFT", "frame", "TOPLEFT", -0.5, -10.5 },
        name = { "LEFT", "bg", "TOPLEFT", 4, -15.5, 117 },
        level = { 177.83, -55.5 },
        glows = {
            combat = { retailArt .. "Target-InCombat", 188, 67, { 0, 376 / 512, 0, 134 / 256 }, "frame", 1, 24 },
        },
    },
    small = {
        -- Stock portrait position and size (captured before ForeverUI moves it).
        health = { "LEFT", "portrait", "RIGHT", 2, 1, 70.5, 10 },
        power = { "LEFT", "portrait", "RIGHT", -1.5, -9, 74, 7.5 },
        bg = { retailArt .. "ToT-BACKGROUND", retailArt .. "ToT-BORDER", 128, 64, "LEFT", "portrait", "CENTER", -24.5, -9.5 },
        name = { "LEFT", "portrait", "RIGHT", 3, 13, 65 },
    },
}
retailSpecs.target.glows.status = retailSpecs.target.glows.combat
retailSpecs.small.glows = {}
local function retailActive() return ui.Settings().barLayout == "retail" end

local skins = {}
local healthBars = {}
local powerBars = {}
local barPanels = {}
local chromeRings, portraitRings, dividers, pvpIcons, restIcons = {}, {}, {}, {}, {}
-- Halo textures generated from the chrome silhouette: canvas size and margin in CharacterFrames px.
local chromeGlows = {
    player = { file = "Player-ChromeGlow", margin = 28, width = 536, height = 226 },
    target = { file = "Target-ChromeGlow", margin = 28, width = 536, height = 228 },
}

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

-- Remembers where a bar panel sits so the border can be drawn outside the bars, whatever its thickness.
local function rememberPanel(panel)
    panel.base = {}
    for i = 1, panel:GetNumPoints() do panel.base[i] = { panel:GetPoint(i) } end
    if #panel.base == 1 then panel.baseSize = { panel:GetWidth(), panel:GetHeight() } end
end

local function placePanel(panel, outset)
    if not panel.base then return end
    panel:ClearAllPoints()
    for _, anchor in ipairs(panel.base) do
        local point, relative, relativePoint, x, y = unpack(anchor, 1, 5)
        local dx = point:find("LEFT") and -outset or point:find("RIGHT") and outset or 0
        local dy = point:find("TOP") and outset or point:find("BOTTOM") and -outset or 0
        if panel.baseSize then
            -- A single corner anchor grows the panel by the outset on every side.
            dx, dy = point:find("RIGHT") and outset or -outset, point:find("BOTTOM") and -outset or outset
        end
        panel:SetPoint(point, relative, relativePoint, (x or 0) + dx, (y or 0) + dy)
    end
    if panel.baseSize then panel:SetSize(panel.baseSize[1] + 2 * outset, panel.baseSize[2] + 2 * outset) end
end

local function applyPanelMedia(panel, scale)
    local settings = ui.Settings()
    local background = ui.MediaPath("background", settings.unitBarBackground)
    local border = ui.MediaPath("border", settings.unitBarBorder)
    -- The bronze chrome of the player, target and party frames already is their border.
    if panel.foreverChrome then border = "" end
    -- The Retail art brings its own wells.
    if panel.retailOn then
        placePanel(panel, 0)
        panel:SetBackdrop(nil)
        return
    end
    local edgeSize, inset = 0, 0
    if border ~= "" then
        if border == art .. "UnitFrame-Edge" then
            edgeSize, inset = 4, 1.5
        else
            edgeSize, inset = setting("ufBorderSize", 12), setting("ufBorderInset", 3)
        end
        edgeSize, inset = edgeSize * scale, inset * scale
    end
    placePanel(panel, inset)
    if background == "" and border == "" then
        panel:SetBackdrop(nil)
        return
    end
    panel:SetBackdrop({
        bgFile = background ~= "" and background or nil,
        edgeFile = border ~= "" and border or nil,
        edgeSize = edgeSize,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    if border ~= "" then
        local edge = color("ufBorderColor", { 1, 1, 1, 1 })
        panel:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
    end
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
    return line
end

local function apply(frame, style, originX, originY, scale, flip)
    if not frame or skins[frame] then return end

    local prefix = frame:GetName()
    local isParty = prefix:match("^PartyMemberFrame%d+$")
    local retailKind = retailKinds[prefix]
    -- rt is the Retail layer of this frame (nil for frames that have none); rt.on says which look is shown.
    local rt = retailKind and { kind = retailKind, spec = retailSpecs[retailKind], on = false }
    local pvpIcon = frame.pvpIcon or _G[prefix .. "PVPIcon"] or (frame == PlayerFrame and PlayerPVPIcon)
    if pvpIcon then
        pvpIcons[pvpIcon] = true
        pvpIcon:SetAlpha(setting("ufShowPvP", false) and 1 or 0)
        hookFaction(pvpIcon, 26)
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

    if rt then
        local point, relative, relativePoint, x, y = portrait:GetPoint(1)
        rt.stockPortrait = { point, relative, relativePoint, x, y, portrait:GetWidth(), portrait:GetHeight() }
    end

    local function positionPortrait()
        if rt and rt.on then return rt.layoutPortrait() end
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
    rememberPanel(panel)
    applyPanelMedia(panel, scale)

    local function divide(parent, bar, geometry)
        local leftOffset = left + 1 - geometry[1]
        local rightOffset = right - 1 - geometry[1] - geometry[3]
        if flip then leftOffset, rightOffset = -rightOffset, -leftOffset end
        return addBarDivider(parent, bar, leftOffset, rightOffset, scale)
    end
    local dividerLines = {}
    if not style.nameBelow and not style.chrome then dividerLines[1] = divide(panel, health, style.health) end
    skinHealth(health, frame)
    if power then
        if not style.chrome then dividerLines[2] = divide(power, power, style.power) end
        skinPower(power, frame)
    end

    local role = (frame == PlayerFrame or isParty) and _G[prefix .. "RoleIcon"]
    if role then
        role:SetParent(portraitLayer)
        role:SetDrawLayer("OVERLAY", 3)
        hookRole(role, isParty and 11 or 14)
    end

    -- Leader crown and loot-master flag: the stock code only shows and hides these, so the art is set once.
    local function foreverIcon(icon, suffix)
        if not (icon and icon.SetTexture) then return end
        if suffix == "LeaderIcon" then
            setBadge(icon, "leader")
            icon:SetSize(badgeSize("leader", 16))
        elseif suffix == "MasterIcon" then
            setBadge(icon, "master")
            icon:SetSize(badgeSize("master", 14))
        end
    end

    -- Leader, loot master, guide and raid-mark icons live on the stock art frame, which is now below the
    -- portrait layer (party frames are handled further down). Lift them so the ring cannot cover them.
    if not isParty then
        local stockPrefix = frame == PlayerFrame and "Player" or prefix
        for _, suffix in ipairs({ "LeaderIcon", "GuideIcon", "MasterIcon", "RaidTargetIcon" }) do
            local icon = _G[stockPrefix .. suffix] or _G[prefix .. suffix] or _G[prefix .. "TextureFrame" .. suffix]
            if icon and icon.SetParent and icon.SetDrawLayer then
                icon:SetParent(portraitLayer)
                icon:SetDrawLayer("OVERLAY", 4)
                foreverIcon(icon, suffix)
            end
        end
    end

    local name = frame.name or _G[prefix .. "TextureFrameName"] or _G[prefix .. "Name"]
    if rt and name then rt.stockFont = { name:GetFont() } end
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
        if rt and rt.on then return rt.layoutBars() end
        position(health, "TOPLEFT", unpack(style.health))
        center(health.TextString, health)
        if power then
            position(power, "TOPLEFT", unpack(style.power))
            center(power.TextString, power)
        end
        if name then
            local x, y, width = unpack(style.name)
            local left = flip and -x - width or x
            local roleSpace = isParty and role and 14 or 0
            local height = isParty and 10 or 12
            if style.nameSlot and scale < 0.9 then
                -- Scaled-down chrome: fill the name slot and shrink the font to fit it.
                y, height = style.nameSlot[1], style.nameSlot[2] * scale
                local font, _, flags = name:GetFont()
                if font then name:SetFont(font, math.max(6, math.min(12, math.floor(height * 0.8 + 0.5))), flags) end
            end
            place(name, frame, "TOPLEFT", originX + left * scale, originY + y * scale)
            name:SetSize(width * scale - roleSpace, height)
            name:SetWordWrap(false)
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
    if style.nameFill then
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
                if setting("ufTargetAccent", true) and not (rt and rt.on) then accent:Show() else accent:Hide() end
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
        setBadge(badge, "level")
        local badgeW, badgeH = badgeSize("level", isParty and 40 or 32)
        local function placeBadge()
            if rt and rt.on and rt.spec.level then
                badge:ClearAllPoints()
                badge:SetPoint("CENTER", rt.bg, "TOPLEFT", rt.spec.level[1], rt.spec.level[2])
                badge:SetSize(badgeW * scale, badgeH * scale)
            else
                position(badge, "CENTER", x, y, badgeW, badgeH)
            end
        end
        if rt then rt.placeBadge = placeBadge end
        placeBadge()
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
    -- The stock status and threat glows keep their colours, pulsing and timing from the client;
    -- only their art is replaced by a halo cut to the WoW: Forever chrome.
    local function chromeGlow(region, enabled, which)
        if not region then return end
        if not enabled then
            region:SetTexture(nil)
            return
        end
        local retailGlow = rt and rt.on and rt.spec.glows[which or "combat"]
        if retailGlow then
            -- DragonUI's glows: the player's on the background art, the target's on the frame corner.
            region:SetParent(portraitLayer)
            region:SetDrawLayer("ARTWORK", -6)
            region:SetTexture(retailGlow[1])
            region:SetTexCoord(unpack(retailGlow[4]))
            region:SetBlendMode("ADD")
            region:ClearAllPoints()
            region:SetSize(retailGlow[2], retailGlow[3])
            if retailGlow[5] == "bg" then
                region:SetPoint("TOPLEFT", rt.bg, "TOPLEFT", retailGlow[6], retailGlow[7])
            else
                region:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", retailGlow[6], retailGlow[7])
            end
            return
        end
        local glow = style.chrome and chromeGlows[style == target and "target" or "player"]
        if not glow then
            portraitGlow(region)
            return
        end
        region:SetParent(portraitLayer)
        region:SetDrawLayer("ARTWORK", -5)
        region:SetTexture(art .. glow.file)
        region:SetTexCoord(0, 1, 0, 1)
        region:SetBlendMode("ADD")
        local sy = style.chrome[3] / style.chrome[2]
        position(region, "TOPLEFT", -glow.margin * 0.4, -glow.margin * sy, glow.width * 0.4, glow.height * sy)
    end
    if frame == PlayerFrame then
        skin.reglow = function()
            chromeGlow(PlayerFrameFlash, setting("ufThreatGlow", true), "combat")
            chromeGlow(PlayerStatusTexture, setting("ufStatusGlow", true), "status")
        end
        skin.reglow()
        -- The client pulses the alpha of these every frame, so only an empty texture hides them.
        if PlayerAttackBackground then PlayerAttackBackground:SetTexture(nil) end
        if PlayerRestGlow then PlayerRestGlow:SetTexture(nil) end
        -- In combat the stock frame swaps the level for crossed swords: show them on the level badge.
        if skin.badge and PlayerAttackIcon then
            for _, icon in ipairs({ PlayerAttackIcon, PlayerAttackGlow }) do
                if icon then
                    icon:SetParent(portraitLayer)
                    icon:SetDrawLayer("OVERLAY", 1)
                    icon:ClearAllPoints()
                    icon:SetPoint("CENTER", skin.badge, "CENTER", 0, 0)
                end
            end
            PlayerAttackIcon:SetSize(17 * scale, 17 * scale)
            if PlayerAttackGlow then PlayerAttackGlow:SetSize(28 * scale, 28 * scale) end
        end
        skin.updateBadge = function()
            if not skin.badge then return end
            if PlayerLevelText:IsShown() or (PlayerAttackIcon and PlayerAttackIcon:IsShown()) then
                skin.badge:Show()
            else
                skin.badge:Hide()
            end
        end
        hooksecurefunc("PlayerFrame_UpdateStatus", skin.updateBadge)
        skin.updateBadge()
        if PlayerRestIcon then
            PlayerRestIcon:SetAlpha(0)
            -- WoW Forever resting animation: 42 frames of 60 x 60 px, 6 per row (360 x 420 of the 512 px sheet).
            local CELL = 60 / 512
            local rest = portraitLayer:CreateTexture(nil, "OVERLAY", nil, 2)
            rest:SetTexture(art .. "Forever\\Rest-Flipbook")
            rest:SetTexCoord(0, CELL, 0, CELL)
            rest:SetSize(30 * scale, 30 * scale)
            rest:SetPoint("BOTTOMLEFT", portrait, "TOPRIGHT", -20 * scale, -6 * scale)
            local restAnim = CreateFrame("Frame", nil, portraitLayer)
            restAnim:Hide()
            local frameIndex, waited = 0, 0
            restAnim:SetScript("OnUpdate", function(self, elapsed)
                waited = waited + elapsed
                if waited < 0.05 then return end
                waited = 0
                frameIndex = (frameIndex + 1) % 42
                local col, row = frameIndex % 6, math.floor(frameIndex / 6)
                rest:SetTexCoord(col * CELL, (col + 1) * CELL, row * CELL, (row + 1) * CELL)
            end)
            local function updateRest()
                if PlayerRestIcon:IsShown() and setting("ufRestIcon", true) then
                    rest:Show()
                    restAnim:Show()
                else
                    rest:Hide()
                    restAnim:Hide()
                end
            end
            restIcons[rest] = updateRest
            hooksecurefunc("PlayerFrame_UpdateStatus", updateRest)
            updateRest()
        end
    elseif isParty then
        if frame.threatIndicator then
            skin.reglow = function() chromeGlow(frame.threatIndicator, setting("ufThreatGlow", true)) end
            skin.reglow()
        end
        for _, suffix in ipairs({ "Status", "LeaderIcon", "GuideIcon", "MasterIcon", "Disconnect" }) do
            local icon = _G[prefix .. suffix]
            if icon then
                icon:SetParent(portraitLayer)
                foreverIcon(icon, suffix)
            end
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
    if not skin.reglow and frame ~= PlayerFrame and frame.threatIndicator then
        skin.reglow = function() chromeGlow(frame.threatIndicator, setting("ufThreatGlow", true)) end
        skin.reglow()
    end
    if style == large or style == target then
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

    if rt then
        local spec = rt.spec
        local piece = spec.bg
        -- The background sits on the bar panel, below the bars; the border above everything but the portrait.
        rt.bg = panel:CreateTexture(nil, "BACKGROUND", nil, -6)
        rt.bg:SetTexture(piece[1])
        rt.bg:SetSize(piece[3], piece[4])
        rt.border = portraitLayer:CreateTexture(nil, "ARTWORK", nil, -4)
        rt.border:SetTexture(piece[2])
        rt.border:SetSize(piece[3], piece[4])
        rt.bg:Hide()
        rt.border:Hide()
        local refs = { frame = frame, portrait = portrait, health = health, bg = rt.bg }
        local function anchor(region, point, relative, relativePoint, x, y)
            region:ClearAllPoints()
            region:SetPoint(point, refs[relative], relativePoint, x, y)
        end
        function rt.layoutPortrait()
            portrait:SetDrawLayer("BORDER")
            local s = spec.portrait
            if s then
                portrait:ClearAllPoints()
                portrait:SetPoint(s[1], frame, s[3], s[4], s[5])
                portrait:SetSize(s[6], s[6])
            else
                local p = rt.stockPortrait
                portrait:ClearAllPoints()
                portrait:SetPoint(p[1], p[2], p[3], p[4], p[5])
                portrait:SetSize(p[6], p[7])
            end
        end
        function rt.layoutBars()
            rt.layoutPortrait()
            local h = spec.health
            anchor(health, h[1], h[2], h[3], h[4], h[5])
            health:SetSize(h[6], h[7])
            center(health.TextString, health)
            if power then
                local m = spec.power
                anchor(power, m[1], m[2], m[3], m[4], m[5])
                power:SetSize(m[6], m[7])
                center(power.TextString, power)
            end
            if name then
                local n = spec.name
                if rt.stockFont and rt.stockFont[1] then name:SetFont(unpack(rt.stockFont)) end
                anchor(name, n[1], n[2], n[3], n[4], n[5])
                name:SetSize(n[6], 12)
                name:SetWordWrap(false)
                name:SetJustifyH("LEFT")
            end
        end
        function rt.set(on)
            if rt.on == on then return end
            rt.on = on
            local a = spec.bg
            if on then
                anchor(rt.bg, a[5], a[6], a[7], a[8], a[9])
                rt.border:ClearAllPoints()
                rt.border:SetAllPoints(rt.bg)
                rt.bg:Show()
                rt.border:Show()
                ring:Hide()
                panel.retailOn = true
            else
                rt.bg:Hide()
                rt.border:Hide()
                ring:Show()
                panel.retailOn = nil
            end
            for _, line in pairs(dividerLines) do
                if on then line:Hide() else line:Show() end
            end
            applyPanelMedia(panel, scale)
            positionPortrait()
            positionBars()
            if rt.placeBadge then rt.placeBadge() end
            if skin.reglow then skin.reglow() end
            if skin.updateTarget then skin.updateTarget() end
            if skin.dragon then skin.dragon(nil, true) end
        end
        skin.retail = rt
        if retailActive() then rt.set(true) end
    end
    return skin
end

local function reskinPlayer()
    local skin = skins[PlayerFrame]
    if not skin then return end
    skin.bars()
    skin.portrait()
    if skin.reglow then skin.reglow() end
    if skin.updateBadge then skin.updateBadge() end
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
            rememberPanel(plate)
            applyPanelMedia(plate, 1)
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
    -- Tinting the bronze chrome is optional; by default the stock threat glow shows instead.
    local tint = status and status >= 2 and setting("ufAggroTint", false)
    skin.aggro:SetVertexColor(rgb(tint and aggroColor() or chromeColor()))
    indicator:SetAlpha(tint and 0 or 1)
end

local function applyStock()
    apply(PlayerFrame, player, 36, 8, 1)
    apply(TargetFrame, target, 4, 6, 1)
    -- Every other frame uses the same bronze chrome, scaled so its portrait stays where the stock one is.
    local chrome = setting("ufChromeAll", true)
    if chrome then
        apply(FocusFrame, target, 4, 6, 1)
        apply(TargetFrameToT, player, 3, 3.5, 0.55)
        apply(FocusFrameToT, player, 3, 3.5, 0.55)
        apply(PetFrame, player, 3.7, 6.7, 0.6)
    else
        apply(FocusFrame, large, 1, 9, 1)
        apply(TargetFrameToT, secondary, 2, 3, 0.79)
        apply(FocusFrameToT, secondary, 2, 3, 0.79)
        apply(PetFrame, small, 1, 5, 1)
    end
    for i = 1, 4 do
        local prefix = "PartyMemberFrame" .. i
        apply(_G[prefix], player, 2, 1, 0.625)
        if chrome then
            apply(_G[prefix .. "PetFrame"], player, -0.5, -1, 0.4)
        else
            apply(_G[prefix .. "PetFrame"], small, 1, 1, 0.53)
        end

        local boss = _G["Boss" .. i .. "TargetFrame"]
        local skin
        if chrome then skin = apply(boss, target, 0, 10, 0.8) else skin = apply(boss, large, 0, 12, 0.8) end
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
        -- The stock code resets the threat flash art for elite and normal targets.
        if skin and skin.reglow then skin.reglow() end
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
        local skin = (name == "target" and skins[TargetFrame]) or (name == "focus" and skins[FocusFrame])
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
            if skin.reglow then skin.reglow() end
            if skin.updateBadge then skin.updateBadge() end
        end
    end
    if TargetFrame_UpdateAuras and TargetFrame and UnitExists("target") then TargetFrame_UpdateAuras(TargetFrame) end
end

-- Switches the player, target, focus and target-of-target frames between the Classic and Retail looks.
local function applyLayout()
    local on = retailActive()
    for _, skin in pairs(skins) do
        if type(skin) == "table" and skin.retail then skin.retail.set(on) end
    end
end

-- Rogue and druid combo points on the target frame: WoW Forever socket and red gem (Art/Forever/Combo-Points.tga,
-- 64 x 32: socket at 1..25 x 1..25, gem at 32..48 x 1..18). The stock code only shows and hides the highlight.
local comboArt = art .. "Forever\\Combo-Points"
local function skinComboPoints()
    for index = 1, 5 do
        local point = _G["ComboPoint" .. index]
        local gem = _G["ComboPoint" .. index .. "Highlight"]
        if point and gem then
            for _, region in ipairs({ point:GetRegions() }) do
                if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" then
                    region:SetTexture(comboArt)
                    region:SetTexCoord(1 / 64, 25 / 64, 1 / 32, 25 / 32)
                    region:ClearAllPoints()
                    region:SetPoint("CENTER", point, "CENTER", 0, 0)
                    region:SetSize(13, 13)
                end
            end
            gem:SetTexture(comboArt)
            gem:SetTexCoord(32 / 64, 48 / 64, 1 / 32, 18 / 32)
            gem:ClearAllPoints()
            gem:SetPoint("CENTER", point, "CENTER", 0, 0.5)
            gem:SetSize(9, 9.5)
            local shine = _G["ComboPoint" .. index .. "Shine"]
            if shine then shine:SetAlpha(0) end
        end
    end
end
-- Death knight runes: the stock code sets "UI-PlayerFrame-Deathknight-<Type>" on each rune icon; the WoW Forever
-- skull of that type is swapped in (Art/Forever/Runes.tga, 128 x 32, from uideathknightrunes).
local runeArt = art .. "Forever\\Runes"
local runeCells = {
    blood = { 1, 18, 1, 27 }, death = { 33, 50, 1, 28 }, frost = { 65, 82, 1, 27 }, unholy = { 97, 114, 1, 27 },
}
local runeSwapping = {}
local function skinRunes()
    for index = 1, 6 do
        local icon = _G["RuneButtonIndividual" .. index .. "Rune"]
        if icon and runeSwapping[icon] == nil then
            runeSwapping[icon] = false
            local stockW, stockH = icon:GetSize()
            local function swap(self, path)
                if runeSwapping[self] or type(path) ~= "string" then return end
                local kind = path:lower():match("deathknight%-(%a+)$")
                local cell = kind and runeCells[kind]
                if not cell then return end
                runeSwapping[self] = true
                self:SetTexture(runeArt)
                self:SetTexCoord(cell[1] / 128, cell[2] / 128, cell[3] / 32, cell[4] / 32)
                local h = math.max(stockH or 0, 18)
                self:SetSize(h * (cell[2] - cell[1]) / (cell[4] - cell[3]), h)
                runeSwapping[self] = false
            end
            hooksecurefunc(icon, "SetTexture", swap)
            swap(icon, icon:GetTexture())
        end
    end
end

local comboDriver = CreateFrame("Frame")
comboDriver:RegisterEvent("PLAYER_LOGIN")
comboDriver:SetScript("OnEvent", function()
    skinComboPoints()
    skinRunes()
end)

ui.UnitFrames = {
    ApplyLayout = applyLayout,
    ApplyHealthColor = function() for bar in pairs(healthBars) do updateHealthColor(bar) end end,
    ApplyBarFill = applyBarFill,
    ApplyPanelMedia = applyBarPanelMedia,
    ApplyColors = applyColors,
    ApplyVisibility = applyVisibility,
}
