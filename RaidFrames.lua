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
local floor, max, min, abs, format = math.floor, math.max, math.min, math.abs, string.format
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
    rfMoveContainer = true, rfHandle = true, rfPetsUnder = true, rfGrowth = "center",
    rfPartyShow = "client", rfRaidShow = "client",
    rfRoleIcon = true, rfRoleSet = "blizzard2", rfRoleSize = 12, rfRoleAnchor = "TOPLEFT", rfRoleX = 2, rfRoleY = -2,
    rfRoleHideDamager = false, rfRoleHideClient = true, rfRoleSort = false, rfRoleOrder = "THD",
    -- Highlight of the button under the cursor and of the player's target
    rfHover = true, rfHoverStyle = "both", rfHoverColor = { 1, 1, 1, 0.85 },
    rfTarget = true, rfTargetClass = false, rfTargetColor = { 1, 0.82, 0.3, 1 }, rfTargetSize = 2,
    rfTargetHideClient = true,
    -- Own name text (the client's one stays, invisible: unitOf reads it)
    rfNameCustom = true, rfNameFont = 1, rfNameSize = 11, rfNameOutline = "OUTLINE", rfNameShadow = false,
    rfNameMaxLetters = 0, rfNameFit = true, rfNameColorMode = "custom", rfNameColor = { 1, 1, 1 },
    rfNameAnchor = "CENTER", rfNameX = 0, rfNameY = 1,
    -- Drinking indicator: the label "Пьёт - - -" while the unit drinks out of combat (mana users only by default)
    rfDrink = true, rfDrinkStyle = "text", rfDrinkManaOnly = true, rfDrinkAnchor = "BOTTOMLEFT", rfDrinkX = 2, rfDrinkY = 2,
    rfDrinkScale = 1,
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
    -- The drink mug became the label "Пьёт - - -" bottom left: the stored old defaults move along.
    if part.rfDrinkStyle == "icon" then part.rfDrinkStyle = "text" end
    if part.rfDrinkAnchor == "TOP" and (part.rfDrinkX or 0) == 0 and part.rfDrinkY == -2 then
        part.rfDrinkAnchor, part.rfDrinkX, part.rfDrinkY = "BOTTOMLEFT", 2, 2
    end
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

---------------------------------------------------------------------------------------------------
-- Settings per group type: "party" (5), "raid10" and "raid25" are tuned apart. The party settings are
-- the "raid" part of the suite profile itself (old profiles keep working); the raid ones live in
-- raid.kinds[kind] and start as a copy of the party ones. A few keys describe the module or the
-- client frames as a whole and are shared by all three (RF.sharedKeys).
---------------------------------------------------------------------------------------------------
RF.layoutKinds = { "party", "raid10", "raid25" }
RF.kindLabels = { party = L("Группа (5)", "Party (5)"), raid10 = L("Рейд (10)", "Raid (10)"),
    raid25 = L("Рейд (25)", "Raid (25)") }
RF.sharedKeys = { rfEnabled = true, rfPartyShow = true, rfRaidShow = true, rfMoveContainer = true, rfHandle = true,
    rfGrowth = true, kinds = true }
local sharedKeys = RF.sharedKeys

-- The group type the frames follow now: a raid of more than 10 is a raid of 25.
function RF.LiveKind()
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raid > 10 then return "raid25" end
    if raid > 0 then return "raid10" end
    return "party"
end

-- The settings shown: the one picked on the options page while it is open, else the live one.
function RF.ViewKind() return RF.editKind or RF.LiveKind() end

local function validKind(kind) return kind == "party" or kind == "raid10" or kind == "raid25" end
RF.ValidKind = validKind

local function copyOwn(source)
    local out = {}
    for key, value in pairs(source) do
        if not sharedKeys[key] then out[key] = Suite.Copy(value) end
    end
    return out
end

local filled = setmetatable({}, { __mode = "k" })
local proxies = setmetatable({}, { __mode = "k" })

-- Raw table of one group type (no shared keys in it, except for the party one, which is the base).
function RF.KindStore(kind)
    local base = Suite.Part("raid")
    if kind ~= "raid10" and kind ~= "raid25" then return base, base end
    if type(base.kinds) ~= "table" then base.kinds = {} end
    local store = base.kinds[kind]
    if type(store) ~= "table" then
        store = copyOwn(base)
        base.kinds[kind] = store
    end
    if not filled[store] then
        filled[store] = true
        for key, value in pairs(DEFAULTS) do
            if store[key] == nil and not sharedKeys[key] then store[key] = Suite.Copy(value) end
        end
        if type(store.indicators) ~= "table" then store.indicators = Suite.Copy(base.indicators or {}) end
    end
    return store, base
end

-- Settings table of one group type. Raid types get a proxy: shared keys go to the base table.
function RF.KindSettings(kind)
    local store, base = RF.KindStore(kind)
    if store == base then return base end
    local proxy = proxies[store]
    if not proxy then
        proxy = setmetatable({}, {
            __index = function(_, key)
                if sharedKeys[key] then return base[key] end
                return store[key]
            end,
            __newindex = function(_, key, value)
                if sharedKeys[key] then base[key] = value else store[key] = value end
            end,
        })
        proxies[store] = proxy
    end
    return proxy
end

local function cfg() return RF.KindSettings(RF.ViewKind()) end
RF.Settings = cfg

-- Copies every own setting (bars, auras, indicators, name, ...) of one group type into another.
function RF.CopyKind(source, target)
    if not validKind(source) or not validKind(target) or source == target then return false end
    local from = RF.KindStore(source)
    local data = copyOwn(from)
    local base = Suite.Part("raid")
    if target == "party" then
        for key in pairs(copyOwn(base)) do base[key] = nil end
        for key, value in pairs(data) do base[key] = value end
    else
        if type(base.kinds) ~= "table" then base.kinds = {} end
        base.kinds[target] = data
    end
    if RF.SettingsSwitched then RF.SettingsSwitched(true) end
    return true
end

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

    deco.name = layer:CreateFontString(nil, "OVERLAY")
    deco.name:Hide()

    -- Drinking: a text label "Пьёт - - -" (or "Пьёт 42%"), bottom left by default.
    deco.drink = CreateFrame("Frame", nil, layer)
    deco.drink:EnableMouse(false)
    deco.drink:SetFrameLevel(layer:GetFrameLevel() + 2)
    deco.drink:Hide()
    -- Behind it a soft dark gradient from the start of the label to its end.
    deco.drinkBack = deco.drink:CreateTexture(nil, "BACKGROUND")
    deco.drinkBack:SetTexture(white)
    deco.drinkBack:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0.75, 0, 0, 0, 0)
    deco.drinkBack:SetAllPoints(deco.drink)
    deco.drinkText = deco.drink:CreateFontString(nil, "OVERLAY")
    deco.drinkText:SetPoint("LEFT", deco.drink, "LEFT", 2, 0)

    -- Hover: a light wash over the button and a 1 px edge. Target: a solid edge inside the button
    -- (the threat border sits 1 px outside, so both stay readable together).
    deco.hoverFill = layer:CreateTexture(nil, "ARTWORK")
    deco.hoverFill:SetAllPoints(frame)
    deco.hoverFill:SetTexture(white)
    deco.hoverFill:SetBlendMode("ADD")
    deco.hoverFill:Hide()
    deco.hoverEdge = CreateFrame("Frame", nil, layer)
    deco.hoverEdge:SetAllPoints(frame)
    deco.hoverEdge:EnableMouse(false)
    deco.hoverEdge:Hide()
    deco.target = CreateFrame("Frame", nil, layer)
    deco.target:SetAllPoints(frame)
    deco.target:EnableMouse(false)
    deco.target:Hide()
    return deco
