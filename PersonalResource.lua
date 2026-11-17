-- ForeverUI Personal Resource Display: a vertical stack under the character with the player's procs,
-- health (incoming heals, shields, critical glow), the primary power (druid forms, druid mana, energy
-- tick, five second rule) and the WotLK class resource (combo points, death knight runes, shaman
-- totems, tracked stacks, soul shards). It fades out when nothing happens and wakes on combat, an
-- attackable target or any change of health and resources.
--
-- WotLK 3.3.5a notes: powers fire UNIT_MANA / UNIT_RAGE / UNIT_ENERGY / UNIT_RUNIC_POWER (no
-- UNIT_POWER); combo points fire UNIT_COMBO_POINTS; runes RUNE_POWER_UPDATE / RUNE_TYPE_UPDATE
-- (slots 1-2 Blood, 3-4 Unholy, 5-6 Frost, type 4 = Death); totems PLAYER_TOTEM_UPDATE with slots
-- 1 Fire, 2 Earth, 3 Water, 4 Air. UnitBuff returns the spell id as the 11th value. There is no heal
-- prediction API in the stock client: UnitGetIncomingHeals (if the Nozdor client has it) wins, then
-- LibHealComm-4.0 (if another addon ships it). Absorb amounts come from UnitGetTotalAbsorbs when it
-- exists; otherwise known shield auras only light the shield border. Everything here is plain
-- (insecure) frames, so nothing waits for combat to end.
--
-- Performance: every update is event driven. The single OnUpdate on `driver` runs only while a bar
-- animates, the panel fades, a rune or totem counts down, an aura timer is visible or a spark moves,
-- and its text work is throttled to 10 Hz.
local _, ui = ...
local L = ui.L
local floor, ceil, max, min, abs, format = math.floor, math.ceil, math.max, math.min, math.abs, string.format
local WHITE = "Interface\\Buttons\\WHITE8X8"

local PRD = {}
ui.PersonalResource = PRD

local _, playerClass = UnitClass("player")
PRD.class = playerClass

---------------------------------------------------------------------------------------------------
-- Settings: per talent group or shared (ui.Settings().prdProfiles), read through a lazy cache
---------------------------------------------------------------------------------------------------
local function mainDB() return ui.Settings() end

function PRD.TalentGroup()
    return GetActiveTalentGroup and GetActiveTalentGroup() or 1
end

-- The table the per-spec options of the schema live in. A spec table is created from the shared one.
function PRD.DB()
    local s = mainDB()
    if type(s.prdProfiles) ~= "table" then s.prdProfiles = {} end
    local profiles = s.prdProfiles
    if type(profiles.shared) ~= "table" then profiles.shared = {} end
    -- The bar texture used to default to WoW: Forever (2); the stock one (1) is the default now.
    for _, t in pairs(profiles) do
        if type(t) == "table" and not t.prdStockTexture then
            if t.prdTexture == 2 then t.prdTexture = 1 end
            t.prdStockTexture = true
        end
    end
    if not s.prdPerSpec then return profiles.shared end
    local group = PRD.TalentGroup()
    if type(profiles[group]) ~= "table" then profiles[group] = ui.CopyTable and ui.CopyTable(profiles.shared) or {} end
    return profiles[group]
end

-- Copies the settings of the other talent group (or the shared set) into the edited one.
function PRD.CopyFrom(source)
    local s = mainDB()
    local profiles = s.prdProfiles or {}
    local from = profiles[source]
    if type(from) ~= "table" then return false end
    local target = PRD.DB()
    if target == from then return false end
    for k in pairs(target) do target[k] = nil end
    for k, v in pairs(ui.CopyTable and ui.CopyTable(from) or from) do target[k] = v end
    PRD.Apply()
    ui.Fire("OptionsRefresh", "prd")
    return true
end

local cache
local function resetCache()
    cache = setmetatable({}, { __index = function(t, key)
        local value = ui.GetOption and ui.GetOption("prd", key)
        if value ~= nil then rawset(t, key, value) end
        return value
    end })
end
resetCache()
local function C(key) return cache[key] end
PRD.Get = C

---------------------------------------------------------------------------------------------------
-- Static data
---------------------------------------------------------------------------------------------------
PRD.powerColors = {
    [0] = { 0.20, 0.45, 1.00 },  -- mana
    [1] = { 0.90, 0.15, 0.15 },  -- rage
    [2] = { 1.00, 0.50, 0.25 },  -- focus (hunter pets)
    [3] = { 1.00, 0.90, 0.20 },  -- energy
    [6] = { 0.00, 0.82, 1.00 },  -- runic power
}
PRD.runeColors = {
    [1] = { 1.00, 0.25, 0.30 },  -- Blood
    [2] = { 0.35, 0.85, 0.25 },  -- Unholy
    [3] = { 0.35, 0.70, 1.00 },  -- Frost
    [4] = { 0.75, 0.40, 0.95 },  -- Death
}
PRD.runeOrders = {
    buf = { 1, 2, 3, 4, 5, 6 },  -- Blood, Unholy, Frost
    bfu = { 1, 2, 5, 6, 3, 4 },  -- Blood, Frost, Unholy
    fub = { 5, 6, 3, 4, 1, 2 },
    ufb = { 3, 4, 5, 6, 1, 2 },
}
PRD.totemOrder = { 1, 2, 3, 4 }  -- Fire, Earth, Water, Air (GetTotemInfo slots)
PRD.totemColors = {
    [1] = { 1.00, 0.45, 0.10 }, [2] = { 0.65, 0.48, 0.22 }, [3] = { 0.20, 0.55, 1.00 }, [4] = { 0.70, 0.85, 1.00 },
}

-- Procs that ask for an immediate press: the icon border glows.
PRD.procIDs = {
    59578, 53489,       -- The Art of War
    57761,              -- Brain Freeze (Fireball!)
    48108,              -- Hot Streak
    44401,              -- Missile Barrage
    12536, 16870,       -- Clearcasting (mage, druid)
    46916,              -- Bloodsurge (Slam!)
    52437,              -- Sudden Death
    50227,              -- Sword and Board
    60503,              -- Taste for Blood
    59052,              -- Freezing Fog (Rime)
    51124,              -- Killing Machine
    48517, 48518,       -- Eclipse
    17941,              -- Shadow Trance (Nightfall)
    34936,              -- Backlash
    63167,              -- Decimation
    71165,              -- Molten Core
    33151,              -- Surge of Light
    54149,              -- Infusion of Light
    56453,              -- Lock and Load
    64823,              -- Elune's Wrath (4T8)
    69369,              -- Predator's Swiftness
    53817,              -- Maelstrom Weapon (glows at 5 stacks only)
}
-- Short personal cooldowns and talents worth seeing in the middle of the screen in every filter mode.
PRD.importantIDs = {
    871, 12975, 2565, 55694, 1719, 12292, 46924, 18499,          -- warrior
    48792, 48707, 55233, 49222, 51271, 49016, 49039,             -- death knight
    22812, 61336, 50334, 29166, 22842, 17116,                    -- druid
    498, 642, 31884, 54428, 20216, 31842, 53563,                 -- paladin
    26669, 31224, 13750, 13877, 51713, 5277, 57934, 51690,       -- rogue
    45438, 12472, 12042, 12043, 11129, 66, 44544,                -- mage
    33206, 47788, 10060, 14751, 15286, 47585, 63735,             -- priest
    16188, 16166, 30823, 2825, 32182, 53390, 51466,              -- shaman
    19263, 3045, 34471, 53220, 34477, 56453,                     -- hunter
    63167, 47241, 18708, 17941, 71165,                           -- warlock
    2825, 32182, 54758, 55004, 59626, 60064, 67737,              -- Heroism / Bloodlust, gloves, trinkets
}
-- Long raid buffs hidden by default (the smart filter already drops buffs cast by others and long ones).
PRD.raidBuffIDs = {
    1126, 21849, 48469, 48470,          -- Mark / Gift of the Wild
    19740, 25898, 20217, 25899, 48932, 48934, 48936, 48938, 20911, 25782, -- Blessings
    1243, 21562, 48161, 48162,          -- Power Word: Fortitude / Prayer
    14752, 27681, 48073, 48074,         -- Divine Spirit / Prayer of Spirit
    976, 27683, 48169, 48170,           -- Shadow Protection
    1459, 23028, 42995, 43002, 61024, 61316, -- Arcane Intellect / Brilliance / Dalaran
    6673, 47436, 469, 47440,            -- Battle Shout, Commanding Shout
    57330, 57623, 19506, 53138,         -- Horn of Winter, Trueshot, Abomination's Might
    465, 7294, 19746, 19891, 19876, 19888, 19897, 32223, 54043, -- paladin auras
    24907, 24932, 50170, 29801, 53648, 30808, 31869, 75447, -- Moonkin, Leader of the Pack, Rampage, Unleashed Rage, Arcane Empowerment, Ferocious Inspiration
    8076, 8075, 5677, 5675, 8836, 8515, 3738, 52109, 58753, -- totem auras
}
-- Shields: their presence lights the shield border when the client tells no absorb amount.
PRD.shieldIDs = { 17, 53601, 58597, 11426, 1463, 47753, 543, 6143, 6229, 48707, 64413, 64411, 7812 }

