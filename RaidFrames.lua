-- ForeverUI raid and party frame extension. The Nozdor client ships its own compact raid frames
-- (Custom_CompactRaidFrames: CompactRaidFrameContainer, CompactPartyFrame, CompactUnitFrame_* code).
-- They are not replaced: this module finds those unit buttons and decorates them in the Cell style
-- with click-through layers only (bar textures, background, own buff/debuff icons, corner indicators for
-- HoTs, shields and class buffs, hover highlight, drinking label, power bar colour and height). What the
-- client's raid profile already does (health text and colour, incoming heals, absorbs, pets, name,
-- target highlight) is left to the client (removed here on 2026-11-26).
-- Secure attributes, sizes and anchors of the client buttons are never touched here; the protected
-- actions (re-anchoring and sizing the container) wait for the end of combat.
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
    -- Power bar: colour "light" (the client's colour lifted towards white by rfPowerLighten %), "custom"
    -- (per power type) or "client"; own height and gap (0/0 = the client's geometry, set out of combat),
    -- a divider line above the bar and a background under its empty part.
    rfPowerColorMode = "light", rfPowerLighten = 25,
    rfPowerColorMana = { 0.25, 0.5, 1 }, rfPowerColorRage = { 0.9, 0.22, 0.22 },
    rfPowerColorEnergy = { 1, 0.88, 0.3 }, rfPowerColorRunic = { 0.25, 0.8, 1 },
    rfPowerHeight = 0, rfPowerGap = 0, rfPowerDivider = false, rfPowerDividerColor = { 0, 0, 0, 0.9 },
    rfPowerBack = false, rfPowerBackColor = { 0.03, 0.06, 0.14, 0.85 },
    rfBackgroundColor = { 0.07, 0.07, 0.08, 0.9 }, rfBackgroundForever = true,
    rfHideClientAuras = true,
    rfBuffs = true, rfBuffSize = 13, rfBuffMax = 3, rfBuffAnchor = "BOTTOMRIGHT", rfBuffGrow = "LEFT",
    rfBuffSpacing = 1, rfBuffX = -2, rfBuffY = 2, rfBuffFilter = "all", rfAuraTimer = false,
    rfBuffTrack = "",   -- filled from RF.defaultTracked below
    rfDebuffs = true, rfDebuffSize = 15, rfDebuffMax = 3, rfDebuffAnchor = "BOTTOMLEFT", rfDebuffGrow = "RIGHT",
    rfDebuffSpacing = 1, rfDebuffX = 2, rfDebuffY = 2, rfDebuffFilter = "all", rfDispelScale = 1.25,
    rfIndicators = true, rfIndicatorTimer = true,
    rfMoveContainer = true, rfHandle = true, rfGrowth = "center", rfTemplateSize = 0,
    rfGroupsPerLine = 5,   -- groups side by side before the next line (0 = the client's layout)
    rfPartyShow = "client", rfRaidShow = "client",
    -- Highlight of the button under the cursor
    rfHover = true, rfHoverStyle = "both", rfHoverColor = { 1, 1, 1, 0.85 },
    -- Drinking indicator: the label "Пьёт - - -" while the unit drinks out of combat (mana users only by default)
    -- The client's role icon: the damage dealer one can be faded (tank and healer icons stay)
    rfHideDamagerIcon = true,
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

local function joinIds(list)
    local parts = {}
    for i, id in ipairs(list) do parts[i] = tostring(id) end
    return table.concat(parts, ", ")
end
RF.JoinIds = joinIds
DEFAULTS.rfBuffTrack = joinIds(RF.defaultTracked)
RF.defaultExclusionText = { rfBuffTrack = DEFAULTS.rfBuffTrack }

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
    -- Removed on 2026-11-25 (role icon and sort, threat border, out of range fade, dispel highlight, debuff
    -- exclusions, settings per group type) and 2026-11-26 (what the client does): their stored values go.
    for key in pairs(RF.removedKeys) do part[key] = nil end
    -- The drink mug became the label "Пьёт - - -" bottom left: the stored old defaults move along.
    if part.rfDrinkStyle == "icon" then part.rfDrinkStyle = "text" end
    if part.rfDrinkAnchor == "TOP" and (part.rfDrinkX or 0) == 0 and part.rfDrinkY == -2 then
        part.rfDrinkAnchor, part.rfDrinkX, part.rfDrinkY = "BOTTOMLEFT", 2, 2
    end
end

RF.removedKeys = { rfThreat = true, rfBorderSize = true, rfRangeMode = true, rfRangeAlpha = true, rfRangeFade = true,
    rfDispelHighlight = true, rfDispelOnlyMine = true, rfDispelStyle = true, rfDispelAlpha = true, rfDispelIcon = true,
    rfDispelIconSize = true, rfDispelIconAnchor = true, rfDebuffHide = true, rfRoleMode = true, rfRoleSet = true,
    rfRoleSize = true, rfRoleAnchor = true, rfRoleX = true, rfRoleY = true, rfRoleTank = true, rfRoleHealer = true,
    rfRoleDamager = true, rfRoleMainTank = true, rfRoleSort = true, rfRoleOrder = true, kinds = true,
    -- Removed on 2026-11-26: what the client's raid profile already does (incoming heals, health text and
    -- colour, absorb bar, pets, name, target highlight).
    rfHealPrediction = true, rfHealColor = true, rfDeficitText = true, rfTextSize = true, rfHealthColorMode = true,
    rfHealthColor = true, rfShield = true, rfShieldTexture = true, rfShieldColor = true, rfShieldAlpha = true,
    rfShieldHeight = true, rfShieldMode = true, rfShieldAlign = true, rfHideAbsorbGlow = true, rfPetMode = true,
    rfPetAuras = true, rfPetsUnder = true, rfNameCustom = true, rfNameFont = true, rfNameSize = true,
    rfNameOutline = true, rfNameShadow = true, rfNameMaxLetters = true, rfNameFit = true, rfNameColorMode = true,
    rfNameColor = true, rfNameAnchor = true, rfNameX = true, rfNameY = true, rfTarget = true, rfTargetClass = true,
    rfTargetColor = true, rfTargetSize = true, rfTargetHideClient = true }

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
    for key in pairs(RF.removedKeys) do db[key] = nil end
    -- "Groups per line" came on 2026-11-26 with 0 by default and got 5 the same day: profiles saved in
    -- between move to 5 once (rfGroupsPerLineV marks it, a later choice of 0 stays).
    if db.rfGroupsPerLineV ~= 1 then
        if db.rfGroupsPerLine == 0 then db.rfGroupsPerLine = 5 end
        db.rfGroupsPerLineV = 1
    end
    if type(db.indicators) ~= "table" then
        local _, class = UnitClass("player")
        db.indicators = Suite.Copy(classIndicators[class] or {})
        if RF.healerClasses[class] then RF.AddPresets(db.indicators, RF.healerIndicators) end
    end
end)

---------------------------------------------------------------------------------------------------
-- One set of settings for party and raids (until 2026-11-25 party, raid 10 and raid 25 had their own;
-- the party set, the base of the "raid" part, is the one kept). The group type still sizes the samples.
---------------------------------------------------------------------------------------------------
-- The group type now: a raid of more than 10 is a raid of 25.
function RF.LiveKind()
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raid > 10 then return "raid25" end
    if raid > 0 then return "raid10" end
    return "party"
end
RF.ViewKind = RF.LiveKind

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

-- Name -> unit token of the group, rebuilt on demand after a roster or name change (RF.MarkNamesStale).
local unitByName = { stale = true }   -- name -> token; the "stale" key is a flag, no player name
function RF.MarkNamesStale() unitByName.stale = true end

local function rebuildNames()
    for k in pairs(unitByName) do unitByName[k] = nil end
    for _, unit in ipairs(groupTokens) do
        local name = UnitExists(unit) and UnitName(unit)
        if name and not unitByName[name] then unitByName[name] = unit end
    end
end

local function unitOf(frame)
    local attribute = frame.GetAttribute and frame:GetAttribute("unit")
    if type(attribute) ~= "string" or attribute == "" then attribute = nil end
    local first = attribute or frame.displayedUnit or frame.unit
    local name = shownName(frame)
    if not name then return first end
    if attribute and UnitName(attribute) == name then return attribute end
    local displayed, own = frame.displayedUnit, frame.unit
    if displayed and UnitName(displayed) == name then return displayed end
    if own and UnitName(own) == name then return own end
    if unitByName.stale then rebuildNames() end
    local unit = unitByName[name]
    if unit and UnitName(unit) ~= name then
        -- The roster moved under us without an event yet: look again.
        rebuildNames()
        unit = unitByName[name]
    end
    return unit or first
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
RF.pointOffsets = pointOffsets

-- Where an indicator dropped on the preview goes: the health bar is w x h, (x, y) is the drop spot (the
-- centre of the widget) from its bottom-left corner. The nearest of the nine anchors (thirds of the bar)
-- wins; the offset puts the widget's centre on the spot, clamped to the option range (+-30).
function RF.IndicatorDrop(w, h, x, y, size)
    size = size or 8
    local col = x < w / 3 and "LEFT" or x > w * 2 / 3 and "RIGHT" or ""
    local row = y > h * 2 / 3 and "TOP" or y < h / 3 and "BOTTOM" or ""
    local point = row .. col
    if point == "" then point = "CENTER" end
    local px = col == "LEFT" and -1 or col == "RIGHT" and 1 or 0
    local py = row == "TOP" and 1 or row == "BOTTOM" and -1 or 0
    local hx = col == "LEFT" and 0 or col == "RIGHT" and w or w / 2
    local hy = row == "TOP" and h or row == "BOTTOM" and 0 or h / 2
    local o = pointOffsets[point]
    local function clamp(v) return max(-30, min(30, floor(v + 0.5))) end
    return point, clamp(x + px * size / 2 - hx - o[1]), clamp(y + py * size / 2 - hy - o[2])
end

local function createDeco(frame)
    local deco = { frame = frame, buffs = {}, debuffs = {}, indicators = {} }
    deco.health = fieldOf(frame, "healthBar", "healthbar", "HealthBar")
    deco.power = fieldOf(frame, "powerBar", "powerbar", "PowerBar", "manaBar")
    deco.background = fieldOf(frame, "background", "Background")

    -- Every layer is click-through so click-casting reaches the client button.
    local layer = CreateFrame("Frame", nil, frame)
    layer:SetAllPoints(frame)
    layer:SetFrameLevel(frame:GetFrameLevel() + 6)
    layer:EnableMouse(false)
    deco.layer = layer

    deco.bg = frame:CreateTexture(nil, "BACKGROUND")
    deco.bg:SetAllPoints(frame)
    deco.bg:Hide()

    -- Power bar extras: a background under the empty part (on the bar, so it hides with it) and a divider
    -- line between health and power (above the bars, shown only while the client shows the power bar).
    if deco.power and deco.power.CreateTexture then
        deco.powerBack = deco.power:CreateTexture(nil, "BACKGROUND")
        deco.powerBack:SetAllPoints(deco.power)
        deco.powerBack:SetTexture(white)
        deco.powerBack:Hide()
        deco.powerDivider = layer:CreateTexture(nil, "ARTWORK")
        deco.powerDivider:SetTexture(white)
        deco.powerDivider:Hide()
    end

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

    -- Hover: a light wash over the button and a 1 px edge.
    deco.hoverFill = layer:CreateTexture(nil, "ARTWORK")
    deco.hoverFill:SetAllPoints(frame)
    deco.hoverFill:SetTexture(white)
    deco.hoverFill:SetBlendMode("ADD")
    deco.hoverFill:Hide()
    deco.hoverEdge = CreateFrame("Frame", nil, layer)
    deco.hoverEdge:SetAllPoints(frame)
    deco.hoverEdge:EnableMouse(false)
    deco.hoverEdge:Hide()
    return deco
end

---------------------------------------------------------------------------------------------------
-- Hover highlight
---------------------------------------------------------------------------------------------------
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
    frame:HookScript("OnShow", function() deco.unitDirty = true RF.MarkDirty() end)
    frame:HookScript("OnEnter", function() setHover(deco, true) end)
    frame:HookScript("OnLeave", function() setHover(deco, false) end)
    frame:HookScript("OnHide", function() setHover(deco, false) end)
    if frame.HookScript then
        frame:HookScript("OnAttributeChanged", function(_, name)
            if name == "unit" then deco.unitDirty = true RF.MarkDirty() end
        end)
    end
    local power = deco.power
    if power and power.SetStatusBarColor then
        -- Every colour the client gives the power bar is remembered and replaced by ours right away.
        hooksecurefunc(power, "SetStatusBarColor", function(_, r, g, b)
            if deco.powerGuard or type(r) ~= "number" then return end
            deco.powerClient = { r, g, b }
            RF.ColorPower(deco)
        end)
    end
    if power and power.HookScript then
        -- The client shows or hides the bar with its "display power bars" option: the extras follow at
        -- once, the geometry on the next pass (the client may be in the middle of laying the bars out).
        local function toggled()
            RF.StylePower(deco, nil, true)
            deco.powerLayoutDirty = true
            RF.MarkDirty()
        end
        power:HookScript("OnShow", toggled)
        power:HookScript("OnHide", toggled)
    end
    applyStyle(deco)
    deco.unitDirty, deco.auraDirty = true, true
    RF.MarkDirty()
    if ui.ClickCast and ui.ClickCast.Attach then ui.ClickCast.Attach(frame) end
    return deco
end

---------------------------------------------------------------------------------------------------
-- Style (textures, colours, fonts): applied on settings change and new frames
---------------------------------------------------------------------------------------------------
-- The client's aura icons stay invisible and click-through. The client runs this on every aura update of
-- the unit (hook) but rarely makes new icons: only icons beyond the ones already faded are touched.
local clientAuraFields = { "buffFrames", "debuffFrames", "dispelDebuffFrames" }
local function hideClientAuras(deco, hide)
    local done = deco.clientAurasHidden
    if not done then
        done = {}
        deco.clientAurasHidden = done
    end
    for _, field in ipairs(clientAuraFields) do
        local list = deco.frame[field]
        if type(list) == "table" then
            if hide then
                for i = (done[field] or 0) + 1, #list do
                    local aura = list[i]
                    aura:SetAlpha(0)
                    if aura.EnableMouse then aura:EnableMouse(false) end
                end
                done[field] = #list
            else
                for _, aura in ipairs(list) do aura:SetAlpha(1) end
                done[field] = nil
            end
        end
    end
end

-- The client's own role icon. ForeverUI draws no roles of its own and works none out: it only reads the
-- picture the client put on the button. The client's sheet of small role circles: the tank cell starts at
-- the left edge, the healer cell at the top, the damage dealer cell at neither (also checked: a file name
-- with dps/damage/tank/heal in it). A whole picture (0, 0 corner: the main tank or assist icon) has no role.
function RF.ClientRoleOf(icon)
    local texture = icon and icon.GetTexture and icon:GetTexture()
    if type(texture) ~= "string" or texture == "" then return nil end
    local lower = texture:lower()
    if lower:find("dps", 1, true) or lower:find("damage", 1, true) then return "DAMAGER" end
    if lower:find("maintank", 1, true) or lower:find("mainassist", 1, true) then return nil end
    if lower:find("tank", 1, true) then return "TANK" end
    if lower:find("heal", 1, true) then return "HEALER" end
    local left, top = icon:GetTexCoord()
    if type(left) ~= "number" or type(top) ~= "number" or (left < 0.1 and top < 0.1) then return nil end
    if left < 0.1 then return "TANK" end
    if top < 0.1 then return "HEALER" end
    return "DAMAGER"
end

-- rfHideDamagerIcon: the client's damage dealer icon is faded (alpha), tank and healer icons stay. The
-- client keeps drawing it; every change of its picture is checked again (hooks on the icon itself).
function RF.UpdateClientRole(deco)
    local icon = deco.frame.roleIcon
    if not (icon and icon.SetAlpha) then return end
    local settings = cfg()
    local hide = settings.rfEnabled and settings.rfHideDamagerIcon and RF.ClientRoleOf(icon) == "DAMAGER"
    local alpha = hide and 0 or 1
    if icon.foreverAlpha ~= alpha then
        icon.foreverAlpha = alpha
        icon:SetAlpha(alpha)
    end
end

function RF.HookClientRole(deco)
    local icon = deco.frame.roleIcon
    if not icon or icon.foreverRoleHooked or not icon.GetTexCoord then return end
    icon.foreverRoleHooked = true
    local function changed() RF.UpdateClientRole(deco) end
    for _, method in ipairs({ "SetTexture", "SetTexCoord", "Show" }) do
        if icon[method] then hooksecurefunc(icon, method, changed) end
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
    RF.StylePower(deco, settings)
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
    local hover = settings.rfHoverColor
    deco.hoverEdge:SetBackdrop({ edgeFile = white, edgeSize = 1 })
    deco.hoverEdge:SetBackdropBorderColor(hover[1], hover[2], hover[3], hover[4] or 1)
    deco.hoverFill:SetVertexColor(hover[1], hover[2], hover[3], (hover[4] or 1) * 0.2)
    drawHover(deco, hoveredDeco == deco)
    hideClientAuras(deco, enabled and settings.rfHideClientAuras)
    if not deco.preview then
        RF.HookClientRole(deco)
        RF.UpdateClientRole(deco)
    end
    RF.StyleDrink(deco, settings)
    for _, icon in ipairs(deco.buffs) do icon.styled = nil end
    for _, icon in ipairs(deco.debuffs) do icon.styled = nil end
    deco.auraDirty = true
end

---------------------------------------------------------------------------------------------------
-- Auras: own buff/debuff icons, Cell-style indicators
---------------------------------------------------------------------------------------------------
local indicatorLookup = {}   -- name or id -> { indicator index, ... }
local trackedBuffs = {}      -- name or id -> true: the only buffs drawn as icons (indicators see every buff)
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
-- A buff outside the tracked list gets no icon (debuffs are never hidden).
function RF.IsHidden(harmful, aura)
    if harmful then return false end
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

-- Icons are redrawn on every aura change of the unit, so each setter runs only when its value changed:
-- re-anchoring, a new texture or a restarted spiral cost far more than the comparison (raid of 25).
local function placeIcon(icon, frame, anchor, grow, offset, x, y)
    local delta = growDelta[grow] or growDelta.RIGHT
    local px, py = x + delta[1] * offset, y + delta[2] * offset
    if icon.pFrame ~= frame or icon.pAnchor ~= anchor or icon.pX ~= px or icon.pY ~= py then
        icon.pFrame, icon.pAnchor, icon.pX, icon.pY = frame, anchor, px, py
        icon:ClearAllPoints()
        icon:SetPoint(anchor, frame, anchor, px, py)
    end
end
RF.PlaceIcon = placeIcon

-- Sets the text of a font string only when it changes (the cache lives on the font string).
local function setText(fontString, text)
    if fontString.shownText ~= text then
        fontString.shownText = text
        fontString:SetText(text)
    end
end
RF.SetText = setText

local tints = { black = { 0, 0, 0 }, white = { 1, 1, 1 }, debuff = { 0.8, 0, 0 } }

local function setAura(icon, texture, count, duration, expiration, borderColor, now)
    if icon.aTexture ~= texture then
        icon.aTexture = texture
        icon.texture:SetTexture(texture)
    end
    setText(icon.count, count and count > 1 and tostring(count) or "")
    Suite.SetCooldown(icon.cooldown, duration and duration > 0 and expiration - duration or nil, duration)
    icon.expiration = duration and duration > 0 and expiration or nil
    if cfg().rfAuraTimer and icon.expiration then
        setText(icon.timer, Suite.FormatTime(icon.expiration - now))
    else
        setText(icon.timer, "")
    end
    borderColor = borderColor or tints.black
    if icon.aBorder ~= borderColor then
        icon.aBorder = borderColor
        icon.border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3])
    end
    if not icon:IsShown() then icon:Show() end