end

---------------------------------------------------------------------------------------------------
-- Name text, hover highlight and target border
---------------------------------------------------------------------------------------------------
local function utf8Cut(text, limit)
    if not limit or limit <= 0 then return text end
    local count, i = 0, 1
    while i <= #text do
        count = count + 1
        if count > limit then return text:sub(1, i - 1) end
        local byte = text:byte(i)
        i = i + (byte >= 240 and 4 or byte >= 224 and 3 or byte >= 192 and 2 or 1)
    end
    return text
end
RF.CutName = utf8Cut

-- Drops whole UTF-8 characters from the end until the string fits `width`.
local function fitName(label, text, width)
    label:SetText(text)
    local last = #text
    while last > 0 and label:GetStringWidth() > width do
        while last > 1 and text:byte(last) >= 128 and text:byte(last) < 192 do last = last - 1 end
        last = last - 1
        label:SetText(text:sub(1, last))
    end
end

local justifyOf = { TOPLEFT = "LEFT", LEFT = "LEFT", BOTTOMLEFT = "LEFT", TOPRIGHT = "RIGHT", RIGHT = "RIGHT",
    BOTTOMRIGHT = "RIGHT" }

local function styleName(deco, settings)
    local label = deco.name
    local size, flags = settings.rfNameSize, settings.rfNameOutline or ""
    local font = ui.MediaPath and ui.MediaPath("font", settings.rfNameFont, true) or Suite.art.font
    if not label:SetFont(font, size, flags) then label:SetFont(Suite.art.font, size, flags) end
    if settings.rfNameShadow then
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
    else
        label:SetShadowOffset(0, 0)
    end
    local point = settings.rfNameAnchor
    label:ClearAllPoints()
    label:SetPoint(point, deco.health or deco.frame, point, settings.rfNameX, settings.rfNameY)
    label:SetJustifyH(justifyOf[point] or "CENTER")
    deco.nameKey = nil
end

local function updateName(deco)
    deco.nameDirty = nil
    local settings = cfg()
    local own = settings.rfEnabled and settings.rfNameCustom
    local client = deco.frame.name
    if type(client) == "table" and client.SetAlpha and (own or deco.clientNameHidden) then
        client:SetAlpha(own and 0 or 1)
        deco.clientNameHidden = own or nil
    end
    local label = deco.name
    if not own then
        label:Hide()
        return
    end
    local unit = deco.unit
    local text = deco.previewName or (unit and UnitExists(unit) and UnitName(unit)) or shownName(deco.frame) or ""
    local width = settings.rfNameFit and max(8, (deco.frame:GetWidth() or 0) - 6) or 0
    local key = text .. "|" .. settings.rfNameMaxLetters .. "|" .. width
    if deco.nameKey ~= key then
        deco.nameKey = key
        text = utf8Cut(text, settings.rfNameMaxLetters)
        if width > 0 then fitName(label, text, width) else label:SetText(text) end
    end
    local color
    if settings.rfNameColorMode == "class" then
        local class = deco.previewClass
        if not class and unit and UnitExists(unit) then
            local _, token = UnitClass(unit)
            class = token
        end
        color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    end
    if color then
        label:SetTextColor(color.r, color.g, color.b)
    else
        local c = settings.rfNameColor
        label:SetTextColor(c[1], c[2], c[3])
    end
    label:Show()
end

local function updateTarget(deco)
    deco.targetDirty = nil
    local settings = cfg()
    local unit = deco.unit
    local on = settings.rfEnabled and settings.rfTarget
    if on then
        if deco.preview then
            on = deco.previewTarget
        else
            on = unit and UnitExists(unit) and UnitExists("target") and UnitIsUnit(unit, "target")
        end
    end
    if not on then
        deco.target:Hide()
        return
    end
    local c = settings.rfTargetColor
    local r, g, b = c[1], c[2], c[3]
    if settings.rfTargetClass then
        local class = deco.previewClass
        if not class and unit then
            local _, token = UnitClass(unit)
            class = token
        end
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then r, g, b = color.r, color.g, color.b end
    end
    deco.target:SetBackdropBorderColor(r, g, b, c[4] or 1)
    deco.target:Show()
end

local function drawHover(deco, on)
    local settings = cfg()
    local show = on and settings.rfEnabled and settings.rfHover
    local style = settings.rfHoverStyle
    Suite.Shown(deco.hoverEdge, show and style ~= "fill" or false)
    Suite.Shown(deco.hoverFill, show and style ~= "border" or false)
end

-- Only one button is highlighted: entering the next one clears the previous even if its OnLeave
-- never came (fast moves between neighbours, a grid rebuilt under the cursor).
local hoveredDeco
local function setHover(deco, on)
    if on then
        if hoveredDeco and hoveredDeco ~= deco then drawHover(hoveredDeco, false) end
        hoveredDeco = deco
    elseif hoveredDeco == deco then
        hoveredDeco = nil
    end
    drawHover(deco, on)
end
RF.SetHover = setHover

local function hookClientRegion(deco, region)
    if not region or region.foreverHooked then return end
    region.foreverHooked = true
    local function changed() deco.healthDirty = true RF.MarkDirty() end
    if region.SetWidth then hooksecurefunc(region, "SetWidth", changed) end
    if region.Show then hooksecurefunc(region, "Show", changed) end
    if region.Hide then hooksecurefunc(region, "Hide", changed) end
end

local applyStyle -- forward