-- Stack trackers by class: the first aura found wins ("auto"); max is the segment count.
PRD.stackSets = {
    SHAMAN = { { id = 53817, max = 5 }, { id = 324, max = 3 }, { id = 52127, max = 3 }, { id = 974, max = 8 } },
    DEATHKNIGHT = { { id = 49222, max = 3 } },
    PRIEST = { { id = 63735, max = 3 }, { id = 15258, max = 5 } },
    MAGE = { { id = 36032, max = 4, harmful = true } },
    WARLOCK = { { shards = 6265 } },
}

PRD.sampleAuras = {
    { id = 53817, count = 5, glow = true, duration = 30, left = 21 },
    { id = 59578, glow = true, duration = 15, left = 9 },
    { id = 871, duration = 12, left = 6.5 },
    { id = 2825, duration = 40, left = 33 },
    { id = 60064, duration = 10, left = 3.2 },
}

local function spellName(id)
    local name = GetSpellInfo and GetSpellInfo(id)
    return name
end

local function buildSet(ids)
    local set = { ids = {}, names = {} }
    for _, id in ipairs(ids) do
        set.ids[id] = true
        local name = spellName(id)
        if name then set.names[name] = true end
    end
    return set
end

local sets
local function staticSets()
    if not sets then
        sets = { procs = buildSet(PRD.procIDs), important = buildSet(PRD.importantIDs),
            raid = buildSet(PRD.raidBuffIDs), shields = buildSet(PRD.shieldIDs) }
    end
    return sets
end
PRD.StaticSets = staticSets

local function inSet(set, name, id)
    return (id and set.ids[id]) or (name and set.names[name]) or false
end

-- User lists: names or spell ids separated by commas, semicolons or new lines.
function PRD.ParseList(text)
    local set = { ids = {}, names = {} }
    if type(text) ~= "string" then return set end
    for token in text:gmatch("[^,;\n]+") do
        token = token:gsub("^%s+", ""):gsub("%s+$", "")
        if token ~= "" then
            local id = tonumber(token)
            if id then
                set.ids[id] = true
                local name = spellName(id)
                if name then set.names[name] = true end
            else
                set.names[token] = true
            end
        end
    end
    return set
end

---------------------------------------------------------------------------------------------------
-- Formatting and colours
---------------------------------------------------------------------------------------------------
function PRD.Short(value)
    value = value or 0
    if value >= 1000000 then return format("%.1fM", value / 1000000) end
    if value >= 10000 then return format("%.0fk", value / 1000) end
    if value >= 1000 then return format("%.1fk", value / 1000) end
    return tostring(floor(value + 0.5))
end

function PRD.FormatValue(mode, current, most)
    if mode == "none" or not most or most <= 0 then return "" end
    local pct = floor(current / most * 100 + 0.5)
    if mode == "percent" then return pct .. "%" end
    if mode == "current" then return PRD.Short(current) end
    if mode == "full" then return PRD.Short(current) .. " / " .. PRD.Short(most) end
    return PRD.Short(current) .. " | " .. pct .. "%"   -- "both"
end

function PRD.FormatTime(left)
    if not left or left <= 0 then return "" end
    if left >= 3600 then return ceil(left / 3600) .. "h" end
    if left >= 60 then return ceil(left / 60) .. "m" end
    if left >= 10 then return tostring(floor(left)) end
    return format("%.1f", left)
end

-- Green at full health, yellow at half, red when empty.
function PRD.GradientColor(fraction)
    fraction = max(0, min(1, fraction or 0))
    if fraction > 0.5 then return (1 - fraction) * 2, 0.85, 0.1 end
    return 1, fraction * 2 * 0.85, 0.1
end

function PRD.ClassColor()
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[playerClass]
    if color then return color.r, color.g, color.b end
    return 0.2, 0.8, 0.2
end

local function rgb(value, fallback)
    value = type(value) == "table" and value or fallback
    return value[1] or 1, value[2] or 1, value[3] or 1, value[4]
end

local function shown(region, visible)
    if visible then region:Show() else region:Hide() end
end

local function fontPath() return ui.MediaPath and ui.MediaPath("font", C("prdFont") or 1, true) or STANDARD_TEXT_FONT end
local function barPath() return ui.MediaPath and ui.MediaPath("statusbar", C("prdTexture") or 2, true) or WHITE end

local function setFont(text, size)
    local outline = C("prdFontOutline")
    text:SetFont(fontPath() or STANDARD_TEXT_FONT, size or C("prdFontSize") or 11, outline ~= "" and outline or nil)
    text:SetShadowOffset(outline == "" and 1 or 0, outline == "" and -1 or 0)
end

---------------------------------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------------------------------
local root = CreateFrame("Frame", "ForeverStockUIPersonalResource", UIParent)
root:SetFrameStrata("MEDIUM")
root:SetClampedToScreen(true)
root:SetWidth(220)
root:SetHeight(40)
root:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
root:SetAlpha(0)
root:Hide()
PRD.root = root

local function skin(frame, alpha)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    frame:SetBackdropColor(0.04, 0.04, 0.05, alpha or 0.6)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
end

local function newText(parent, layer)
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    return text
end