end

-- Hides icons from index `from` on (only those still shown).
local function hideFrom(list, from)
    for i = from, #list do
        local icon = list[i]
        if icon:IsShown() then icon:Hide() end
    end
end

local scratchDebuffs = {}
local foundIndicator = {}
RF.OTHERS_ALPHA = 0.45   -- indicators in "everyone's, others dimmed" mode for an aura cast by someone else

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

-- Debuffs you can dispel first, then the ones that run out sooner.
local function debuffOrder(a, b)
    if a.dispellable ~= b.dispellable then return a.dispellable end
    return (a.expiration or 0) < (b.expiration or 0)
end

-- Fills deco from an aura list: { {name, icon, count, type, duration, expiration, caster, id, harmful}, ... }
function RF.DrawAuras(deco, buffs, debuffs, now)
    local settings = cfg()
    local frame = deco.health or deco.frame
    -- buffs
    local shownBuffs = 0
    if settings.rfEnabled and settings.rfBuffs then
        local size, whose = settings.rfBuffSize, settings.rfBuffFilter
        for _, aura in ipairs(buffs) do
            if shownBuffs >= settings.rfBuffMax then break end
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
    hideFrom(deco.buffs, shownBuffs + 1)

    -- debuffs: dispellable first, larger
    local shownDebuffs, offset = 0, 0
    if settings.rfEnabled and settings.rfDebuffs and #debuffs > 0 then
        for i = #scratchDebuffs, 1, -1 do scratchDebuffs[i] = nil end
        for _, aura in ipairs(debuffs) do
            aura.dispellable = aura.type and Suite.CanDispel(aura.type) or false
            scratchDebuffs[#scratchDebuffs + 1] = aura
        end
        if #scratchDebuffs > 1 then table.sort(scratchDebuffs, debuffOrder) end
        local filter = settings.rfDebuffFilter
        for _, aura in ipairs(scratchDebuffs) do
            if shownDebuffs >= settings.rfDebuffMax then break end
            local allowed = filter == "all" or aura.dispellable or (filter == "typed" and aura.type)
            if allowed and not aura.indicated then
                shownDebuffs = shownDebuffs + 1
                local size = floor(settings.rfDebuffSize * (aura.dispellable and settings.rfDispelScale or 1) + 0.5)
                local icon = auraIcon(deco, deco.debuffs, shownDebuffs, size)
                placeIcon(icon, frame, settings.rfDebuffAnchor, settings.rfDebuffGrow, offset,
                    settings.rfDebuffX, settings.rfDebuffY)
                offset = offset + size + settings.rfDebuffSpacing
                setAura(icon, aura.icon, aura.count, aura.duration, aura.expiration,
                    aura.type and Suite.dispelColors[aura.type] or tints.debuff, now)
            end
        end
        for i = #scratchDebuffs, 1, -1 do scratchDebuffs[i] = nil end
    end
    hideFrom(deco.debuffs, shownDebuffs + 1)
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
                        local found = foundIndicator[index]
                        -- My own copy wins over somebody else's (two priests' Renew on one target).
                        if entry and (entry.harmful and pass == 2 or not entry.harmful and pass == 1)
                            and (not entry.mine or aura.mine) and (not found or (aura.mine and not found.mine)) then
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
            local fresh = not widget or widget.stamp ~= entry or widget.styleVersion ~= RF.styleVersion
            widget = indicatorWidget(deco, index, entry)
            if fresh then
                -- Restyled (or new): the cached values below describe the old look.
                widget.iTexture, widget.iAlpha = nil, nil
                local c = entry.color or tints.white
                if entry.style == "text" then
                    widget.text:SetTextColor(c[1], c[2], c[3])
                else
                    widget.text:SetTextColor(1, 1, 1)
                end
                if entry.style == "icon" then
                    local _, icon = Suite.SpellInfo(Suite.ParseSpellList(entry.spell)[1])
                    widget.spellIcon = icon
                end
            end
            if entry.style == "icon" then
                local texture = aura and aura.icon or widget.spellIcon
                if widget.iTexture ~= texture then
                    widget.iTexture = texture
                    widget.square:SetTexture(texture)
                end
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
            setText(widget.text, text)
            widget.expiration = entry.style == "text" and aura and duration > 0 and aura.expiration or nil
            -- "Everyone's, others dimmed": somebody else's aura is drawn faded.
            local alpha = (entry.dimOthers and not entry.mine and aura and not aura.mine) and RF.OTHERS_ALPHA or 1
            if widget.iAlpha ~= alpha then
                widget.iAlpha = alpha
                widget:SetAlpha(alpha)
            end
            if not widget:IsShown() then widget:Show() end
        elseif widget and widget:IsShown() then
            widget:Hide()
        end
    end
    -- Widgets exist only for indicators that were ever shown, so the table has holes: use pairs.
    for index, widget in pairs(deco.indicators) do
        if not list[index] and widget:IsShown() then widget:Hide() end
    end
end

-- One walk over the unit's auras feeds the indicators, the buff and debuff icons and the drinking label.
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
    local drinking = false
    if not unit or not UnitExists(unit) or not settings.rfEnabled then
        drawIndicators(deco, buffList, debuffList, now)
        RF.DrawAuras(deco, buffList, debuffList, now)
    else
        -- Every buff is collected: indicators of others' shields and saves need them. "Whose buffs" only
        -- filters the icons (RF.DrawAuras).
        collect(unit, "HELPFUL", buffList, false)
        if settings.rfBuffFilter == "raid" then markRaidBuffs(unit, buffList) end
        collect(unit, "HARMFUL", debuffList, false)
        for _, aura in ipairs(buffList) do
            if Suite.IsDrinkAura(aura.name, aura.id) then
                drinking = true
                break
            end
        end
        -- Indicators claim their auras first so they are not drawn twice.
        drawIndicators(deco, buffList, debuffList, now)
        RF.DrawAuras(deco, buffList, debuffList, now)
        release(buffList)
        release(debuffList)
    end
    if deco.drinking ~= drinking then
        deco.drinking = drinking
        deco.drinkDirty = true
    end
end

---------------------------------------------------------------------------------------------------
-- Performance counters (/fuiraid perf): milliseconds and calls per part while a measurement runs.
-- Off, every probe is one boolean test.
---------------------------------------------------------------------------------------------------
local perf = { on = false, parts = {}, events = {}, started = 0, frames = 0, fps = 0, clock = debugprofilestop }
RF.perf = perf

local function perfStart()
    if perf.on then return perf.clock() end
end

local function perfStop(part, started)
    if not started then return end
    local entry = perf.parts[part]
    if not entry then
        entry = { ms = 0, calls = 0 }
        perf.parts[part] = entry
    end
    entry.ms = entry.ms + (perf.clock() - started)
    entry.calls = entry.calls + 1
end
RF.PerfStart, RF.PerfStop = perfStart, perfStop