-- Path of the texture the health bar draws now (what the client reports back after SetStatusBarTexture).
function RF.BarTexture(deco)
    local bar = deco.health
    if not bar or type(bar.GetStatusBarTexture) ~= "function" then return nil end
    local texture = bar:GetStatusBarTexture()
    if type(texture) == "table" and type(texture.GetTexture) == "function" then return texture:GetTexture() end
    if type(texture) == "string" then return texture end
    return nil
end

function RF.Restyle(deco)
    applyStyle(deco)
    deco.unitDirty = true
    RF.MarkDirty()
end

decorate = function(frame)
    local deco = createDeco(frame)
    decos[frame] = deco
    ordered[#ordered + 1] = deco
    hookClientRegion(deco, deco.clientAbsorb)
    for _, region in ipairs(deco.clientHeals) do hookClientRegion(deco, region) end
    frame:HookScript("OnShow", function() deco.unitDirty = true RF.MarkDirty() end)
    frame:HookScript("OnEnter", function() setHover(deco, true) end)
    frame:HookScript("OnLeave", function() setHover(deco, false) end)
    frame:HookScript("OnHide", function() setHover(deco, false) end)
    if type(frame.name) == "table" and frame.name.SetText then
        hooksecurefunc(frame.name, "SetText", function() deco.nameDirty = true RF.MarkDirty() end)
    end
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
    deco.styledTexture = enabled and RF.BarTexture(deco) or nil
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
    styleName(deco, settings)
    local hover = settings.rfHoverColor
    deco.hoverEdge:SetBackdrop({ edgeFile = white, edgeSize = 1 })
    deco.hoverEdge:SetBackdropBorderColor(hover[1], hover[2], hover[3], hover[4] or 1)
    deco.hoverFill:SetVertexColor(hover[1], hover[2], hover[3], (hover[4] or 1) * 0.2)
    deco.target:SetBackdrop({ edgeFile = white, edgeSize = max(1, settings.rfTargetSize) })
    local selection = deco.frame.selectionHighlight
    if selection and selection.SetAlpha then
        selection:SetAlpha(enabled and settings.rfTarget and settings.rfTargetHideClient and 0 or 1)
    end
    drawHover(deco, hoveredDeco == deco)
    deco.nameDirty, deco.targetDirty = true, true
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
    RF.StyleDrink(deco, settings)
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
    deco.nameDirty, deco.targetDirty, deco.drinkDirty = true, true, true
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
            if deco.nameDirty then updateName(deco) end
            if deco.targetDirty then updateTarget(deco) end
            if deco.drinkDirty then RF.UpdateDrink(deco) end
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
        -- A hover highlight whose OnLeave was lost goes away here.
        if hoveredDeco and MouseIsOver and not (hoveredDeco.frame:IsVisible() and MouseIsOver(hoveredDeco.frame)) then
            setHover(hoveredDeco, false)
        end
        local enabled = cfg().rfEnabled
        for _, deco in ipairs(ordered) do
            if deco.frame:IsVisible() then
                if unitOf(deco.frame) ~= deco.unit then
                    deco.unitDirty = true
                    anyDirty = true
                end
                -- The client put its own bar texture back (setup outside the hooked functions): restyle.
                if enabled and deco.styledTexture and RF.BarTexture(deco) ~= deco.styledTexture then
                    RF.Restyle(deco)
                end
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
    "UNIT_PET", "PLAYER_REGEN_ENABLED", "PLAYER_ROLES_ASSIGNED", "PLAYER_TARGET_CHANGED", "UNIT_NAME_UPDATE",
    "UNIT_FLAGS", "UNIT_MANA", "UNIT_MAXMANA", "UNIT_DISPLAYPOWER", "PLAYER_REGEN_DISABLED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" then
        markGUID(unit, "auraDirty")
        markGUID(unit, "drinkDirty")
    elseif event == "UNIT_FLAGS" or event == "UNIT_DISPLAYPOWER" then
        -- UNIT_FLAGS also reports entering combat: the indicator goes at once.
        markGUID(unit, "drinkDirty")
    elseif event == "UNIT_MANA" or event == "UNIT_MAXMANA" then
        if cfg().rfDrinkStyle == "mana" then markGUID(unit, "drinkDirty") end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if RF.templateShown then RF.SetTemplate(false) end
        for _, deco in ipairs(ordered) do deco.drinkDirty = true end
        anyDirty = true
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        markGUID(unit, "healthDirty")
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
        markGUID(unit, "threatDirty")
    elseif event == "UNIT_CONNECTION" then
        markGUID(unit, "healthDirty")
    elseif event == "PLAYER_TARGET_CHANGED" then
        for _, deco in ipairs(ordered) do deco.targetDirty = true end
        anyDirty = true
    elseif event == "UNIT_NAME_UPDATE" then
        markGUID(unit, "nameDirty")
    else
        if not InCombatLockdown() then RF.Scan() end
        for _, deco in ipairs(ordered) do deco.unitDirty = true end
        anyDirty = true
        if event == "PLAYER_LOGIN" then RF.Init() end
        if event == "PLAYER_ENTERING_WORLD" then RF.Rehook() end
        if event ~= "PLAYER_REGEN_ENABLED" and event ~= "UNIT_PET" then RF.ApplySort(true) end
        if event ~= "PLAYER_LOGIN" then RF.LayoutPets() end
    end
end)

---------------------------------------------------------------------------------------------------
-- Hooks into the client compact frame code (only those that exist on this client)
---------------------------------------------------------------------------------------------------
-- Each client function is hooked once. installHooks runs again on PLAYER_ENTERING_WORLD and
-- ADDON_LOADED, so functions the client defines after PLAYER_LOGIN are still hooked.
local hookedGlobals = {}
local function hookGlobal(name, fn)
    if hookedGlobals[name] then return true end
    if type(_G[name]) == "function" then
        hooksecurefunc(name, fn)
        hookedGlobals[name] = true
        return true
    end
end
RF.hookedGlobals = hookedGlobals

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
    -- The client setup (DefaultCompactUnitFrameSetup) puts its own bar textures and background back,
    -- for example when its frame profile loads after login or the group is rebuilt. A frame that is
    -- already decorated gets the ForeverUI style again right after it.
    local function setUp(frame)
        if type(frame) ~= "table" then return end
        local deco = decos[frame]
        if deco then
            RF.Restyle(deco)
        else
            register(frame)
        end
    end
    for _, name in ipairs({ "CompactUnitFrame_SetUpFrame", "DefaultCompactUnitFrameSetup", "DefaultCompactMiniFrameSetup" }) do
        hookGlobal(name, setUp)
    end
    for _, name in ipairs({ "CompactUnitFrame_SetUnit", "CompactUnitFrame_UpdateAll" }) do
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
    hookGlobal("CompactRaidFrameContainer_LayoutFrames", function()
        RF.MarkDirty()
        RF.SyncAnchor()
        RF.LayoutPets()
    end)
    for _, name in ipairs({ "CompactPartyFrame_UpdateLayout", "CompactPartyFrame_Generate" }) do
        hookGlobal(name, function() RF.LayoutPets() end)
    end
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