-- A bordered status bar. `smooth` bars glide to their target value on the driver.
local smoothBars = {}
local function newBar(parent, smooth)
    local holder = CreateFrame("Frame", nil, parent)
    skin(holder)
    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetStatusBarTexture(WHITE)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture(WHITE)
    bar.target, bar.current = 0, 0
    holder.bar = bar
    holder.text = newText(bar)
    holder.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    if smooth then smoothBars[#smoothBars + 1] = bar end
    return holder
end

-- A soft glow around a frame (critical health, shield, max combo points, proc icons).
local function newGlow(parent, size)
    local glow = CreateFrame("Frame", nil, parent)
    glow:SetPoint("TOPLEFT", -(size or 2), size or 2)
    glow:SetPoint("BOTTOMRIGHT", size or 2, -(size or 2))
    glow:SetBackdrop({ edgeFile = WHITE, edgeSize = size or 2 })
    glow:SetFrameLevel(parent:GetFrameLevel() + 5)
    glow:Hide()
    return glow
end

-- Aura strip -------------------------------------------------------------------------------------
local auraStrip = CreateFrame("Frame", nil, root)
auraStrip:SetHeight(24)
local auraIcons = {}
PRD.auraIcons = auraIcons

local function auraIcon(index)
    local icon = auraIcons[index]
    if icon then return icon end
    icon = CreateFrame("Button", nil, auraStrip)
    skin(icon, 1)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetPoint("TOPLEFT", 1, -1)
    icon.texture:SetPoint("BOTTOMRIGHT", -1, 1)
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints(icon.texture)
    if icon.cooldown.SetDrawEdge then icon.cooldown:SetDrawEdge(false) end
    icon.cooldown.noCooldownCount = true   -- OmniCC and friends: we draw our own timer
    local top = CreateFrame("Frame", nil, icon)
    top:SetAllPoints()
    top:SetFrameLevel(icon.cooldown:GetFrameLevel() + 2)
    icon.timer = newText(top)
    icon.timer:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
    icon.count = newText(top)
    icon.count:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -1)
    icon.glow = newGlow(icon, 2)
    icon:EnableMouse(PRD.mouseOn or false)
    icon:SetScript("OnEnter", function(self)
        if not self.auraIndex and not self.spellId then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.auraIndex then
            GameTooltip:SetUnitBuff("player", self.auraIndex)
        else
            GameTooltip:SetHyperlink("spell:" .. self.spellId)
        end
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    auraIcons[index] = icon
    return icon
end

-- Health ------------------------------------------------------------------------------------------
local health = newBar(root, true)
PRD.health = health
health.heal = health.bar:CreateTexture(nil, "ARTWORK")
health.heal:SetTexture(WHITE)
health.heal:Hide()
health.absorb = health.bar:CreateTexture(nil, "ARTWORK")
health.absorb:SetTexture(WHITE)
health.absorb:Hide()
health.critical = newGlow(health, 2)
health.shieldGlow = newGlow(health, 1)
health.text:SetDrawLayer("OVERLAY")

-- Power -------------------------------------------------------------------------------------------
local power = newBar(root, true)
PRD.power = power
power.spark = power.bar:CreateTexture(nil, "OVERLAY")
power.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
power.spark:SetBlendMode("ADD")
power.spark:SetWidth(10)
power.spark:Hide()

local druidMana = newBar(root, true)
PRD.druidMana = druidMana
druidMana.text:Hide()

-- Class module: up to 6 cells (combo, runes, totems, stacks) ---------------------------------------
local classFrame = CreateFrame("Frame", nil, root)
PRD.classFrame = classFrame
-- The bars sit above the class row, so even a glow of a cell never covers them.
classFrame:SetFrameLevel(root:GetFrameLevel() + 1)
health:SetFrameLevel(root:GetFrameLevel() + 4)
power:SetFrameLevel(root:GetFrameLevel() + 4)
druidMana:SetFrameLevel(root:GetFrameLevel() + 4)
local cells = {}
PRD.cells = cells
local function cell(index)
    local c = cells[index]
    if c then return c end
    c = newBar(classFrame, false)
    c.icon = c.bar:CreateTexture(nil, "ARTWORK")
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.icon:Hide()
    c.glow = newGlow(c, 1)
    c.text:ClearAllPoints()
    c.text:SetPoint("CENTER", c.bar, "CENTER", 0, 0)
    c:EnableMouse(false)
    c:SetScript("OnEnter", function(self)
        if self.totemSlot and GameTooltip.SetTotem then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetTotem(self.totemSlot)
            GameTooltip:Show()
        end
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cells[index] = c
    return c
end
for i = 1, 6 do cell(i) end
local classLabel = newText(classFrame)   -- soul shard counter
classLabel:SetPoint("LEFT", classFrame, "RIGHT", 4, 0)
PRD.classLabel = classLabel


---------------------------------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------------------------------
local state = {
    combat = false, hostile = false, mouse = false, busy = false,
    powerType = 0, lastPower = nil, energyTick = nil, tickGap = nil, fiveStart = nil,
    critical = false, criticalFlash = 0, shield = false, absorb = 0, heal = 0,
    runesBusy = false, totemsBusy = false, timedAuras = false, combo = 0,
    alpha = 0, targetAlpha = 0, stacks = 0,
}
PRD.state = state
PRD.test = false

local function enabled() return C("prdEnabled") ~= false end

---------------------------------------------------------------------------------------------------
-- Health
---------------------------------------------------------------------------------------------------
local healComm
PRD.healSource = UnitGetIncomingHeals and "api" or nil

function PRD.IncomingHeals()
    if UnitGetIncomingHeals then return UnitGetIncomingHeals("player") or 0 end
    if healComm then
        local guid = UnitGUID("player")
        local amount = guid and healComm:GetHealAmount(guid, healComm.ALL_HEALS, GetTime() + 4)
        return (amount or 0) * (healComm:GetHealModifier(guid) or 1)
    end
    return 0
end

function PRD.Absorbs()
    if UnitGetTotalAbsorbs then return UnitGetTotalAbsorbs("player") or 0 end
    return 0
end

local function healthValues()
    if PRD.test then return 72, 100, 12, 8 end
    local cur, most = UnitHealth("player") or 0, UnitHealthMax("player") or 0
    return cur, most, PRD.IncomingHeals(), PRD.Absorbs()
end

-- New value of a bar: set at once, or glide there on the driver. The driver must be started here: it
-- used to start only when the opacity changed, so a fully visible panel (combat, target) froze its bars.
function PRD.SetBarTarget(bar, fraction)
    fraction = max(0, min(1, fraction or 0))
    bar.target = fraction
    if not C("prdSmooth") then
        bar.current = fraction
        bar:SetValue(fraction)
    elseif abs(fraction - (bar.current or 0)) > 0.0005 then
        PRD.Run()
    else
        bar.current = fraction
        bar:SetValue(fraction)
    end
end

local function placeOverlay(texture, anchor, offset, width, fraction, maxFraction, r, g, b, a)
    local w = width * max(0, min(fraction, maxFraction))
    if w < 1 then texture:Hide() return 0 end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", anchor, "TOPRIGHT", offset, 0)
    texture:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", offset, 0)
    texture:SetWidth(w)
    texture:SetVertexColor(r, g, b, a)
    texture:Show()
    return w
end

function PRD.ColorHealth(fraction)
    local mode = C("prdHealthColorMode")
    local r, g, b
    if mode == "gradient" then
        r, g, b = PRD.GradientColor(fraction)
    elseif mode == "custom" then
        r, g, b = rgb(C("prdHealthColor"), { 0.2, 0.8, 0.2 })
    else
        r, g, b = PRD.ClassColor()
    end
    health.bar:SetStatusBarColor(r, g, b)
    health.bar.bg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2, 0.85)
end

function PRD.UpdateHealth()
    local cur, most, heal, absorb = healthValues()
    local fraction = most > 0 and cur / most or 0
    local bar = health.bar
    PRD.SetBarTarget(bar, fraction)
    PRD.ColorHealth(fraction)
    health.text:SetText(PRD.FormatValue(C("prdHealthText") or "both", cur, most))
    -- Incoming heals and shields sit on the missing part, anchored to the fill's right edge.
    local width = bar:GetWidth() or 0
    local missing = 1 - bar.target
    local used = 0
    if C("prdHealPrediction") and most > 0 then
        local r, g, b, a = rgb(C("prdHealColor"), { 0.4, 1, 0.5, 0.45 })
        used = placeOverlay(health.heal, bar:GetStatusBarTexture(), 0, width, heal / most, missing, r, g, b, a or 0.45)
    else
        health.heal:Hide()
    end
    state.heal = heal
    state.absorb = absorb
    local shieldOn = C("prdShield")
    if shieldOn and most > 0 and absorb > 0 then
        local r, g, b, a = rgb(C("prdShieldColor"), { 0.85, 0.95, 1, 0.6 })
        placeOverlay(health.absorb, bar:GetStatusBarTexture(), used, width, absorb / most,
            max(0, missing - (width > 0 and used / width or 0)), r, g, b, a or 0.6)
    else
        health.absorb:Hide()
    end
    local r, g, b = rgb(C("prdShieldColor"), { 0.85, 0.95, 1 })
    health.shieldGlow:SetBackdropBorderColor(r, g, b, 0.9)
    shown(health.shieldGlow, shieldOn and (absorb > 0 or state.shield or PRD.test))
    -- Critical health: a short pulse when crossing the threshold, then a steady soft edge.
    local critical = most > 0 and fraction * 100 < (C("prdCritical") or 30) and not UnitIsDeadOrGhost("player")
    if PRD.test then critical = false end
    if critical and not state.critical and C("prdCriticalGlow") then
        state.criticalFlash = GetTime() + 1.5
        PRD.Wake()
    end
    state.critical = critical
    local cr, cg, cb = rgb(C("prdCriticalColor"), { 1, 0.1, 0.1 })
    health.critical:SetBackdropBorderColor(cr, cg, cb, 0.6)
    shown(health.critical, critical and C("prdCriticalGlow"))
    PRD.Evaluate()
end

---------------------------------------------------------------------------------------------------
-- Power
---------------------------------------------------------------------------------------------------
local function powerValues()
    if PRD.test then return 60, 100, UnitPowerType("player") or 0 end
    local kind = UnitPowerType("player") or 0
    return UnitPower("player", kind) or 0, UnitPowerMax("player", kind) or 0, kind
end

-- Rage and runic power rest at 0; mana, energy and focus at the maximum.
function PRD.PowerAtRest(kind, cur, most)
    if kind == 1 or kind == 6 then return cur <= 0 end
    return most <= 0 or cur >= most
end

function PRD.UpdatePower()
    local cur, most, kind = powerValues()
    local now = GetTime()
    if kind ~= state.powerType then
        state.powerType, state.lastPower, state.energyTick = kind, nil, nil
        PRD.Layout()   -- the druid mana bar comes and goes with the form
        PRD.UpdateClass()
    end
    local last = state.lastPower
    if not PRD.test and last then
        if kind == 3 and cur > last and cur - last >= 8 then
            if state.energyTick then
                local gap = now - state.energyTick
                if gap > 1.5 and gap < 2.6 then state.tickGap = gap end
            end
            state.energyTick = now
        elseif kind == 0 and cur < last then
            state.fiveStart = now
        end
    end
    state.lastPower = cur
    local bar = power.bar
    local fraction = most > 0 and cur / most or 0
    PRD.SetBarTarget(bar, fraction)
    local color = PRD.powerColors[kind] or PRD.powerColors[0]
    local r, g, b = color[1], color[2], color[3]
    if C("prdPowerColorMode") == "custom" then r, g, b = rgb(C("prdPowerColor"), color) end
    bar:SetStatusBarColor(r, g, b)
    bar.bg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2, 0.85)
    power.text:SetText(PRD.FormatValue(C("prdPowerText") or "current", cur, most))
    state.powerRest = PRD.PowerAtRest(kind, cur, most)
    PRD.UpdateDruidMana()
    PRD.Evaluate()