function RF.PerfBegin()
    if not perf.clock then return false end
    perf.parts, perf.events, perf.frames, perf.fps = {}, {}, 0, 0
    perf.started, perf.on = GetTime(), true
    return true
end

-- The measurement as lines (ASCII), the costliest parts first.
function RF.PerfReport()
    local seconds = max(0.001, GetTime() - perf.started)
    local lines = { ("raid frames perf: %.1f s, %d buttons shown, avg fps %.1f"):format(seconds,
        RF.ShownCount(), perf.frames > 0 and perf.fps / perf.frames or 0) }
    local list, total = {}, 0
    for part, entry in pairs(perf.parts) do
        list[#list + 1] = { part, entry }
        total = total + entry.ms
    end
    table.sort(list, function(a, b) return a[2].ms > b[2].ms end)
    lines[#lines + 1] = ("total %.2f ms/s"):format(total / seconds)
    for _, item in ipairs(list) do
        local entry = item[2]
        lines[#lines + 1] = ("  %-10s %7.2f ms/s %6d calls %6.3f ms/call"):format(item[1], entry.ms / seconds,
            entry.calls, entry.ms / max(1, entry.calls))
    end
    local events = {}
    for event, count in pairs(perf.events) do events[#events + 1] = { event, count } end
    table.sort(events, function(a, b) return a[2] > b[2] end)
    for _, item in ipairs(events) do
        lines[#lines + 1] = ("  event %-28s %6d (%.1f/s)"):format(item[1], item[2], item[2] / seconds)
    end
    return lines
end

function RF.PerfEnd()
    perf.on = false
    return RF.PerfReport()
end

---------------------------------------------------------------------------------------------------
-- Update loop: dirty flags per decoration, one pass per frame, timers and checks on a slow clock
---------------------------------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local anyDirty = false
-- Clocks and pending work of the loop: timers, sweep, roster burst, client layout, layout snapshot.
local sched = { timer = 0, sweep = 0, learnAt = 0 }
-- Auras of one button are redrawn at most this often; health, name and the rest stay immediate.
RF.AURA_INTERVAL = 0.1

function RF.MarkDirty() anyDirty = true end

function RF.ShownCount()
    local count = 0
    for _, deco in ipairs(ordered) do
        if deco.frame:IsVisible() then count = count + 1 end
    end
    return count
end

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
    deco.auraDirty, deco.drinkDirty = true, true
    deco.auraAt, deco.drinking = nil, nil
    -- A new member may have another power type (custom colours go by type).
    if deco.powerClient and cfg().rfPowerColorMode == "custom" then RF.ColorPower(deco) end
end

local function process()
    anyDirty = false
    local now = GetTime()
    for _, deco in ipairs(ordered) do
        if deco.frame:IsVisible() then
            local started
            if deco.unitDirty then
                started = perfStart()
                refreshUnit(deco)
                perfStop("unit", started)
            end
            if deco.auraDirty then
                if not deco.auraAt or now >= deco.auraAt then
                    deco.auraAt = now + RF.AURA_INTERVAL
                    started = perfStart()
                    updateAuras(deco)
                    perfStop("auras", started)
                else
                    anyDirty = true   -- drawn on a later frame, when the interval is over
                end
            end
            if deco.drinkDirty then
                started = perfStart()
                RF.UpdateDrink(deco)
                perfStop("text", started)
            end
            if deco.powerLayoutDirty and not InCombatLockdown() then RF.LayoutPower(deco) end
        end
    end
end

local function tickTimers(now)
    local settings = cfg()
    local auraTimer = settings.rfAuraTimer
    if not auraTimer and not settings.rfIndicators then return end
    for _, deco in ipairs(ordered) do
        if deco.frame:IsVisible() then
            if auraTimer then
                for _, icon in ipairs(deco.buffs) do
                    if icon.expiration and icon:IsShown() then setText(icon.timer, Suite.FormatTime(icon.expiration - now)) end
                end
                for _, icon in ipairs(deco.debuffs) do
                    if icon.expiration and icon:IsShown() then setText(icon.timer, Suite.FormatTime(icon.expiration - now)) end
                end
            end
            for _, widget in pairs(deco.indicators) do
                if widget.expiration and widget:IsShown() then
                    setText(widget.text, Suite.FormatTime(widget.expiration - now))
                end
            end
        end
    end
end

-- Roster changes arrive in bursts (several events per player who leaves or joins): the work runs once,
-- ROSTER_DELAY after the last event of a burst, and at the latest ROSTER_MAX after the first one.
-- The client's layout of its frames is followed by the anchor size and, at most every LEARN_GAP seconds,
-- a layout snapshot.
RF.ROSTER_DELAY, RF.ROSTER_MAX, RF.LEARN_GAP = 0.15, 0.5, 2

function RF.QueueRoster()
    local now = GetTime()
    sched.rosterLatest = sched.rosterLatest or now + RF.ROSTER_MAX
    sched.rosterDue = min(now + RF.ROSTER_DELAY, sched.rosterLatest)
end

function RF.RosterPending() return sched.rosterDue ~= nil end

-- One pass for a whole burst: new client buttons are registered (out of combat), only buttons whose
-- member changed are read again, and pets are hung under their owners once.
function RF.RosterPass()
    sched.rosterDue, sched.rosterLatest = nil, nil
    local started = perfStart()
    RF.MarkNamesStale()
    if not InCombatLockdown() then RF.Scan() end
    for _, deco in ipairs(ordered) do
        local unit = unitOf(deco.frame)
        if unit ~= deco.unit or (unit and UnitGUID(unit) ~= deco.guid) then
            deco.unitDirty = true
            anyDirty = true
        end
    end
    if not InCombatLockdown() and RF.PerLine() > 0 then RF.ApplyLines() end
    if RF.VisibilityChanged and RF.VisibilityChanged() then RF.ApplyVisibility() end
    perfStop("roster", started)
end

-- The client finished a layout of its frames: anchor size and the layout snapshot on the next frame.
function RF.LayoutDone()
    sched.layoutDue = sched.layoutDue or GetTime()
end

driver:SetScript("OnUpdate", function(_, elapsed)
    local now = GetTime()
    if perf.on then
        perf.frames = perf.frames + 1
        perf.fps = perf.fps + (GetFramerate and GetFramerate() or 0)
    end
    if sched.rosterDue and now >= sched.rosterDue then RF.RosterPass() end
    if anyDirty then process() end
    if sched.layoutDue and now >= sched.layoutDue then
        sched.layoutDue = nil
        local started = perfStart()
        RF.SyncAnchor()
        if now >= sched.learnAt then
            sched.learnAt = now + RF.LEARN_GAP
            RF.LearnLayout()
        end
        perfStop("layout", started)
    end
    sched.timer, sched.sweep = sched.timer + elapsed, sched.sweep + elapsed
    if sched.timer >= 0.25 then
        sched.timer = 0
        local started = perfStart()
        tickTimers(now)
        perfStop("timers", started)
    end
    -- Units of client buttons can change without an event we see (sorting): check twice a second.
    if sched.sweep >= 0.5 then
        sched.sweep = 0
        local started = perfStart()
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
        perfStop("sweep", started)
    end
end)

local function markGUID(unit, field, onlyDrinking)
    local guid = unit and UnitGUID(unit)
    local set = guid and byGUID[guid]
    if not set then return end
    for deco in pairs(set) do
        if not onlyDrinking or deco.drinking then
            deco[field] = true
            anyDirty = true
        end
    end
end

local events = CreateFrame("Frame")
-- No health events: health, its text and colour, incoming heals and absorbs are the client's (2026-11-26).
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UNIT_AURA", "PARTY_MEMBERS_CHANGED",
    "RAID_ROSTER_UPDATE", "UNIT_PET", "PLAYER_REGEN_ENABLED", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_DISPLAYPOWER",
    "PLAYER_REGEN_DISABLED" }) do
    events:RegisterEvent(event)
end
RF.events = events

-- Mana changes of every member come many times a second: listened to only for the "Пьёт 42%" label.
function RF.WatchMana()
    local settings = cfg()
    local want = settings.rfEnabled and settings.rfDrink and settings.rfDrinkStyle == "mana"
    for _, event in ipairs({ "UNIT_MANA", "UNIT_MAXMANA" }) do
        if want then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
end

events:SetScript("OnEvent", function(_, event, unit)
    if perf.on then perf.events[event] = (perf.events[event] or 0) + 1 end
    if event == "UNIT_AURA" then
        markGUID(unit, "auraDirty")
    elseif event == "UNIT_FLAGS" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_MANA" or event == "UNIT_MAXMANA" then
        -- Only a drinking member can lose the label (entering combat, another power) or change its %.
        markGUID(unit, "drinkDirty", true)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if RF.templateShown then RF.SetTemplate(false) end
        for _, deco in ipairs(ordered) do
            if deco.drinking then deco.drinkDirty = true end
        end
        anyDirty = true
    elseif event == "UNIT_NAME_UPDATE" then
        RF.MarkNamesStale()
    elseif event == "PLAYER_LOGIN" then
        RF.Scan()
        for _, deco in ipairs(ordered) do deco.unitDirty = true end
        anyDirty = true
        RF.Init()
        RF.WatchMana()
    else
        -- PLAYER_ENTERING_WORLD, roster changes, pets, end of combat (buttons made in combat).
        if event == "PLAYER_ENTERING_WORLD" then RF.Rehook() end
        RF.QueueRoster()
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
        local started = perfStart()
        local deco = decos[frame]
        if deco then
            RF.PowerRelaid(deco)
            RF.Restyle(deco)
        else
            register(frame)
        end
        perfStop("hookSetup", started)
    end
    for _, name in ipairs({ "CompactUnitFrame_SetUpFrame", "DefaultCompactUnitFrameSetup", "DefaultCompactMiniFrameSetup" }) do
        hookGlobal(name, setUp)
    end
    for _, name in ipairs({ "CompactUnitFrame_SetUnit", "CompactUnitFrame_UpdateAll" }) do
        hookGlobal(name, adopt)
    end
    local function reHide(frame)
        local deco = decos[frame]
        if not deco then return end
        local started = perfStart()
        local settings = cfg()
        if settings.rfEnabled and settings.rfHideClientAuras then hideClientAuras(deco, true) end
        perfStop("hookAuras", started)
    end
    for _, name in ipairs({ "CompactUnitFrame_UpdateAuras", "CompactUnitFrame_UpdateBuffs",
        "CompactUnitFrame_UpdateDebuffs", "CompactUnitFrame_UpdateDispellableDebuffs" }) do
        hookGlobal(name, reHide)
    end
    -- The anchor size and the layout snapshot wait for the next frame, once per burst of client layouts.
    hookGlobal("CompactRaidFrameContainer_LayoutFrames", function()
        local started = perfStart()
        RF.MarkDirty()
        RF.LayoutDone()
        perfStop("hookLayout", started)
    end)
    -- A changed raid profile or container size of the client re-lays the sample frames.
    for _, name in ipairs({ "CompactUnitFrameProfiles_ApplyProfile", "CompactRaidFrameManager_SetSetting",
        "CompactRaidFrameManager_ResizeFrame_UpdateContainerSize" }) do
        hookGlobal(name, function()
            if RF.PerLine() > 0 or RF.lines.ownW then ui.RunOutOfCombat("rfLines", RF.ApplyLines) end
            if RF.templateShown then RF.LayoutTemplate() end
        end)
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

-- width, height: screen (UIParent) units, as measured from the shown buttons.
-- The place is computed from a pinned point, not by adding to the last place: the middle (growth from the centre)
-- or the left edge ("corner"), in screen units from UIParent's left (config.pinX). One wrong measure (the client
-- container before its buttons show) then only lasts until the next right one, instead of shifting the group for
-- good (checked in game after /reload). The pin is taken again from the saved spot whenever someone else wrote it
-- (a drag, Edit Mode, the setup wizard): then the spot is no longer the one written here last (config.lastX).
function RF.ResizeAnchor(width, height)
    local entry = editEntry()
    local config = entry and entry.config
    local position = savedPosition() and config.position
    local ratio = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if ratio <= 0 then ratio = 1 end
    anchor:SetWidth(width / ratio)
    anchor:SetHeight(height / ratio)
    if not position then return end
    local savedWidth = config.width
    local w, h = width, height
    config.width, config.height = w, h
    local parentRight = UIParent:GetRight()
    -- No size saved with the position (saved by an older version): keep the right corner as it is.
    if not (finite(savedWidth) and finite(position[1]) and finite(position[2]) and parentRight) then return end
    local mode = cfg().rfGrowth == "corner" and "corner" or "center"
    if config.pinMode ~= mode or not finite(config.pinX) or not finite(config.lastX)
        or abs(config.lastX - position[1]) > 0.5 then
        local left = parentRight + position[1] - savedWidth
        config.pinX, config.pinMode = mode == "corner" and left or left + savedWidth / 2, mode
    end
    local left = mode == "corner" and config.pinX or config.pinX - w / 2
    local x = RF.LeftPinnedOffset(left, w, parentRight)
    config.lastX = x
    if abs(x - position[1]) <= 0.5 then return end
    position[1] = x
    attaching = true
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x / ratio, position[2] / ratio)
    attaching = nil
    return x, position[2]
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

-- Another saved spot was loaded in place (talent set switch, setup wizard, profile): the remembered middle
-- (pinX) belongs to the old spot, so it is taken again from the loaded one, and the anchor and the client
-- container go there now and once more after the client has laid its frames out again.
local reapplyTimer = CreateFrame("Frame")
function RF.ReapplyPosition(delayed)
    local entry = editEntry()
    local config = entry and entry.config
    if config then config.pinX, config.lastX, config.pinMode = nil, nil, nil end
    local function run()
        if InCombatLockdown() then
            ui.RunOutOfCombat("rfReapply", run)
            return
        end
        RF.RestoreAnchor()
        RF.AttachContainer()
        RF.SyncAnchor()
    end
    run()
    if delayed == false then return end
    local waited, marks = 0, { 0.3, 1.5 }
    reapplyTimer:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + elapsed
        if waited < marks[1] then return end
        table.remove(marks, 1)
        if #marks == 0 then self:SetScript("OnUpdate", nil) end
        run()
    end)
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
    -- No button shown yet (right after /reload): the client container keeps the size of a full raid. It may size
    -- an anchor that has no saved place; a saved place is never re-centred on that size.
    if not left and not savedPosition() then
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
-- The strata of the group buttons (placeHandle), not HIGH: windows over the group cover the handle too.
handle:SetFrameStrata("LOW")
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
    -- Same strata as the buttons, just above them: a window that covers the group covers the handle as well.
    local strata, level
    for _, deco in ipairs(ordered) do
        local frame = deco.frame
        if frame:IsVisible() and frame.GetFrameStrata then
            strata = strata or frame:GetFrameStrata()
            level = max(level or 0, frame:GetFrameLevel() or 0)
        end
    end
    if strata and handle:GetFrameStrata() ~= strata then handle:SetFrameStrata(strata) end
    if level and handle:GetFrameLevel() ~= level + 5 then handle:SetFrameLevel(level + 5) end
    return true