-- Saved position = offset of the anchor's TOPRIGHT corner from UIParent's (Edit Mode format).
-- When the number of shown buttons changes, so does the width: keep the LEFT edge where it was, so the
-- group grows and shrinks to the right instead of drifting.
local function finite(value) return type(value) == "number" and abs(value) < math.huge end

function RF.LeftPinnedOffset(left, width, parentRight)
    return left + width - parentRight
end

-- New saved offset (x, y of the TOPRIGHT corner) when the group changes from savedW x savedH to w x h.
--   center - the horizontal middle stays: players of a row (horizontal layout) or whole groups, one column each
--            (vertical layout), spread left and right evenly; the top stays, so a group's players grow downwards
--   corner - the top-left corner stays: it grows to the right and downwards
-- The top never moves; savedH is kept for the signature (and older saves without it).
function RF.GrowOffset(x, y, savedW, savedH, w, h, mode)
    local dx = finite(savedW) and (w - savedW) or 0
    if mode == "corner" then return x + dx, y end
    return x + dx / 2, y
end

-- The left edge comes from the SAVED position and the width it was saved with (config.width, screen
-- units), never from where the anchor stands now: after /reload the anchor sits at its default place
-- (left, next to the chat) until Edit Mode applies the saved one, and measuring it there overwrote
-- the saved position with that default place.

function RF.ResizeAnchor(width, height)
    local entry = editEntry()
    local config = entry and entry.config
    local position = savedPosition() and config.position
    anchor:SetWidth(width)
    anchor:SetHeight(height)
    if not position then return end
    local ratio = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local savedWidth, savedHeight = config.width, config.height
    local w, h = width * ratio, height * ratio
    config.width, config.height = w, h
    -- No size saved with the position (saved by an older version): keep the right corner as it is.
    if not (finite(savedWidth) and finite(position[1]) and finite(position[2])) then return end
    if not finite(savedHeight) then savedHeight = nil end
    if abs(savedWidth - w) <= 0.5 and (not savedHeight or abs(savedHeight - h) <= 0.5) then return end
    local x, y = RF.GrowOffset(position[1], position[2], savedWidth, savedHeight, w, h, cfg().rfGrowth)
    position[1], position[2] = x, y
    attaching = true
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x / ratio, y / ratio)
    attaching = nil
    return x, y
end

-- At login: the anchor takes its saved size and place at once, before anything measures it.
function RF.RestoreAnchor()
    local entry = editEntry()
    local config = entry and entry.config
    if not (config and savedPosition()) then return end
    local position = config.position
    if not (finite(position[1]) and finite(position[2])) then return end
    local ratio = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if finite(config.width) and config.width > 20 then anchor:SetWidth(config.width / ratio) end
    if finite(config.height) and config.height > 20 then anchor:SetHeight(config.height / ratio) end
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", position[1] / ratio, position[2] / ratio)  -- hook attaches
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
        RF.ResizeAnchor(right - left, top - bottom)
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

---------------------------------------------------------------------------------------------------
-- Drag handle: a small label above the shown buttons while the cursor is over them. Dragging it moves
-- the anchor (same saved position as Edit Mode) without opening Edit Mode. Not in combat.
---------------------------------------------------------------------------------------------------
local handle = CreateFrame("Button", "ForeverStockUIRaidHandle", UIParent)
handle:SetWidth(84)
handle:SetHeight(16)
handle:SetFrameStrata("HIGH")
handle:SetClampedToScreen(true)
handle:EnableMouse(true)
handle:Hide()
RF.handle = handle
handle.back = handle:CreateTexture(nil, "BACKGROUND")
handle.back:SetAllPoints(handle)
handle.back:SetTexture(0, 0, 0, 0.55)
handle.icon = handle:CreateTexture(nil, "OVERLAY")
handle.icon:SetTexture("Interface\\CURSOR\\UI-Cursor-Move")
handle.icon:SetWidth(12)
handle.icon:SetHeight(12)
handle.icon:SetPoint("LEFT", handle, "LEFT", 2, 0)
handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
handle.text:SetPoint("LEFT", handle.icon, "RIGHT", 2, 0)
handle.text:SetText(L("Группа", "Group"))
local dragging

-- Keeps the right-corner offset (x, y; both <= 0) inside the screen for an anchor of that size.
function RF.ClampPosition(x, y, width, height, parentWidth, parentHeight)
    return max(width - parentWidth, min(0, x)), max(height - parentHeight, min(0, y))
end

function RF.HandleEnabled()
    local settings = cfg()
    return settings.rfEnabled and settings.rfHandle and settings.rfMoveContainer and not InCombatLockdown()
        and not (ForeverStockUIEditMode and ForeverStockUIEditMode:IsShown())
end

-- Cursor over the shown buttons or the strip just above them (where the handle sits)?
function RF.CursorOverGroup(cx, cy)
    local left, bottom, right, top = buttonBounds()
    if not left then return false end
    return cx >= left and cx <= right and cy >= bottom and cy <= top + 20
end

local function cursor()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

local function stopHandleDrag()
    if not dragging then return end
    dragging = nil
    handle:SetScript("OnUpdate", nil)
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
    ui.RunOutOfCombat("rfAttach", RF.AttachContainer)
    RF.SyncAnchor()
end

-- One drag step: the cursor offset since the start moves the saved position.
function RF.DragStep(entry, cx, cy)
    local d = dragging
    if not (d and entry and entry.config) then return end
    local ratio = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local width, height = anchor:GetWidth() * ratio, anchor:GetHeight() * ratio
    local x, y = RF.ClampPosition(d.x + cx - d.cx, d.y + cy - d.cy, width, height,
        UIParent:GetRight(), UIParent:GetTop())
    entry.config.position = { x, y }
    entry.config.width, entry.config.height = width, height   -- the size the position belongs to
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x / ratio, y / ratio)   -- the hook re-attaches the container
    -- the handle rides on the group while it moves
    handle:ClearAllPoints()
    handle:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
end