end

function PRD.DruidManaVisible()
    return playerClass == "DRUID" and C("prdDruidMana") and C("prdShowPower") and (state.powerType ~= 0 or false)
end

function PRD.UpdateDruidMana()
    if not PRD.DruidManaVisible() then
        state.druidRest = true
        return
    end
    local cur, most = UnitPower("player", 0) or 0, UnitPowerMax("player", 0) or 0
    if PRD.test then cur, most = 80, 100 end
    local bar = druidMana.bar
    PRD.SetBarTarget(bar, most > 0 and cur / most or 0)
    local c = PRD.powerColors[0]
    bar:SetStatusBarColor(c[1], c[2], c[3])
    bar.bg:SetVertexColor(c[1] * 0.2, c[2] * 0.2, c[3] * 0.2, 0.85)
    state.druidRest = most <= 0 or cur >= most
end

-- The spark: energy ticks every 2 s (measured gap when known), the five second rule after mana spend.
function PRD.SparkPosition(now)
    local kind = state.powerType
    if kind == 3 and C("prdEnergyTick") then
        if PRD.test then return (now % 2) / 2 end
        if not state.energyTick or state.powerRest then return nil end
        local gap = state.tickGap or 2
        return ((now - state.energyTick) % gap) / gap
    elseif kind == 0 and C("prdFiveSecond") then
        if PRD.test then return (now % 5) / 5 end
        if not state.fiveStart then return nil end
        local t = now - state.fiveStart
        if t >= 5 then state.fiveStart = nil return nil end
        return t / 5
    end
    return nil
end

---------------------------------------------------------------------------------------------------
-- Class module
---------------------------------------------------------------------------------------------------
-- Which block the class module shows right now: "combo", "runes", "totems", "stacks" or nil.
function PRD.ClassMode()
    if not C("prdShowClass") then return nil end
    if playerClass == "ROGUE" then return "combo" end
    if playerClass == "DRUID" and state.powerType == 3 then return "combo" end
    if playerClass == "DEATHKNIGHT" and C("prdRunes") then return "runes" end
    if playerClass == "SHAMAN" and C("prdTotems") then return "totems" end
    if C("prdStacks") and PRD.StackInfo() then return "stacks" end
    return nil
end

local auraCounts = {}   -- name -> stacks (1 for unstacked auras) from the last scan, helpful and harmful
local harmfulCounts = {}
PRD.auraCounts = auraCounts

-- The tracked stack aura: { name, count, max, icon } or nil.
function PRD.StackInfo()
    local custom = C("prdStackCustom")
    if type(custom) == "string" and custom:match("%S") then
        local id = tonumber(custom)
        local name = id and spellName(id) or custom:gsub("^%s+", ""):gsub("%s+$", "")
        local count = auraCounts[name] or harmfulCounts[name] or 0
        if PRD.test then count = 3 end
        return { name = name, count = count, max = max(1, min(10, C("prdStackCustomMax") or 5)) }
    end
    local list = PRD.stackSets[playerClass]
    if not list then return nil end
    local first
    for _, entry in ipairs(list) do
        if entry.shards then
            local count = GetItemCount and GetItemCount(entry.shards) or 0
            if PRD.test then count = 12 end
            return { shards = true, count = count, icon = GetItemIcon and GetItemIcon(entry.shards) }
        end
        local name = spellName(entry.id)
        if name then
            local count = (entry.harmful and harmfulCounts[name]) or auraCounts[name]
            local info = { name = name, count = count or 0, max = max(entry.max, count or 0) }
            if count then return info end
            first = first or info
        end
    end
    if first and PRD.test then first.count = min(first.max, 3) end
    return first
end

local function comboPoints()
    if PRD.test then return 4 end
    local unit = (UnitHasVehicleUI and UnitHasVehicleUI("player")) and "vehicle" or "player"
    return GetComboPoints and GetComboPoints(unit, "target") or 0
end

local testRunes = { { 1, 0, true }, { 1, 0.4, false }, { 2, 0, true }, { 2, 0, true }, { 4, 0, true }, { 3, 0.7, false } }
local testTotems = { { 3599, 0.8 }, { 8075, 0.55 }, { 5675, 0.3 }, { 8512, 0.9 } }

local function layoutCells(count)
    local width = C("prdWidth") or classFrame:GetWidth() or 0
    local gap = C("prdCellGap") or 2
    local w = count > 0 and (width - gap * (count - 1)) / count or 0
    for i = 1, #cells do
        local c = cells[i]
        if i <= count then
            c:ClearAllPoints()
            -- Pinned to the row at the top and the bottom: the cell never leaves the class row.
            c:SetPoint("TOPLEFT", classFrame, "TOPLEFT", (i - 1) * (w + gap), 0)
            c:SetPoint("BOTTOMLEFT", classFrame, "BOTTOMLEFT", (i - 1) * (w + gap), 0)
            c:SetWidth(max(1, w))
            c:Show()
        else
            c:Hide()
        end
        c.totemSlot = nil
        c.icon:Hide()
        c.text:SetText("")
        c.glow:Hide()
    end
end