end

-- Is the frame under the cursor the group itself (a button, its containers, the handle) or the bare world?
-- Anything else (a window, a menu over the group) means the cursor is not on the group.
local groupRoots = {}
function RF.FocusOnGroup(focus)
    if focus == nil or focus == WorldFrame or focus == UIParent then return true end
    local raid, party = containers()
    groupRoots[handle], groupRoots[anchor] = true, true
    if raid then groupRoots[raid] = true end
    if party then groupRoots[party] = true end
    local frame, depth = focus, 0
    while frame and frame ~= UIParent and depth < 20 do
        if groupRoots[frame] or decos[frame] then return true end
        frame = frame.GetParent and frame:GetParent()
        depth = depth + 1
    end
    return false
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
    local focus = GetMouseFocus and GetMouseFocus()
    if not RF.FocusOnGroup(focus) then
        -- A window or menu is over the group: the handle must not catch its clicks.
        if handle:IsShown() then handle:Hide() end
        lastOver = 0
        return
    end
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
            entry.onRightClick = function() ui.OpenOptions("raidframes", "position") end
            entry.resetPosition = function()
                if entry.config then entry.config.width, entry.config.height = nil, nil end
                RF.SyncAnchor()
            end
            anchor.editEntry = entry
            RF.RestoreAnchor()
        end
    end
    rebuildIndicatorLookup()
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
-- Role icon sets (Art/Roles, copied from Cell's third-party sets and MidUI), used by the healer mana banner
-- (RF.SetRoleTexture). The raid frames themselves keep the client's role icon as it is.
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

---------------------------------------------------------------------------------------------------
-- Power bar (only while the client shows it: "display power bars" in its raid profile).
-- Colour: a hook on the bar's SetStatusBarColor keeps the client's colour (deco.powerClient) and puts
-- ours on top (RF.PowerColor; not protected, works in combat). Geometry: with rfPowerHeight or
-- rfPowerGap the power bar keeps the client's insets but gets our height, and the health bar ends
-- above it. The bars are children of the secure button, so they move only out of combat; the client's
-- anchors are saved (deco.powerSaved) and put back for 0/0, the module off or a hidden power bar.
-- A client setup that lays the bars out again drops the saved anchors (RF.PowerRelaid).
---------------------------------------------------------------------------------------------------
local powerTokens = { [0] = "MANA", [1] = "RAGE", [3] = "ENERGY", [6] = "RUNIC_POWER" }
local powerColorKeys = { MANA = "rfPowerColorMana", RAGE = "rfPowerColorRage", ENERGY = "rfPowerColorEnergy",
    RUNIC_POWER = "rfPowerColorRunic" }
-- The client's colours (PowerBarColor of 3.3.5), for the preview when the global is missing.
RF.powerClientColors = { MANA = { 0, 0, 1 }, RAGE = { 1, 0, 0 }, ENERGY = { 1, 1, 0 }, RUNIC_POWER = { 0, 0.82, 1 } }

-- Colour the power bar gets for the client's r, g, b of power type `token` (pure).
function RF.PowerColor(settings, r, g, b, token)
    local mode = settings.rfPowerColorMode
    if not settings.rfEnabled or mode == "client" then return r, g, b end
    if mode == "custom" then
        local color = settings[powerColorKeys[token] or ""]
        if type(color) == "table" then return color[1], color[2], color[3] end
    end
    local k = min(1, max(0, (tonumber(settings.rfPowerLighten) or 0) / 100))
    return r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k
end

function RF.PowerToken(unit)
    if not unit or not UnitPowerType or not UnitExists(unit) then return nil end
    local index, token = UnitPowerType(unit)
    return token or powerTokens[index]
end

function RF.ColorPower(deco, settings)
    local power = deco.power
    if not power or not power.SetStatusBarColor then return end
    settings = settings or cfg()
    local client = deco.powerClient
    if not client then
        local r, g, b
        if power.GetStatusBarColor then r, g, b = power:GetStatusBarColor() end
        if type(r) ~= "number" then return end
        client = { r, g, b }
        deco.powerClient = client
    end
    local token = deco.previewPower or RF.PowerToken(deco.unit)
    deco.powerGuard = true
    power:SetStatusBarColor(RF.PowerColor(settings, client[1], client[2], client[3], token))
    deco.powerGuard = nil
end

local function savePoints(region)
    local list = {}
    for i = 1, (region.GetNumPoints and region:GetNumPoints() or 0) do list[i] = { region:GetPoint(i) } end
    return list
end

local function restorePoints(region, list)
    region:ClearAllPoints()
    for _, point in ipairs(list) do region:SetPoint(unpack(point)) end
end

-- Distances of a region's edges from the frame's edges, nil while the client has not laid it out.
local function insets(region, frame)
    local fl, fr, ft, fb = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
    if not (fl and fr and ft and fb and l and r and t and b) then return nil end
    return { left = l - fl, right = fr - r, top = ft - t, bottom = b - fb, height = t - b }
end

-- The client set the bars up again: when its anchors replaced ours, the saved ones are stale.
function RF.PowerRelaid(deco)
    local saved = deco.powerSaved
    if not saved or not deco.power then return end
    local now = { deco.power:GetPoint(1) }
    local mark = saved.mark or {}
    for i = 1, 5 do
        if now[i] ~= mark[i] then
            deco.powerSaved = nil
            return
        end
    end
end

function RF.LayoutPower(deco, settings)
    deco.powerLayoutDirty = nil
    local health, power, frame = deco.health, deco.power, deco.frame
    if deco.preview or not (health and power and power.SetHeight and health.ClearAllPoints) then return end
    settings = settings or cfg()
    local height = settings.rfEnabled and max(0, tonumber(settings.rfPowerHeight) or 0) or 0
    local gap = settings.rfEnabled and max(0, tonumber(settings.rfPowerGap) or 0) or 0
    local own = (height > 0 or gap > 0) and power:IsShown() and true or false
    local saved = deco.powerSaved
    if not own and not saved then return end
    if InCombatLockdown() then
        deco.powerLayoutDirty = true
        ui.RunOutOfCombat("rfPowerLayout", RF.LayoutAllPower)
        return
    end
    if not own then
        -- Both cleared first: the client's own anchors may tie the bars to each other in either direction.
        health:ClearAllPoints()
        power:ClearAllPoints()
        if saved.height then power:SetHeight(saved.height) end
        restorePoints(power, saved.power)
        restorePoints(health, saved.health)
        deco.powerSaved = nil
        return
    end
    if not saved then
        local h, p = insets(health, frame), insets(power, frame)
        if not h or not p then
            deco.powerLayoutDirty = true   -- not laid out yet: the next pass tries again
            return
        end
        saved = { health = savePoints(health), power = savePoints(power), h = h, p = p,
            height = power.GetHeight and power:GetHeight() or nil }
        deco.powerSaved = saved
    end
    -- Both bars hang on the button only. The client anchors its power bar to the health bar when it sets
    -- the button up again: a health bar anchored to the power bar would make a loop, and the client's
    -- SetPoint fails with "HealthBar is dependent on this" (in-game error 2026-11-24).
    local powerHeight = height > 0 and height or saved.p.height
    health:ClearAllPoints()
    power:ClearAllPoints()
    power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", saved.p.left, saved.p.bottom)
    power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -saved.p.right, saved.p.bottom)
    power:SetHeight(powerHeight)
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", saved.h.left, -saved.h.top)
    health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -saved.h.right, saved.p.bottom + powerHeight + gap)
    saved.mark = { power:GetPoint(1) }
end

-- One line for /fuiraid (ASCII): the power bar as the client set it up (shown, height, anchors, its
-- colour) and what ForeverUI does with it, to tune the defaults on this client.
function RF.DescribePower(deco)
    local power, health, frame = deco.power, deco.health, deco.frame
    if not power then return "Power: no power bar on this button" end
    local function name(region)
        if region == frame then return "frame" end
        if region == health then return "health" end
        if region == power then return "power" end
        return region and region.GetName and region:GetName() or tostring(region)
    end
    local function anchors(region, list)
        local out = {}
        for i, p in ipairs(list or savePoints(region)) do
            out[i] = ("%s>%s:%s %.1f,%.1f"):format(tostring(p[1]), name(p[2]), tostring(p[3]), tonumber(p[4]) or 0,
                tonumber(p[5]) or 0)
        end
        return #out > 0 and table.concat(out, " ") or "-"
    end
    local saved = deco.powerSaved
    local c = deco.powerClient or {}
    return ("Power: shown=%d h=%.1f health h=%.1f client anchors: power %s | health %s; client colour %.2f,%.2f,%.2f; "
        .. "own layout=%s mode=%s"):format(power:IsShown() and 1 or 0, power.GetHeight and power:GetHeight() or 0,
        health and health.GetHeight and health:GetHeight() or 0, anchors(power, saved and saved.power),
        health and anchors(health, saved and saved.health) or "-", c[1] or -1, c[2] or -1, c[3] or -1,
        saved and "yes" or "no", tostring(cfg().rfPowerColorMode))
end

function RF.LayoutAllPower()
    for _, deco in ipairs(ordered) do RF.LayoutPower(deco) end
end

-- Colour, background, divider and geometry of one frame's power bar (applyStyle, show/hide of the bar;
-- noLayout leaves the geometry to the next pass).
function RF.StylePower(deco, settings, noLayout)
    local power = deco.power
    if not power then return end
    settings = settings or cfg()
    local enabled = settings.rfEnabled and true or false
    if deco.powerBack then
        local c = settings.rfPowerBackColor or { 0, 0, 0, 0 }
        deco.powerBack:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        Suite.Shown(deco.powerBack, enabled and settings.rfPowerBack and true or false)
    end
    local divider = deco.powerDivider
    if divider then
        local c = settings.rfPowerDividerColor or { 0, 0, 0, 1 }
        divider:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        divider:ClearAllPoints()
        divider:SetPoint("BOTTOMLEFT", power, "TOPLEFT", 0, 0)
        divider:SetPoint("BOTTOMRIGHT", power, "TOPRIGHT", 0, 0)
        divider:SetHeight(max(1, tonumber(settings.rfPowerGap) or 0))
        Suite.Shown(divider, enabled and settings.rfPowerDivider and power:IsShown() and true or false)
    end
    RF.ColorPower(deco, settings)
    if not noLayout then RF.LayoutPower(deco, settings) end
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
-- `drinking` is what the last aura walk found (nil: look the buffs up here).
function RF.DrinkText(unit, settings, drinking)
    settings = settings or cfg()
    if not (settings.rfEnabled and settings.rfDrink) or not unit or not UnitExists(unit) then return nil end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return nil end
    if UnitAffectingCombat and UnitAffectingCombat(unit) then return nil end
    local mana = not UnitPowerType or UnitPowerType(unit) == 0
    if settings.rfDrinkManaOnly and not mana then return nil end
    if drinking == nil then drinking = Suite.DrinkAura(unit) and true or false end
    if not drinking then return nil end
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
    RF.DrawDrink(deco, RF.DrinkText(unit, nil, deco.drinking))
end

---------------------------------------------------------------------------------------------------
-- Pet buttons: the client places them (the "Pets" block of ForeverUI was removed on 2026-11-26); they
-- are only told apart from players (layout snapshots, the direction of the groups).
---------------------------------------------------------------------------------------------------
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
    return type(name) == "string" and name:match("^CompactPartyFramePet%d+$") ~= nil
end
RF.IsPetDeco = isPetDeco

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

---------------------------------------------------------------------------------------------------
-- Live apply from the options
---------------------------------------------------------------------------------------------------
RF.styleVersion = 0
function RF.Apply()
    RF.styleVersion = RF.styleVersion + 1
    -- Data of the removed role recognition (2026-11-22): manual marks and the inspection cache.
    local db = ui.Settings and ui.Settings()
    if db then db.roleMarks, db.roleCache = nil, nil end
    rebuildIndicatorLookup()
    RF.WatchMana()
    RF.ApplyLines()
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
local lastVisibility          -- RF.VisibilityKey() when the visibility was last applied