function RF.StartHandleDrag()
    local entry = editEntry()
    if not RF.HandleEnabled() or not (entry and entry.config) then return end
    RF.SyncAnchor()
    local position = entry.config.position
    if type(position) ~= "table" or type(position[1]) ~= "number" or type(position[2]) ~= "number" then
        local right, top = anchor:GetRight(), anchor:GetTop()
        if not (right and top and UIParent:GetRight() and UIParent:GetTop()) then return end
        local ratio = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
        position = { right * ratio - UIParent:GetRight(), top * ratio - UIParent:GetTop() }
    end
    local cx, cy = cursor()
    dragging = { x = position[1], y = position[2], cx = cx, cy = cy }
    handle:SetScript("OnUpdate", function()
        if not RF.HandleEnabled() then
            stopHandleDrag()
            return
        end
        RF.DragStep(editEntry(), cursor())
    end)
end

function RF.IsHandleDragging() return dragging ~= nil end

handle:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then RF.StartHandleDrag() end
end)
handle:SetScript("OnMouseUp", stopHandleDrag)
handle:SetScript("OnHide", stopHandleDrag)

local function placeHandle()
    local left, _, _, top = buttonBounds()
    if not left then return false end
    handle:ClearAllPoints()
    handle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, top + 2)
    return true
end

-- Hover poll (4 times a second): shows the handle over the group, hides it shortly after the cursor leaves.
local poll, pollElapsed, lastOver = CreateFrame("Frame"), 0, 0
function RF.UpdateHandle(now)
    if dragging then return end
    if not RF.HandleEnabled() then
        if handle:IsShown() then handle:Hide() end
        return
    end
    local cx, cy = cursor()
    if RF.CursorOverGroup(cx, cy) or MouseIsOver(handle) then lastOver = now end
    if now - lastOver < 0.6 then
        if placeHandle() and not handle:IsShown() then handle:Show() end
    elseif handle:IsShown() then
        handle:Hide()
    end
end
poll:SetScript("OnUpdate", function(_, elapsed)
    pollElapsed = pollElapsed + elapsed
    if pollElapsed < 0.25 then return end
    pollElapsed = 0
    RF.UpdateHandle(GetTime())
end)
poll:RegisterEvent("PLAYER_REGEN_DISABLED")
poll:SetScript("OnEvent", function()
    stopHandleDrag()
    handle:Hide()
end)

hooksecurefunc(anchor, "SetPoint", function()
    if attaching then return end
    RF.AttachContainer()
end)

function RF.Init()
    RF.initialized = true
    installHooks()
    local raid, party = containers()
    hookContainer(raid)
    hookContainer(party)
    if ui.RegisterEditFrame then
        local entry = ui.RegisterEditFrame(anchor, L("Фреймы группы и рейда", "Party and raid frames"), "raidframes")
        if entry then
            entry.onRightClick = function() ui.OpenOptions("raidframes") end
            entry.resetPosition = function()
                if entry.config then entry.config.width, entry.config.height = nil, nil end
                RF.SyncAnchor()
            end
            anchor.editEntry = entry
            RF.RestoreAnchor()
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

-- Late client code: the compact frame functions and containers may appear after PLAYER_LOGIN (a client
-- addon loaded later, frames generated on the first group). Hook what is new and pick up its frames.
function RF.Rehook()
    installHooks()
    local raid, party = containers()
    hookContainer(raid)
    hookContainer(party)
    RF.Scan()
end

local lateEvents = CreateFrame("Frame")
lateEvents:RegisterEvent("ADDON_LOADED")
lateEvents:SetScript("OnEvent", function(_, _, name)
    if name ~= "ForeverUI" and RF.initialized then RF.Rehook() end
end)

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
-- Drinking indicator: the label "Пьёт - - -" while the unit has a drink buff (Suite.DrinkAura:
-- localized names, then spell ids), out of combat, by default only for mana users (UnitPowerType 0).
-- Styles: "text" (Пьёт - - -) or "mana" (Пьёт 42%); the old "icon" value reads as "text". UNIT_AURA,
-- UNIT_FLAGS (combat) and roster changes raise drinkDirty; UNIT_MANA matters only in the "mana" style.
---------------------------------------------------------------------------------------------------
local DRINK_SIZE = 9

function RF.StyleDrink(deco, settings)
    settings = settings or cfg()
    local size = max(6, floor(DRINK_SIZE * (tonumber(settings.rfDrinkScale) or 1) + 0.5))
    deco.drinkText:SetFont(Suite.art.font, size, "OUTLINE")
    deco.drinkText:SetTextColor(0.55, 0.8, 1)
    deco.drink:SetHeight(size + 4)
    deco.drink:ClearAllPoints()
    local point = settings.rfDrinkAnchor or "BOTTOMLEFT"
    deco.drink:SetPoint(point, deco.health or deco.frame, point, settings.rfDrinkX or 0, settings.rfDrinkY or 0)
    deco.drinkKey = nil
    deco.drinkDirty = true
end

-- The label for a style and a mana percent (nil outside the "mana" style).
function RF.DrinkLabel(style, pct)
    if style == "mana" and pct then return L("Пьёт", "Drinking") .. " " .. pct .. "%" end
    return L("Пьёт", "Drinking") .. " - - -"
end

-- What the indicator shows for a unit right now: nil, or the label.
function RF.DrinkText(unit, settings)
    settings = settings or cfg()
    if not (settings.rfEnabled and settings.rfDrink) or not unit or not UnitExists(unit) then return nil end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return nil end
    if UnitAffectingCombat and UnitAffectingCombat(unit) then return nil end
    local mana = not UnitPowerType or UnitPowerType(unit) == 0
    if settings.rfDrinkManaOnly and not mana then return nil end
    if not Suite.DrinkAura(unit) then return nil end
    local pct
    if settings.rfDrinkStyle == "mana" and mana then
        local most = UnitManaMax(unit) or 0
        if most > 0 then pct = floor((UnitMana(unit) or 0) / most * 100 + 0.5) end
    end
    return RF.DrinkLabel(settings.rfDrinkStyle, pct)
end

function RF.DrawDrink(deco, text)
    if not text then
        if deco.drink:IsShown() then deco.drink:Hide() end
        return
    end
    if deco.drinkKey ~= text then
        deco.drinkKey = text
        deco.drinkText:SetText(text)
        deco.drink:SetWidth(max(1, (deco.drinkText:GetStringWidth() or 0) + 8))
    end
    if not deco.drink:IsShown() then deco.drink:Show() end
end

