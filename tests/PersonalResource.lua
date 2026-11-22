-- Personal Resource Display on mocks (real Core/Config.lua, PersonalResource.lua and its schema):
-- forbidden APIs, layer layout, health text / colours / heal prediction / shields / critical glow,
-- druid forms and druid mana, energy tick and five second rule, combo points, runes (order, death
-- runes, recharge), totems, stacks and soul shards, aura filter (procs, raid buffs, lists, glow),
-- fade and wake triggers, click-through, per-spec settings, Edit Mode (drag, scale, reset, preview), test mode, disable.
-- Run from the addon root (see INDEX.md).
local forbidden = { "C_Timer", "BackdropTemplate", "SetShown(", "SetColorTexture", "SetAtlas", "UNIT_POWER_UPDATE",
    "UNIT_POWER_FREQUENT", "C_NamePlate", "CreateFramePool" }

---------------------------------------------------------------------------------------------------
-- Permissive frames
---------------------------------------------------------------------------------------------------
local objects, events = {}, {}
local methods = {}
local function new(kind, name, parent)
    local f = setmetatable({ kind = kind, shown = true, alpha = 1, scripts = {}, width = 0, height = 0, name = name,
        parent = parent, value = 0, level = 1, mouse = false, points = {} },
        { __index = function(_, key)
            if methods[key] then return methods[key] end
            if type(key) == "string" and key:match("^%u") then return function() end end
        end })
    objects[#objects + 1] = f
    if name then _G[name] = f end
    return f
end
function methods:Show() local was = self.shown self.shown = true if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local was = self.shown self.shown = false if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:SetAlpha(a) self.alpha = a end
function methods:GetAlpha() return self.alpha end
function methods:SetScript(n, fn) self.scripts[n] = fn end
function methods:GetScript(n) return self.scripts[n] end
function methods:HookScript(n, fn) local old = self.scripts[n]; self.scripts[n] = function(...) if old then old(...) end fn(...) end end
function methods:CreateTexture() return new("Texture", nil, self) end
function methods:CreateFontString() return new("FontString", nil, self) end
function methods:SetText(t) self.text = t end
function methods:GetText() return self.text end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetTexture(t) self.texture = t end
function methods:GetName() return self.name end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(l) self.level = l end
function methods:SetValue(v) self.value = v end
function methods:GetValue() return self.value end
function methods:SetStatusBarColor(r, g, b) self.color = { r, g, b } end
function methods:SetVertexColor(r, g, b, a) self.vcolor = { r, g, b, a } end
function methods:SetBackdropBorderColor(r, g, b, a) self.border = { r, g, b, a } end
function methods:GetStatusBarTexture() self.fill = self.fill or new("Texture", nil, self) return self.fill end
function methods:EnableMouse(on) self.mouse = on and true or false end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetScale(s) self.scale = s end
function methods:SetAllPoints(other) self.points = { { "ALL", other } } end
function hooksecurefunc(t, key, fn)
    local old = t[key]
    t[key] = function(...) local r1, r2 = old(...) fn(...) return r1, r2 end
end
function methods:GetEffectiveScale() return 1 end
function methods:GetCenter() return 512 + (self.cx or 0), 384 + (self.cy or 0) end
function methods:SetCooldown(start, duration) self.cooldown = { start, duration } end
function methods:SetFont(path, size, flags) self.font = { path, size, flags } end
function methods:RegisterEvent(event) events[event] = events[event] or {}; events[event][self] = true end
function methods:UnregisterEvent(event) if events[event] then events[event][self] = nil end end
function methods:IsEventRegistered(event) return events[event] and events[event][self] or false end
function CreateFrame(kind, name, parent) return new(kind, name, parent) end
UIParent = new("Frame", "UIParent")
GameTooltip = new("GameTooltip", "GameTooltip")
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
SlashCmdList = {}
RAID_CLASS_COLORS = { ROGUE = { r = 1, g = 0.96, b = 0.41 }, DRUID = { r = 1, g = 0.49, b = 0.04 },
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 }, SHAMAN = { r = 0, g = 0.44, b = 0.87 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 } }

local now = 100
function GetTime() return now end
function GetLocale() return "ruRU" end
function geterrorhandler() return function(e) error(e, 2) end end
LibStub = nil
local combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
local modifier = false
function IsShiftKeyDown() return modifier end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end

local function fire(event, ...)
    for frame in pairs(events[event] or {}) do frame.scripts.OnEvent(frame, event, ...) end
end
local function tick(seconds, steps)
    for _ = 1, steps or 1 do
        now = now + seconds
        for _, f in ipairs(objects) do
            if f.scripts.OnUpdate then f.scripts.OnUpdate(f, seconds) end
        end
    end