-- What the visibility depends on besides the frames' own OnShow/OnHide: the two settings and whether
-- the player is in a raid, in a party or alone. A roster change inside the same kind of group changes
-- nothing here, so the client containers are not touched then (RF.RosterPass).
function RF.VisibilityKey()
    local settings = cfg()
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    local party = GetNumPartyMembers and GetNumPartyMembers() or 0
    return tostring(settings.rfPartyShow) .. tostring(settings.rfRaidShow) .. (raid > 0 and "R" or party > 0 and "P" or "S")
end

function RF.VisibilityChanged() return RF.VisibilityKey() ~= lastVisibility end

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
    lastVisibility = RF.VisibilityKey()
    if (container and desiredVisibility(container) == true) or (party and desiredVisibility(party) == true) then
        RF.Scan()
        for _, deco in ipairs(ordered) do deco.unitDirty = true end
        RF.MarkDirty()
    end
end

-- Another settings table is in force (profile switch): everything is drawn again from it.
function RF.SettingsSwitched()
    if ui.NormalizeModule then ui.NormalizeModule("raidframes") end
    RF.Apply()
    RF.ApplyLayout()
    RF.ApplyVisibility()
end
ui.RegisterCallback("SuiteProfileChanged", function() RF.SettingsSwitched() end, "RaidFramesProfile")

ui.RegisterCallback("SuiteSpellsChanged", function()
    for _, deco in ipairs(ordered) do deco.auraDirty = true end
    anyDirty = true
end, "RaidFramesSpells")

---------------------------------------------------------------------------------------------------
-- Live preview for the options page: a mock unit button decorated by the same code
---------------------------------------------------------------------------------------------------
-- Each variant shows one state clearly instead of everything on one frame. The bars, the name and the
-- health colour (class colour) stand for what the client draws; indicators, buffs and debuffs are the
-- same set on all three, built from the current settings (previewAuras), so every change shows the
-- same way on each frame.
local previewVariants = {
    tank = { name = L("Танк", "Tank"), class = "WARRIOR", health = 0.92, power = "RAGE", powerValue = 0.35 },
    healer = { name = L("Лекарь", "Healer"), class = "PRIEST", health = 0.62, drink = true, power = "MANA",
        powerValue = 0.42 },
    dps = { name = L("Боец", "Damage"), class = "MAGE", health = 0.34, hover = true, power = "MANA", powerValue = 0.8 },
    pet = { name = L("Питомец", "Pet"), class = "HUNTER", health = 0.8 },
}
RF.previewOrder = { "tank", "healer", "dps" }
RF.previews = {}

local PREVIEW_DISPEL = "Curse"   -- the preview pretends the player removes curses (first and larger)
local PREVIEW_POWER = 6          -- power bar height of the sample frames at the client's height
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

-- others = true: the auras were cast by somebody else (a raid member), as in the "others dimmed" example.
local function demoAuras(list, now, others)
    local result = {}
    for i, aura in ipairs(list) do
        result[i] = { name = aura.name, icon = aura.icon, count = aura.count or 0, type = aura.type, id = aura.id,
            duration = aura.duration, expiration = now + (aura.left or 0), mine = not others, raid = true,
            caster = others and "raid1" or "player" }
    end
    return result
end

local function mergeData(variant, override)
    local data = previewVariants[variant or "healer"] or previewVariants.healer
    if not override then return data end
    local merged = {}
    for key, value in pairs(data) do merged[key] = value end
    for key, value in pairs(override) do merged[key] = value end
    return merged
end