function PRD.UpdateCombo()
    local points = comboPoints()
    state.combo = points
    layoutCells(5)
    local full = points >= 5
    local r, g, b = rgb(C("prdComboColor"), { 1, 0.85, 0.25 })
    local mr, mg, mb = rgb(C("prdComboMaxColor"), { 1, 0.35, 0.15 })
    for i = 1, 5 do
        local c = cells[i]
        c.bar:SetValue(i <= points and 1 or 0)
        if full then c.bar:SetStatusBarColor(mr, mg, mb) else c.bar:SetStatusBarColor(r, g, b) end
        c.bar.bg:SetVertexColor(0.12, 0.12, 0.12, 0.8)
        if full then c.glow:SetBackdropBorderColor(mr, mg, mb, 0.8) end
        shown(c.glow, full)
    end
end

function PRD.UpdateRunes()
    layoutCells(6)
    local order = PRD.runeOrders[C("prdRuneOrder") or "buf"] or PRD.runeOrders.buf
    local now = GetTime()
    local busy = false
    local showTimer = C("prdRuneTimer")
    for i = 1, 6 do
        local slot = order[i]
        local c = cells[i]
        local kind, progress, ready
        if PRD.test then
            local t = testRunes[slot]
            kind, progress, ready = t[1], t[2], t[3]
        else
            kind = GetRuneType and GetRuneType(slot) or 1
            local start, duration, isReady = GetRuneCooldown(slot)
            ready = isReady
            progress = 0
            if not isReady and start and duration and duration > 0 then
                progress = max(0, min(1, (now - start) / duration))
                if showTimer then c.text:SetText(PRD.FormatTime(start + duration - now)) end
            end
        end
        local color = PRD.runeColors[kind] or PRD.runeColors[1]
        if ready then
            c.bar:SetValue(1)
            c.bar:SetStatusBarColor(color[1], color[2], color[3])
            c.text:SetText("")
        else
            busy = true
            c.bar:SetValue(progress)
            c.bar:SetStatusBarColor(color[1] * 0.55, color[2] * 0.55, color[3] * 0.55)
        end
        c.bar.bg:SetVertexColor(color[1] * 0.15, color[2] * 0.15, color[3] * 0.15, 0.9)
    end
    state.runesBusy = busy and not PRD.test
    if busy then PRD.Run() end
end

function PRD.UpdateTotems()
    layoutCells(4)
    local now = GetTime()
    local any = false
    local showTimer = C("prdTotemTimer")
    for i, slot in ipairs(PRD.totemOrder) do
        local c = cells[i]
        local color = PRD.totemColors[slot]
        local have, name, start, duration, icon
        if PRD.test then
            local t = testTotems[i]
            local _, _, texture = GetSpellInfo(t[1])
            have, icon, duration, start = true, texture, 100, now - 100 * (1 - t[2])
        elseif GetTotemInfo then
            have, name, start, duration, icon = GetTotemInfo(slot)
        end
        c.totemSlot = slot
        local active = have and duration and duration > 0 and icon and icon ~= ""
        if active then
            any = true
            local left = start + duration - now
            c.bar:SetValue(max(0, min(1, left / duration)))
            c.bar:SetStatusBarColor(color[1], color[2], color[3])
            local h = classFrame:GetHeight() or 10
            c.icon:ClearAllPoints()
            c.icon:SetPoint("LEFT", c.bar, "LEFT", 0, 0)
            c.icon:SetWidth(h - 2)
            c.icon:SetHeight(h - 2)
            c.icon:SetTexture(icon)
            c.icon:Show()
            c.text:SetText(showTimer and PRD.FormatTime(left) or "")
        else
            c.bar:SetValue(0)
            c.icon:Hide()
            c.text:SetText("")
        end
        c.bar.bg:SetVertexColor(color[1] * 0.15, color[2] * 0.15, color[3] * 0.15, 0.9)
    end
    state.totemsBusy = any and not PRD.test
    if any then PRD.Run() end
end

function PRD.UpdateStacks()
    local info = PRD.StackInfo()
    classLabel:SetText("")
    if not info then layoutCells(0) state.stacks = 0 return end
    state.stacks = info.count or 0
    if info.shards then
        layoutCells(0)
        classLabel:ClearAllPoints()
        classLabel:SetPoint("CENTER", classFrame, "CENTER", 0, 0)
        classLabel:SetText((info.icon and ("|T" .. info.icon .. ":0|t ") or "") .. info.count)
        return
    end
    local count = min(info.max, info.count)
    layoutCells(info.max)
    -- No stacks: the row stays (the panel does not jump) but shows nothing.
    classFrame:SetAlpha((count <= 0 and C("prdStackHideEmpty")) and 0 or 1)
    local r, g, b = rgb(C("prdStackColor"), { 0.3, 0.75, 1 })
    local mr, mg, mb = rgb(C("prdComboMaxColor"), { 1, 0.35, 0.15 })
    local full = count >= info.max
    for i = 1, info.max do
        local c = cells[i]
        c.bar:SetValue(i <= count and 1 or 0)
        if full then c.bar:SetStatusBarColor(mr, mg, mb) else c.bar:SetStatusBarColor(r, g, b) end
        c.bar.bg:SetVertexColor(0.12, 0.12, 0.12, 0.8)
        if full then c.glow:SetBackdropBorderColor(mr, mg, mb, 0.8) end
        shown(c.glow, full)
    end
end

function PRD.UpdateClass()
    local mode = PRD.ClassMode()
    if mode ~= PRD.classMode then PRD.ResetMouse() end
    PRD.classMode = mode
    state.combo, state.runesBusy, state.totemsBusy, state.stacks = 0, false, false, 0
    classLabel:SetText("")
    classFrame:SetAlpha(1)
    if mode ~= PRD.layoutMode then PRD.Layout() end
    if mode == "combo" then PRD.UpdateCombo()
    elseif mode == "runes" then PRD.UpdateRunes()
    elseif mode == "totems" then PRD.UpdateTotems()
    elseif mode == "stacks" then PRD.UpdateStacks()
    else layoutCells(0) end
    PRD.Evaluate()
end

---------------------------------------------------------------------------------------------------
-- Auras: one scan per UNIT_AURA feeds the strip, the stack tracker and the shield border
---------------------------------------------------------------------------------------------------
local userLists = {}
function PRD.RebuildLists()
    userLists.white = PRD.ParseList(C("prdAuraWhitelist"))
    userLists.black = PRD.ParseList(C("prdAuraBlacklist"))
end

-- Whether a helpful aura belongs on the strip.
function PRD.AuraWanted(name, id, duration, caster)
    local s = staticSets()
    if userLists.white and inSet(userLists.white, name, id) then return true end
    if userLists.black and inSet(userLists.black, name, id) then return false end
    if C("prdAuraHideRaid") and inSet(s.raid, name, id) then return false end
    if inSet(s.procs, name, id) or inSet(s.important, name, id) then return true end
    local mode = C("prdAuraFilter") or "smart"
    if mode == "procs" then return false end
    duration = duration or 0
    if duration <= 0 or duration > (C("prdAuraMaxDuration") or 60) then return false end
    if mode == "all" then return true end
    return caster == "player" or caster == "pet" or caster == "vehicle"
end

function PRD.AuraGlows(name, id, count)
    if not C("prdAuraProcGlow") then return false end
    if not inSet(staticSets().procs, name, id) then return false end
    local maelstrom = spellName(53817)
    if id == 53817 or (maelstrom and name == maelstrom) then return (count or 0) >= 5 end
    return true
end

local auraList = {}
PRD.auraList = auraList