end

---------------------------------------------------------------------------------------------------
-- The player
---------------------------------------------------------------------------------------------------
local P = { class = "ROGUE", hp = 100, maxHp = 100, powerType = 3, power = { [0] = 100, [1] = 0, [3] = 100, [6] = 0 },
    maxPower = { [0] = 100, [1] = 100, [3] = 100, [6] = 100 }, buffs = {}, debuffs = {}, combo = 0, target = nil,
    talentGroup = 1, runes = {}, totems = {}, shards = 0, dead = false }
function UnitClass(unit) if unit == "player" then return P.class, P.class end end
function UnitHealth() return P.hp end
function UnitHealthMax() return P.maxHp end
function UnitPowerType() return P.powerType end
function UnitPower(_, kind) return P.power[kind or P.powerType] or 0 end
function UnitPowerMax(_, kind) return P.maxPower[kind or P.powerType] or 0 end
function UnitIsDeadOrGhost(unit) if unit == "player" then return P.dead end return false end
function UnitExists(unit) return unit == "player" or (unit == "target" and P.target ~= nil) end
function UnitCanAttack(_, unit) return unit == "target" and P.target == "enemy" end
function UnitHasVehicleUI() return false end
function UnitGUID() return "0x1" end
function GetComboPoints() return P.combo end
function GetActiveTalentGroup() return P.talentGroup end
function GetRuneType(slot) return (P.runes[slot] or {}).kind or ({ 1, 1, 2, 2, 3, 3 })[slot] end
function GetRuneCooldown(slot)
    local r = P.runes[slot]
    if not r or not r.start then return 0, 10, true end
    return r.start, r.duration, false
end
function GetTotemInfo(slot)
    local t = P.totems[slot]
    if not t then return false, "", 0, 0, "" end
    return true, t.name, t.start, t.duration, t.icon
end
function GetItemCount(id) return id == 6265 and P.shards or 0 end
function GetItemIcon() return "Interface\\Icons\\INV_Misc_Gem_Amethyst_02" end
local spellNames = { [53817] = "Оружие Водоворота", [59578] = "Искусство войны", [871] = "Глухая оборона",
    [1126] = "Знак дикой природы", [48469] = "Знак дикой природы", [17] = "Слово силы: Щит", [324] = "Щит молний",
    [49222] = "Костяной щит", [2825] = "Жажда крови", [60064] = "Сила тьмы", [3599] = "Тотем опаляющего огня",
    [8075] = "Тотем силы земли", [5675] = "Тотем источника маны", [8512] = "Тотем неистовства ветра" }
function GetSpellInfo(id)
    local n = spellNames[id]
    return n, "", n and ("Interface\\Icons\\S" .. id) or nil
end
function UnitBuff(_, i)
    local b = P.buffs[i]
    if not b then return nil end
    return b.name, "", b.icon or "icon", b.count or 0, nil, b.duration or 0, b.expires or 0, b.caster, nil, nil, b.id
end
function UnitDebuff(_, i)
    local b = P.debuffs[i]
    if not b then return nil end
    return b.name, "", "icon", b.count or 0
end