function RF.UpdateDrink(deco)
    deco.drinkDirty = nil
    if deco.preview then return end
    local unit = deco.unit
    if unit and UnitGUID(unit) ~= deco.guid then unit = nil end
    RF.DrawDrink(deco, RF.DrinkText(unit))
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
-- Pets under their owners (horizontal layout). The client flow layout puts the pet buttons in their
-- own row after all the players; here each one is hung under its owner's button instead. Out of
-- combat only (the buttons are protected). Turning it off hands the layout back to the client.
---------------------------------------------------------------------------------------------------
local PET_GAP = 2

-- Owner token of a pet token ("partypet2" -> "party2", "pet" -> "player"); nil for anything else.
function RF.PetOwner(unit)
    if type(unit) ~= "string" then return end
    if unit == "pet" then return "player" end
    local n = unit:match("^partypet(%d+)$")
    if n then return "party" .. n end
    n = unit:match("^raidpet(%d+)$")
    if n then return "raid" .. n end
end

local function isPetDeco(deco)
    if RF.PetOwner(deco.unit) then return true end
    local name = deco.frame.GetName and deco.frame:GetName()
    return name ~= nil and name:match("^CompactPartyFramePet%d+$") ~= nil
end

-- Owner deco of a pet deco: by unit token, else CompactPartyFramePetN under CompactPartyFrameMemberN.
local function ownerOf(deco, byUnit)
    local owner = RF.PetOwner(deco.unit)
    if owner and byUnit[owner] then return byUnit[owner] end
    local name = deco.frame.GetName and deco.frame:GetName()
    local n = name and name:match("^CompactPartyFramePet(%d+)$")
    if n then
        local frame = _G["CompactPartyFrameMember" .. n]
        return frame and decos[frame]
    end
end

-- Horizontal = at least two shown player buttons side by side (same top, different left).
function RF.IsHorizontal()
    local first
    for _, deco in ipairs(ordered) do
        if deco.frame:IsVisible() and not isPetDeco(deco) then
            local l, _, _, t = screenRect(deco.frame)
            if l then
                if not first then
                    first = { l, t }
                elseif abs(t - first[2]) < 2 and abs(l - first[1]) > 2 then
                    return true
                end
            end
        end
    end
    return false
end

local petsMoved
function RF.LayoutPets()
    if InCombatLockdown() then
        ui.RunOutOfCombat("rfPets", RF.LayoutPets)
        return
    end
    local settings = cfg()
    if not (settings.rfEnabled and settings.rfPetsUnder) then
        if petsMoved then
            petsMoved = nil
            for _, container in ipairs({ _G.CompactRaidFrameContainer, _G.CompactPartyFrame }) do
                if container then
                    if type(_G.CompactRaidFrameContainer_TryUpdate) == "function" and container == _G.CompactRaidFrameContainer then
                        pcall(_G.CompactRaidFrameContainer_TryUpdate, container)
                    elseif type(_G.CompactRaidFrameContainer_LayoutFrames) == "function" then
                        pcall(_G.CompactRaidFrameContainer_LayoutFrames, container)
                    end
                end
            end
        end
        return
    end
    if not RF.IsHorizontal() then return end
    local byUnit = {}
    for _, deco in ipairs(ordered) do
        if deco.unit and deco.frame:IsVisible() and not isPetDeco(deco) then byUnit[deco.unit] = deco end
    end
    attaching = true
    for _, deco in ipairs(ordered) do
        if deco.frame:IsVisible() and isPetDeco(deco) then
            local owner = ownerOf(deco, byUnit)
            if owner then
                deco.frame:ClearAllPoints()
                deco.frame:SetPoint("TOPLEFT", owner.frame, "BOTTOMLEFT", 0, -PET_GAP)
                petsMoved = true
            end
        end
    end
    attaching = nil
    RF.SyncAnchor()
end

---------------------------------------------------------------------------------------------------
-- Live apply from the options
---------------------------------------------------------------------------------------------------
RF.styleVersion = 0
function RF.Apply()
    RF.styleVersion = RF.styleVersion + 1
    rebuildIndicatorLookup()
    RF.ApplySort()
    RF.LayoutPets()
    if RF.templateShown then RF.LayoutTemplate() end
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

-- Another settings table is in force (profile switch, group type change, the options page picked
-- another group type, a copy): everything is drawn again from it.
function RF.SettingsSwitched(kindChanged)
    if ui.NormalizeModule then ui.NormalizeModule("raidframes") end
    RF.Apply()
    RF.ApplyLayout()
    RF.ApplyVisibility()
    if kindChanged then
        ui.Fire("RaidFramesKindChanged", RF.ViewKind())
        ui.Fire("OptionsRefresh", "raidframes")
    end
end
ui.RegisterCallback("SuiteProfileChanged", function() RF.SettingsSwitched(false) end, "RaidFramesProfile")

-- The options page picks which group type it edits (nil = the live one). Another type than the live
-- one shows its sample frames in place of the group, so what is edited is what is seen.
function RF.SetEditKind(kind)
    if not validKind(kind) then kind = nil end
    if kind == RF.editKind then return end
    RF.editKind = kind
    if kind and kind ~= RF.LiveKind() then
        if not RF.templateShown and not InCombatLockdown() then
            RF.SetTemplate(true)
            RF.autoTemplate = true
        end
    elseif RF.autoTemplate then
        RF.autoTemplate = nil
        if RF.templateShown then RF.SetTemplate(false) end
    end
    RF.SettingsSwitched(true)
end

-- Joining, growing or leaving a raid switches the settings table.
local lastLiveKind
local kindEvents = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE" }) do
    kindEvents:RegisterEvent(event)