function PRD.ScanAuras()
    for k in pairs(auraCounts) do auraCounts[k] = nil end
    for k in pairs(harmfulCounts) do harmfulCounts[k] = nil end
    for i = #auraList, 1, -1 do auraList[i] = nil end
    local s = staticSets()
    local shield = false
    local strip = C("prdShowAuras")
    for i = 1, 40 do
        local name, _, icon, count, _, duration, expires, caster, _, _, id = UnitBuff("player", i)
        if not name then break end
        auraCounts[name] = (count and count > 0) and count or 1
        if inSet(s.shields, name, id) then shield = true end
        if strip and PRD.AuraWanted(name, id, duration, caster) then
            auraList[#auraList + 1] = { index = i, name = name, icon = icon, count = count or 0, duration = duration or 0,
                expires = expires or 0, id = id, glow = PRD.AuraGlows(name, id, count) }
        end
    end
    for i = 1, 40 do
        local name, _, _, count = UnitDebuff("player", i)
        if not name then break end
        harmfulCounts[name] = (count and count > 0) and count or 1
    end
    state.shield = shield
    table.sort(auraList, function(a, b)
        if a.glow ~= b.glow then return a.glow end
        local ea = a.expires > 0 and a.expires or math.huge
        local eb = b.expires > 0 and b.expires or math.huge
        if ea ~= eb then return ea < eb end
        return a.index < b.index
    end)
end

function PRD.UpdateAuras()
    if PRD.test then
        for i = #auraList, 1, -1 do auraList[i] = nil end
        local now = GetTime()
        for i, sample in ipairs(PRD.sampleAuras) do
            local name, _, icon = GetSpellInfo(sample.id)
            auraList[i] = { name = name, icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark", count = sample.count or 0,
                duration = sample.duration, expires = now + sample.left, id = sample.id,
                glow = sample.glow and C("prdAuraProcGlow") }
        end
    else
        PRD.ScanAuras()
    end
    local limit = C("prdShowAuras") and (C("prdAuraCount") or 6) or 0
    local size = C("prdAuraSize") or 24
    local gap = 2
    local count = min(limit, #auraList)
    local total = count * size + max(0, count - 1) * gap
    local timed = false
    for i = 1, max(count, #auraIcons) do
        local data = i <= count and auraList[i]
        local icon = data and auraIcon(i) or auraIcons[i]
        if data then
            icon:SetWidth(size)
            icon:SetHeight(size)
            icon:ClearAllPoints()
            icon:SetPoint("BOTTOMLEFT", auraStrip, "BOTTOM", -total / 2 + (i - 1) * (size + gap), 0)
            icon.texture:SetTexture(data.icon)
            icon.auraIndex = data.index
            icon.spellId = data.id
            icon.data = data
            icon.count:SetText((data.count or 0) > 1 and data.count or "")
            setFont(icon.count, max(8, floor(size * 0.42)))
            setFont(icon.timer, max(8, floor(size * 0.38)))
            if data.duration > 0 and data.expires > 0 then
                icon.cooldown:SetCooldown(data.expires - data.duration, data.duration)
                icon.cooldown:Show()
                timed = true
            else
                icon.cooldown:Hide()
                icon.timer:SetText("")
            end
            shown(icon.cooldown, C("prdAuraSwipe") and data.duration > 0)
            local gr, gg, gb = rgb(C("prdAuraGlowColor"), { 1, 0.85, 0.2 })
            icon.glow:SetBackdropBorderColor(gr, gg, gb, 1)
            shown(icon.glow, data.glow)
            icon:SetBackdropBorderColor(0, 0, 0, 1)
            icon:Show()
        elseif icon then
            icon.data, icon.auraIndex, icon.spellId = nil, nil, nil
            icon:Hide()
        end
    end
    state.timedAuras = timed and C("prdAuraTimer")
    if state.timedAuras or (count > 0 and C("prdAuraProcGlow")) then PRD.Run() end
    if C("prdShowClass") and not PRD.inClassUpdate then
        local mode = PRD.ClassMode()
        if mode ~= PRD.classMode then PRD.UpdateClass() elseif mode == "stacks" then PRD.UpdateStacks() end
    end
    if C("prdShield") then
        shown(health.shieldGlow, state.absorb > 0 or state.shield or PRD.test)
    end
    PRD.Evaluate()
end

---------------------------------------------------------------------------------------------------
-- Visibility: wake triggers, fade and click-through
---------------------------------------------------------------------------------------------------
function PRD.Busy()
    if PRD.test then return true end
    local cur, most = UnitHealth("player") or 0, UnitHealthMax("player") or 0
    if most > 0 and cur < most and not UnitIsDeadOrGhost("player") then return true end
    if C("prdShowPower") and state.powerRest == false then return true end
    if PRD.DruidManaVisible() and state.druidRest == false then return true end
    if (state.combo or 0) > 0 or state.runesBusy or state.totemsBusy then return true end
    return false
end

function PRD.WantedAlpha()
    if PRD.test or PRD.editing then return 1 end
    if not C("prdFade") then return (C("prdAlphaCombat") or 100) / 100 end
    if state.combat then return (C("prdAlphaCombat") or 100) / 100 end
    if state.hostile then return (C("prdAlphaTarget") or 100) / 100 end
    if state.mouse or PRD.Busy() or GetTime() < (state.criticalFlash or 0) then
        return (C("prdAlphaActive") or 100) / 100
    end
    return (C("prdAlphaIdle") or 0) / 100
end

local modifiers = { shift = IsShiftKeyDown, ctrl = IsControlKeyDown, alt = IsAltKeyDown }
function PRD.MouseWanted()
    if PRD.editing then return false end   -- the Edit Mode outline takes the clicks
    if not C("prdClickThrough") then return true end
    local check = modifiers[C("prdModifier") or "shift"]
    if check and check() then return true end
    if state.combat then return false end
    return C("prdTooltips") and state.alpha > 0.05 or false
end

function PRD.UpdateMouse()
    local want = PRD.MouseWanted() and true or false
    if want == PRD.mouseOn then return end
    PRD.mouseOn = want
    health:EnableMouse(want)
    power:EnableMouse(want)
    for _, icon in ipairs(auraIcons) do icon:EnableMouse(want) end
    for _, c in ipairs(cells) do c:EnableMouse(want and PRD.classMode == "totems") end
end
PRD.ResetMouse = function() PRD.mouseOn = nil end

function PRD.Evaluate()
    if not root:IsShown() then return end
    local target = PRD.WantedAlpha()
    if abs(target - state.alpha) > 0.001 then
        state.targetAlpha = target
        PRD.Run()
    end
    PRD.UpdateMouse()
end

function PRD.Wake()
    state.targetAlpha = PRD.WantedAlpha()
    PRD.Run()
end

local function hover(frame, text)
    frame:SetScript("OnEnter", function(self)
        state.mouse = true
        PRD.Evaluate()
        if not C("prdTooltips") then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(text())
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        state.mouse = false
        GameTooltip:Hide()
        PRD.Evaluate()
    end)
end
hover(health, function()
    return format("%s: %d / %d", L("Здоровье", "Health"), UnitHealth("player") or 0, UnitHealthMax("player") or 0)
end)
hover(power, function()
    local kind = UnitPowerType("player") or 0
    return format("%d / %d", UnitPower("player", kind) or 0, UnitPowerMax("player", kind) or 0)
end)

---------------------------------------------------------------------------------------------------
-- Driver: smoothing, fade, spark, rune and totem timers, aura timers
---------------------------------------------------------------------------------------------------
local driver = CreateFrame("Frame")
PRD.driver = driver
local textClock = 0

local function step(self, elapsed)
    local now = GetTime()
    local active = false
    -- Bars glide towards their target.
    if C("prdSmooth") then
        local rate = min(1, elapsed * 10)
        for _, bar in ipairs(smoothBars) do
            local diff = bar.target - bar.current
            if abs(diff) > 0.0005 then
                bar.current = bar.current + diff * rate
                if abs(bar.target - bar.current) <= 0.0005 then bar.current = bar.target end
                bar:SetValue(bar.current)
                active = true
            end
        end
    end
    -- Fade.
    local target = PRD.WantedAlpha()
    state.targetAlpha = target
    if abs(target - state.alpha) > 0.001 then
        local speed = 1 / max(0.05, C("prdFadeTime") or 0.4)
        if target > state.alpha then
            state.alpha = min(target, state.alpha + elapsed * speed)
        else
            state.alpha = max(target, state.alpha - elapsed * speed)
        end
        root:SetAlpha(state.alpha)
        active = true
        PRD.UpdateMouse()
    end
    -- Critical pulse; the flash also wakes the panel, so keep running until it ends.
    if now < (state.criticalFlash or 0) then active = true end
    if health.critical:IsShown() then
        local flash = now < (state.criticalFlash or 0)
        health.critical:SetAlpha(flash and (0.5 + 0.5 * math.sin(now * 12)) or 0.55)
        if flash then active = true end
    end
    -- Spark.
    local position = C("prdShowPower") and PRD.SparkPosition(now)
    if position then
        local width = power.bar:GetWidth() or 0
        power.spark:ClearAllPoints()
        power.spark:SetPoint("CENTER", power.bar, "LEFT", width * position, 0)
        power.spark:SetHeight((power.bar:GetHeight() or 10) * 2)
        power.spark:Show()
        active = true
    else
        power.spark:Hide()
    end
    -- Glowing procs pulse.
    for _, icon in ipairs(auraIcons) do
        if icon:IsShown() and icon.glow:IsShown() then
            icon.glow:SetAlpha(0.55 + 0.45 * math.sin(now * 6))
            active = true
        end
    end
    -- Timers at 10 Hz.
    textClock = textClock + elapsed
    if textClock >= 0.1 then
        textClock = 0
        if PRD.classMode == "runes" and (state.runesBusy or PRD.test) then PRD.UpdateRunes() end
        if PRD.classMode == "totems" and (state.totemsBusy or PRD.test) then PRD.UpdateTotems() end
        if state.timedAuras then
            for _, icon in ipairs(auraIcons) do
                local data = icon:IsShown() and icon.data
                if data and data.expires > 0 then
                    local left = data.expires - now
                    if PRD.test and left <= 0 then data.expires = now + data.duration left = data.duration end
                    icon.timer:SetText(PRD.FormatTime(left))
                end
            end
        end
    end
    if state.runesBusy or state.totemsBusy or state.timedAuras or PRD.test then active = true end
    if not active then self:SetScript("OnUpdate", nil) PRD.running = false end
end
PRD.Step = step

function PRD.Run()
    if PRD.running or not root:IsShown() then return end
    PRD.running = true
    driver:SetScript("OnUpdate", step)
end

---------------------------------------------------------------------------------------------------
-- Layout and appearance
---------------------------------------------------------------------------------------------------
function PRD.Layout()
    local width = C("prdWidth") or 220
    local gap = C("prdGap") or 2
    local y = 0
    local above   -- the layer above: each layer hangs under it, so no two layers can overlap
    local function place(frame, height, visible, offset)
        if not visible then frame:Hide() return end
        offset = offset or 0
        frame:ClearAllPoints()
        if above then
            frame:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -offset)
            frame:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -offset)
        else
            frame:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -offset)
            frame:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, -offset)
        end
        frame:SetHeight(height)
        frame:Show()
        above = frame
        y = y + offset + height
    end
    local auraSize = C("prdAuraSize") or 24
    place(auraStrip, auraSize, C("prdShowAuras"), 0)
    local first = true
    local function offsetFor(g) if first then first = false return C("prdShowAuras") and gap or 0 end return g end
    if C("prdShowHealth") then place(health, C("prdHealthHeight") or 14, true, offsetFor(gap)) else health:Hide() end
    if C("prdShowPower") then place(power, C("prdPowerHeight") or 8, true, offsetFor(C("prdPowerGap") or 0)) else power:Hide() end
    if PRD.DruidManaVisible() then
        place(druidMana, C("prdDruidHeight") or 4, true, offsetFor(0))
    else
        druidMana:Hide()
    end
    local mode = PRD.ClassMode()
    PRD.layoutMode = mode
    if mode then
        place(classFrame, C("prdClassHeight") or 8, true, offsetFor(C("prdClassGap") or 3))
    else
        classFrame:Hide()
    end
    root:SetWidth(width)
    root:SetHeight(max(1, y))
