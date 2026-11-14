-- ForeverUI raid and party frame extension. The Nozdor client ships its own compact raid frames
-- (Custom_CompactRaidFrames: CompactRaidFrameContainer, CompactPartyFrame, CompactUnitFrame_* code).
-- They are not replaced: this module finds those unit buttons and decorates them in the Cell style
-- with click-through layers only (bar textures and colours, health deficit, incoming heals, a shield
-- line without glow, own buff/debuff icons, dispel highlight for what the player can remove,
-- corner indicators for HoTs, shields and class buffs, threat border, smooth range fade).
-- Secure attributes, sizes and anchors of the client buttons are never touched here; the only
-- protected action, re-anchoring the container to the Edit Mode anchor, waits for the end of combat.
-- Events are mapped to frames by GUID and coalesced into one pass per rendered frame.
local _, ui = ...
local L, Suite = ui.L, ui.Suite
local floor, max, min, format = math.floor, math.max, math.min, string.format
local GetTime, UnitGUID, UnitAura = GetTime, UnitGUID, UnitAura

local RF = {}
ui.RaidFrames = RF

---------------------------------------------------------------------------------------------------
-- Settings (the "raid" part of the active suite profile; the schema reads the same table)
---------------------------------------------------------------------------------------------------
local DEFAULTS = {
    rfEnabled = true,
    rfHealthTexture = "WoW Forever Raid", rfPowerTexture = "WoW Forever Raid",
    rfHealthColorMode = "client", rfHealthColor = { 0.22, 0.78, 0.32 },
    rfBackgroundColor = { 0.07, 0.07, 0.08, 0.9 }, rfBackgroundForever = true,
    rfDeficitText = "none", rfTextSize = 10,
    rfHealPrediction = true, rfHealColor = { 0.25, 0.95, 0.45, 0.55 },
    rfThreat = true, rfBorderSize = 2,
    rfRangeMode = "custom", rfRangeAlpha = 0.4, rfRangeFade = true,
    rfHideClientAuras = true,
    rfBuffs = true, rfBuffSize = 13, rfBuffMax = 3, rfBuffAnchor = "BOTTOMRIGHT", rfBuffGrow = "LEFT",
    rfBuffSpacing = 1, rfBuffX = -2, rfBuffY = 2, rfBuffFilter = "all", rfAuraTimer = false,
    rfBuffTrack = "", rfDebuffHide = "",   -- filled from RF.defaultTracked / RF.defaultExclusions below
    rfDebuffs = true, rfDebuffSize = 15, rfDebuffMax = 3, rfDebuffAnchor = "BOTTOMLEFT", rfDebuffGrow = "RIGHT",
    rfDebuffSpacing = 1, rfDebuffX = 2, rfDebuffY = 2, rfDebuffFilter = "all", rfDispelScale = 1.25,
    rfDispelHighlight = true, rfDispelOnlyMine = true, rfDispelStyle = "both", rfDispelAlpha = 0.45,
    rfDispelIcon = true, rfDispelIconSize = 13, rfDispelIconAnchor = "TOPRIGHT",
    rfShield = true, rfShieldTexture = "WoW Forever Raid", rfShieldColor = { 0.85, 0.95, 1, 1 }, rfShieldAlpha = 0.7,
    rfShieldHeight = 0, rfShieldMode = "attached", rfShieldAlign = "BOTTOM", rfHideAbsorbGlow = true,
    rfIndicators = true, rfIndicatorTimer = true,
    rfMoveContainer = true,
    rfPartyShow = "client", rfRaidShow = "client",
    rfRoleIcon = true, rfRoleSet = "blizzard2", rfRoleSize = 12, rfRoleAnchor = "TOPLEFT", rfRoleX = 2, rfRoleY = -2,
    rfRoleHideDamager = false, rfRoleHideClient = true, rfRoleSort = false, rfRoleOrder = "THD",
}
RF.defaults = DEFAULTS