-- Live preview for the options page: a mock unit button decorated by the same code.
-- `override` (optional) replaces fields of the variant for this cell: name, class, health, hover, drink,
-- power, others (auras cast by somebody else).
-- frame:SetData(variant, override) changes the member later, frame:SetMask({ part = true }) draws only
-- those parts (nil = everything; parts: drink, hover, buffs, debuffs, indicators), frame:SetState("dead" |
-- "combat" | nil) shows a unit state. The name and the "Dead" label stand for the client's (frame.name,
-- frame.statusText).
function RF.BuildPreview(parent, width, height, variant, override)
    width, height = width or 120, height or 48
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame.healthBar = CreateFrame("StatusBar", nil, frame)
    frame.healthBar:SetPoint("TOPLEFT", 1, -1)
    frame.healthBar:SetWidth(width - 2)
    frame.healthBar:SetHeight(height - 9)
    frame.healthBar:SetMinMaxValues(0, 1)
    frame.powerBar = CreateFrame("StatusBar", nil, frame)
    frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -1)
    frame.powerBar:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.powerBar:SetMinMaxValues(0, 1)
    frame.powerBar:SetValue(0.8)
    frame.powerBar:SetStatusBarColor(0, 0.45, 1)
    frame.name = frame.healthBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.name:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", 3, -2)
    frame.name:SetPoint("TOPRIGHT", frame.healthBar, "TOPRIGHT", -3, -2)
    frame.name:SetJustifyH("LEFT")
    frame.statusText = frame.healthBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.statusText:SetPoint("BOTTOM", frame.healthBar, "BOTTOM", 0, 2)
    frame.statusText:SetText(L("Мёртв", "Dead"))
    frame.statusText:Hide()
    local deco = createDeco(frame)
    deco.preview = true
    frame.deco = deco
    frame.data = mergeData(variant, override)
    function frame:SetData(newVariant, newOverride)
        self.data = mergeData(newVariant, newOverride)
    end
    function frame:SetMask(mask) self.mask = mask end
    function frame:SetState(state) self.state = state end
    applyStyle(deco)
    function frame:Refresh()
        applyStyle(deco)
        local data, mask, state = self.data, self.mask, self.state
        local function on(part) return not mask or mask[part] and true or false end
        local settings = cfg()
        local dead = state == "dead"
        local health = dead and 0 or data.health
        -- As the client draws it with "class colours": the bar in the class colour, the name on it.
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[data.class]
        local bar = frame.healthBar
        bar:SetValue(health)
        if color then bar:SetStatusBarColor(color.r, color.g, color.b) else bar:SetStatusBarColor(0.1, 0.75, 0.2) end
        frame.name:SetText(data.name or "")
        Suite.Shown(frame.statusText, dead)
        local now = GetTime()
        local buffSet, debuffSet = previewAuras()
        if dead then buffSet, debuffSet = {}, {} end
        local buffs, debuffs = demoAuras(buffSet, now, data.others), demoAuras(debuffSet, now, data.others)
        deco.unit = "player"
        drawIndicators(deco, buffs, debuffs, now)
        local canDispel = Suite.CanDispel
        Suite.CanDispel = function(kind) return kind == PREVIEW_DISPEL end
        RF.DrawAuras(deco, buffs, debuffs, now)
        Suite.CanDispel = canDispel
        if not on("indicators") or dead then
            for _, widget in pairs(deco.indicators) do widget:Hide() end
        end
        if not on("buffs") then for _, icon in ipairs(deco.buffs) do icon:Hide() end end
        if not on("debuffs") then for _, icon in ipairs(deco.debuffs) do icon:Hide() end end
        -- The healer drinks in the preview (the style decides the text, 42% mana in the "mana" style);
        -- in combat or dead nobody drinks.
        local drinkText
        if data.drink and on("drink") and not dead and state ~= "combat" and settings.rfEnabled and settings.rfDrink then
            drinkText = RF.DrinkLabel(settings.rfDrinkStyle, 42)
        end
        RF.DrawDrink(deco, drinkText)
        -- Power: the client's colour of the sample's power type, then ours; the height and gap as set.
        local token = data.power or "MANA"
        local clientColor = PowerBarColor and PowerBarColor[token]
        deco.previewPower = token
        deco.powerClient = clientColor and { clientColor.r, clientColor.g, clientColor.b }
            or RF.powerClientColors[token] or RF.powerClientColors.MANA
        frame.powerBar:SetValue(dead and 0 or (data.powerValue or 0.8))
        local powerHeight = settings.rfEnabled and tonumber(settings.rfPowerHeight) or 0
        local powerGap = settings.rfEnabled and tonumber(settings.rfPowerGap) or 0
        local own = powerHeight > 0 or powerGap > 0
        frame.powerBar:ClearAllPoints()
        frame.powerBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        frame.powerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        local barHeight = powerHeight > 0 and powerHeight or PREVIEW_POWER
        frame.powerBar:SetHeight(barHeight)
        frame.healthBar:ClearAllPoints()
        frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1 + barHeight + (own and powerGap or 1))
        RF.StylePower(deco, settings)
        drawHover(deco, data.hover and on("hover"))
        if frame.flashPart then RF.FlashPreview(frame, frame.flashPart, frame.flashIndex) end
    end
    frame:Refresh()
    RF.previews[#RF.previews + 1] = frame
    RF.preview = frame
    return frame
end

-- Regions of one part of a preview frame that are on screen now.
local function partRegions(frame, part, index)
    local deco, list = frame.deco, {}
    local function add(region) if region and region:IsShown() then list[#list + 1] = region end end
    if part == "buffs" or part == "debuffs" then
        for _, icon in ipairs(deco[part]) do add(icon) end
    elseif part == "indicators" then
        if index then
            add(deco.indicators[index])
        else
            for _, widget in pairs(deco.indicators) do add(widget) end
        end
    elseif part == "hover" then
        add(deco.hoverEdge)
        add(deco.hoverFill)
    elseif part == "health" then
        add(deco.health)
    elseif part == "frame" then
        add(frame)
    else
        add(deco[part])
    end
    return list
end
RF.PreviewPartRegions = partRegions

-- Pulsing outline around one part of a preview frame (the setting under the cursor). part = nil stops it.
function RF.FlashPreview(frame, part, index)
    local flash = frame.flash
    frame.flashPart, frame.flashIndex = part, index
    local regions = part and partRegions(frame, part, index) or {}
    if #regions == 0 then
        if flash then
            flash:Hide()
            flash:SetScript("OnUpdate", nil)
        end
        return
    end
    if not flash then
        flash = CreateFrame("Frame", nil, frame)
        flash:SetFrameLevel(frame:GetFrameLevel() + 40)
        flash:EnableMouse(false)
        flash:SetBackdrop({ edgeFile = white, edgeSize = 1 })
        flash:SetBackdropBorderColor(1, 0.82, 0.2, 1)
        flash.fill = flash:CreateTexture(nil, "BACKGROUND")
        flash.fill:SetAllPoints(flash)
        flash.fill:SetTexture(white)
        flash.fill:SetBlendMode("ADD")
        flash.fill:SetVertexColor(1, 0.82, 0.2, 0.18)
        frame.flash = flash
    end
    flash:ClearAllPoints()
    -- One box around every region of the part, in the frame's own units (all regions share its scale).
    local left, right, top, bottom
    local fl, fb = frame:GetLeft(), frame:GetBottom()
    for _, region in ipairs(regions) do
        local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
        if not (l and r and t and b) then
            left = nil
            break
        end
        left, right = min(left or l, l), max(right or r, r)
        top, bottom = max(top or t, t), min(bottom or b, b)
    end
    if left and fl and fb then
        flash:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", left - fl - 2, top - fb + 2)
        flash:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", right - fl + 2, bottom - fb - 2)
    else
        flash:SetPoint("TOPLEFT", regions[1], "TOPLEFT", -2, 2)
        flash:SetPoint("BOTTOMRIGHT", regions[#regions], "BOTTOMRIGHT", 2, -2)
    end
    local elapsed = 0
    flash:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + (delta or 0)
        self:SetAlpha(0.35 + 0.65 * math.abs(math.sin(elapsed * 4)))
    end)
    flash:SetAlpha(1)
    flash:Show()
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
-- A raid of 40 (the raid 25 profile covers it): the raid 25 roster and three more groups.
do
    local raid40 = {}
    for i, member in ipairs(RF.templateRoster.raid25) do raid40[i] = member end
    local extra = { { T, "DEATHKNIGHT" }, { H, "SHAMAN" }, { D, "MAGE" }, { D, "ROGUE" }, { D, "HUNTER", pet = 1 },
        { H, "PALADIN" }, { D, "WARLOCK", pet = 2 }, { D, "DRUID" }, { D, "WARRIOR" }, { D, "MAGE" },
        { H, "PRIEST" }, { D, "SHAMAN" }, { D, "ROGUE" }, { D, "DEATHKNIGHT" }, { D, "HUNTER" } }
    for _, member in ipairs(extra) do raid40[#raid40 + 1] = member end
    RF.templateRoster.raid40 = raid40
end

function RF.TemplateMember(kind, index)
    local roster = RF.templateRoster[kind] or RF.templateRoster.party
    -- More sample players than the type has (40 on the raid 25 profile): the 40 roster.
    if index > #roster then roster = RF.templateRoster.raid40 end
    local member = roster[index]
    if not member then return end
    local names = { tank = L("Танк", "Tank"), healer = L("Лекарь", "Healer"), dps = L("Боец", "Damage") }
    local health = templateHealth[(index - 1) % #templateHealth + 1]
    local data = {
        name = names[member[1]] .. (#roster > TEMPLATE_ROW and (" " .. index) or ""),
        class = member[2], health = health, heal = 0, absorb = 0,
        deficit = health >= 1 and "" or ("-%.1fk"):format((1 - health) * 25),
        target = false, drink = false, hover = false,
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
    if index == firstOf.tank then data.absorb = 0.3 end
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

---------------------------------------------------------------------------------------------------
-- The client's own raid profile (Interface > Raid profiles): button size, rows or columns, groups kept
-- together, pets. Read from the saved table of this character (CompactRaidFrameDB, the values exactly
-- as saved), then from the client API (GetRaidProfileOption errors on options that are off, so an error
-- there means "off"). Checked in game with /fuiraid profile: the API and the table both exist.
---------------------------------------------------------------------------------------------------
local function truthy(value) return value == true or value == 1 or value == "1" end

-- Which "activate automatically for N players" box decides the profile of a group of `players`.
function RF.AutoActivateKey(players)
    if players <= 2 then return "autoActivate2Players" end
    if players <= 3 then return "autoActivate3Players" end
    if players <= 5 then return "autoActivate5Players" end
    if players <= 10 then return "autoActivate10Players" end
    if players <= 15 then return "autoActivate15Players" end
    if players <= 25 then return "autoActivate25Players" end
    return "autoActivate40Players"
end

-- profiles: the PROFILES list of CompactRaidFrameDB[character] (or nil), active: the active name.
-- Returns { w, h, horizontal, together, pets, flagged, sortBy, name, source } or nil.
function RF.PickProfile(profiles, active, players, apiOption)
    local chosen
    if type(profiles) == "table" then
        local auto = players and RF.AutoActivateKey(players)
        for _, profile in ipairs(profiles) do
            if type(profile) == "table" and auto and truthy(profile[auto]) then
                chosen = profile
                break
            end
        end
        if not chosen then
            for _, profile in ipairs(profiles) do
                if type(profile) == "table" and profile.name == active then
                    chosen = profile
                    break
                end
            end
        end
        if not chosen and type(profiles[1]) == "table" then chosen = profiles[1] end
    end
    if not chosen and not (active and apiOption) then return nil end
    local function option(key)
        if chosen and chosen[key] ~= nil then return chosen[key] end
        if active and apiOption then return apiOption(active, key) end
    end
    local w, h = tonumber(option("frameWidth")), tonumber(option("frameHeight"))
    if not (w and h and w > 0 and h > 0) then return nil end
    return { w = w, h = h, horizontal = truthy(option("horizontalGroups")),
        together = truthy(option("keepGroupsTogether")), pets = truthy(option("displayPets")),
        flagged = truthy(option("displayMainTankAndAssist")), sortBy = option("sortBy"),
        name = chosen and chosen.name or active, source = chosen and "saved" or "api" }
end

function RF.ClientProfile(players)
    local db = _G.CompactRaidFrameDB
    local entry = type(db) == "table" and db[UnitName("player") or ""] or nil
    local profiles = type(entry) == "table" and type(entry.PROFILES) == "table" and entry.PROFILES.value or nil
    local active = type(entry) == "table" and type(entry.ACTIVE_PROFILE) == "table" and entry.ACTIVE_PROFILE.value or nil
    if type(GetActiveRaidProfile) == "function" then
        local ok, name = pcall(GetActiveRaidProfile)
        if ok and type(name) == "string" then active = name end
    end
    local apiOption
    if type(GetRaidProfileOption) == "function" then
        apiOption = function(name, key)
            local ok, value = pcall(GetRaidProfileOption, name, key)
            if ok then return value end
            return false
        end
    end
    return RF.PickProfile(profiles, active, players, apiOption)
end

-- The client's flow container: the box it fills (the raid manager's resize handle sets it) and the
-- spacing between its objects, in UIParent units. Without the container, a wide default box.
function RF.ContainerBox()
    local container = _G.CompactRaidFrameContainer
    local ratio, w, h = 1, 1000, 400
    if container and container.GetWidth then
        ratio = (container:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
        w, h = container:GetWidth() or w, container:GetHeight() or h
    end
    local function spacing(key)
        local value = container and container[key]
        return type(value) == "number" and value or 0
    end
    return w, h, ratio, spacing("flowHorizontalSpacing"), spacing("flowVerticalSpacing")
end

local GROUP_TITLE, GROUP_SIZE = 14, 5   -- measured in game: a group is its 14 px title and five slots

-- Positions (x right, y down from the container's top-left) as the client's flow container lays the
-- buttons out. o = { count, w, h, petW, petH, hasPet = {}, together, horizontal, pets,
-- boxW, boxH, gapX, gapY }.
-- Kept together: every group is one block (title + five slots, empty slots included), a column when
-- groups are vertical and a row when they are horizontal. The blocks flow across (vertical groups) or
-- down (horizontal groups) and wrap at the edge of the box. Seen in game for a vertical group: the
-- block is w x (14 + 5h) and the flow runs across.
-- Not kept together: the buttons themselves flow the same way without titles. Not seen in game yet:
-- the first real raid replaces the guess with what the client really does (RF.LearnLayout).
-- Pets continue the same flow after everyone (the retail client adds them without a line break); ForeverUI
-- leaves them where the client puts them. No gaps anywhere: the client has none either.
function RF.ClientLayout(o)
    local out = { cells = {}, pets = {}, groups = {}, width = 0, height = 0 }
    local count = o.count or 0
    if count == 0 then return out end
    local w, h, gapX, gapY = o.w, o.h, o.gapX or 0, o.gapY or 0
    local across = not o.horizontal   -- primary direction of the flow: across (x) or down (y)
    local boxW, boxH = max(o.boxW or 1000, w), max(o.boxH or 400, h)
    -- flow state: position on the current line and the line's thickness
    local x, y, line = 0, 0, 0
    local function place(ow, oh)
        if across then
            if x > 0 and x + ow > boxW then x, y, line = 0, y + line + gapY, 0 end
            local px, py = x, y
            x = x + ow + gapX
            line = max(line, oh)
            return px, py
        end
        if y > 0 and y + oh > boxH then y, x, line = 0, x + line + gapX, 0 end
        local px, py = x, y
        y = y + oh + gapY
        line = max(line, ow)
        return px, py
    end
    if o.together then
        local groups = math.ceil(count / GROUP_SIZE)
        local gw = o.horizontal and GROUP_SIZE * w or w
        local gh = GROUP_TITLE + (o.horizontal and h or GROUP_SIZE * h)
        for g = 1, groups do
            local gx, gy = place(gw, gh)
            out.groups[g] = { x = gx, y = gy, w = gw, h = gh, index = g }
            for slot = 1, GROUP_SIZE do
                local i = (g - 1) * GROUP_SIZE + slot
                if i > count then break end
                local cx = gx + (o.horizontal and (slot - 1) * w or 0)
                local cy = gy + GROUP_TITLE + (o.horizontal and 0 or (slot - 1) * h)
                out.cells[i] = { cx, cy }
            end
        end
    else
        for i = 1, count do
            local cx, cy = place(w, h)
            out.cells[i] = { cx, cy }
        end
    end
    if o.pets then
        local petW, petH = o.petW or w, o.petH or max(12, floor(h / 2))
        for i = 1, count do
            if o.hasPet and o.hasPet[i] then
                local px, py = place(petW, petH)
                out.pets[#out.pets + 1] = { owner = i, x = px, y = py, w = petW, h = petH }
            end
        end
    end
    -- extent of everything placed
    local right, bottom = 0, 0
    for _, group in ipairs(out.groups) do
        right, bottom = max(right, group.x + group.w), max(bottom, group.y + group.h)
    end
    for _, cell in ipairs(out.cells) do right, bottom = max(right, cell[1] + w), max(bottom, cell[2] + h) end
    for _, pet in ipairs(out.pets) do right, bottom = max(right, pet.x + pet.w), max(bottom, pet.y + pet.h) end
    out.width, out.height = right, bottom
    return out
end

---------------------------------------------------------------------------------------------------
-- Groups per line (rfGroupsPerLine, 0 = as the client does it): how many kept-together groups stand side
-- by side before the next line starts. The client's flow container wraps its groups at its own edge (seen
-- in game: vertical groups flow across and wrap at the container's width), so the container only gets a
-- size that holds exactly that many groups across. No field of the client's is written: a value written
-- into the container (flowSortFunc, 2026-11-25) tainted its layout and blocked Show() in combat; a size is
-- read back from the C side and stays clean. The client lays the frames out again itself (its OnSizeChanged,
-- else its next layout). Horizontal groups (rows) flow down (a guess from retail): the box is as tall as
-- ceil(groups / N) rows, so N rows stand side by side, filled column by column. The other side of the box
-- grows when the lines need it: retail hides what does not fit. Out of combat only (the container holds
-- protected buttons). The client's own size is kept and comes back at 0.
---------------------------------------------------------------------------------------------------
RF.lines = {}   -- clientW, clientH: the client's own size; ownW, ownH: the size set here; sizing: guard

-- Pure: the box (w, h) for `perLine` groups along a line. o = { perLine, groups, players, w, h, horizontal,
-- pets, boxW, boxH, gapX, gapY } (container units; boxW, boxH = the client's box). nil when perLine < 1.
-- The reserve for pets (one per player, half height, after the groups in the flow) keeps them from being
-- hidden by the client for lack of room; it does not depend on how many pets there are now, so the box
-- (and the key of a learnt layout) stays the same while pets come and go.
function RF.LineBox(o)
    local n = floor(tonumber(o.perLine) or 0)
    if n < 1 then return end
    local w, h, gapX, gapY = o.w, o.h, o.gapX or 0, o.gapY or 0
    local groups = max(1, floor(tonumber(o.groups) or 1))
    local pets = o.pets and max(0, floor(tonumber(o.players) or groups * GROUP_SIZE)) or 0
    local petH = max(1, h / 2)
    local boxW, boxH = max(o.boxW or 0, w), max(o.boxH or 0, h)
    if not o.horizontal then
        local gw, gh = w, GROUP_TITLE + GROUP_SIZE * h
        local width = n * (gw + gapX) - gapX + gw / 2
        local lines = math.ceil(groups / n)
        local need = lines * (gh + gapY) - gapY
        if pets > 0 then
            local perLine = max(1, floor((width + gapX) / (w + gapX)))
            need = need + gapY + (math.ceil(pets / perLine) + 1) * (petH + gapY)
        end
        return width, max(boxH, need)
    end
    local gw, gh = GROUP_SIZE * w, GROUP_TITLE + h
    local rows = math.ceil(groups / n)
    local height = rows * (gh + gapY) - gapY + gh / 2
    local need = n * (gw + gapX) - gapX
    if pets > 0 then
        local perColumn = max(1, floor((height + gapY) / (petH + gapY)))
        need = need + gapX + (math.ceil(pets / perColumn) + 1) * (w + gapX)
    end
    return max(boxW, need), height
end

-- The groups the client shows now: used raid subgroups (plus the main tank and assist block when the
-- profile shows it and someone is flagged), 1 in a party or alone. Raid assignments only, no roles.
function RF.ShownGroups(profile)
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raid == 0 or type(GetRaidRosterInfo) ~= "function" then return 1, max(1, raid) end
    local used, count, flagged = {}, 0, false
    for i = 1, raid do
        local _, _, subgroup, _, _, _, _, _, _, assignment = GetRaidRosterInfo(i)
        if subgroup and not used[subgroup] then used[subgroup], count = true, count + 1 end
        if assignment == "MAINTANK" or assignment == "MAINASSIST" then flagged = true end
    end
    if flagged and profile and profile.flagged then count = count + 1 end
    return max(1, count), raid
end

-- The client's own box: its size before ForeverUI changed it, else the container as it is.
function RF.ClientBox()
    local w, h, ratio, gapX, gapY = RF.ContainerBox()
    local state = RF.lines
    if state.ownW and state.clientW then w, h = state.clientW, state.clientH end
    return w, h, ratio, gapX, gapY
end

-- The wanted number per line (0 = the client's layout).
function RF.PerLine()
    local settings = cfg()
    if not settings.rfEnabled then return 0 end
    return max(0, floor(tonumber(settings.rfGroupsPerLine) or 0))
end

local function setContainerSize(container, w, h)
    local state = RF.lines
    state.sizing = true
    if abs((container:GetWidth() or 0) - w) > 0.5 then container:SetWidth(w) end
    if abs((container:GetHeight() or 0) - h) > 0.5 then container:SetHeight(h) end
    state.sizing = nil
end

-- The client sizing its container (its resize handle, a profile): that is its new own size, and ours goes
-- back on top of it once combat allows.
local function hookLineSize(container)
    if container.foreverLinesHooked then return end
    container.foreverLinesHooked = true
    local function changed(width, height)
        local state = RF.lines
        if state.sizing then return end
        if type(width) == "number" then state.clientW = width end
        if type(height) == "number" then state.clientH = height end
        if state.ownW then ui.RunOutOfCombat("rfLines", RF.ApplyLines) end
    end
    local hooks = {
        SetWidth = function(_, width) changed(width, nil) end,
        SetHeight = function(_, height) changed(nil, height) end,
        SetSize = function(_, width, height) changed(width, height) end,
    }
    for method, hook in pairs(hooks) do
        if type(container[method]) == "function" then hooksecurefunc(container, method, hook) end
    end
end

function RF.ApplyLines()
    local container = _G.CompactRaidFrameContainer
    if not (container and container.GetWidth and container.SetWidth and container.SetHeight) then return end
    if InCombatLockdown() then
        ui.RunOutOfCombat("rfLines", RF.ApplyLines)
        return
    end
    hookLineSize(container)
    local state = RF.lines
    if not state.ownW then state.clientW, state.clientH = container:GetWidth(), container:GetHeight() end
    local n = RF.PerLine()
    local w, h
    if n >= 1 then
        local groups, players = RF.ShownGroups()
        local profile = RF.ClientProfile(players)
        if profile then groups = RF.ShownGroups(profile) end
        if profile and profile.together then
            local _, _, _, gapX, gapY = RF.ContainerBox()
            w, h = RF.LineBox({ perLine = n, groups = groups, players = players, w = profile.w, h = profile.h,
                horizontal = profile.horizontal, pets = profile.pets, boxW = state.clientW, boxH = state.clientH,
                gapX = gapX, gapY = gapY })
        end
    end
    if not w then
        -- Off, no profile or groups not kept together: the client's own size comes back.
        if state.ownW and state.clientW then setContainerSize(container, state.clientW, state.clientH) end
        state.ownW, state.ownH = nil, nil
        return
    end
    state.ownW, state.ownH = w, h
    setContainerSize(container, w, h)
end

-- A snapshot of the real layout, taken whenever the client shows a group (not while the samples hide
-- it): button size and the place of each player and pet button in the container, per profile, number
-- of players and box. The sample frames replay it exactly when the same case comes back.
local function layoutKey(count, profile, boxW, boxH, petMode)
    return ("%d/%dx%d/%s%s%s%s/%dx%d"):format(count, profile.w, profile.h, profile.together and "T" or "F",
        profile.horizontal and "H" or "V", profile.pets and "P" or "-", tostring(petMode or "client"):sub(1, 1),
        floor(boxW + 0.5), floor(boxH + 0.5))
end
RF.LayoutKey = layoutKey

-- Order of the client's buttons: group, then slot (CompactRaidGroup2Member3), else the button number.
local function buttonOrder(frame)
    local name = frame:GetName() or ""
    local group, member = name:match("Group(%d+)Member(%d+)$")
    if group then return tonumber(group) * 10 + tonumber(member) end
    member = name:match("Member(%d+)$") or name:match("(%d+)$")
    return tonumber(member) or 999
end

function RF.LearnLayout()
    if RF.templateFaded or RF.templateShown then return end
    local container = _G.CompactRaidFrameContainer
    if not (container and container:IsVisible()) then return end
    local players, pets = {}, {}
    for _, deco in ipairs(ordered) do
        if deco.frame:IsVisible() then
            local list = isPetDeco(deco) and pets or players
            list[#list + 1] = deco.frame
        end
    end
    if #players < 2 then return end
    local cl, _, _, ct = screenRect(container)
    if not cl then return end
    local boxW, boxH, ratio = RF.ContainerBox()
    local profile = RF.ClientProfile(#players)
    if not profile then return end
    table.sort(players, function(a, b) return buttonOrder(a) < buttonOrder(b) end)
    table.sort(pets, function(a, b) return buttonOrder(a) < buttonOrder(b) end)
    local snapshot = { cells = {}, pets = {}, ratio = ratio }
    local right, bottom = 0, 0
    local function add(list, frame)
        local l, b, r, t = screenRect(frame)
        if not l then return false end
        list[#list + 1] = { floor(l - cl + 0.5), floor(ct - t + 0.5), floor(r - l + 0.5), floor(t - b + 0.5) }
        right, bottom = max(right, r - cl), max(bottom, ct - b)
        return true
    end
    for _, frame in ipairs(players) do if not add(snapshot.cells, frame) then return end end
    for _, frame in ipairs(pets) do add(snapshot.pets, frame) end
    snapshot.width, snapshot.height = floor(right + 0.5), floor(bottom + 0.5)
    local settings = ui.Settings()
    if type(settings.rfSeenLayouts) ~= "table" then settings.rfSeenLayouts = {} end
    settings.rfSeenLayouts[layoutKey(#players, profile, boxW * ratio, boxH * ratio, "client")] = snapshot
    return snapshot
end

-- How many sample players: the option (0 = by group type: 5, 10, 25).
function RF.TemplateCount(kind)
    local chosen = tonumber(cfg().rfTemplateSize) or 0
    if chosen > 0 then return min(40, chosen) end
    return RF.templateKinds[kind] or 5
end

-- The plan of the sample frames: size, cells, pets, group titles and where it came from
-- ("seen" = the client's own layout, "profile" = computed from the client's raid profile,
-- "measured" = no profile, the old rows or columns of five).
function RF.TemplatePlan(kind, count, hasPet)
    local profile = RF.ClientProfile(count)
    local petMode = "client"   -- pets stay where the client puts them (part of the snapshot key)
    if profile then
        local boxW, boxH, ratio, gapX, gapY = RF.ClientBox()
        if profile.together then
            local lineW, lineH = RF.LineBox({ perLine = RF.PerLine(), groups = math.ceil(count / GROUP_SIZE),
                players = count, w = profile.w, h = profile.h, horizontal = profile.horizontal, pets = profile.pets,
                boxW = boxW, boxH = boxH, gapX = gapX, gapY = gapY })
            if lineW then boxW, boxH = lineW, lineH end
        end
        local w, h = floor(profile.w * ratio + 0.5), floor(profile.h * ratio + 0.5)
        local petH = max(8, floor(h / 2 + 0.5))
        local plan = RF.ClientLayout({ count = count, w = w, h = h, petW = w, petH = petH, hasPet = hasPet,
            together = profile.together, horizontal = profile.horizontal, pets = profile.pets,
            boxW = boxW * ratio, boxH = boxH * ratio, gapX = gapX * ratio, gapY = gapY * ratio })
        plan.w, plan.h, plan.petW, plan.petH, plan.source, plan.profile = w, h, w, petH, "profile", profile
        local seen = ui.Settings().rfSeenLayouts
        local snapshot = type(seen) == "table" and seen[layoutKey(count, profile, boxW * ratio, boxH * ratio, petMode)]
        if snapshot and #snapshot.cells == count then
            plan.source = "seen"
            for i, cell in ipairs(snapshot.cells) do plan.cells[i] = { cell[1], cell[2] } end
            if snapshot.cells[1] then plan.w, plan.h = snapshot.cells[1][3] or w, snapshot.cells[1][4] or h end
            -- Pets: the seen places when the sample has as many pets, else the computed ones.
            if #snapshot.pets == #plan.pets then
                for k, pet in ipairs(plan.pets) do
                    local spot = snapshot.pets[k]
                    pet.x, pet.y, pet.w, pet.h = spot[1], spot[2], spot[3] or pet.w, spot[4] or pet.h
                end
            end
            -- The titles cannot be told from a snapshot: only the pets block title is kept.
            local kept = {}
            for _, group in ipairs(plan.groups) do
                if group.pets and #snapshot.pets == #plan.pets then kept[#kept + 1] = group end
            end
            plan.groups = kept
            plan.width, plan.height = max(plan.width, snapshot.width or 0), max(plan.height, snapshot.height or 0)
        end
        return plan
    end
    -- No client profile: the real button size, groups kept together, rows or columns as last seen.
    local w, h, petW, petH = RF.TemplateMetrics()
    local boxW, boxH, ratio = RF.ClientBox()
    boxW, boxH = boxW * ratio, boxH * ratio
    local horizontal = RF.TemplateHorizontal(kind)
    local lineW, lineH = RF.LineBox({ perLine = RF.PerLine(), groups = math.ceil(count / GROUP_SIZE), players = count,
        w = w, h = h, horizontal = horizontal, pets = true, boxW = boxW, boxH = boxH })
    if lineW then boxW, boxH = lineW, lineH end
    local plan = RF.ClientLayout({ count = count, w = w, h = h, petW = petW, petH = petH, hasPet = hasPet,
        together = true, horizontal = horizontal, pets = true, boxW = boxW, boxH = boxH })
    plan.w, plan.h, plan.petW, plan.petH, plan.source = w, h, petW, petH, "measured"
    return plan
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
    local kind = RF.ViewKind()
    local count = RF.TemplateCount(kind)
    local hasPet, members = {}, {}
    for i = 1, count do
        local variant, data, pet = RF.TemplateMember(kind, i)
        members[i] = { variant, data, pet }
        hasPet[i] = pet ~= nil
    end
    -- measured before the real frames fade (they stay measurable: alpha does not hide them)
    local plan = RF.TemplatePlan(kind, count, hasPet)
    local w, h, petW, petH = plan.w, plan.h, plan.petW, plan.petH
    local key = kind .. "/" .. count .. "/" .. w .. "x" .. h .. "/" .. petW .. "x" .. petH
    if frame.poolKey ~= key then
        for _, list in ipairs({ frame.cells, frame.pets }) do
            for _, cell in ipairs(list) do cell:Hide() end
        end
        frame.pools[key] = frame.pools[key] or { cells = {}, pets = {} }
        frame.cells, frame.pets, frame.poolKey = frame.pools[key].cells, frame.pools[key].pets, key
    end
    for i = 1, count do
        placeCell(frame, frame.cells, i, members[i][1], w, h, members[i][2], plan.cells[i][1], -plan.cells[i][2])
    end
    for i = count + 1, #frame.cells do frame.cells[i]:Hide() end
    local petNames = { L("Волк", "Wolf"), L("Бес", "Imp") }
    for k, pet in ipairs(plan.pets) do
        local which = members[pet.owner][3] or 1
        placeCell(frame, frame.pets, k, "pet", petW, petH,
            { name = petNames[which], class = which == 2 and "WARLOCK" or "HUNTER" }, pet.x, -pet.y)
    end
    for k = #plan.pets + 1, #frame.pets do frame.pets[k]:Hide() end
    -- Group titles, as the client writes them above each kept-together group.
    frame.titles = frame.titles or {}
    for g, group in ipairs(plan.groups) do
        local title = frame.titles[g]
        if not title then
            title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            frame.titles[g] = title
        end
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", group.x + 2, -group.y - 1)
        if group.pets then
            title:SetText(L("Питомцы", "Pets"))
        elseif kind == "party" and g == 1 and not (plan.groups[2] and not plan.groups[2].pets) then
            title:SetText(L("Группа", "Party"))
        else
            title:SetText((L("Группа %d", "Group %d")):format(g))
        end
        title:Show()
    end
    for g = #plan.groups + 1, #frame.titles do frame.titles[g]:Hide() end
    frame:SetWidth(max(plan.width, 1))
    frame:SetHeight(max(plan.height, 1))
    RF.templatePlan = plan
    return plan
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
-- Diagnostics: /fuiraid profile — how the client lays out its raid frames (its raid profile, the
-- functions it has, the container and every shown button). The sample frames must follow the same
-- rules, and the client's Lua was never seen, so this is read in game first. The full snapshot goes to
-- ForeverStockUIDB.raidDumps[<group type>] (written to SavedVariables on /reload or logout); the chat
-- gets a short summary. Values only, ASCII text: some chat fonts print Cyrillic as "?".
---------------------------------------------------------------------------------------------------
local profileKeys = { "frameWidth", "frameHeight", "horizontalGroups", "keepGroupsTogether", "displayPets",
    "displayMainTankAndAssist", "displayPowerBar", "displayBorder", "sortBy", "healthText", "isDynamic", "locked",
    "shown", "autoActivate2Players", "autoActivate3Players", "autoActivate5Players", "autoActivate10Players",
    "autoActivate15Players", "autoActivate25Players", "autoActivate40Players", "autoActivatePvP", "autoActivatePvE" }
local profileFunctions = { "GetActiveRaidProfile", "GetRaidProfileOption", "GetRaidProfileFlattenedOptions",
    "GetNumRaidProfiles", "GetRaidProfileName", "RaidProfileExists", "GetRaidProfileSavedPosition",
    "CompactUnitFrameProfiles_ApplyProfile", "CompactUnitFrameProfiles_ApplyCurrentSettings",
    "CompactUnitFrameProfiles_ActivateRaidProfile", "CompactUnitFrameProfiles_GetAutoActivationState",
    "CompactUnitFrameProfiles_CheckAutoActivation", "CompactRaidFrameContainer_SetGroupMode",
    "CompactRaidFrameContainer_SetFlowFilterFunction", "CompactRaidFrameContainer_SetFlowSortFunction",
    "CompactRaidFrameContainer_SetDisplayPets", "CompactRaidFrameContainer_SetDisplayMainTankAndAssist",
    "CompactRaidFrameContainer_LayoutFrames", "CompactRaidFrameContainer_ApplyToFrames",
    "CompactRaidFrameManager_SetSetting", "CompactRaidFrameManager_ResizeFrame_UpdateContainerSize",
    "CompactRaidGroup_UpdateLayout", "CompactRaidGroup_GenerateForGroup", "CompactPartyFrame_UpdateLayout",
    "FlowContainer_DoLayout", "FlowContainer_SetOrientation", "FlowContainer_SetMaxPerLine",
    "FlowContainer_SetHorizontalSpacing", "FlowContainer_SetVerticalSpacing", "DefaultCompactUnitFrameSetup",
    "DefaultCompactMiniFrameSetup" }

local function plain(value)
    local kind = type(value)
    if kind == "number" then return floor(value * 100 + 0.5) / 100 end
    if kind == "string" or kind == "boolean" or kind == "nil" then return value end
    return "<" .. kind .. ">"
end

-- number, string and boolean fields of a frame (the client keeps its layout state there)
local function scalarFields(frame, limit)
    local out = {}
    if type(frame) ~= "table" then return out end
    local n = 0
    for key, value in pairs(frame) do
        local kind = type(value)
        if type(key) == "string" and (kind == "number" or kind == "string" or kind == "boolean") then
            out[key] = plain(value)
            n = n + 1
            if n >= (limit or 60) then break end
        end
    end
    return out
end

local function rectOf(frame, origin)
    if not (frame and frame.GetLeft) then return nil end
    local l, b, r, t = screenRect(frame)
    local rect = { shown = frame:IsShown() and true or false, visible = frame:IsVisible() and true or false,
        w = plain(frame:GetWidth()), h = plain(frame:GetHeight()), scale = plain(frame:GetScale()),
        effective = plain(frame:GetEffectiveScale() / UIParent:GetEffectiveScale()) }
    if l then
        rect.left, rect.top, rect.right, rect.bottom = plain(l), plain(t), plain(r), plain(b)
        if origin then rect.x, rect.y = plain(l - origin[1]), plain(origin[2] - t) end
    end
    local parent = frame:GetParent()
    rect.parent = parent and (parent:GetName() or "?") or "-"
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    if point then
        rect.point = ("%s %s %s %s %s"):format(point, relative and (relative:GetName() or "?") or "-",
            tostring(relativePoint), tostring(plain(x)), tostring(plain(y)))
    end
    return rect
end

function RF.DumpProfile()
    local dump = { kind = RF.LiveKind(), raid = GetNumRaidMembers and GetNumRaidMembers() or -1,
        party = GetNumPartyMembers and GetNumPartyMembers() or -1, functions = {}, missing = {} }
    for _, name in ipairs(profileFunctions) do
        if type(_G[name]) == "function" then
            dump.functions[#dump.functions + 1] = name
        else
            dump.missing[#dump.missing + 1] = name
        end
    end
    -- The client API (retail names), when there is one.
    local api = {}
    if type(GetActiveRaidProfile) == "function" then
        local ok, active = pcall(GetActiveRaidProfile)
        api.active = ok and plain(active) or "error"
        if ok and active and type(GetRaidProfileOption) == "function" then
            api.options = {}
            for _, key in ipairs(profileKeys) do
                local okOption, value = pcall(GetRaidProfileOption, active, key)
                api.options[key] = okOption and plain(value) or "error"
            end
        end
    end
    if type(GetNumRaidProfiles) == "function" then
        local ok, count = pcall(GetNumRaidProfiles)
        api.count = ok and plain(count) or "error"
    end
    dump.api = api
    -- The saved table of the client, for this character.
    local db = _G.CompactRaidFrameDB
    local char = UnitName("player")
    local saved = { present = type(db) == "table", char = type(db) == "table" and type(db[char]) == "table" }
    if saved.char then
        local entry = db[char]
        saved.active = type(entry.ACTIVE_PROFILE) == "table" and plain(entry.ACTIVE_PROFILE.value) or plain(entry.ACTIVE_PROFILE)
        saved.profiles = {}
        local list = type(entry.PROFILES) == "table" and entry.PROFILES.value or nil
        for i, profile in ipairs(type(list) == "table" and list or {}) do
            local copy = { index = i, active = profile.name == saved.active }
            for _, key in ipairs(profileKeys) do copy[key] = plain(profile[key]) end
            saved.profiles[i] = copy
        end
        saved.keys = {}
        for key in pairs(entry) do saved.keys[#saved.keys + 1] = tostring(key) end
    end
    dump.saved = saved
    -- The container, the group frames and every unit button with its place in the container.
    local raid, party = containers()
    local origin
    if raid and raid.GetLeft then
        local l, _, _, t = screenRect(raid)
        if l then origin = { l, t } end
    end
    dump.container = rectOf(raid)
    dump.containerFields = scalarFields(raid)
    dump.partyFrame = rectOf(party)
    dump.partyFields = scalarFields(party, 30)
    dump.manager = rectOf(_G.CompactRaidFrameManager)
    dump.managerFields = scalarFields(_G.CompactRaidFrameManager, 40)
    dump.groups = {}
    for i = 1, 8 do
        local group = _G["CompactRaidGroup" .. i]
        if group then
            local rect = rectOf(group, origin)
            rect.index = i
            rect.fields = scalarFields(group, 20)
            dump.groups[#dump.groups + 1] = rect
        end
    end
    dump.buttons = {}
    for _, deco in ipairs(ordered) do
        local frame = deco.frame
        if frame:IsVisible() then
            local rect = rectOf(frame, origin)
            rect.name = frame:GetName() or "?"
            rect.unit = plain(deco.unit or frame.displayedUnit or frame.unit)
            rect.pet = isPetDeco(deco) or nil
            -- The first button also keeps its power bar line (geometry and colour from the client).
            if #dump.buttons == 0 then rect.power = RF.DescribePower(deco) end
            dump.buttons[#dump.buttons + 1] = rect
        end
    end
    dump.horizontalSeen = RF.IsHorizontal()
    -- Groups per line: the client's own box, the one set here and whether the client re-lays on a new size.
    local lines = RF.lines
    dump.lines = { perLine = RF.PerLine(), clientW = plain(lines.clientW), clientH = plain(lines.clientH),
        ownW = plain(lines.ownW), ownH = plain(lines.ownH), orientation = plain(raid and raid.flowOrientation),
        groupMode = plain(raid and raid.groupMode),
        sizeScript = raid and raid.GetScript and raid:GetScript("OnSizeChanged") ~= nil or false }
    dump.metrics = { RF.TemplateMetrics() }
    -- What the sample frames would use now for this group type.
    local viewKind = RF.ViewKind()
    local count = RF.TemplateCount(viewKind)
    local has = {}
    for i = 1, count do has[i] = select(3, RF.TemplateMember(viewKind, i)) ~= nil end
    local plan = RF.TemplatePlan(viewKind, count, has)
    local snapshots = 0
    for _ in pairs(type(ui.Settings().rfSeenLayouts) == "table" and ui.Settings().rfSeenLayouts or {}) do
        snapshots = snapshots + 1
    end
    dump.template = { count = count, source = plan.source, w = plan.w, h = plan.h, groups = #plan.groups,
        width = plan.width, height = plan.height, snapshots = snapshots }
    local settings = ui.Settings()
    if type(settings.raidDumps) ~= "table" then settings.raidDumps = {} end
    -- One snapshot per group size: raids over 25 apart, since the client may lay out 40 differently.
    local key = dump.raid > 25 and "raid40" or dump.raid > 0 and dump.kind or dump.party > 0 and "party" or "solo"
    dump.key = key
    settings.raidDumps[key] = dump
    return dump
end

local function printProfile(dump)
    local function yesno(value) return value == nil and "-" or tostring(value) end
    ui.Print(("Raid profile dump [%s]: raid=%d party=%d, saved to ForeverStockUIDB.raidDumps (/reload writes it)")
        :format(dump.key, dump.raid, dump.party))
    ui.Print(("Client API: %d of %d functions. Active (API): %s"):format(#dump.functions,
        #dump.functions + #dump.missing, yesno(dump.api.active and "yes")))
    local options = dump.api.options
    if not options then
        for _, profile in ipairs(dump.saved.profiles or {}) do
            if profile.active or not options then options = profile end
        end
    end
    if options then
        ui.Print(("Profile: %sx%s horizontal=%s together=%s pets=%s tanks=%s power=%s border=%s sort=%s"):format(
            yesno(options.frameWidth), yesno(options.frameHeight), yesno(options.horizontalGroups),
            yesno(options.keepGroupsTogether), yesno(options.displayPets), yesno(options.displayMainTankAndAssist),
            yesno(options.displayPowerBar), yesno(options.displayBorder), yesno(options.sortBy)))
    else
        ui.Print("Profile: not found (no API, no CompactRaidFrameDB entry for this character)")
    end
    local c = dump.container
    if c then
        ui.Print(("Container: %sx%s scale=%s effective=%s shown=%s"):format(yesno(c.w), yesno(c.h), yesno(c.scale),
            yesno(c.effective), yesno(c.visible)))
    end
    local first, second = dump.buttons[1], dump.buttons[2]
    ui.Print(("Buttons shown: %d, groups: %d, horizontal seen: %s"):format(#dump.buttons, #dump.groups,
        tostring(dump.horizontalSeen)))
    if first then
        ui.Print(("First: %sx%s at %s,%s; second at %s,%s"):format(yesno(first.w), yesno(first.h), yesno(first.x),
            yesno(first.y), yesno(second and second.x), yesno(second and second.y)))
    end
    local lines = dump.lines
    if lines then
        ui.Print(("Lines: per line=%s client=%sx%s own=%sx%s orientation=%s mode=%s onSizeChanged=%s"):format(
            yesno(lines.perLine), yesno(lines.clientW), yesno(lines.clientH), yesno(lines.ownW), yesno(lines.ownH),
            yesno(lines.orientation), yesno(lines.groupMode), yesno(lines.sizeScript)))
    end
    local plan = dump.template
    if plan then
        ui.Print(("Samples: %d players from %s, %sx%s, %s groups, %d snapshots saved"):format(plan.count, plan.source,
            yesno(plan.w), yesno(plan.h), yesno(plan.groups), plan.snapshots))
    end
end
RF.PrintProfile = printProfile

SLASH_FOREVERUIRAID1 = "/fuiraid"
-- /fuiraid perf: the first call starts a measurement, the next one prints it (stops by itself after
-- PERF_LIMIT seconds and prints then). ASCII only: some client chat fonts print Cyrillic as "?".
local PERF_LIMIT = 120
local perfTimer = CreateFrame("Frame")
local function perfFinish()
    perfTimer:SetScript("OnUpdate", nil)
    local lines = RF.PerfEnd()
    for _, line in ipairs(lines) do ui.Print(line) end
    local settings = ui.Settings()
    settings.raidPerf = lines   -- kept in the saved variables too, to send it on
end

function RF.TogglePerf()
    if RF.perf.on then
        perfFinish()
        return
    end
    if not RF.PerfBegin() then
        ui.Print("raid frames perf: debugprofilestop is missing on this client")
        return
    end
    ui.Print(("raid frames perf: measuring; /fuiraid perf again to print (stops by itself after %d s)"):format(PERF_LIMIT))
    local waited = 0
    perfTimer:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + elapsed
        if waited >= PERF_LIMIT then perfFinish() end
    end)
end

SlashCmdList.FOREVERUIRAID = function(input)
    if (input or ""):lower():match("preview") then
        RF.ToggleTemplate()
        return
    end
    if (input or ""):lower():match("perf") then
        RF.TogglePerf()
        return
    end
    RF.Scan()
    if (input or ""):lower():match("profile") then
        printProfile(RF.DumpProfile())
        return
    end
    if (input or ""):lower():match("pos") then
        -- Where the group should stand (saved spot of this talent set) and where it really is. ASCII only.
        local config = editEntry() and editEntry().config or {}
        local position = type(config.position) == "table" and config.position or {}
        ui.Print(("Talent set %s, move=%s, saved x=%s y=%s width=%s pinX=%s lastX=%s"):format(
            tostring(GetActiveTalentGroup and GetActiveTalentGroup()), tostring(cfg().rfMoveContainer),
            tostring(position[1]), tostring(position[2]), tostring(config.width), tostring(config.pinX),
            tostring(config.lastX)))
        local function where(frame)
            if not frame then return "-" end
            local point, relative, relativePoint, x, y = frame:GetPoint(1)
            return ("%s %s %s %.1f %.1f (%d points) left=%s top=%s"):format(tostring(point),
                relative and (relative:GetName() or "?") or "-", tostring(relativePoint), x or 0, y or 0,
                frame:GetNumPoints(), tostring(frame:GetLeft()), tostring(frame:GetTop()))
        end
        ui.Print("Anchor: " .. where(anchor))
        local raid, party = containers()
        ui.Print("CompactRaidFrameContainer: " .. where(raid))
        ui.Print("CompactPartyFrame: " .. where(party))
        return
    end
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
        ui.Print(RF.DescribePower(deco))
    end
    -- The client's role icons as ForeverUI reads them (what rfHideDamagerIcon decides on), first 6. ASCII only.
    local roleLines = 0
    for _, d in ipairs(ordered) do
        local icon = d.frame.roleIcon
        if roleLines < 6 and icon and icon.IsShown and icon:IsShown() and icon.GetTexture and icon:GetTexture() then
            roleLines = roleLines + 1
            local l, t = icon:GetTexCoord()
            ui.Print(("Role icon %s: %s coords %.3f,%.3f -> %s alpha %.2f"):format(d.frame:GetName() or "?",
                tostring(icon:GetTexture()), tonumber(l) or -1, tonumber(t) or -1, tostring(RF.ClientRoleOf(icon) or "-"),
                icon:GetAlpha() or 0))
        end
    end
    local hooks = {}
    for _, name in ipairs({ "CompactUnitFrame_UpdateAll", "CompactUnitFrame_SetUpFrame", "CompactUnitFrame_UpdateHealPrediction",
        "CompactUnitFrame_UpdateAuras", "CompactRaidFrameContainer_LayoutFrames" }) do
        if type(_G[name]) == "function" then hooks[#hooks + 1] = name end
    end
    ui.Print(L("Хуки: ", "Hooks: ") .. (#hooks > 0 and table.concat(hooks, ", ") or "-"))
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
end