end

function PRD.ApplyAppearance()
    local texture = barPath()
    local size = C("prdFontSize") or 11
    -- A text never grows past its bar: a bigger one would spill onto the layers above and below.
    local heights = { [health] = C("prdHealthHeight") or 14, [power] = C("prdPowerHeight") or 8,
        [druidMana] = C("prdDruidHeight") or 4 }
    for _, holder in ipairs({ health, power, druidMana }) do
        holder.bar:SetStatusBarTexture(texture)
        holder.bar.bg:SetTexture(texture)
        setFont(holder.text, max(6, min(size, heights[holder] + 2)))
    end
    for _, c in ipairs(cells) do
        c.bar:SetStatusBarTexture(texture)
        c.bar.bg:SetTexture(texture)
        setFont(c.text, max(6, min(size - 2, (C("prdClassHeight") or 9) + 2)))
    end
    setFont(classLabel)
    health.heal:SetTexture(texture)
    health.absorb:SetTexture(texture)
    shown(health.text, C("prdHealthText") ~= "none")
    shown(power.text, C("prdPowerText") ~= "none")
    -- Keep the fill below the texts.
    health.heal:SetDrawLayer("ARTWORK")
    health.absorb:SetDrawLayer("ARTWORK")
end

-- prdX / prdY are screen (UIParent) pixels from the centre; point offsets count in the frame's own scale.
function PRD.ApplyPosition()
    local s = mainDB()
    local scale = max(0.3, (s.prdScale or 100) / 100)
    root:SetScale(scale)
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "CENTER", (s.prdX or 0) / scale, (s.prdY or -170) / scale)
end

function PRD.Refresh()
    PRD.UpdateHealth()
    PRD.UpdatePower()
    PRD.UpdateClass()
    PRD.UpdateAuras()
end

---------------------------------------------------------------------------------------------------
-- Position
local function currentOffset()
    local cx, cy = root:GetCenter()
    if not cx then return 0, 0 end
    local scale = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local ux, uy = UIParent:GetCenter()
    return floor(cx * scale - ux + 0.5), floor(cy * scale - uy + 0.5)
end
PRD.CurrentOffset = currentOffset

function PRD.SetPosition(x, y)
    local s = mainDB()
    s.prdX, s.prdY = floor((x or 0) + 0.5), floor((y or 0) + 0.5)
    PRD.ApplyPosition()
    ui.Fire("OptionsRefresh", "prd")
end

function PRD.SetTest(on)
    PRD.test = (on or PRD.editing) and true or false
    if PRD.test and not enabled() then PRD.test = false end
    PRD.Refresh()
    PRD.Wake()
    return PRD.test
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame")
PRD.events = events
local powerEvents = { "UNIT_MANA", "UNIT_RAGE", "UNIT_FOCUS", "UNIT_ENERGY", "UNIT_RUNIC_POWER", "UNIT_MAXMANA",
    "UNIT_MAXRAGE", "UNIT_MAXFOCUS", "UNIT_MAXENERGY", "UNIT_MAXRUNIC_POWER", "UNIT_DISPLAYPOWER" }
local isPowerEvent = {}
for _, e in ipairs(powerEvents) do isPowerEvent[e] = true end

local liveEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_TARGET_CHANGED", "MODIFIER_STATE_CHANGED", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
    "UPDATE_SHAPESHIFT_FORM", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ALIVE" }
local classEvents = {
    ROGUE = { "UNIT_COMBO_POINTS" }, DRUID = { "UNIT_COMBO_POINTS" },
    DEATHKNIGHT = { "RUNE_POWER_UPDATE", "RUNE_TYPE_UPDATE" },
    SHAMAN = { "PLAYER_TOTEM_UPDATE" },
    WARLOCK = { "BAG_UPDATE" },
}
PRD.classEvents = classEvents