end
kindEvents:SetScript("OnEvent", function()
    local kind = RF.LiveKind()
    if kind == lastLiveKind then return end
    lastLiveKind = kind
    if RF.editKind or not Suite.ready then return end
    RF.SettingsSwitched(true)
end)
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
        deficit = "-9.5k", target = true, drink = true },
    dps = { name = L("Боец", "Damage"), class = "MAGE", health = 0.34, heal = 0.1, absorb = 0.08, role = "DAMAGER",
        deficit = "-16.8k", hover = true },
    pet = { name = L("Питомец", "Pet"), class = "HUNTER", health = 0.8, heal = 0, absorb = 0, deficit = "", noRole = true },
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
-- `override` (optional) replaces fields of the variant for this cell: name, class, role, health.
function RF.BuildPreview(parent, width, height, variant, override)
    width, height = width or 120, height or 48
    local data = previewVariants[variant or "healer"] or previewVariants.healer
    if override then
        local merged = {}
        for key, value in pairs(data) do merged[key] = value end
        for key, value in pairs(override) do merged[key] = value end
        data = merged
    end
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
    -- The name, the target border (healer) and the hover highlight (damage dealer) follow the settings.
    deco.previewName, deco.previewClass, deco.previewTarget = data.name, data.class, data.target
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[data.class]
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
        if data.noRole then deco.role:Hide() else RF.UpdateRole(deco, data.role) end
        -- The healer drinks in the preview (the style decides the text, 42% mana in the "mana" style).
        local drinkText
        if data.drink and settings.rfEnabled and settings.rfDrink then
            drinkText = RF.DrinkLabel(settings.rfDrinkStyle, 42)
        end
        RF.DrawDrink(deco, drinkText)
        updateName(deco)
        updateTarget(deco)
        drawHover(deco, data.hover)
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
-- Template preview: fills the group frame's place with decorated sample buttons (tank, healer,
-- damage dealers, pets), so the layout can be judged without a group. Plain non-clickable frames.
---------------------------------------------------------------------------------------------------
RF.templateKinds = { party = 5, raid10 = 10, raid25 = 25 }
local TEMPLATE_GAP, TEMPLATE_ROW = 2, 5
local DEFAULT_W, DEFAULT_H = 150, 55   -- used while no real button is shown

-- Who stands in each sample group: role variant, class (for class colours) and the pet of hunters
-- (1, wolf) and warlocks (2, imp). Groups of five, as the client lays them out.
local T, H, D = "tank", "healer", "dps"
RF.templateRoster = {
    party = { { T, "WARRIOR" }, { H, "PRIEST" }, { D, "MAGE" }, { D, "HUNTER", pet = 1 }, { D, "WARLOCK", pet = 2 } },
    raid10 = {
        { T, "WARRIOR" }, { T, "PALADIN" }, { H, "PRIEST" }, { H, "SHAMAN" }, { H, "DRUID" },
        { D, "MAGE" }, { D, "ROGUE" }, { D, "HUNTER", pet = 1 }, { D, "WARLOCK", pet = 2 }, { D, "DEATHKNIGHT" },
    },
    raid25 = {
        { T, "WARRIOR" }, { T, "PALADIN" }, { H, "PRIEST" }, { H, "SHAMAN" }, { D, "MAGE" },
        { H, "DRUID" }, { H, "PALADIN" }, { D, "ROGUE" }, { D, "HUNTER", pet = 1 }, { D, "DEATHKNIGHT" },
        { D, "MAGE" }, { D, "WARLOCK", pet = 2 }, { D, "DEATHKNIGHT" }, { D, "SHAMAN" }, { D, "ROGUE" },
        { D, "HUNTER", pet = 1 }, { D, "MAGE" }, { D, "WARLOCK", pet = 2 }, { D, "DRUID" }, { D, "WARRIOR" },
        { H, "PRIEST" }, { D, "ROGUE" }, { D, "MAGE" }, { D, "SHAMAN" }, { D, "DEATHKNIGHT" },
    },
}
-- Health of the sample members in turn, so the group does not look like one frame copied.
local templateHealth = { 1, 0.86, 0.62, 1, 0.45, 0.93, 1, 0.71, 0.34, 1, 0.8, 0.55 }