-- Buff icons show only what is in the tracked list (an empty list shows no buff icons): big
-- defensive cooldowns, external saves and mana or haste cooldowns a healer reacts to. Matched by spell
-- name, so one id covers every rank. Indicators still see every buff.
local defensives = {
    33206, 47788, 1022, 6940, 642, 498,     -- Pain Suppression, Guardian Spirit, Hand of Protection, Hand of Sacrifice, Divine Shield, Divine Protection
    871, 12975, 48792, 48707, 55233,        -- Shield Wall, Last Stand, Icebound Fortitude, Anti-Magic Shell, Vampiric Blood
    61336, 22812, 5277, 31224, 45438, 19263, -- Survival Instincts, Barkskin, Evasion, Cloak of Shadows, Ice Block, Deterrence
}
RF.defaultTracked = {}
for _, id in ipairs(defensives) do RF.defaultTracked[#RF.defaultTracked + 1] = id end
for _, id in ipairs({ 10060, 29166, 64901, 31821, 1044, 6346 }) do -- Power Infusion, Innervate, Hymn of Hope, Aura Mastery, Hand of Freedom, Fear Ward
    RF.defaultTracked[#RF.defaultTracked + 1] = id
end

-- Debuffs that tell nothing on a raid frame: long debuffs nobody can act on. Based on Cell (Ghost,
-- Exhaustion, Sated), extended for 3.3.5.
RF.defaultExclusions = {
    debuffs = {
        8326, 57723, 57724,                 -- Ghost, Exhaustion, Sated (Cell)
        15007, 26013, 71041,                -- Resurrection Sickness, Deserter, Dungeon Deserter
        11196, 41425, 66233,                -- Recently Bandaged, Hypothermia, Ardent Defender cooldown
        69127,                              -- Chill of the Throne (Icecrown Citadel, on everyone)
        2479, 24755,                        -- Honorless Target, Tricked or Treated
    },
}
local function joinIds(list)
    local parts = {}
    for i, id in ipairs(list) do parts[i] = tostring(id) end
    return table.concat(parts, ", ")
end
RF.JoinIds = joinIds
DEFAULTS.rfBuffTrack = joinIds(RF.defaultTracked)
DEFAULTS.rfDebuffHide = joinIds(RF.defaultExclusions.debuffs)
RF.defaultExclusionText = { rfBuffTrack = DEFAULTS.rfBuffTrack, rfDebuffHide = DEFAULTS.rfDebuffHide }

-- Profiles from before the tracked list (they had an exclusion list rfBuffHide and the "mine" filter)
-- get the recommended tracked list; the old filter would hide the defensives cast by others.
function RF.MigrateExclusions(part)
    if type(part) ~= "table" then return end
    if part.rfBuffHide ~= nil then
        part.rfBuffHide = nil
        part.rfBuffTrack = DEFAULTS.rfBuffTrack
        part.rfBuffFilter = "all"
    end
    if part.rfBuffTrack == nil then part.rfBuffTrack = DEFAULTS.rfBuffTrack end
    if part.rfDebuffHide == nil then part.rfDebuffHide = DEFAULTS.rfDebuffHide end
end

local function indicator(name, spell, point, color, extra)
    local entry = { enabled = true, name = name, spell = tostring(spell), kind = "aura", mine = true, harmful = false,
        point = point, style = "square", size = 8, color = color, timer = true, stacks = false, x = 0, y = 0 }
    for k, v in pairs(extra or {}) do entry[k] = v end
    return entry
end
local classIndicators = {
    PRIEST = {
        indicator("Renew", 139, "TOPLEFT", { 0.3, 1, 0.3 }),
        indicator("Power Word: Shield", 17, "TOP", { 1, 0.9, 0.3 }, { mine = false }),
        indicator("Prayer of Mending", 33076, "TOPRIGHT", { 1, 0.5, 0.2 }, { stacks = true, mine = false }),
        indicator("Divine Aegis", 47753, "TOP", { 1, 1, 0.8 }, { x = 10, size = 6 }),
        indicator("Grace", 47930, "TOPRIGHT", { 0.9, 0.9, 1 }, { stacks = true, x = -10, size = 6 }),
        indicator("Weakened Soul", 6788, "TOP", { 0.8, 0.2, 0.2 }, { harmful = true, mine = false, enabled = false, y = -10 }),
        indicator("Fortitude", "1243, 21562", "BOTTOM", { 1, 1, 1 }, { kind = "missing", mine = false, size = 6 }),
    },
    DRUID = {
        indicator("Rejuvenation", 774, "TOPLEFT", { 0.75, 0.35, 1 }),
        indicator("Regrowth", 8936, "TOP", { 0.3, 1, 0.3 }),
        indicator("Lifebloom", 33763, "TOPRIGHT", { 0.6, 1, 0.4 }, { stacks = true }),
        indicator("Wild Growth", 48438, "TOP", { 0.6, 0.9, 0.2 }, { x = 10 }),
        indicator("Mark of the Wild", "1126, 21849", "BOTTOM", { 1, 0.5, 1 }, { kind = "missing", mine = false, size = 6 }),
    },
    SHAMAN = {
        indicator("Riptide", 61295, "TOPLEFT", { 0.2, 0.7, 1 }),
        indicator("Earth Shield", 974, "TOPRIGHT", { 0.65, 0.45, 0.2 }, { stacks = true }),
        indicator("Earthliving", 51945, "TOP", { 0.4, 0.9, 0.3 }),
        indicator("Ancestral Fortitude", 16177, "TOP", { 0.8, 0.7, 0.4 }, { x = 10, size = 6 }),
    },
    PALADIN = {
        indicator("Beacon of Light", 53563, "TOPLEFT", { 1, 0.85, 0.3 }),
        indicator("Sacred Shield", 53601, "TOPRIGHT", { 1, 0.95, 0.6 }),
        indicator("Hand of Freedom", 1044, "TOP", { 1, 0.7, 0.3 }, { mine = false, size = 6 }),
    },
    MAGE = { indicator("Arcane Intellect", "1459, 23028, 61316", "BOTTOM", { 0.4, 0.6, 1 }, { kind = "missing", mine = false, size = 6 }) },
}
-- What every healer watches, whatever the class: a big defensive or an external save on the member
-- (any caster, as a spell icon on the right) and healing reduction (Mortal Strike, Wound Poison,
-- Aimed Shot) as a red mark on the left.
RF.healerIndicators = {
    indicator("Defensive cooldown", joinIds(defensives), "RIGHT", { 1, 1, 1 },
        { mine = false, style = "icon", size = 14, x = -2 }),
    indicator("Healing reduced", "12294, 13218, 19434", "LEFT", { 1, 0.15, 0.15 },
        { harmful = true, mine = false, size = 7, x = 2 }),
}
RF.classIndicators = classIndicators
RF.healerClasses = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }

-- Adds preset entries that are not in the list yet (by name). Returns how many were added.
function RF.AddPresets(list, presets)
    local have, added = {}, 0
    for _, entry in ipairs(list) do have[entry.name or ""] = true end
    for _, entry in ipairs(presets or {}) do
        if not have[entry.name] then
            list[#list + 1] = Suite.Copy(entry)
            have[entry.name] = true
            added = added + 1
        end
    end
    return added
end

Suite.RegisterProfilePart("raid", function(db)
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then db[key] = Suite.Copy(value) end
    end
    if type(db.indicators) ~= "table" then
        local _, class = UnitClass("player")
        db.indicators = Suite.Copy(classIndicators[class] or {})
        if RF.healerClasses[class] then RF.AddPresets(db.indicators, RF.healerIndicators) end
    end
end)

local function cfg() return Suite.Part("raid") end
RF.Settings = cfg

local function texturePath(name)
    return ui.MediaPath and ui.MediaPath("statusbar", name, true) or Suite.art.bar
end

---------------------------------------------------------------------------------------------------
-- Frame discovery
---------------------------------------------------------------------------------------------------
local decos = {}            -- client button -> decoration
local byGUID = {}           -- guid -> { deco = true }
local ordered = {}          -- list of decorations for sweeps

local function fieldOf(frame, ...)
    for i = 1, select("#", ...) do
        local value = frame[select(i, ...)]
        if type(value) == "table" then return value end
    end
end

-- Which unit a client button shows. The candidates (secure "unit" attribute, then the Lua fields of
-- the client code) are not reliable on this client: several party buttons reported the same unit
-- while the client drew different names on them, so every frame read one ally's auras. The name the
-- client wrote on the button decides: the candidate whose UnitName matches it wins, and if none does,
-- the group is searched for that name.
local groupTokens = { "player" }
for i = 1, 4 do groupTokens[#groupTokens + 1] = "party" .. i end
for i = 1, 40 do groupTokens[#groupTokens + 1] = "raid" .. i end

local function shownName(frame)
    local label = frame.name
    if type(label) ~= "table" or type(label.GetText) ~= "function" then return nil end
    local text = label:GetText()
    if type(text) ~= "string" or text == "" then return nil end
    return (text:gsub("%-.*$", ""))
end

local function unitOf(frame)
    local attribute = frame.GetAttribute and frame:GetAttribute("unit")
    if type(attribute) ~= "string" or attribute == "" then attribute = nil end
    local first = attribute or frame.displayedUnit or frame.unit
    local name = shownName(frame)
    if not name then return first end
    for _, unit in ipairs({ attribute, frame.displayedUnit, frame.unit }) do
        if unit and UnitName(unit) == name then return unit end
    end
    for _, unit in ipairs(groupTokens) do
        if UnitExists(unit) and UnitName(unit) == name then return unit end
    end
    return first
end
RF.UnitOf = unitOf

local function isUnitButton(frame)
    return type(frame) == "table" and type(frame.GetObjectType) == "function"
        and fieldOf(frame, "healthBar", "healthbar", "HealthBar") ~= nil
end

local decorate -- forward

local function register(frame)
    if not isUnitButton(frame) or decos[frame] then return decos[frame] end
    if InCombatLockdown() then
        ui.RunOutOfCombat("rfRegister", function() RF.Scan() end)
        return
    end
    return decorate(frame)
end
RF.Register = register

local function scanChildren(parent, depth)
    if not parent or depth > 3 or not parent.GetChildren then return end
    for _, child in ipairs({ parent:GetChildren() }) do
        if isUnitButton(child) then register(child) else scanChildren(child, depth + 1) end
    end
end

function RF.Scan()
    for i = 1, 80 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then register(frame) end
    end
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame then register(frame) end
        end
    end
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then register(frame) end
        frame = _G["CompactPartyFramePet" .. i]
        if frame then register(frame) end
    end
    scanChildren(_G.CompactRaidFrameContainer, 0)
    scanChildren(_G.CompactPartyFrame, 0)
end

function RF.EachFrame(fn)
    for _, deco in ipairs(ordered) do fn(deco.frame, deco) end
end

---------------------------------------------------------------------------------------------------
-- Decoration
---------------------------------------------------------------------------------------------------
local white = Suite.art.white
local pointOffsets = {
    TOPLEFT = { 1, -1 }, TOP = { 0, -1 }, TOPRIGHT = { -1, -1 }, LEFT = { 1, 0 }, CENTER = { 0, 0 },
    RIGHT = { -1, 0 }, BOTTOMLEFT = { 1, 1 }, BOTTOM = { 0, 1 }, BOTTOMRIGHT = { -1, 1 },
}

-- Client textures that glow around absorbs (retail names, plus anything named like a shield glow).
local glowFields = { "overAbsorbGlow", "overHealAbsorbGlow", "absorbGlow", "shieldGlow" }

local function silence(region)
    if not region or region.foreverSilenced then return end
    region.foreverSilenced = true
    region:SetAlpha(0)
    if region.EnableMouse then region:EnableMouse(false) end
    if region.SetAlpha then hooksecurefunc(region, "SetAlpha", function(self, alpha)
        if alpha ~= 0 and self.foreverSilenced and cfg().rfHideAbsorbGlow then self:SetAlpha(0) end
    end) end
end

local function hideGlows(deco)
    local frame, settings = deco.frame, cfg()
    if not settings.rfHideAbsorbGlow then
        for _, field in ipairs(glowFields) do
            local region = frame[field]
            if region and region.foreverSilenced then
                region.foreverSilenced = nil
                region:SetAlpha(1)
            end
        end
        return
    end
    for _, field in ipairs(glowFields) do silence(frame[field]) end
    -- Unnamed regions with a glow texture on the frame or the health bar.
    for _, owner in ipairs({ frame, deco.health }) do
        for _, region in ipairs({ owner:GetRegions() }) do
            local texture = region.GetTexture and region:GetTexture()
            if type(texture) == "string" then
                local lower = texture:lower()
                if (lower:find("absorb", 1, true) or lower:find("shield", 1, true)) and lower:find("glow", 1, true) then
                    silence(region)
                end
            end
        end
    end
end

local function createDeco(frame)
    local deco = { frame = frame, buffs = {}, debuffs = {}, indicators = {} }
    deco.health = fieldOf(frame, "healthBar", "healthbar", "HealthBar")
    deco.power = fieldOf(frame, "powerBar", "powerbar", "PowerBar", "manaBar")
    deco.background = fieldOf(frame, "background", "Background")
    deco.clientAbsorb = fieldOf(frame, "totalAbsorb", "absorbBar", "shieldBar")
    deco.clientAbsorbOverlay = frame.totalAbsorbOverlay
    deco.clientHeals = { frame.myHealPrediction, frame.otherHealPrediction }

    -- Every layer is click-through so click-casting reaches the client button.
    local layer = CreateFrame("Frame", nil, frame)
    layer:SetAllPoints(frame)
    layer:SetFrameLevel(frame:GetFrameLevel() + 6)
    layer:EnableMouse(false)
    deco.layer = layer

    local bars = CreateFrame("Frame", nil, deco.health)
    bars:SetAllPoints(deco.health)
    bars:SetFrameLevel(deco.health:GetFrameLevel() + 1)
    bars:EnableMouse(false)
    deco.bars = bars
    deco.heal = bars:CreateTexture(nil, "ARTWORK")
    deco.heal:Hide()
    deco.shield = bars:CreateTexture(nil, "OVERLAY")
    deco.shield:Hide()

    deco.bg = frame:CreateTexture(nil, "BACKGROUND")
    deco.bg:SetAllPoints(frame)
    deco.bg:Hide()

    deco.dispelTint = layer:CreateTexture(nil, "BACKGROUND")
    deco.dispelTint:SetAllPoints(deco.health)
    deco.dispelTint:SetTexture(white)
    deco.dispelTint:SetGradientAlpha("VERTICAL", 1, 1, 1, 0.75, 1, 1, 1, 0)
    deco.dispelTint:Hide()
    deco.dispelOutline = layer:CreateTexture(nil, "ARTWORK")
    deco.dispelOutline:SetAllPoints(frame)
    Suite.RaidCell(deco.dispelOutline, "outline")
    deco.dispelOutline:Hide()
    deco.dispelIcon = layer:CreateTexture(nil, "OVERLAY")
    deco.dispelIcon:Hide()

    deco.border = CreateFrame("Frame", nil, layer)
    deco.border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    deco.border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    deco.border:EnableMouse(false)
    deco.border:Hide()

    deco.role = layer:CreateTexture(nil, "OVERLAY")
    deco.role:Hide()

    deco.text = layer:CreateFontString(nil, "OVERLAY")
    deco.text:SetPoint("BOTTOM", deco.health, "BOTTOM", 0, 2)
    deco.text:Hide()
    return deco
end

local function hookClientRegion(deco, region)
    if not region or region.foreverHooked then return end
    region.foreverHooked = true
    local function changed() deco.healthDirty = true RF.MarkDirty() end
    if region.SetWidth then hooksecurefunc(region, "SetWidth", changed) end
    if region.Show then hooksecurefunc(region, "Show", changed) end
    if region.Hide then hooksecurefunc(region, "Hide", changed) end
end

local applyStyle -- forward

decorate = function(frame)
    local deco = createDeco(frame)
    decos[frame] = deco
    ordered[#ordered + 1] = deco
    hookClientRegion(deco, deco.clientAbsorb)
    for _, region in ipairs(deco.clientHeals) do hookClientRegion(deco, region) end
    frame:HookScript("OnShow", function() deco.unitDirty = true RF.MarkDirty() end)
    if frame.HookScript then
        frame:HookScript("OnAttributeChanged", function(_, name)
            if name == "unit" then deco.unitDirty = true RF.MarkDirty() end
        end)
    end
    if deco.health and deco.health.HookScript then
        deco.health:HookScript("OnSizeChanged", function() deco.healthDirty = true RF.MarkDirty() end)
        deco.health:HookScript("OnValueChanged", function() deco.healthDirty = true RF.MarkDirty() end)
    end
    applyStyle(deco)
    deco.unitDirty, deco.auraDirty, deco.healthDirty = true, true, true
    RF.MarkDirty()
    if ui.ClickCast and ui.ClickCast.Attach then ui.ClickCast.Attach(frame) end
    return deco
end

---------------------------------------------------------------------------------------------------
-- Style (textures, colours, fonts): applied on settings change and new frames
---------------------------------------------------------------------------------------------------
local clientAuraFields = { "buffFrames", "debuffFrames", "dispelDebuffFrames" }
local function hideClientAuras(deco, hide)
    for _, field in ipairs(clientAuraFields) do
        local list = deco.frame[field]
        if type(list) == "table" then
            for _, aura in ipairs(list) do
                if hide then
                    aura:SetAlpha(0)
                    if aura.EnableMouse then aura:EnableMouse(false) end
                else
                    aura:SetAlpha(1)
                end
            end
        end
    end
end

applyStyle = function(deco)
    local settings = cfg()
    local enabled = settings.rfEnabled
    if deco.health and deco.health.SetStatusBarTexture then
        if enabled then
            deco.health:SetStatusBarTexture(texturePath(settings.rfHealthTexture))
        end
    end
    if deco.power and deco.power.SetStatusBarTexture and enabled then
        deco.power:SetStatusBarTexture(texturePath(settings.rfPowerTexture))
    end
    local bgColor = settings.rfBackgroundColor
    if enabled then
        deco.bg:SetTexture(settings.rfBackgroundForever and Suite.art.raidBackground or white)
        deco.bg:SetVertexColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
        deco.bg:Show()
        if deco.background and deco.background.SetAlpha then deco.background:SetAlpha(0) end
    else
        deco.bg:Hide()
        if deco.background and deco.background.SetAlpha then deco.background:SetAlpha(1) end
    end
    deco.text:SetFont(Suite.art.font, settings.rfTextSize, "OUTLINE")
    local edge = settings.rfBorderSize
    deco.border:SetBackdrop({ edgeFile = white, edgeSize = max(1, edge) })
    local hc = settings.rfHealColor
    deco.heal:SetTexture(texturePath(settings.rfHealthTexture))
    deco.heal:SetVertexColor(hc[1], hc[2], hc[3], hc[4] or 0.6)
    local sc = settings.rfShieldColor
    deco.shield:SetTexture(texturePath(settings.rfShieldTexture))
    deco.shield:SetVertexColor(sc[1], sc[2], sc[3], (sc[4] or 1) * settings.rfShieldAlpha)
    hideClientAuras(deco, enabled and settings.rfHideClientAuras)
    hideGlows(deco)
    local clientRole = deco.frame.roleIcon
    if clientRole and clientRole.SetAlpha then
        clientRole:SetAlpha(enabled and settings.rfRoleIcon and settings.rfRoleHideClient and 0 or 1)
    end
    deco.roleKey = nil
    -- Our shield replaces the client's one (no glow): keep theirs updating but invisible.
    local ownShield = enabled and settings.rfShield
    for _, region in ipairs({ deco.clientAbsorb, deco.clientAbsorbOverlay }) do
        if region and region.SetAlpha then region:SetAlpha(ownShield and 0 or 1) end
    end
    for _, region in ipairs(deco.clientHeals) do
        if region and region.SetAlpha then region:SetAlpha(enabled and settings.rfHealPrediction and RF.healSource and 0 or 1) end
    end
    for _, icon in ipairs(deco.buffs) do icon.styled = nil end
    for _, icon in ipairs(deco.debuffs) do icon.styled = nil end
    deco.healthDirty, deco.auraDirty = true, true
end

---------------------------------------------------------------------------------------------------
-- Health: colour, deficit text, incoming heals, shield line
---------------------------------------------------------------------------------------------------
local healComm
RF.healSource = UnitGetIncomingHeals and "api" or nil

local function incomingHeals(unit)
    if UnitGetIncomingHeals then return UnitGetIncomingHeals(unit) or 0 end
    if healComm then
        local guid = UnitGUID(unit)
        local amount = guid and healComm:GetHealAmount(guid, healComm.ALL_HEALS)
        return (amount or 0) * (healComm:GetHealModifier(guid) or 1)
    end
    return 0
end

local function absorbFraction(deco, unit, maxHealth)
    if UnitGetTotalAbsorbs then
        local amount = UnitGetTotalAbsorbs(unit) or 0
        return maxHealth > 0 and amount / maxHealth or 0
    end
    local region = deco.clientAbsorb
    if region and region:IsShown() then
        local width = deco.health:GetWidth()
        if width and width > 0 then return (region:GetWidth() or 0) / width end
    end
    return 0
end

local function classColor(unit)
    local _, class = UnitClass(unit)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return 0.5, 0.5, 0.5
end

local function colorHealth(deco, unit, fraction)
    local settings = cfg()
    local mode = settings.rfHealthColorMode
    if mode == "client" or not settings.rfEnabled then return end
    local r, g, b
    if mode == "class" then
        r, g, b = classColor(unit)
    elseif mode == "custom" then
        local color = settings.rfHealthColor
        r, g, b = color[1], color[2], color[3]
    else -- gradient red -> yellow -> green
        if fraction > 0.5 then
            r, g, b = (1 - fraction) * 2, 1, 0
        else
            r, g, b = 1, fraction * 2, 0
        end
    end
    deco.colorGuard = true
    deco.health:SetStatusBarColor(r, g, b)
    deco.colorGuard = nil
end

-- Lays a texture from `start` px over the bar, `width` px wide, with the configured thickness.
local function lay(texture, bar, start, width, thickness, align)
    if width < 0.5 then
        texture:Hide()
        return
    end
    texture:ClearAllPoints()
    texture:SetPoint(align .. "LEFT", bar, align .. "LEFT", start, 0)
    texture:SetWidth(width)
    texture:SetHeight(thickness)
    texture:Show()
end

-- fraction values are relative to maximum health.
function RF.DrawBars(deco, healthFraction, healFraction, absorb)
    local settings = cfg()
    local bar = deco.health
    local width, height = bar:GetWidth() or 0, bar:GetHeight() or 0
    if width <= 0 then return end
    local healthEnd = healthFraction * width
    local healWidth = 0
    if settings.rfEnabled and settings.rfHealPrediction and healFraction > 0 then
        healWidth = min(healFraction * width, width - healthEnd)
        lay(deco.heal, bar, healthEnd, healWidth, height, "")
    else
        deco.heal:Hide()
    end
    if not (settings.rfEnabled and settings.rfShield) or absorb <= 0 then
        deco.shield:Hide()
        return
    end
    local thickness = settings.rfShieldHeight > 0 and min(height, settings.rfShieldHeight) or height
    local align = settings.rfShieldAlign == "CENTER" and "" or settings.rfShieldAlign
    if thickness >= height then align = "" end
    local mode, size = settings.rfShieldMode, absorb * width
    local start
    if mode == "attached" then
        start = healthEnd + healWidth
        size = min(size, width - start)
    elseif mode == "overlay" then
        start = healthEnd + healWidth
        if start + size > width then start = max(0, width - size) end
        size = min(size, width)
    elseif mode == "reverse" then
        size = min(size, width)
        start = width - size
    else -- line from the left edge
        start = 0
        size = min(size, width)
    end
    lay(deco.shield, bar, start, size, thickness, align)
end

local function updateHealth(deco)
    deco.healthDirty = nil
    local unit = deco.unit
    local settings = cfg()
    if not unit or not UnitExists(unit) or not settings.rfEnabled then
        deco.heal:Hide()
        deco.shield:Hide()
        deco.text:Hide()
        return
    end
    local health, maxHealth = UnitHealth(unit) or 0, UnitHealthMax(unit) or 0
    local fraction = maxHealth > 0 and health / maxHealth or 0
    colorHealth(deco, unit, fraction)
    local dead = UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit)
    local heals = dead and 0 or incomingHeals(unit)
    RF.DrawBars(deco, fraction, maxHealth > 0 and heals / maxHealth or 0, dead and 0 or absorbFraction(deco, unit, maxHealth))
    local mode = settings.rfDeficitText
    if mode == "none" or dead then
        deco.text:Hide()
        return
    end
    local text
    if mode == "deficit" then
        local missing = maxHealth - health
        text = missing > 0 and ("-" .. Suite.ShortNumber(missing)) or nil
    elseif mode == "percent" then
        text = fraction < 1 and format("%d%%", floor(fraction * 100 + 0.5)) or nil
    else
        text = Suite.ShortNumber(health)
    end
    deco.text:SetText(text or "")
    Suite.Shown(deco.text, text ~= nil)
end

---------------------------------------------------------------------------------------------------
-- Auras: own buff/debuff icons, dispel highlight, Cell-style indicators
---------------------------------------------------------------------------------------------------
local indicatorLookup = {}   -- name or id -> { indicator index, ... }
local trackedBuffs = {}      -- name or id -> true: the only buffs drawn as icons (indicators see every buff)
local hiddenDebuffs = {}     -- the same for debuff icons and the dispel highlight
local function fillHidden(target, text)
    for k in pairs(target) do target[k] = nil end
    for _, spell in ipairs(Suite.ParseSpellList(text or "")) do
        target[spell] = true
        if type(spell) == "number" then
            local name = GetSpellInfo(spell)
            if name then target[name] = true end
        end
    end
end
local function rebuildIndicatorLookup()
    for k in pairs(indicatorLookup) do indicatorLookup[k] = nil end
    RF.MigrateExclusions(cfg())
    fillHidden(trackedBuffs, cfg().rfBuffTrack)
    fillHidden(hiddenDebuffs, cfg().rfDebuffHide)
    for index, entry in ipairs(cfg().indicators or {}) do
        if entry.enabled then
            for _, spell in ipairs(Suite.ParseSpellList(entry.spell)) do
                local key = type(spell) == "number" and (GetSpellInfo(spell) or spell) or spell
                indicatorLookup[key] = indicatorLookup[key] or {}
                table.insert(indicatorLookup[key], index)
                if type(spell) == "number" then
                    indicatorLookup[spell] = indicatorLookup[spell] or {}
                    table.insert(indicatorLookup[spell], index)
                end
            end
        end
    end
end
RF.RebuildIndicators = rebuildIndicatorLookup
function RF.IsHidden(harmful, aura)
    if harmful then return (aura.id and hiddenDebuffs[aura.id] or aura.name and hiddenDebuffs[aura.name]) and true or false end
    return not ((aura.id and trackedBuffs[aura.id]) or (aura.name and trackedBuffs[aura.name]))
end

local function auraIcon(deco, list, index, size)
    local icon = list[index]
    if not icon then
        icon = Suite.CreateIcon(deco.layer, size)
        icon.border:SetVertexColor(0, 0, 0)
        icon.cooldown:SetReverse(true)
        list[index] = icon
    end
    if icon.size ~= size then
        icon:SetWidth(size)
        icon:SetHeight(size)
        icon.count:SetFont(Suite.art.font, max(8, floor(size * 0.62)), "OUTLINE")
        icon.timer:SetFont(Suite.art.font, max(7, floor(size * 0.55)), "OUTLINE")
        icon.texture:SetPoint("TOPLEFT", 1, -1)
        icon.texture:SetPoint("BOTTOMRIGHT", -1, 1)
        icon.cooldown:SetPoint("TOPLEFT", 1, -1)
        icon.cooldown:SetPoint("BOTTOMRIGHT", -1, 1)
        icon.size = size
    end
    return icon
end

local growDelta = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

local function placeIcon(icon, frame, anchor, grow, offset, x, y)
    local delta = growDelta[grow] or growDelta.RIGHT
    icon:ClearAllPoints()
    icon:SetPoint(anchor, frame, anchor, x + delta[1] * offset, y + delta[2] * offset)
end

local function setAura(icon, texture, count, duration, expiration, borderColor, now)
    icon.texture:SetTexture(texture)
    icon.count:SetText(count and count > 1 and count or "")
    Suite.SetCooldown(icon.cooldown, duration and duration > 0 and expiration - duration or nil, duration)
    icon.expiration = duration and duration > 0 and expiration or nil
    if cfg().rfAuraTimer and icon.expiration then
        icon.timer:SetText(Suite.FormatTime(icon.expiration - now))
    else
        icon.timer:SetText("")
    end
    if borderColor then
        icon.border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3])
    else
        icon.border:SetVertexColor(0, 0, 0)
    end
    icon:Show()
end

local scratchDebuffs = {}
local foundIndicator = {}

local INDICATOR_LAYERS = 24
local function indicatorWidget(deco, index, entry)
    local widget = deco.indicators[index]
    if not widget then
        widget = CreateFrame("Frame", nil, deco.layer)
        widget:EnableMouse(false)
        widget.square = widget:CreateTexture(nil, "ARTWORK")
        widget.square:SetAllPoints(widget)
        widget.edge = widget:CreateTexture(nil, "BACKGROUND")
        widget.edge:SetPoint("TOPLEFT", -1, 1)
        widget.edge:SetPoint("BOTTOMRIGHT", 1, -1)
        widget.edge:SetTexture(white)
        widget.edge:SetVertexColor(0, 0, 0, 0.9)
        widget.cooldown = CreateFrame("Cooldown", nil, widget)
        widget.cooldown:SetAllPoints(widget)
        widget.cooldown:SetReverse(true)
        widget.cooldown.noCooldownCount = true
        widget.text = widget:CreateFontString(nil, "OVERLAY")
        widget.text:SetPoint("CENTER", 0, 0)
        deco.indicators[index] = widget
    end
    -- Restyle when the entry or any setting changed (RF.Apply bumps styleVersion): entries are edited in
    -- place, so the table identity alone would keep the old size, colour or position (preview included).
    if widget.stamp ~= entry or widget.styleVersion ~= RF.styleVersion then
        widget.stamp, widget.styleVersion = entry, RF.styleVersion
        -- List order is the layer order: the first indicator is drawn above the ones below it, so
        -- "Up"/"Down" in the options decide which of two overlapping indicators is on top. Each widget
        -- takes two levels (square, then its cooldown spiral) above the layer.
        local level = deco.layer:GetFrameLevel() + 1 + (INDICATOR_LAYERS - min(index, INDICATOR_LAYERS)) * 2
        widget:SetFrameLevel(level)
        widget.cooldown:SetFrameLevel(level + 1)
        local size = entry.size or 8
        widget:SetWidth(size)
        widget:SetHeight(size)
        widget:ClearAllPoints()
        local offset = pointOffsets[entry.point] or pointOffsets.TOPLEFT
        widget:SetPoint(entry.point or "TOPLEFT", deco.health, entry.point or "TOPLEFT",
            offset[1] * 1 + (entry.x or 0), offset[2] * 1 + (entry.y or 0))
        widget.text:SetFont(Suite.art.font, max(7, size), "OUTLINE")
        if entry.style == "icon" then
            widget.square:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            widget.square:SetVertexColor(1, 1, 1)
        else
            widget.square:SetTexture(white)
            widget.square:SetTexCoord(0, 1, 0, 1)
            local c = entry.color or { 1, 1, 1 }
            widget.square:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        end
        Suite.Shown(widget.square, entry.style ~= "text")
        Suite.Shown(widget.edge, entry.style ~= "text")
    end
    return widget
end

-- Fills deco from an aura list: { {name, icon, count, type, duration, expiration, caster, id, harmful}, ... }
function RF.DrawAuras(deco, buffs, debuffs, now)
    local settings = cfg()
    local frame = deco.health or deco.frame
    -- buffs
    local shownBuffs = 0
    if settings.rfEnabled and settings.rfBuffs then
        local size = settings.rfBuffSize
        for _, aura in ipairs(buffs) do
            if shownBuffs >= settings.rfBuffMax then break end
            local whose = settings.rfBuffFilter
            local allowed = whose == "all" or (whose == "mine" and aura.mine) or (whose == "raid" and aura.raid)
            if allowed and not aura.indicated and (trackedBuffs[aura.id] or trackedBuffs[aura.name]) then
                shownBuffs = shownBuffs + 1
                local icon = auraIcon(deco, deco.buffs, shownBuffs, size)
                placeIcon(icon, frame, settings.rfBuffAnchor, settings.rfBuffGrow,
                    (shownBuffs - 1) * (size + settings.rfBuffSpacing), settings.rfBuffX, settings.rfBuffY)
                setAura(icon, aura.icon, aura.count, aura.duration, aura.expiration, nil, now)
            end
        end
    end
    for i = shownBuffs + 1, #deco.buffs do deco.buffs[i]:Hide() end

    -- debuffs: dispellable first, larger
    local shownDebuffs, offset = 0, 0
    local dispelType
    for i = #scratchDebuffs, 1, -1 do scratchDebuffs[i] = nil end
    for _, aura in ipairs(debuffs) do
        if not (hiddenDebuffs[aura.id] or hiddenDebuffs[aura.name]) then
            aura.dispellable = aura.type and Suite.CanDispel(aura.type) or false
            if aura.dispellable and not dispelType then dispelType = aura.type end
            if not dispelType and not settings.rfDispelOnlyMine and aura.type and Suite.dispelColors[aura.type] then
                dispelType = aura.type
            end
            scratchDebuffs[#scratchDebuffs + 1] = aura
        end
    end
    if settings.rfEnabled and settings.rfDebuffs then
        table.sort(scratchDebuffs, function(a, b)
            if a.dispellable ~= b.dispellable then return a.dispellable end
            return (a.expiration or 0) < (b.expiration or 0)
        end)
        for _, aura in ipairs(scratchDebuffs) do
            if shownDebuffs >= settings.rfDebuffMax then break end
            local allowed = settings.rfDebuffFilter == "all" or aura.dispellable
                or (settings.rfDebuffFilter == "typed" and aura.type)
            if allowed and not aura.indicated then
                shownDebuffs = shownDebuffs + 1
                local size = floor(settings.rfDebuffSize * (aura.dispellable and settings.rfDispelScale or 1) + 0.5)
                local icon = auraIcon(deco, deco.debuffs, shownDebuffs, size)
                placeIcon(icon, frame, settings.rfDebuffAnchor, settings.rfDebuffGrow, offset,
                    settings.rfDebuffX, settings.rfDebuffY)
                offset = offset + size + settings.rfDebuffSpacing
                setAura(icon, aura.icon, aura.count, aura.duration, aura.expiration,
                    aura.type and Suite.dispelColors[aura.type] or { 0.8, 0, 0 }, now)
            end
        end
    end
    for i = shownDebuffs + 1, #deco.debuffs do deco.debuffs[i]:Hide() end

    -- dispel highlight
    local color = settings.rfEnabled and settings.rfDispelHighlight and dispelType and Suite.dispelColors[dispelType]
    if color then
        local style, alpha = settings.rfDispelStyle, settings.rfDispelAlpha
        deco.dispelTint:SetVertexColor(color[1], color[2], color[3], alpha)
        Suite.Shown(deco.dispelTint, style == "overlay" or style == "both")
        deco.dispelOutline:SetVertexColor(color[1], color[2], color[3], 1)
        Suite.Shown(deco.dispelOutline, style == "border" or style == "both")
        if settings.rfDispelIcon and Suite.RaidCell(deco.dispelIcon, dispelType) then
            local size = settings.rfDispelIconSize
            deco.dispelIcon:SetWidth(size)
            deco.dispelIcon:SetHeight(size)
            deco.dispelIcon:ClearAllPoints()
            local point = settings.rfDispelIconAnchor
            local o = pointOffsets[point] or pointOffsets.TOPRIGHT
            deco.dispelIcon:SetPoint(point, deco.health, point, o[1] * 2, o[2] * 2)
            deco.dispelIcon:Show()
        else
            deco.dispelIcon:Hide()
        end
    else
        deco.dispelTint:Hide()
        deco.dispelOutline:Hide()
        deco.dispelIcon:Hide()
    end
end

local auraPool, buffList, debuffList = {}, {}, {}

local function collect(unit, filter, list, mineOnly)
    for i = 1, 40 do
        local name, _, icon, count, debuffType, duration, expiration, caster, _, _, spellId = UnitAura(unit, i, filter)
        if not name then break end
        if not mineOnly or caster == "player" or caster == "pet" or caster == "vehicle" then
            local aura = table.remove(auraPool) or {}
            aura.name, aura.icon, aura.count, aura.type = name, icon, count, debuffType
            aura.duration, aura.expiration, aura.caster, aura.id = duration, expiration, caster, spellId
            aura.indicated, aura.mine = nil, caster == "player" or caster == "pet" or caster == "vehicle"
            list[#list + 1] = aura
        end
    end
end

local raidNames = {}
local function markRaidBuffs(unit, list)
    for k in pairs(raidNames) do raidNames[k] = nil end
    for i = 1, 40 do
        local name = UnitAura(unit, i, "HELPFUL|RAID")
        if not name then break end
        raidNames[name] = true
    end
    for _, aura in ipairs(list) do aura.raid = raidNames[aura.name] or false end
end

local function release(list)
    for i = #list, 1, -1 do
        auraPool[#auraPool + 1] = list[i]
        list[i] = nil
    end
end

local function drawIndicators(deco, buffs, debuffs, now)
    local settings = cfg()
    local list = settings.indicators or {}
    for index in pairs(foundIndicator) do foundIndicator[index] = nil end
    if settings.rfEnabled and settings.rfIndicators then
        for pass = 1, 2 do
            for _, aura in ipairs(pass == 1 and buffs or debuffs) do
                local hits = indicatorLookup[aura.id] or indicatorLookup[aura.name]
                if hits then
                    for _, index in ipairs(hits) do
                        local entry = list[index]
                        if entry and (entry.harmful and pass == 2 or not entry.harmful and pass == 1)
                            and (not entry.mine or aura.mine) and not foundIndicator[index] then
                            foundIndicator[index] = aura
                            if entry.kind ~= "missing" then aura.indicated = true end
                        end
                    end
                end
            end
        end
    end
    for index, entry in ipairs(list) do
        local aura = foundIndicator[index]
        local show
        if not (settings.rfEnabled and settings.rfIndicators and entry.enabled) then
            show = false
        elseif entry.kind == "missing" then
            show = aura == nil and UnitIsConnected(deco.unit or "") and not UnitIsDeadOrGhost(deco.unit or "")
        else
            show = aura ~= nil
        end
        local widget = deco.indicators[index]
        if show then
            widget = indicatorWidget(deco, index, entry)
            if entry.style == "icon" then
                local _, icon = Suite.SpellInfo(Suite.ParseSpellList(entry.spell)[1])
                widget.square:SetTexture(aura and aura.icon or icon)
            end
            local duration = aura and aura.duration or 0
            if settings.rfIndicatorTimer and entry.timer and duration > 0 and entry.style ~= "text" then
                Suite.SetCooldown(widget.cooldown, aura.expiration - duration, duration)
            else
                Suite.SetCooldown(widget.cooldown, nil)
            end
            local text = ""
            if entry.stacks and aura and (aura.count or 0) > 1 then
                text = tostring(aura.count)
            elseif entry.style == "text" and aura and duration > 0 then
                text = Suite.FormatTime(aura.expiration - now)
            end
            widget.text:SetText(text)
            local c = entry.color or { 1, 1, 1 }
            widget.text:SetTextColor(entry.style == "text" and c[1] or 1, entry.style == "text" and c[2] or 1,
                entry.style == "text" and c[3] or 1)
            widget.expiration = entry.style == "text" and aura and duration > 0 and aura.expiration or nil
            widget:Show()
        elseif widget then
            widget:Hide()
        end
    end
    -- Widgets exist only for indicators that were ever shown, so the table has holes: use pairs.
    for index, widget in pairs(deco.indicators) do
        if not list[index] then widget:Hide() end
    end
end

local function updateAuras(deco)
    deco.auraDirty = nil
    -- A recycled client button can show another unit before our sweep sees it: never read the
    -- auras of a token that no longer belongs to the GUID this frame was mapped to.
    if deco.unit and UnitGUID(deco.unit) ~= deco.guid then
        deco.unitDirty = true
        RF.MarkDirty()
        deco.unit = nil
    end
    local unit = deco.unit
    local now = GetTime()
    local settings = cfg()
    -- The client may create more aura icons later (more max buffs): keep them hidden too.
    if settings.rfEnabled and settings.rfHideClientAuras then hideClientAuras(deco, true) end
    if not unit or not UnitExists(unit) or not settings.rfEnabled then
        RF.DrawAuras(deco, buffList, debuffList, now)
        drawIndicators(deco, buffList, debuffList, now)
        return
    end
    -- Every buff is collected: indicators of others' shields and saves need them. "Whose buffs" only
    -- filters the icons (RF.DrawAuras).
    collect(unit, "HELPFUL", buffList, false)
    if settings.rfBuffFilter == "raid" then markRaidBuffs(unit, buffList) end
    collect(unit, "HARMFUL", debuffList, false)
    -- Indicators claim their auras first so they are not drawn twice.
    drawIndicators(deco, buffList, debuffList, now)
    RF.DrawAuras(deco, buffList, debuffList, now)
    release(buffList)
    release(debuffList)
end

---------------------------------------------------------------------------------------------------
-- Threat and range
---------------------------------------------------------------------------------------------------
local function updateThreat(deco)
    deco.threatDirty = nil
    local unit = deco.unit
    local settings = cfg()
    local status = settings.rfEnabled and settings.rfThreat and unit and UnitExists(unit) and UnitThreatSituation(unit)
    if status and status > 0 then
        local r, g, b = GetThreatStatusColor(status)
        deco.border:SetBackdropBorderColor(r, g, b, 1)
        deco.border:Show()
    else
        deco.border:Hide()
    end
end

local fading = {}
local function targetAlpha(deco)
    local settings = cfg()
    local unit = deco.unit
    if not unit or not settings.rfEnabled or settings.rfRangeMode ~= "custom" then return nil end
    if UnitIsUnit(unit, "player") then return 1 end
    if not UnitIsConnected(unit) then return settings.rfRangeAlpha end
    local inRange = UnitInRange(unit)
    if inRange == nil and not (UnitInRaid(unit) or UnitInParty(unit)) then
        inRange = CheckInteractDistance(unit, 4)
    end
    return inRange and 1 or settings.rfRangeAlpha
end

local function updateRange(deco)
    local wanted = targetAlpha(deco)
    if not wanted then
        fading[deco] = nil
        return
    end
    deco.alphaTarget = wanted
    local current = deco.frame:GetAlpha()
    if math.abs(current - wanted) < 0.01 then
        fading[deco] = nil
        return
    end
    if cfg().rfRangeFade then
        fading[deco] = true
    else
        deco.frame:SetAlpha(wanted)
    end
end

---------------------------------------------------------------------------------------------------
-- Update loop: dirty flags per decoration, one pass per frame, range and timers on a slow clock
---------------------------------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local anyDirty = false
local rangeClock, timerClock, sweepClock = 0, 0, 0

function RF.MarkDirty() anyDirty = true end

local function refreshUnit(deco)
    deco.unitDirty = nil
    local unit = unitOf(deco.frame)
    local guid = unit and UnitGUID(unit)
    if deco.guid and deco.guid ~= guid and byGUID[deco.guid] then byGUID[deco.guid][deco] = nil end
    deco.unit, deco.guid = unit, guid
    if guid then
        byGUID[guid] = byGUID[guid] or {}
        byGUID[guid][deco] = true
    end
    deco.auraDirty, deco.healthDirty, deco.threatDirty = true, true, true
    RF.UpdateRole(deco)
    updateRange(deco)
end

local function process()
    anyDirty = false
    for _, deco in ipairs(ordered) do
        if deco.frame:IsVisible() then
            if deco.unitDirty then refreshUnit(deco) end
            if deco.healthDirty then updateHealth(deco) end
            if deco.auraDirty then updateAuras(deco) end
            if deco.threatDirty then updateThreat(deco) end
        end
    end
end

local function tickTimers(now)
    if not cfg().rfAuraTimer and not cfg().rfIndicators then return end
    for _, deco in ipairs(ordered) do
        if deco.frame:IsVisible() then
            for _, list in ipairs({ deco.buffs, deco.debuffs }) do
                for _, icon in ipairs(list) do
                    if icon.expiration and icon:IsShown() and cfg().rfAuraTimer then
                        icon.timer:SetText(Suite.FormatTime(icon.expiration - now))
                    end
                end
            end
            for _, widget in pairs(deco.indicators) do
                if widget.expiration and widget:IsShown() then
                    widget.text:SetText(Suite.FormatTime(widget.expiration - now))
                end
            end
        end
    end
end

driver:SetScript("OnUpdate", function(_, elapsed)
    if anyDirty then process() end
    rangeClock, timerClock, sweepClock = rangeClock + elapsed, timerClock + elapsed, sweepClock + elapsed
    if rangeClock >= 0.2 then
        rangeClock = 0
        for _, deco in ipairs(ordered) do
            if deco.frame:IsVisible() then updateRange(deco) end
        end
    end
    if next(fading) then
        local step = elapsed * 4
        for deco in pairs(fading) do
            local current, wanted = deco.frame:GetAlpha(), deco.alphaTarget or 1
            local nextAlpha = current < wanted and min(wanted, current + step) or max(wanted, current - step)
            deco.frame:SetAlpha(nextAlpha)
            if nextAlpha == wanted then fading[deco] = nil end
        end
    end
    if timerClock >= 0.25 then
        timerClock = 0
        tickTimers(GetTime())
    end
    -- Units of client buttons can change without an event we see (sorting): check twice a second.
    if sweepClock >= 0.5 then
        sweepClock = 0
        for _, deco in ipairs(ordered) do
            if deco.frame:IsVisible() and unitOf(deco.frame) ~= deco.unit then
                deco.unitDirty = true
                anyDirty = true
            end
        end
    end
end)

local function markGUID(unit, field)
    local guid = unit and UnitGUID(unit)
    local set = guid and byGUID[guid]
    if not set then return end
    for deco in pairs(set) do
        deco[field] = true
        anyDirty = true
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UNIT_AURA", "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_THREAT_SITUATION_UPDATE", "UNIT_CONNECTION", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
    "UNIT_PET", "PLAYER_REGEN_ENABLED", "PLAYER_ROLES_ASSIGNED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" then
        markGUID(unit, "auraDirty")
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        markGUID(unit, "healthDirty")
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
        markGUID(unit, "threatDirty")
    elseif event == "UNIT_CONNECTION" then
        markGUID(unit, "healthDirty")
    else
        if not InCombatLockdown() then RF.Scan() end
        for _, deco in ipairs(ordered) do deco.unitDirty = true end
        anyDirty = true
        if event == "PLAYER_LOGIN" then RF.Init() end
        if event ~= "PLAYER_REGEN_ENABLED" and event ~= "UNIT_PET" then RF.ApplySort(true) end
    end
end)

---------------------------------------------------------------------------------------------------
-- Hooks into the client compact frame code (only those that exist on this client)
---------------------------------------------------------------------------------------------------
local function hookGlobal(name, fn)
    if type(_G[name]) == "function" then
        hooksecurefunc(name, fn)
        return true
    end
end

local function installHooks()
    local function adopt(frame)
        if type(frame) ~= "table" then return end
        local deco = decos[frame]
        if not deco then
            register(frame)
        elseif unitOf(frame) ~= deco.unit or (deco.unit and UnitGUID(deco.unit) ~= deco.guid) then
            deco.unitDirty = true
            anyDirty = true
        end
    end
    for _, name in ipairs({ "CompactUnitFrame_SetUpFrame", "CompactUnitFrame_SetUnit", "DefaultCompactUnitFrameSetup",
        "DefaultCompactMiniFrameSetup", "CompactUnitFrame_UpdateAll" }) do
        hookGlobal(name, adopt)
    end
    hookGlobal("CompactUnitFrame_UpdateHealthColor", function(frame)
        local deco = decos[frame]
        if deco and not deco.colorGuard and cfg().rfHealthColorMode ~= "client" then
            deco.healthDirty = true
            anyDirty = true
        end
    end)
    hookGlobal("CompactUnitFrame_UpdateInRange", function(frame)
        local deco = decos[frame]
        if deco and deco.alphaTarget and cfg().rfRangeMode == "custom" and not fading[deco] then
            frame:SetAlpha(deco.alphaTarget)
        end
    end)
    local function reHide(frame)
        local deco = decos[frame]
        if deco and cfg().rfEnabled and cfg().rfHideClientAuras then hideClientAuras(deco, true) end
    end
    for _, name in ipairs({ "CompactUnitFrame_UpdateAuras", "CompactUnitFrame_UpdateBuffs",
        "CompactUnitFrame_UpdateDebuffs", "CompactUnitFrame_UpdateDispellableDebuffs" }) do
        hookGlobal(name, reHide)
    end
    hookGlobal("CompactUnitFrame_UpdateHealPrediction", function(frame)
        local deco = decos[frame]
        if deco then
            deco.healthDirty = true
            anyDirty = true
            if cfg().rfHideAbsorbGlow then hideGlows(deco) end
        end
    end)
    hookGlobal("CompactRaidFrameContainer_LayoutFrames", function() RF.MarkDirty() RF.SyncAnchor() end)
end

---------------------------------------------------------------------------------------------------
-- Edit Mode anchor for the whole raid/party container
---------------------------------------------------------------------------------------------------
local anchor = CreateFrame("Frame", "ForeverStockUIRaidAnchor", UIParent)
anchor:SetWidth(220)
anchor:SetHeight(160)
anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 22, -240)
anchor:SetClampedToScreen(true)
anchor:Hide()
RF.anchor = anchor
local attaching

-- Mock grid drawn inside the anchor while editing, so the anchor is visible even out of a group.
local mock = CreateFrame("Frame", nil, anchor)
mock:SetAllPoints(anchor)
mock.cells = {}
for i = 1, 10 do
    local cell = mock:CreateTexture(nil, "ARTWORK")
    cell:SetTexture(texturePath("WoW Forever Raid"))
    mock.cells[i] = cell
end
local mockLabel = mock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mockLabel:SetPoint("CENTER")
mockLabel:SetText(L("Фреймы группы и рейда", "Party and raid frames"))

local function containers()
    return _G.CompactRaidFrameContainer, _G.CompactPartyFrame
end

local function editEntry()
    return anchor.editEntry
end

local function savedPosition()
    local entry = editEntry()
    local config = entry and entry.config
    return config and type(config.position) == "table"
end

local function drawMock()
    local width, height = anchor:GetWidth(), anchor:GetHeight()
    local cw, ch = (width - 6) / 2, (height - 12) / 5
    for i, cell in ipairs(mock.cells) do
        local col, row = (i - 1) % 2, floor((i - 1) / 2)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", anchor, "TOPLEFT", 2 + col * (cw + 2), -2 - row * (ch + 2))
        cell:SetWidth(cw)
        cell:SetHeight(ch)
        local shade = 0.55 + 0.08 * ((i * 3) % 5)
        cell:SetVertexColor(0.2 * shade, 0.75 * shade, 0.3 * shade, 0.8)
    end
end

local function hookContainer(container)
    if not container or container.foreverAnchored then return end
    container.foreverAnchored = true
    hooksecurefunc(container, "SetPoint", function()
        if attaching or not savedPosition() or not cfg().rfMoveContainer then return end
        -- The client re-placed it (manager, layout): put it back once combat allows.
        ui.RunOutOfCombat("rfAttach", RF.AttachContainer)
    end)
end

-- Screen rectangle (UIParent units) of a region, or nil while it has no valid layout.
local function screenRect(region)
    local left, bottom, right, top = region:GetLeft(), region:GetBottom(), region:GetRight(), region:GetTop()
    if not (left and bottom and right and top) then return end
    local scale = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return left * scale, bottom * scale, right * scale, top * scale
end

-- Bounds of the unit buttons that are really shown. The client container keeps the size of a full
-- raid even with five players, so it cannot size the anchor.
local function buttonBounds()
    local left, bottom, right, top
    for _, deco in ipairs(ordered) do
        if deco.frame:IsVisible() then
            local l, b, r, t = screenRect(deco.frame)
            if l then
                left, bottom = left and min(left, l) or l, bottom and min(bottom, b) or b
                right, top = right and max(right, r) or r, top and max(top, t) or t
            end
        end
    end
    return left, bottom, right, top
end

-- Puts the anchor over the shown buttons (when the user never moved it) and sizes it like them.
-- Everything is measured before the anchor moves: the container may hang on the anchor, and clearing
-- the anchor's points leaves the container (and its buttons) without a position until the next layout.
function RF.SyncAnchor()
    if InCombatLockdown() then return end
    local raid, party = containers()
    hookContainer(raid)
    hookContainer(party)
    local left, bottom, right, top = buttonBounds()
    if not left then
        local source = (raid and raid:IsShown() and raid) or (party and party:IsShown() and party)
        if source then left, bottom, right, top = screenRect(source) end
    end
    if left and right - left > 20 and top - bottom > 20 then
        anchor:SetWidth(right - left)
        anchor:SetHeight(top - bottom)
        if not savedPosition() then
            attaching = true
            anchor:ClearAllPoints()
            anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            attaching = nil
        end
    end
    drawMock()
end

-- Re-anchors the client container to the anchor. Protected: only out of combat.
function RF.AttachContainer()
    if not cfg().rfMoveContainer or not savedPosition() then return end
    if InCombatLockdown() then
        ui.RunOutOfCombat("rfAttach", RF.AttachContainer)
        return
    end
    local raid, party = containers()
    attaching = true
    for _, container in ipairs({ raid, party }) do
        if container and container ~= anchor then
            local parent = container:GetParent()
            if parent ~= raid then
                container:ClearAllPoints()
                container:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
            end
        end
    end
    attaching = nil
end

hooksecurefunc(anchor, "SetPoint", function()
    if attaching then return end
    RF.AttachContainer()
end)

function RF.Init()
    installHooks()
    local raid, party = containers()
    hookContainer(raid)
    hookContainer(party)
    if ui.RegisterEditFrame then
        local entry = ui.RegisterEditFrame(anchor, L("Фреймы группы и рейда", "Party and raid frames"), "raidframes")
        if entry then
            entry.onRightClick = function() ui.OpenOptions("raidframes") end
            entry.resetPosition = function() RF.SyncAnchor() end
            anchor.editEntry = entry
        end
    end
    rebuildIndicatorLookup()
    healComm = LibStub and LibStub("LibHealComm-4.0", true)
    if healComm and not RF.healSource then
        RF.healSource = "lib"
        local function changed(_, _, _, _, ...)
            for i = 1, select("#", ...) do
                local set = byGUID[select(i, ...)]
                if set then for deco in pairs(set) do deco.healthDirty = true end end
            end
            anyDirty = true
        end
        for _, callback in ipairs({ "HealComm_HealStarted", "HealComm_HealUpdated", "HealComm_HealDelayed",
            "HealComm_HealStopped", "HealComm_ModifierChanged" }) do
            healComm.RegisterCallback(RF, callback, changed)
        end
    end
    RF.Scan()
    RF.SyncAnchor()
    RF.AttachContainer()
    if RF.ApplyVisibility then RF.ApplyVisibility() end
end

if ForeverStockUIEditMode then
    ForeverStockUIEditMode:HookScript("OnShow", function()
        RF.SyncAnchor()
        anchor:Show()
        local raid, party = containers()
        Suite.Shown(mock, not ((raid and raid:IsVisible()) or (party and party:IsVisible())))
        if ui.RefreshEditLayout then ui.RefreshEditLayout() end
    end)
    ForeverStockUIEditMode:HookScript("OnHide", function() anchor:Hide() end)
end

---------------------------------------------------------------------------------------------------
-- Role icons: several sets (Art/Roles, copied from Cell's third-party sets and MidUI), size, anchor,
-- offsets, hide damage dealers, hide the client's own role icon.
---------------------------------------------------------------------------------------------------
local ROLE_PATH = "Interface\\AddOns\\ForeverUI\\Art\\Roles\\"
-- Sheet layouts: the 256 px Blizzard 2 sheet and the 64 px small-circle sheet (Blizzard, MattUI, MidUI).
local bigCoords = { TANK = { 0, 67 / 256, 67 / 256, 134 / 256 }, HEALER = { 67 / 256, 134 / 256, 0, 67 / 256 },
    DAMAGER = { 67 / 256, 134 / 256, 67 / 256, 134 / 256 } }
local smallCoords = { TANK = { 0, 19 / 64, 22 / 64, 41 / 64 }, HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 } }
RF.roleSets = {
    { "blizzard2", "Blizzard", sheet = "Blizzard2_ROLES", coords = bigCoords },
    { "blizzard", L("Blizzard (круглые)", "Blizzard (round)"), sheet = "Blizzard_ROLES", coords = smallCoords },
    { "blizzard3", "Blizzard 3", prefix = "Blizzard3_" },
    { "blizzard4", "Blizzard 4", prefix = "Blizzard4_" },
    { "ffxiv", "FFXIV", prefix = "FFXIV_" },
    { "miirgui", "MiirGui", prefix = "MiirGui_" },
    { "mattui", "MattUI", sheet = "MattUI_ROLES", coords = smallCoords },
    { "midui", "MidUI", sheet = "MidUI-Roles", coords = smallCoords },
}
local roleSetById = {}
for _, set in ipairs(RF.roleSets) do roleSetById[set[1]] = set end

-- Puts the icon of `role` from the chosen set on a texture; false when there is nothing to show.
function RF.SetRoleTexture(texture, role, setId)
    local set = roleSetById[setId] or RF.roleSets[1]
    if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then return false end
    if set.prefix then
        texture:SetTexture(ROLE_PATH .. set.prefix .. role)
        texture:SetTexCoord(0, 1, 0, 1)
    else
        local c = set.coords[role]
        texture:SetTexture(ROLE_PATH .. set.sheet)
        texture:SetTexCoord(c[1], c[2], c[3], c[4])
    end
    return true
end

function RF.UpdateRole(deco, forcedRole)
    local settings = cfg()
    local role = forcedRole or Suite.UnitRole(deco.unit)
    if not (settings.rfEnabled and settings.rfRoleIcon) or not role
        or (role == "DAMAGER" and settings.rfRoleHideDamager) then
        deco.role:Hide()
        deco.roleKey = nil
        return
    end
    local key = role .. settings.rfRoleSet .. settings.rfRoleSize .. settings.rfRoleAnchor .. settings.rfRoleX .. settings.rfRoleY
    if deco.roleKey ~= key then
        deco.roleKey = key
        RF.SetRoleTexture(deco.role, role, settings.rfRoleSet)
        deco.role:SetWidth(settings.rfRoleSize)
        deco.role:SetHeight(settings.rfRoleSize)
        deco.role:ClearAllPoints()
        local point = settings.rfRoleAnchor
        deco.role:SetPoint(point, deco.health or deco.frame, point, settings.rfRoleX, settings.rfRoleY)
    end
    deco.role:Show()
end

---------------------------------------------------------------------------------------------------
-- Sorting by role: the client's flow container sorts its unit tokens with container.flowSortFunc
-- (Blizzard CompactRaidFrameContainer). Our function puts tanks, healers and damage dealers in the
-- chosen order and keeps the client's own order inside each role. Protected layout: out of combat.
---------------------------------------------------------------------------------------------------
local orders = { THD = { TANK = 1, HEALER = 2, DAMAGER = 3 }, HTD = { HEALER = 1, TANK = 2, DAMAGER = 3 },
    TDH = { TANK = 1, DAMAGER = 2, HEALER = 3 } }
local sortOwners = {}   -- container -> its original flowSortFunc (false when it had none)

local function unitIndex(unit)
    if unit == "player" then return 0 end
    return tonumber(tostring(unit):match("(%d+)$")) or 99
end

local function makeRoleSort(original)
    return function(a, b)
        local rank = orders[cfg().rfRoleOrder] or orders.THD
        local ra, rb = rank[Suite.UnitRole(a) or ""] or 4, rank[Suite.UnitRole(b) or ""] or 4
        if ra ~= rb then return ra < rb end
        if original then return original(a, b) end
        local ia, ib = unitIndex(a), unitIndex(b)
        if ia ~= ib then return ia < ib end
        return tostring(a) < tostring(b)
    end
end
RF.MakeRoleSort = makeRoleSort

local function relayout(container)
    if type(_G.CompactRaidFrameContainer_TryUpdate) == "function" then
        CompactRaidFrameContainer_TryUpdate(container)
    elseif type(_G.CompactRaidFrameContainer_LayoutFrames) == "function" then
        CompactRaidFrameContainer_LayoutFrames(container)
    end
end

-- Returns true when the client supports a sort function on at least one container.
function RF.ApplySort(onlyIfActive)
    local settings = cfg()
    local want = settings.rfEnabled and settings.rfRoleSort
    if onlyIfActive and not want then return end
    if InCombatLockdown() then
        ui.RunOutOfCombat("rfRoleSort", function() RF.ApplySort() end)
        return
    end
    local supported = false
    for _, container in ipairs({ _G.CompactRaidFrameContainer, _G.CompactPartyFrame }) do
        if container and (container.flowSortFunc ~= nil or sortOwners[container] ~= nil
            or type(_G.CompactRaidFrameContainer_SetFlowSortFunction) == "function") then
            supported = true
            if want then
                if sortOwners[container] == nil then
                    local current = container.flowSortFunc
                    sortOwners[container] = type(current) == "function" and current or false
                end
                local sorter = makeRoleSort(sortOwners[container] or nil)
                if container == _G.CompactRaidFrameContainer and type(_G.CompactRaidFrameContainer_SetFlowSortFunction) == "function" then
                    CompactRaidFrameContainer_SetFlowSortFunction(container, sorter)
                else
                    container.flowSortFunc = sorter
                    relayout(container)
                end
            elseif sortOwners[container] ~= nil then
                local original = sortOwners[container] or nil
                sortOwners[container] = nil
                if container == _G.CompactRaidFrameContainer and original
                    and type(_G.CompactRaidFrameContainer_SetFlowSortFunction) == "function" then
                    CompactRaidFrameContainer_SetFlowSortFunction(container, original)
                else
                    container.flowSortFunc = original
                    relayout(container)
                end
            end
        end
    end
    RF.sortSupported = supported
    return supported
end

---------------------------------------------------------------------------------------------------
-- Live apply from the options
---------------------------------------------------------------------------------------------------
RF.styleVersion = 0
function RF.Apply()
    RF.styleVersion = RF.styleVersion + 1
    rebuildIndicatorLookup()
    RF.ApplySort()
    for _, deco in ipairs(ordered) do
        for _, widget in pairs(deco.indicators) do widget.stamp = nil end
        applyStyle(deco)
        deco.unitDirty = true
    end
    anyDirty = true
    for _, preview in ipairs(RF.previews or {}) do preview:Refresh() end
end

function RF.ApplyLayout()
    if cfg().rfMoveContainer then RF.AttachContainer() end
end

---------------------------------------------------------------------------------------------------
-- Visibility: "client" leaves the frames to the client, "always" keeps them shown (also solo or in a
-- party), "hidden" turns them off. Show/Hide of the protected containers happens only out of combat.
---------------------------------------------------------------------------------------------------
local visibilityForced = {}   -- frame -> its shown state before ForeverUI first forced it
local visibilityApplying

local function desiredVisibility(frame)
    local settings = cfg()
    local party, raid = settings.rfPartyShow or "client", settings.rfRaidShow or "client"
    local inRaid = (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
    local partyFrame = _G.CompactPartyFrame
    if frame == partyFrame then
        if party == "hidden" then return false end
        if party == "always" and not inRaid then return true end
        return nil
    elseif frame == _G.CompactRaidFrameContainer then
        if raid == "always" then return true end
        if inRaid or partyFrame then
            if raid == "hidden" then return false end
            return nil
        end
        -- No separate party frame: outside a raid the container shows the party.
        if party == "hidden" then return false end
        if party == "always" then return true end
        return nil
    elseif frame == _G.CompactRaidFrameManager then
        if party == "hidden" and raid == "hidden" then return false end
        return nil
    end
end

local function clientVisibilityUpdate()
    local manager = _G.CompactRaidFrameManager
    for _, name in ipairs({ "CompactRaidFrameManager_UpdateShown", "CompactRaidFrameManager_UpdateContainerVisibility" }) do
        if manager and type(_G[name]) == "function" then pcall(_G[name], manager) end
    end
    if type(_G.CompactPartyFrame_UpdateVisibility) == "function" then pcall(_G.CompactPartyFrame_UpdateVisibility) end
    if _G.CompactRaidFrameContainer and type(_G.CompactRaidFrameContainer_TryUpdate) == "function" then
        pcall(_G.CompactRaidFrameContainer_TryUpdate, _G.CompactRaidFrameContainer)
    end
end

local function visibilityFrames()
    return { _G.CompactRaidFrameContainer, _G.CompactPartyFrame, _G.CompactRaidFrameManager }
end

local visibilityParent = {}  -- frame -> its own parent, while a hidden ancestor forced it onto UIParent
local forcedMembers = {}     -- party member button -> true while ForeverUI shows it outside a group

-- A frame can be shown and still invisible when an ancestor is hidden (the client hides its party frame
-- holder outside a group). Then it is lifted onto UIParent; the old parent comes back on release.
local function revealChain(frame)
    if not frame:IsShown() or frame:IsVisible() then return end
    local parent = frame:GetParent()
    if parent and parent ~= UIParent and not visibilityParent[frame] then
        visibilityParent[frame] = { parent = parent, scale = frame:GetScale() }
        local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        frame:SetParent(UIParent)
        frame:SetScale(scale)
    end
end

local function restoreParent(frame)
    local saved = visibilityParent[frame]
    if not saved then return end
    visibilityParent[frame] = nil
    frame:SetParent(saved.parent)
    frame:SetScale(saved.scale or 1)
end

local function setMemberUnit(member, unit)
    if type(_G.CompactUnitFrame_SetUnit) == "function" then
        pcall(_G.CompactUnitFrame_SetUnit, member, unit)
    else
        member.unit, member.displayedUnit = unit, unit
    end
    if member.SetAttribute then member:SetAttribute("unit", unit) end
end

-- Outside a group the client gives its party buttons no unit, so "always" would show an empty frame:
-- the first button gets the player.
local function fillPartyMembers(show)
    local solo = (GetNumRaidMembers and GetNumRaidMembers() or 0) == 0
        and (GetNumPartyMembers and GetNumPartyMembers() or 0) == 0
    local member = _G.CompactPartyFrameMember1
    if show and solo and member then
        local unit = member.GetAttribute and member:GetAttribute("unit") or member.displayedUnit or member.unit
        if unit ~= "player" then setMemberUnit(member, "player") end
        forcedMembers[member] = true
        member:Show()
        if not member.foreverVisibilityHooked then
            member.foreverVisibilityHooked = true
            member:HookScript("OnHide", function(self)
                if forcedMembers[self] and not visibilityApplying then
                    ui.RunOutOfCombat("rfVisibility", RF.ApplyVisibility)
                end
            end)
        end
        if type(_G.CompactUnitFrame_UpdateAll) == "function" then pcall(_G.CompactUnitFrame_UpdateAll, member) end
    else
        for frame in pairs(forcedMembers) do
            forcedMembers[frame] = nil
            if solo then frame:Hide() end
        end
    end
end

function RF.ApplyVisibility()
    if InCombatLockdown() then
        ui.RunOutOfCombat("rfVisibility", RF.ApplyVisibility)
        return
    end
    visibilityApplying = true
    local released = false
    for _, frame in ipairs(visibilityFrames()) do
        if frame then
            if not frame.foreverVisibilityHooked then
                frame.foreverVisibilityHooked = true
                frame:HookScript("OnShow", function(self)
                    if not visibilityApplying and desiredVisibility(self) == false then
                        ui.RunOutOfCombat("rfVisibility", RF.ApplyVisibility)
                    end
                end)
                frame:HookScript("OnHide", function(self)
                    if not visibilityApplying and desiredVisibility(self) == true then
                        ui.RunOutOfCombat("rfVisibility", RF.ApplyVisibility)
                    end
                end)
            end
            local want = desiredVisibility(frame)
            if want ~= true then restoreParent(frame) end
            if want == nil then
                if visibilityForced[frame] ~= nil then
                    ui.Widgets.SetVisible(frame, visibilityForced[frame])
                    visibilityForced[frame] = nil
                    released = true
                end
            else
                if visibilityForced[frame] == nil then visibilityForced[frame] = frame:IsShown() and true or false end
                ui.Widgets.SetVisible(frame, want)
            end
        end
    end
    -- Hand the frames back: let the client decide again what it shows.
    if released then clientVisibilityUpdate() end
    for _, frame in ipairs(visibilityFrames()) do
        local want = frame and desiredVisibility(frame)
        if want ~= nil then ui.Widgets.SetVisible(frame, want) end
    end
    local party, container = _G.CompactPartyFrame, _G.CompactRaidFrameContainer
    if container and desiredVisibility(container) == true and type(_G.CompactRaidFrameContainer_TryUpdate) == "function" then
        pcall(_G.CompactRaidFrameContainer_TryUpdate, container)
    end
    fillPartyMembers(party ~= nil and desiredVisibility(party) == true)
    for _, frame in ipairs(visibilityFrames()) do
        if frame and desiredVisibility(frame) == true then revealChain(frame) end
    end
    visibilityApplying = nil
    if (container and desiredVisibility(container) == true) or (party and desiredVisibility(party) == true) then
        RF.Scan()
        for _, deco in ipairs(ordered) do deco.unitDirty = true end
        RF.MarkDirty()
    end
end

local visibilityEvents = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE" }) do
    visibilityEvents:RegisterEvent(event)
end
visibilityEvents:SetScript("OnEvent", function() RF.ApplyVisibility() end)

ui.RegisterCallback("SuiteProfileChanged", function()
    if ui.NormalizeModule then ui.NormalizeModule("raidframes") end
    RF.Apply()
    RF.ApplyLayout()
    RF.ApplyVisibility()
end, "RaidFramesProfile")
ui.RegisterCallback("SuiteSpellsChanged", function()
    for _, deco in ipairs(ordered) do deco.auraDirty = true end
    anyDirty = true
end, "RaidFramesSpells")

---------------------------------------------------------------------------------------------------
-- Live preview for the options page: a mock unit button decorated by the same code
---------------------------------------------------------------------------------------------------
-- Each variant shows one state clearly instead of everything on one frame.
-- The three preview frames differ only in their bars (health, shield, incoming heals, threat, role);
-- indicators, buffs and debuffs are the same set on all three, built from the current settings
-- (previewAuras), so every change shows the same way on each frame.
local previewVariants = {
    tank = { name = L("Танк", "Tank"), class = "WARRIOR", health = 0.92, heal = 0, absorb = 0.3, role = "TANK",
        threat = 3, deficit = "-1.2k" },
    healer = { name = L("Лекарь", "Healer"), class = "PRIEST", health = 0.62, heal = 0.15, absorb = 0, role = "HEALER",
        deficit = "-9.5k" },
    dps = { name = L("Боец", "Damage"), class = "MAGE", health = 0.34, heal = 0.1, absorb = 0.08, role = "DAMAGER",
        deficit = "-16.8k" },
}
RF.previewOrder = { "tank", "healer", "dps" }
RF.previews = {}

local PREVIEW_DISPEL = "Curse"   -- the preview pretends the player removes curses, whatever the real class
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
-- Debuffs shown when nothing else fills the row: a curse the "player" can dispel, a poison and an untyped one.
local previewDebuffs = {
    { name = "Curse of Tongues", icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", type = "Curse", duration = 20, left = 14 },
    { name = "Poison", icon = "Interface\\Icons\\Ability_Creature_Poison_06", count = 3, type = "Poison", duration = 12, left = 4 },
    { name = "Rend", icon = "Interface\\Icons\\Ability_Gouge", duration = 15, left = 9 },
}

local function demoAura(spell, harmful, left, extra)
    local name, icon = Suite.SpellInfo(spell)
    local aura = { name = name or tostring(spell), icon = icon or QUESTION, id = type(spell) == "number" and spell or nil,
        count = 0, duration = 15, left = left or 8, harmful = harmful }
    for k, v in pairs(extra or {}) do aura[k] = v end
    return aura
end

-- One aura per enabled indicator (its first spell; "missing" indicators stay empty so they show), then
-- the first tracked buffs that no indicator claims, then the demo debuffs.
local function previewAuras()
    local settings = cfg()
    local buffs, debuffs, used = {}, {}, {}
    for i, entry in ipairs(settings.indicators or {}) do
        local spell = Suite.ParseSpellList(entry.spell)[1]
        if entry.enabled and entry.kind ~= "missing" and spell then
            local aura = demoAura(spell, entry.harmful, 4 + (i % 5) * 2, entry.stacks and { count = 3 } or nil)
            local target = entry.harmful and debuffs or buffs
            target[#target + 1] = aura
            used[aura.name] = true
        end
    end
    local tracked = 0
    for _, spell in ipairs(Suite.ParseSpellList(settings.rfBuffTrack or "")) do
        if tracked >= (settings.rfBuffMax or 3) then break end
        local name = Suite.SpellInfo(spell) or tostring(spell)
        if not used[name] then
            buffs[#buffs + 1] = demoAura(spell, false, 6 + tracked * 3)
            used[name] = true
            tracked = tracked + 1
        end
    end
    for _, aura in ipairs(previewDebuffs) do debuffs[#debuffs + 1] = aura end
    return buffs, debuffs
end

local function demoAuras(list, now)
    local result = {}
    for i, aura in ipairs(list) do
        result[i] = { name = aura.name, icon = aura.icon, count = aura.count or 0, type = aura.type, id = aura.id,
            duration = aura.duration, expiration = now + (aura.left or 0), mine = true, raid = true, caster = "player" }
    end
    return result
end

-- Live preview for the options page: a mock unit button decorated by the same code.
function RF.BuildPreview(parent, width, height, variant)
    width, height = width or 120, height or 48
    local data = previewVariants[variant or "healer"] or previewVariants.healer
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame.healthBar = CreateFrame("StatusBar", nil, frame)
    frame.healthBar:SetPoint("TOPLEFT", 1, -1)
    frame.healthBar:SetWidth(width - 2)
    frame.healthBar:SetHeight(height - 9)
    frame.healthBar:SetMinMaxValues(0, 1)
    frame.healthBar:SetValue(data.health)
    frame.powerBar = CreateFrame("StatusBar", nil, frame)
    frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -1)
    frame.powerBar:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.powerBar:SetMinMaxValues(0, 1)
    frame.powerBar:SetValue(0.8)
    frame.powerBar:SetStatusBarColor(0, 0.45, 1)
    local deco = createDeco(frame)
    deco.preview = true
    frame.deco = deco
    -- The name sits in the middle of the bar, clear of the corner indicators and icons.
    local name = deco.layer:CreateFontString(nil, "OVERLAY")
    name:SetFont(Suite.art.font, 11, "OUTLINE")
    name:SetPoint("LEFT", frame.healthBar, "LEFT", 6, 1)
    name:SetText(data.name)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[data.class]
    if color then name:SetTextColor(color.r, color.g, color.b) end
    applyStyle(deco)
    function frame:Refresh()
        applyStyle(deco)
        local settings = cfg()
        local mode = settings.rfHealthColorMode
        local bar = frame.healthBar
        if mode == "class" and color then
            bar:SetStatusBarColor(color.r, color.g, color.b)
        elseif mode == "custom" then
            local c = settings.rfHealthColor
            bar:SetStatusBarColor(c[1], c[2], c[3])
        elseif mode == "gradient" then
            local f = data.health
            if f > 0.5 then bar:SetStatusBarColor((1 - f) * 2, 1, 0) else bar:SetStatusBarColor(1, f * 2, 0) end
        else
            bar:SetStatusBarColor(0.1, 0.75, 0.2)
        end
        RF.DrawBars(deco, data.health, data.heal, data.absorb)
        local now = GetTime()
        local buffSet, debuffSet = previewAuras()
        local buffs, debuffs = demoAuras(buffSet, now), demoAuras(debuffSet, now)
        deco.unit = "player"
        drawIndicators(deco, buffs, debuffs, now)
        local canDispel = Suite.CanDispel
        Suite.CanDispel = function(kind) return kind == PREVIEW_DISPEL end
        RF.DrawAuras(deco, buffs, debuffs, now)
        Suite.CanDispel = canDispel
        if data.threat and settings.rfEnabled and settings.rfThreat then
            deco.border:SetBackdropBorderColor(1, 0.15, 0.1, 1)
            deco.border:Show()
        else
            deco.border:Hide()
        end
        RF.UpdateRole(deco, data.role)
        local text = settings.rfDeficitText
        deco.text:SetText(text == "percent" and (math.floor(data.health * 100) .. "%")
            or text == "current" and Suite.ShortNumber(data.health * 25000) or data.deficit)
        Suite.Shown(deco.text, settings.rfEnabled and text ~= "none")
    end
    frame:Refresh()
    RF.previews[#RF.previews + 1] = frame
    RF.preview = frame
    return frame
end

---------------------------------------------------------------------------------------------------
-- Diagnostics: /fuiraid lists the client buttons found and the fields this module uses
---------------------------------------------------------------------------------------------------
SLASH_FOREVERUIRAID1 = "/fuiraid"
SlashCmdList.FOREVERUIRAID = function(input)
    RF.Scan()
    if (input or ""):lower():match("aura") then
        -- What each frame believes: its unit, whose GUID that is, and which auras it draws.
        for _, deco in ipairs(ordered) do
            local shown = {}
            for _, widget in pairs(deco.indicators) do
                if widget:IsShown() and widget.stamp then shown[#shown + 1] = "[" .. (widget.stamp.name or "?") .. "]" end
            end
            for _, icon in ipairs(deco.buffs) do
                if icon:IsShown() then shown[#shown + 1] = tostring(icon.texture:GetTexture() or "?"):match("[^\\]+$") end
            end
            local unit = deco.unit or "-"
            ui.Print(("%s %s=%s %s: %s"):format(deco.frame:GetName() or "?", unit, UnitName(unit) or "-",
                deco.guid == UnitGUID(unit) and "ok" or "GUID!", table.concat(shown, " ")))
        end
        return
    end
    ui.Print(format(L("Найдено кнопок рейда/группы: %d", "Raid/party buttons found: %d"), #ordered))
    local deco = ordered[1]
    if deco then
        local frame = deco.frame
        local fields = {}
        for _, field in ipairs({ "healthBar", "powerBar", "background", "totalAbsorb", "totalAbsorbOverlay",
            "overAbsorbGlow", "myHealPrediction", "otherHealPrediction", "buffFrames", "debuffFrames",
            "dispelDebuffFrames", "aggroHighlight", "selectionHighlight", "name", "unit", "displayedUnit" }) do
            if frame[field] ~= nil then fields[#fields + 1] = field end
        end
        ui.Print((frame:GetName() or "?") .. ": " .. table.concat(fields, ", "))
    end
    local hooks = {}
    for _, name in ipairs({ "CompactUnitFrame_UpdateAll", "CompactUnitFrame_SetUpFrame", "CompactUnitFrame_UpdateHealPrediction",
        "CompactUnitFrame_UpdateInRange", "CompactUnitFrame_UpdateAuras", "CompactRaidFrameContainer_LayoutFrames" }) do
        if type(_G[name]) == "function" then hooks[#hooks + 1] = name end
    end
    ui.Print(L("Хуки: ", "Hooks: ") .. (#hooks > 0 and table.concat(hooks, ", ") or "-"))
    local container = _G.CompactRaidFrameContainer
    ui.Print(L("Сортировка по ролям: ", "Role sorting: ") .. ((container and (container.flowSortFunc ~= nil
        or type(_G.CompactRaidFrameContainer_SetFlowSortFunction) == "function")) and L("поддерживается", "supported")
        or L("клиент не даёт функцию сортировки", "the client exposes no sort function")))
    -- Visibility in ASCII only: some client chat fonts print Cyrillic as "?".
    local settings = cfg()
    ui.Print(("Visibility: party=%s raid=%s group=%d/%d"):format(tostring(settings.rfPartyShow),
        tostring(settings.rfRaidShow), GetNumPartyMembers and GetNumPartyMembers() or -1,
        GetNumRaidMembers and GetNumRaidMembers() or -1))
    local function describe(frame)
        local parent = frame:GetParent()
        return ("shown=%d visible=%d alpha=%.2f parent=%s%s"):format(frame:IsShown() and 1 or 0,
            frame:IsVisible() and 1 or 0, frame:GetAlpha() or 0, parent and (parent:GetName() or "?") or "-",
            parent and not parent:IsVisible() and "(hidden)" or "")
    end
    for _, name in ipairs({ "CompactRaidFrameContainer", "CompactPartyFrame", "CompactRaidFrameManager",
        "CompactPartyFrameMember1", "CompactPartyFrameMember2", "CompactRaidFrame1" }) do
        local frame = _G[name]
        local unit = frame and (frame.GetAttribute and frame:GetAttribute("unit") or frame.displayedUnit or frame.unit)
        ui.Print(name .. ": " .. (frame and (describe(frame) .. " unit=" .. tostring(unit)) or "-"))
    end
    ui.Print(L("Источник поглощений: ", "Absorb source: ") .. (UnitGetTotalAbsorbs and "API" or (deco and deco.clientAbsorb and "client bar") or "-")
        .. L(", входящее лечение: ", ", incoming heals: ") .. (RF.healSource or "-"))
end