---------------------------------------------------------------------------------------------------
-- Load
---------------------------------------------------------------------------------------------------
local ui = {}
ui.Print = function() end
local editEntries = {}
ForeverStockUIEditMode = new("Frame", "ForeverStockUIEditMode")
ForeverStockUIEditMode.shown = false
ui.RegisterEditFrame = function(frame, label, category)
    local entry = { frame = frame, label = label, panel = category, config = {} }
    editEntries[#editEntries + 1] = entry
    return entry
end
local prints = {}
for _, path in ipairs({ "Core/Config.lua", "PersonalResource.lua", "Options/PersonalResource.lua" }) do
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    if path ~= "Core/Config.lua" then
        for _, keyword in ipairs(forbidden) do assert(not source:find(keyword, 1, true), path .. ": " .. keyword) end
    end
    assert(loadfile(path))("ForeverUI", ui)
end
ui.Print = function(text) prints[#prints + 1] = text end
assert(ui.RegisterEditFrame, "edit frame stub kept")
ui.MediaPath = function(kind) return kind == "font" and "Fonts\\ARIALN.TTF" or "Interface\\Bar" end
local PRD = ui.PersonalResource
assert(PRD and ui.GetModule("prd"), "module and schema registered")
ForeverStockUIDB = {}
local refreshes = 0
ui.RegisterCallback("OptionsRefresh", function(id) if id == "prd" then refreshes = refreshes + 1 end end, "test")

local root
local function reload(class)
    P.class = class
    PRD.class = class
    -- The class is read at file load: load the module again for each class, silencing the old copy.
    for _, set in pairs(events) do set[PRD.events] = nil end
    PRD.driver.scripts.OnUpdate = nil
    PRD.root.shown = false
    P.buffs, P.runes, P.totems, P.combo, P.target = {}, {}, {}, 0, nil
    assert(loadfile("PersonalResource.lua"))("ForeverUI", ui)
    PRD = ui.PersonalResource
    fire("PLAYER_LOGIN")
    root = PRD.root
    return PRD
end
local function set(key, value) ui.SetOption("prd", key, value) end

---------------------------------------------------------------------------------------------------
-- Rogue: layout, health, energy, combo points
---------------------------------------------------------------------------------------------------
reload("ROGUE")
assert(root:GetName() == "ForeverStockUIPersonalResource")
assert(root.shown, "enabled by default")
assert(PRD.classMode == "combo", "rogue shows combo points")
assert(PRD.health.shown and PRD.power.shown and PRD.classFrame.shown)
assert(not PRD.druidMana.shown, "no druid mana for a rogue")
assert(root.width == 220, "default width")
-- Vertical stack: auras (24) + 3 + health 14 - 1 + power 8 + 3 + class 9
assert(root.height == 24 + 3 + 14 - 1 + 8 + 3 + 9, "stack height " .. root.height)
assert(events.UNIT_ENERGY[PRD.events] and events.UNIT_COMBO_POINTS[PRD.events], "class events")
assert(not (events.RUNE_POWER_UPDATE or {})[PRD.events], "no rune events for a rogue")

-- Idle: full health and energy, no target -> fades to 0.
tick(0.1, 30)
assert(root.alpha == 0, "idle fade to 0, got " .. root.alpha)
assert(not PRD.running, "driver stops when idle")
assert(not PRD.health.mouse, "invisible panel does not take the mouse")
-- Buffs stay visible at rest (prdAuraKeepVisible, on by default): own holder at the active opacity.
local holder = PRD.auraHolder
assert(holder.shown and holder.points[1][2] == root, "aura holder follows the panel")
assert(math.abs(holder.alpha - 0.8) < 0.001, "buffs keep the active opacity while the panel is idle, got " .. holder.alpha)
set("prdAuraKeepVisible", false)
assert(holder.alpha == 0, "option off: buffs fade with the panel")
set("prdAuraKeepVisible", true)
assert(math.abs(holder.alpha - 0.8) < 0.001)
set("prdShowAuras", false)
assert(holder.alpha == 0, "strip off: nothing to keep")
set("prdShowAuras", true)
root:SetScale(1.5)
assert(holder.scale == 1.5, "holder scaled with the panel")
root:SetScale(1)

-- Energy spent: wakes to the active opacity.
P.power[3] = 60
fire("UNIT_ENERGY", "player")
assert(PRD.running, "driver runs on change")
tick(0.1, 20)
assert(math.abs(root.alpha - 0.8) < 0.001, "active opacity 80%")
assert(PRD.power.text.text == "60", "energy text current")
assert(PRD.power.bar.color[1] == 1 and PRD.power.bar.color[2] == 0.9, "energy yellow")
assert(math.abs(PRD.power.bar.value - 0.6) < 0.01, "smooth bar reaches the target")

-- Energy tick spark: ticks of +20 two seconds apart.
set("prdEnergyTick", true)
P.power[3] = 80
fire("UNIT_ENERGY", "player")
now = now + 2
P.power[3] = 100 - 1
fire("UNIT_ENERGY", "player")
assert(PRD.state.tickGap and math.abs(PRD.state.tickGap - 2) < 0.01, "tick gap measured")
assert(PRD.SparkPosition(now + 1) and math.abs(PRD.SparkPosition(now + 1) - 0.5) < 0.01, "spark half way")
tick(0.1)
assert(PRD.power.spark.shown, "spark visible")
P.power[3] = 100
fire("UNIT_ENERGY", "player")
assert(PRD.SparkPosition(now) == nil, "no spark at full energy")

-- Combo points.
P.combo = 3
fire("UNIT_COMBO_POINTS", "player")
assert(PRD.cells[3].bar.value == 1 and PRD.cells[4].bar.value == 0, "3 of 5")
assert(not PRD.cells[1].glow.shown)
P.combo = 5
fire("UNIT_COMBO_POINTS", "player")
assert(PRD.cells[5].bar.value == 1 and PRD.cells[1].glow.shown, "max glows")
assert(PRD.cells[1].bar.color[2] == 0.35, "max colour")
assert(PRD.Busy(), "combo points keep the panel awake")
P.combo = 0
fire("UNIT_COMBO_POINTS", "player")

-- Health text, colours, heal prediction, critical glow.
P.hp = 45000
P.maxHp = 60000
fire("UNIT_HEALTH", "player")
assert(PRD.health.text.text == "45k | 75%", "both: " .. tostring(PRD.health.text.text))
set("prdHealthText", "percent")
assert(PRD.health.text.text == "75%")
set("prdHealthText", "full")
assert(PRD.health.text.text == "45k / 60k")
set("prdHealthText", "none")
assert(not PRD.health.text.shown)
set("prdHealthText", "current")
assert(PRD.health.text.text == "45k")
assert(PRD.health.bar.color[1] == 1 and PRD.health.bar.color[2] == 0.96, "class colour")
set("prdHealthColorMode", "gradient")
local r, g = PRD.GradientColor(0.75)
assert(PRD.health.bar.color[1] == r and r < 1 and g > 0.8, "gradient green-yellow")
assert(select(1, PRD.GradientColor(0.1)) == 1 and select(2, PRD.GradientColor(0)) == 0, "red when low")
set("prdHealthColorMode", "custom")
set("prdHealthColor", { 0.1, 0.2, 0.3 })
assert(PRD.health.bar.color[3] == 0.3, "custom colour")
set("prdHealthColorMode", "class")

UnitGetIncomingHeals = function() return 6000 end
PRD.healSource = "api"
PRD.health.bar.width = 218
fire("UNIT_HEALTH", "player")
assert(PRD.health.heal.shown and math.abs(PRD.health.heal.width - 218 * 0.1) < 0.01, "heal width 10%")
UnitGetIncomingHeals = function() return 60000 end
fire("UNIT_HEALTH", "player")
assert(math.abs(PRD.health.heal.width - 218 * 0.25) < 0.01, "heal clamped to the missing health")
UnitGetTotalAbsorbs = function() return 3000 end
UnitGetIncomingHeals = function() return 0 end
fire("UNIT_HEALTH", "player")
assert(not PRD.health.heal.shown and PRD.health.absorb.shown, "absorb overlay")
assert(PRD.health.shieldGlow.shown, "shield border with an absorb")
UnitGetTotalAbsorbs = nil
UnitGetIncomingHeals = nil
fire("UNIT_HEALTH", "player")
assert(not PRD.health.absorb.shown and not PRD.health.shieldGlow.shown)
P.buffs = { { name = "Слово силы: Щит", id = 48066, duration = 30, expires = now + 30, caster = "party1" } }
fire("UNIT_AURA", "player")
assert(PRD.health.shieldGlow.shown, "shield aura lights the border without an amount")
P.buffs = {}
fire("UNIT_AURA", "player")
assert(not PRD.health.shieldGlow.shown)

P.hp = 12000
fire("UNIT_HEALTH", "player")
assert(PRD.health.critical.shown and PRD.state.criticalFlash > now, "critical glow and flash below 30%")
P.hp = 60000
fire("UNIT_HEALTH", "player")
assert(not PRD.health.critical.shown, "glow off above the threshold")

---------------------------------------------------------------------------------------------------
-- Wake triggers, combat, target, click-through
---------------------------------------------------------------------------------------------------
P.combo, P.power[3] = 0, 100
fire("UNIT_ENERGY", "player")
tick(0.1, 30)
assert(root.alpha == 0, "back to idle")
P.target = "enemy"
fire("PLAYER_TARGET_CHANGED")
tick(0.1, 10)
assert(root.alpha == 1, "attackable target wakes to 100%")
P.target = nil
fire("PLAYER_TARGET_CHANGED")
tick(0.1, 30)
assert(root.alpha == 0)
combat = true
fire("PLAYER_REGEN_DISABLED")
tick(0.1, 10)
assert(root.alpha == 1, "combat opacity")
assert(not PRD.health.mouse, "click-through in combat")
-- Fully visible panel (opacity does not change): the bars must still follow the values.
tick(0.1, 30)
assert(not PRD.running, "nothing to animate")
P.hp = 30000
fire("UNIT_HEALTH", "player")
assert(PRD.running, "a new health value starts the driver")
tick(0.1, 30)
assert(math.abs(PRD.health.bar.value - 0.5) < 0.01, "health bar follows in combat: " .. PRD.health.bar.value)
P.power[3] = 35
fire("UNIT_ENERGY", "player")
tick(0.1, 30)
assert(math.abs(PRD.power.bar.value - 0.35) < 0.01, "power bar follows in combat: " .. PRD.power.bar.value)
set("prdSmooth", false)
P.hp = 60000
fire("UNIT_HEALTH", "player")
assert(PRD.health.bar.value == 1, "without smoothing at once")
set("prdSmooth", true)
P.power[3] = 100
fire("UNIT_ENERGY", "player")
tick(0.1, 30)
modifier = true
fire("MODIFIER_STATE_CHANGED")
assert(PRD.health.mouse, "modifier enables tooltips in combat")
modifier = false
fire("MODIFIER_STATE_CHANGED")
assert(not PRD.health.mouse)
combat = false
fire("PLAYER_REGEN_ENABLED")
P.target = "enemy"
fire("PLAYER_TARGET_CHANGED")
tick(0.1, 10)
assert(PRD.health.mouse, "tooltips out of combat while visible")
P.target = nil
fire("PLAYER_TARGET_CHANGED")
set("prdClickThrough", false)
assert(PRD.health.mouse, "no click-through: mouse always on")
PRD.health.scripts.OnEnter(PRD.health)
tick(0.1, 10)
assert(math.abs(root.alpha - 0.8) < 0.001, "mouse over wakes the panel")
PRD.health.scripts.OnLeave(PRD.health)
tick(0.1, 30)
assert(root.alpha == 0)
set("prdClickThrough", true)
set("prdFade", false)
tick(0.1, 10)
assert(root.alpha == 1, "no fade: combat opacity always")
set("prdFade", true)
tick(0.1, 30)

---------------------------------------------------------------------------------------------------
-- Aura strip: filter, raid buffs, lists, glow, sorting
---------------------------------------------------------------------------------------------------
P.buffs = {
    { name = "Знак дикой природы", id = 48469, duration = 3600, expires = now + 3000, caster = "party1" },
    { name = "Глухая оборона", id = 871, duration = 12, expires = now + 10, caster = "player" },
    { name = "Чужой короткий", id = 9001, duration = 10, expires = now + 5, caster = "party2" },
    { name = "Свой короткий", id = 9002, duration = 20, expires = now + 4, caster = "player" },
    { name = "Свой длинный", id = 9003, duration = 1800, expires = now + 1000, caster = "player" },
    { name = "Оружие Водоворота", id = 53817, count = 5, duration = 30, expires = now + 25, caster = "player" },
    { name = "Без времени", id = 9004, duration = 0, expires = 0, caster = "player" },
}
fire("UNIT_AURA", "player")
local names = {}
for _, a in ipairs(PRD.auraList) do names[#names + 1] = a.name end
assert(#PRD.auraList == 3, "smart filter: " .. table.concat(names, ","))
assert(PRD.auraList[1].name == "Оружие Водоворота" and PRD.auraList[1].glow, "glowing procs first")
assert(PRD.auraList[2].name == "Свой короткий", "then by time left")
assert(PRD.auraIcons[1].shown and PRD.auraIcons[1].glow.shown and PRD.auraIcons[1].count.text == 5)
assert(PRD.auraIcons[2].cooldown.cooldown[2] == 20, "swipe set from the duration")
assert(not PRD.auraIcons[4] or not PRD.auraIcons[4].shown)
tick(0.1, 2)
assert(PRD.auraIcons[2].timer.text == "3.8", "timer " .. tostring(PRD.auraIcons[2].timer.text))
P.buffs[6].count = 3
fire("UNIT_AURA", "player")
assert(not PRD.auraList[1].glow, "maelstrom glows at 5 stacks only")
set("prdAuraFilter", "all")
assert(#PRD.auraList == 4, "all short buffs (others too)")
set("prdAuraFilter", "procs")
assert(#PRD.auraList == 2, "procs only")
set("prdAuraFilter", "smart")
set("prdAuraWhitelist", "Без времени, 1126")
assert(#PRD.auraList == 5, "whitelist by name and by id (resolved to the name)")
set("prdAuraWhitelist", "")
set("prdAuraBlacklist", "871")
assert(#PRD.auraList == 2, "blacklist by id")
set("prdAuraBlacklist", "")
set("prdAuraCount", 2)
assert(PRD.auraIcons[2].shown and not PRD.auraIcons[3].shown, "icon limit")
set("prdAuraCount", 6)
set("prdShowAuras", false)
assert(#PRD.auraList == 0 and not PRD.auraIcons[1].shown, "strip off")
set("prdShowAuras", true)
P.buffs = {}
fire("UNIT_AURA", "player")

---------------------------------------------------------------------------------------------------
-- Per-spec settings
---------------------------------------------------------------------------------------------------
set("prdWidth", 300)
assert(root.width == 300 and ForeverStockUIDB.prdProfiles.shared.prdWidth == 300, "shared table")
ui.SetOption("prd", "prdPerSpec", true)
assert(ForeverStockUIDB.prdPerSpec == true, "per-spec switch in the main table")
assert(ForeverStockUIDB.prdProfiles[1].prdWidth == 300, "spec 1 starts as a copy")
set("prdWidth", 250)
assert(root.width == 250 and ForeverStockUIDB.prdProfiles.shared.prdWidth == 300)
P.talentGroup = 2
refreshes = 0
fire("ACTIVE_TALENT_GROUP_CHANGED")
assert(root.width == 300, "spec 2 copied from shared")
assert(refreshes == 1, "options page refreshed on spec change")
assert(PRD.CopyFrom(1) and root.width == 250, "copy from the other spec")
P.talentGroup = 1
fire("ACTIVE_TALENT_GROUP_CHANGED")
assert(root.width == 250)
ui.SetOption("prd", "prdPerSpec", false)
assert(root.width == 300, "back to shared")
set("prdWidth", 220)

---------------------------------------------------------------------------------------------------
-- Position, test mode, slash
---------------------------------------------------------------------------------------------------
assert(PRD.SetUnlocked == nil and PRD.unlocked == nil, "no own unlock mode")
for _, f in ipairs(objects) do assert(not (f.parent == root and f.scripts.OnDragStop), "no own mover") end
PRD.SetPosition(5, -120)
assert(ui.GetOption("prd", "prdY") == -120, "slider sees the position")
SlashCmdList.FOREVERUIPRD("reset")
assert(ForeverStockUIDB.prdX == 0 and ForeverStockUIDB.prdY == -170)

assert(PRD.SetTest(true))
tick(0.1, 10)
assert(root.alpha == 1 and #PRD.auraList == #PRD.sampleAuras, "test mode shows sample procs")
assert(PRD.health.heal.shown and PRD.health.shieldGlow.shown, "test heal and shield")
assert(PRD.cells[4].bar.value == 1 and PRD.cells[5].bar.value == 0, "test combo 4")
SlashCmdList.FOREVERUIPRD("")
assert(#prints == 3 and prints[1]:match("^enabled=true class=ROGUE"), "diagnostics")
for _, line in ipairs(prints) do assert(not line:find("[\128-\255]"), "ASCII diagnostics") end
combat = true
fire("PLAYER_REGEN_DISABLED")
assert(not PRD.test, "combat ends test mode")
combat = false
fire("PLAYER_REGEN_ENABLED")

---------------------------------------------------------------------------------------------------
-- Edit Mode: registered, preview while open, drag / scale / reset go into prdX / prdY / prdScale
---------------------------------------------------------------------------------------------------
local entry = editEntries[#editEntries]
assert(entry and entry.frame == root and entry.label == "Панель ресурсов" and entry.panel == "prd", "in Edit Mode")
assert(entry == PRD.editEntry and entry.noToggle and not entry.removed)
tick(0.1, 30)
assert(root.alpha == 0, "idle before the editor")
ForeverStockUIEditMode.scripts.OnShow(ForeverStockUIEditMode)
tick(0.1, 10)
assert(PRD.editing and PRD.test and root.alpha == 1, "editor shows the full preview")
assert(PRD.health.heal.shown and PRD.classFrame.shown, "all layers for the outline")
-- The editor moved the frame (TOPRIGHT anchor) and saved its own position.
root.cx, root.cy = 40, 100
entry.config.position, entry.points = { -400, -300 }, { { "CENTER" } }
entry.onDragStop()
assert(ForeverStockUIDB.prdX == 40 and ForeverStockUIDB.prdY == 100, "drag taken over")
assert(entry.config.position == nil and entry.points == nil, "no second position in the edit layout")
assert(ui.GetOption("prd", "prdX") == 40)
local p = root.points[#root.points]
assert(p[1] == "CENTER" and p[4] == 40 and p[5] == 100, "anchored at the centre offset")
assert(entry.changeScale(1.5) == true, "scale handled by the panel")
assert(ForeverStockUIDB.prdScale == 150 and root.scale == 1.5)
p = root.points[#root.points]
assert(math.abs(p[4] - 40 / 1.5) < 0.001 and math.abs(p[5] - 100 / 1.5) < 0.001, "offset in screen pixels at any scale")
assert(entry.config.scale == nil)
entry.resetPosition()
assert(ForeverStockUIDB.prdX == 0 and ForeverStockUIDB.prdY == -170 and ForeverStockUIDB.prdScale == 100, "reset")
ForeverStockUIEditMode.scripts.OnHide(ForeverStockUIEditMode)
assert(not PRD.editing and not PRD.test, "preview ends with the editor")
assert(PRD.SetTest(true))
ForeverStockUIEditMode.scripts.OnShow(ForeverStockUIEditMode)
ForeverStockUIEditMode.scripts.OnHide(ForeverStockUIEditMode)
assert(PRD.test, "test mode switched on before stays on")
PRD.SetTest(false)

-- Disable: hidden, events off.
ui.SetOption("prd", "prdEnabled", false)
assert(not root.shown and not PRD.live and not events.UNIT_HEALTH[PRD.events], "disabled")
assert(entry.removed, "a disabled panel has no Edit Mode outline")
ui.SetOption("prd", "prdEnabled", true)
assert(root.shown and PRD.live and not entry.removed)

---------------------------------------------------------------------------------------------------
-- Druid: forms, druid mana, combo in cat
---------------------------------------------------------------------------------------------------
P.powerType = 0
reload("DRUID")
assert(PRD.classMode == nil and not PRD.druidMana.shown, "caster form: mana, no class block")
P.power[0] = 70
fire("UNIT_MANA", "player")
assert(PRD.power.bar.color[3] == 1 and PRD.power.text.text == "70", "mana blue")
assert(PRD.state.fiveStart == now, "mana spent starts the five second rule")
set("prdFiveSecond", true)
assert(math.abs(PRD.SparkPosition(now + 2.5) - 0.5) < 0.01)
assert(PRD.SparkPosition(now + 6) == nil, "five seconds over")
P.powerType = 1
fire("UNIT_DISPLAYPOWER", "player")
assert(PRD.druidMana.shown, "bear: druid mana bar")
assert(PRD.power.bar.color[1] == 0.9, "rage red")
assert(math.abs(PRD.druidMana.bar.target - 0.7) < 0.01, "druid mana value")
assert(PRD.classMode == nil)
P.powerType = 3
fire("UNIT_DISPLAYPOWER", "player")
assert(PRD.classMode == "combo" and PRD.classFrame.shown, "cat: combo points")
set("prdDruidMana", false)
assert(not PRD.druidMana.shown)
set("prdDruidMana", true)
P.power[0] = 100
P.powerType = 0
fire("UNIT_DISPLAYPOWER", "player")
assert(PRD.classMode == nil and not PRD.druidMana.shown)

---------------------------------------------------------------------------------------------------
-- Death knight: runes
---------------------------------------------------------------------------------------------------
P.powerType = 6
P.power[6] = 0
reload("DEATHKNIGHT")
assert(PRD.classMode == "runes")
assert(events.RUNE_POWER_UPDATE[PRD.events] and not (events.UNIT_COMBO_POINTS or {})[PRD.events])
tick(0.1, 30)
assert(root.alpha == 0, "runic power at 0 and ready runes rest")
P.runes[1] = { start = now - 4, duration = 10 }
P.runes[3] = { kind = 4 }
fire("RUNE_POWER_UPDATE", 1)
assert(math.abs(PRD.cells[1].bar.value - 0.4) < 0.01, "recharge progress")
assert(PRD.cells[1].text.text == "6.0", "timer " .. tostring(PRD.cells[1].text.text))
assert(PRD.cells[3].bar.color[1] == 0.75, "death rune colour")
assert(PRD.cells[2].bar.value == 1 and PRD.cells[2].bar.color[1] == 1, "ready blood rune bright")
assert(PRD.state.runesBusy and PRD.Busy(), "recharging rune wakes")
tick(0.1, 10)
assert(math.abs(PRD.cells[1].bar.value - 0.5) < 0.02, "progress advances on the driver")
set("prdRuneOrder", "bfu")
assert(PRD.cells[3].bar.color[3] == 1, "frost in the third cell")
set("prdRuneOrder", "buf")
P.runes[1] = nil
fire("RUNE_POWER_UPDATE", 1)
P.power[6] = 30
fire("UNIT_RUNIC_POWER", "player")
assert(PRD.power.bar.color[2] == 0.82, "runic power cyan")
assert(PRD.Busy(), "runic power above 0 wakes")
set("prdRunes", false)
assert(PRD.classMode == "stacks", "bone shield stacks instead of runes")
P.buffs = { { name = "Костяной щит", id = 49222, count = 2, duration = 300, expires = now + 200, caster = "player" } }
fire("UNIT_AURA", "player")
assert(PRD.cells[2].bar.value == 1 and PRD.cells[3].bar.value == 0 and PRD.cells[3].shown, "2 of 3 charges")
P.buffs = {}
set("prdRunes", true)

---------------------------------------------------------------------------------------------------
-- Shaman: totems and stacks
---------------------------------------------------------------------------------------------------
P.powerType = 0
reload("SHAMAN")
assert(PRD.classMode == "totems")
P.totems[1] = { name = "Тотем опаляющего огня", start = now - 15, duration = 60, icon = "Interface\\Icons\\T1" }
fire("PLAYER_TOTEM_UPDATE", 1)
assert(math.abs(PRD.cells[1].bar.value - 0.75) < 0.01 and PRD.cells[1].icon.shown, "fire totem")
assert(PRD.cells[1].text.text == "45", "totem timer " .. tostring(PRD.cells[1].text.text))
assert(not PRD.cells[2].icon.shown, "no earth totem")
assert(PRD.state.totemsBusy and PRD.Busy())
P.totems[1] = nil
fire("PLAYER_TOTEM_UPDATE", 1)
assert(not PRD.state.totemsBusy)
set("prdTotems", false)
assert(PRD.classMode == "stacks", "shaman stacks without totems")
P.buffs = { { name = "Оружие Водоворота", id = 53817, count = 4, duration = 30, expires = now + 20, caster = "player" } }
fire("UNIT_AURA", "player")
assert(PRD.cells[4].bar.value == 1 and PRD.cells[5].bar.value == 0 and not PRD.cells[1].glow.shown, "4 of 5")
P.buffs[1].count = 5
fire("UNIT_AURA", "player")
assert(PRD.cells[1].glow.shown, "5 stacks glow")
set("prdStackCustom", "324")
set("prdStackCustomMax", 3)
P.buffs = { { name = "Щит молний", id = 49281, count = 2, duration = 600, expires = now + 500, caster = "player" } }
fire("UNIT_AURA", "player")
assert(PRD.cells[3].shown and not PRD.cells[4].shown and PRD.cells[2].bar.value == 1, "custom stack aura by id")
set("prdStackCustom", "")
set("prdTotems", true)
P.buffs = {}

---------------------------------------------------------------------------------------------------
-- Warlock: soul shards
---------------------------------------------------------------------------------------------------
reload("WARLOCK")
assert(PRD.classMode == "stacks")
P.shards = 7
fire("BAG_UPDATE", 0)
assert(PRD.classLabel.text:match("7$"), "shard count " .. tostring(PRD.classLabel.text))

---------------------------------------------------------------------------------------------------
-- Priest: stacks row under the power bar, never on it; empty stacks hidden; stock texture; text size
---------------------------------------------------------------------------------------------------
spellNames[63735] = "Прозорливость"
P.powerType = 0
ForeverStockUIDB.prdProfiles.shared.prdTexture = 2
ForeverStockUIDB.prdProfiles.shared.prdStockTexture = nil
reload("PRIEST")
assert(ui.GetOption("prd", "prdTexture") == 1, "old WoW: Forever default moved to the stock texture")
assert(ui.GetDefault("prd", "prdTexture") == 1, "stock texture by default")
assert(PRD.classMode == "stacks")
local cp = PRD.classFrame.points
assert(#cp == 2 and cp[1][2] == PRD.power and cp[1][3] == "BOTTOMLEFT" and cp[1][5] == -3, "class row hangs under the power bar")
local pp = PRD.power.points
assert(pp[1][2] == PRD.health and pp[1][3] == "BOTTOMLEFT" and pp[1][5] == 1, "power under health, shared border")
assert(PRD.power.level > PRD.classFrame.level, "bars above the class row")
for i = 1, 3 do
    local c = PRD.cells[i].points
    assert(c[1][1] == "TOPLEFT" and c[1][2] == PRD.classFrame and c[2][1] == "BOTTOMLEFT" and c[2][2] == PRD.classFrame,
        "cell pinned to the class row top and bottom")
end
assert(PRD.classFrame.alpha == 0, "no stacks: row hidden")
P.buffs = { { name = "Прозорливость", id = 63735, count = 2, duration = 20, expires = now + 10, caster = "player" } }
fire("UNIT_AURA", "player")
assert(PRD.classFrame.alpha == 1 and PRD.cells[2].bar.value == 1, "stacks show")
P.buffs = {}
fire("UNIT_AURA", "player")
assert(PRD.classFrame.alpha == 0)
set("prdStackHideEmpty", false)
assert(PRD.classFrame.alpha == 1, "empty stacks shown on request")
assert(PRD.power.text.font[2] == 10 and PRD.health.text.font[2] == 11, "power text fits an 8 px bar")
set("prdPowerHeight", 20)
assert(PRD.power.text.font[2] == 11)
set("prdPowerHeight", 8)

-- Disabling hides the aura holder with the panel.
set("prdEnabled", false)
assert(not PRD.auraHolder.shown, "aura holder hidden with the panel")
set("prdEnabled", true)
assert(PRD.auraHolder.shown)

-- Paladin: nothing to show in the class block.
reload("PALADIN")
assert(PRD.classMode == nil and not PRD.classFrame.shown)

print("PersonalResource tests passed")