-- What one sample cell shows. Each state (threat, target, drinking, shield, incoming heals) is on one
-- cell only: a template where every healer looked targeted and every damage dealer hovered did not
-- read as a group.
function RF.TemplateMember(kind, index)
    local roster = RF.templateRoster[kind] or RF.templateRoster.party
    local member = roster[index]
    if not member then return end
    local names = { tank = L("Танк", "Tank"), healer = L("Лекарь", "Healer"), dps = L("Боец", "Damage") }
    local health = templateHealth[(index - 1) % #templateHealth + 1]
    local data = {
        name = names[member[1]] .. (#roster > TEMPLATE_ROW and (" " .. index) or ""),
        class = member[2], health = health, heal = 0, absorb = 0,
        deficit = health >= 1 and "" or ("-%.1fk"):format((1 - health) * 25),
        threat = false, target = false, drink = false, hover = false,
    }
    local firstOf, secondHealer = {}, nil
    for i, other in ipairs(roster) do
        local role = other[1]
        if not firstOf[role] then
            firstOf[role] = i
        elseif role == "healer" and not secondHealer then
            secondHealer = i
        end
    end
    if index == firstOf.tank then data.threat, data.absorb = 3, 0.3 end
    if index == firstOf.healer then data.target = true end
    if index == (secondHealer or firstOf.healer) then data.drink = true end
    if index == firstOf.dps then data.heal, data.absorb = 0.15, 0.08 end
    return member[1], data, member.pet
end

-- Size of the sample buttons: the real ones (in UIParent units), so the sample is true to scale.
-- Pets: the real pet button when one is shown, else half the height of a player button.
function RF.TemplateMetrics()
    local w, h, petW, petH
    for _, deco in ipairs(ordered) do
        local frame = deco.frame
        if frame:IsVisible() and frame:GetWidth() and frame:GetHeight() then
            local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local fw, fh = floor(frame:GetWidth() * ratio + 0.5), floor(frame:GetHeight() * ratio + 0.5)
            if fw >= 20 and fh >= 10 then
                if isPetDeco(deco) then
                    petW, petH = petW or fw, petH or fh
                else
                    w, h = w or fw, h or fh
                end
            end
        end
    end
    w, h = w or DEFAULT_W, h or DEFAULT_H
    return w, h, petW or w, petH or max(12, floor(h / 2))
end

-- Positions (x right, y down from the top-left corner) of member cells and pet cells.
-- hasPet[i] = member i has a pet. Horizontal: each group of perRow is a row; petsUnder hangs a pet
-- under its owner, otherwise the pets form their own rows after all the players (like the client).
-- Vertical: each group is a column, the pets stand in their own column(s) to the right.
function RF.TemplateLayout(hasPet, perRow, w, h, petH, gap, petsUnder, vertical)
    local out = { cells = {}, pets = {}, width = 0, height = 0 }
    local count = #hasPet
    if count == 0 then return out end
    if vertical then
        local groups = math.ceil(count / perRow)
        for i = 1, count do
            local group, slot = floor((i - 1) / perRow), (i - 1) % perRow
            out.cells[i] = { group * (w + gap), -slot * (h + gap) }
        end
        local columnHeight = min(count, perRow) * (h + gap) - gap
        local perColumn = max(1, floor((columnHeight + gap) / (petH + gap)))
        local x, k = groups * (w + gap), 0
        for i = 1, count do
            if hasPet[i] then
                out.pets[#out.pets + 1] = { owner = i, x = x + floor(k / perColumn) * (w + gap),
                    y = -(k % perColumn) * (petH + gap) }
                k = k + 1
            end
        end
        out.width = (groups + math.ceil(k / perColumn)) * (w + gap) - gap
        out.height = max(columnHeight, min(k, perColumn) * (petH + gap) - gap)
        return out
    end
    local y = 0
    for first = 1, count, perRow do
        local rowPet
        for i = first, min(first + perRow - 1, count) do
            local x = (i - first) * (w + gap)
            out.cells[i] = { x, -y }
            if hasPet[i] and petsUnder then
                out.pets[#out.pets + 1] = { owner = i, x = x, y = -(y + h + gap) }
                rowPet = true
            end
        end
        y = y + h + gap + (rowPet and (petH + gap) or 0)
    end
    if not petsUnder then
        local k = 0
        for i = 1, count do
            if hasPet[i] then
                out.pets[#out.pets + 1] = { owner = i, x = (k % perRow) * (w + gap), y = -(y + floor(k / perRow) * (petH + gap)) }
                k = k + 1
            end
        end
        y = y + math.ceil(k / perRow) * (petH + gap)
    end
    out.width = min(count, perRow) * (w + gap) - gap
    out.height = y - gap
    return out
end

-- Whether the client lays this group type out in rows. Read from the real buttons whenever at least
-- two players are shown and remembered per group type (ForeverStockUIDB.rfSeenHorizontal).
function RF.TemplateHorizontal(kind)
    local settings = ui.Settings()
    if type(settings.rfSeenHorizontal) ~= "table" then settings.rfSeenHorizontal = {} end
    local seen = settings.rfSeenHorizontal
    local players = 0
    for _, deco in ipairs(ordered) do
        if deco.frame:IsVisible() and not isPetDeco(deco) then players = players + 1 end
    end
    if players >= 2 and not RF.templateFaded then seen[RF.LiveKind()] = RF.IsHorizontal() end
    local value = seen[kind]
    if value == nil then value = seen.party end
    return value ~= false
end

local templateFrame
local function getTemplateFrame()
    if templateFrame then return templateFrame end
    templateFrame = CreateFrame("Frame", "ForeverStockUIRaidTemplate", UIParent)
    templateFrame:SetFrameStrata("HIGH")
    templateFrame:EnableMouse(false)
    templateFrame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    templateFrame:SetWidth(DEFAULT_W)
    templateFrame:SetHeight(DEFAULT_H)
    templateFrame.cells, templateFrame.pets, templateFrame.pools = {}, {}, {}
    templateFrame:Hide()
    RF.template = templateFrame
    return templateFrame
end

-- Cells are built once per group type and size: each keeps its member (class colour, role, state).
local function placeCell(frame, list, index, variant, w, h, data, x, y)
    local cell = list[index]
    if not cell then
        cell = RF.BuildPreview(frame, w, h, variant, data)
        list[index] = cell
    end
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    cell:Show()
end

-- While the sample frames are shown, the real group frames under them are made invisible (alpha only,
-- which is allowed in combat too), so the two do not overlap.
local fadedFrames = {}
local function fadeClientFrames(on)
    for _, name in ipairs({ "CompactPartyFrame", "CompactRaidFrameContainer" }) do
        local frame = _G[name]
        if frame and frame.SetAlpha then
            if on and fadedFrames[frame] == nil then
                fadedFrames[frame] = frame.GetAlpha and frame:GetAlpha() or 1
                frame:SetAlpha(0)
            elseif not on and fadedFrames[frame] ~= nil then
                frame:SetAlpha(fadedFrames[frame])
                fadedFrames[frame] = nil
            end
        end
    end
    RF.templateFaded = on or nil
end
RF.FadeClientFrames = fadeClientFrames

function RF.LayoutTemplate()
    local frame = getTemplateFrame()
    local settings = cfg()
    local kind = RF.ViewKind()
    local count = RF.templateKinds[kind] or 5
    local hasPet, members = {}, {}
    for i = 1, count do
        local variant, data, pet = RF.TemplateMember(kind, i)
        members[i] = { variant, data, pet }
        hasPet[i] = pet ~= nil
    end
    -- measured before the real frames fade (they stay measurable: alpha does not hide them)
    local w, h, petW, petH = RF.TemplateMetrics()
    local vertical = not RF.TemplateHorizontal(kind)
    local key = kind .. "/" .. w .. "x" .. h .. "/" .. petW .. "x" .. petH
    if frame.poolKey ~= key then
        for _, list in ipairs({ frame.cells, frame.pets }) do
            for _, cell in ipairs(list) do cell:Hide() end
        end
        frame.pools[key] = frame.pools[key] or { cells = {}, pets = {} }
        frame.cells, frame.pets, frame.poolKey = frame.pools[key].cells, frame.pools[key].pets, key
    end
    local layout = RF.TemplateLayout(hasPet, TEMPLATE_ROW, w, h, petH, TEMPLATE_GAP, settings.rfPetsUnder ~= false, vertical)
    for i = 1, count do
        placeCell(frame, frame.cells, i, members[i][1], w, h, members[i][2], layout.cells[i][1], layout.cells[i][2])
    end
    for i = count + 1, #frame.cells do frame.cells[i]:Hide() end
    local petNames = { L("Волк", "Wolf"), L("Бес", "Imp") }
    for k, pet in ipairs(layout.pets) do
        local which = members[pet.owner][3] or 1
        placeCell(frame, frame.pets, k, "pet", petW, petH,
            { name = petNames[which], class = which == 2 and "WARLOCK" or "HUNTER" }, pet.x, pet.y)
    end
    for k = #layout.pets + 1, #frame.pets do frame.pets[k]:Hide() end
    frame:SetWidth(max(layout.width, 1))
    frame:SetHeight(max(layout.height, 1))
    return layout
end

function RF.SetTemplate(on)
    RF.templateShown = on and true or nil
    if not on then RF.autoTemplate = nil end
    local frame = getTemplateFrame()
    if on then
        RF.LayoutTemplate()
        frame:Show()
    else
        frame:Hide()
    end
    fadeClientFrames(on and true or false)
end

function RF.ToggleTemplate()
    RF.SetTemplate(not RF.templateShown)
    return RF.templateShown
end

---------------------------------------------------------------------------------------------------
-- Diagnostics: /fuiraid lists the client buttons found and the fields this module uses
---------------------------------------------------------------------------------------------------
SLASH_FOREVERUIRAID1 = "/fuiraid"
SlashCmdList.FOREVERUIRAID = function(input)
    if (input or ""):lower():match("preview") then
        RF.ToggleTemplate()
        return
    end
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