local function setLive(on)
    local list = {}
    for _, e in ipairs(liveEvents) do list[#list + 1] = e end
    for _, e in ipairs(powerEvents) do list[#list + 1] = e end
    for _, e in ipairs(classEvents[playerClass] or {}) do list[#list + 1] = e end
    for _, e in ipairs(list) do
        if on then events:RegisterEvent(e) else events:UnregisterEvent(e) end
    end
    PRD.live = on
end

local function hostileTarget()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") or false
end

events:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if event == "PLAYER_LOGIN" then PRD.Init() end
        state.combat = InCombatLockdown() and true or false
        PRD.Apply()
        return
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if mainDB().prdPerSpec then
            PRD.Apply()
            ui.Fire("OptionsRefresh", "prd")
        end
        return
    end
    if not PRD.live then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if unit == "player" then PRD.UpdateHealth() end
    elseif isPowerEvent[event] then
        if unit == "player" then PRD.UpdatePower() end
    elseif event == "UNIT_AURA" then
        if unit == "player" then PRD.UpdateAuras() PRD.UpdateHealth() end
    elseif event == "UNIT_COMBO_POINTS" then
        if PRD.classMode == "combo" then PRD.UpdateCombo() PRD.Evaluate() end
    elseif event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" then
        if PRD.classMode == "runes" then PRD.UpdateRunes() PRD.Evaluate() end
    elseif event == "PLAYER_TOTEM_UPDATE" then
        if PRD.classMode == "totems" then PRD.UpdateTotems() PRD.Evaluate() end
    elseif event == "BAG_UPDATE" then
        if PRD.classMode == "stacks" then PRD.UpdateStacks() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        state.hostile = hostileTarget()
        if PRD.classMode == "combo" then PRD.UpdateCombo() end
        PRD.Evaluate()
    elseif event == "PLAYER_REGEN_DISABLED" then
        state.combat = true
        if PRD.test then PRD.SetTest(false) end
        PRD.Evaluate()
    elseif event == "PLAYER_REGEN_ENABLED" then
        state.combat = false
        PRD.Evaluate()
    elseif event == "MODIFIER_STATE_CHANGED" then
        PRD.UpdateMouse()
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        PRD.UpdatePower()
        PRD.Layout()
        PRD.UpdateClass()
    else
        PRD.Refresh()
    end
end)
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

function PRD.Init()
    if PRD.initialized then return end
    PRD.initialized = true
    healComm = LibStub and LibStub("LibHealComm-4.0", true)
    if healComm and not PRD.healSource then
        PRD.healSource = "lib"
        local function changed() if PRD.live then PRD.UpdateHealth() end end
        for _, callback in ipairs({ "HealComm_HealStarted", "HealComm_HealUpdated", "HealComm_HealDelayed",
            "HealComm_HealStopped", "HealComm_ModifierChanged" }) do
            healComm.RegisterCallback(PRD, callback, changed)
        end
    end
end

-- Reads the settings again and rebuilds the panel (options call this through the schema).
function PRD.Apply()
    resetCache()
    PRD.RebuildLists()
    PRD.ApplyPosition()
    if not enabled() then
        if PRD.editEntry then PRD.editEntry.removed = true end
        setLive(false)
        PRD.test = false
        driver:SetScript("OnUpdate", nil)
        PRD.running = false
        root:Hide()
        return
    end
    if PRD.editEntry then PRD.editEntry.removed = nil end
    setLive(true)
    state.combat = (InCombatLockdown() or UnitAffectingCombat("player")) and true or false
    state.hostile = hostileTarget()
    state.powerType = UnitPowerType("player") or 0
    root:Show()
    PRD.ApplyAppearance()
    PRD.Layout()
    PRD.ResetMouse()
    PRD.Refresh()
    -- No fade-in on login when already active: start at the wanted opacity.
    if not PRD.applied then
        PRD.applied = true
        state.alpha = PRD.WantedAlpha()
        root:SetAlpha(state.alpha)
    end
    PRD.Wake()
end

---------------------------------------------------------------------------------------------------
-- Edit Mode: the editor drags and scales the panel; the result goes back into prdX / prdY / prdScale,
-- so the panel keeps one position (the same the sliders show).
---------------------------------------------------------------------------------------------------
PRD.defaultX, PRD.defaultY = 0, -170

-- Takes over a position Edit Mode left on the frame (its TOPRIGHT anchor) as the panel's own.
function PRD.TakeEditPosition()
    local entry = PRD.editEntry
    if entry and entry.config then entry.config.position, entry.config.scale = nil, nil end
    if entry then entry.points = nil end
    local x, y = currentOffset()
    PRD.SetPosition(x, y)
end

function PRD.SetEditing(on)
    on = on and true or false
    if PRD.editing == on then return end
    PRD.editing = on
    if on then
        PRD.testBeforeEdit = PRD.test
        PRD.SetTest(true)    -- every layer visible: the outline shows the real size
    else
        PRD.SetTest(PRD.testBeforeEdit)
        PRD.testBeforeEdit = nil
    end
    PRD.Wake()
end

if ui.RegisterEditFrame then
    local entry = ui.RegisterEditFrame(root, L("Панель ресурсов", "Personal resources"), "prd")
    PRD.editEntry = entry
    if entry then
        entry.noToggle = true   -- "Show" lives on the options page (prdEnabled)
        entry.onDragStop = PRD.TakeEditPosition
        entry.changeScale = function(value)
            local s = mainDB()
            local x, y = currentOffset()
            s.prdScale = floor(value * 100 + 0.5)
            s.prdX, s.prdY = x, y
            PRD.ApplyPosition()
            ui.Fire("OptionsRefresh", "prd")
            return true
        end
        entry.resetPosition = function()
            local s = mainDB()
            s.prdScale = 100
            PRD.SetPosition(PRD.defaultX, PRD.defaultY)
        end
    end
end
if ForeverStockUIEditMode then
    ForeverStockUIEditMode:HookScript("OnShow", function() PRD.SetEditing(true) end)
    ForeverStockUIEditMode:HookScript("OnHide", function() PRD.SetEditing(false) end)
end

-- /fuiprd [test|reset]: diagnostics in ASCII (the chat font may print Cyrillic as "?").
SLASH_FOREVERUIPRD1 = "/fuiprd"
SlashCmdList.FOREVERUIPRD = function(input)
    input = (input or ""):lower()
    if input:match("test") then
        PRD.SetTest(not PRD.test)
        return
    elseif input:match("reset") then
        mainDB().prdScale = 100
        PRD.SetPosition(PRD.defaultX, PRD.defaultY)
        return
    end
    local x, y = currentOffset()
    ui.Print(format("enabled=%s class=%s mode=%s power=%s alpha=%.2f->%.2f combat=%s hostile=%s busy=%s pos=%d,%d",
        tostring(enabled()), tostring(playerClass), tostring(PRD.classMode), tostring(state.powerType), state.alpha,
        PRD.WantedAlpha(), tostring(state.combat), tostring(state.hostile), tostring(PRD.Busy()), x, y))
    ui.Print(format("heals=%s(%d) absorbAPI=%s absorb=%d shieldAura=%s tickGap=%s runesAPI=%s totemsAPI=%s comboAPI=%s",
        tostring(PRD.healSource), floor(state.heal or 0), tostring(UnitGetTotalAbsorbs ~= nil), floor(state.absorb or 0),
        tostring(state.shield), state.tickGap and format("%.2f", state.tickGap) or "-", tostring(GetRuneCooldown ~= nil),
        tostring(GetTotemInfo ~= nil), tostring(GetComboPoints ~= nil)))
    ui.Print(format("auras shown=%d spec=%d perSpec=%s", #auraList, PRD.TalentGroup(), tostring(mainDB().prdPerSpec)))
end
