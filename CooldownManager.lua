-- ForeverUI Cooldown Manager: any number of tracker groups (icon grids or progress bars) in the
-- WoW Forever look. Tracks spell, item and trinket cooldowns (GCD filtered), present and missing
-- buffs, weapon enchants, food and flasks, own debuffs on target/focus, internal cooldowns,
-- totems and summons. Data lives in the active suite profile (Suite.Part("cdm")).
-- One event frame marks the state dirty; the display is rebuilt at most 20 times a second and the
-- timers tick at 10 Hz only while something is running. Bars move smoothly per frame only while
-- they are animated. WotLK 3.3.5a, Lua 5.1.
local _, ui = ...
local L, Suite = ui.L, ui.Suite
local floor, max, min, format = math.floor, math.max, math.min, string.format
local GetTime = GetTime

local CDM = {}
ui.CooldownManager = CDM

CDM.kinds = {
    { "cooldown", L("Перезарядка", "Cooldown") },
    { "buff", L("Активный бафф", "Active buff") },
    { "missing", L("Отсутствующий бафф", "Missing buff") },
    { "debuff", L("Дебафф / ДоТ", "Debuff / DoT") },
    { "icd", L("Внутренняя перезарядка (ICD)", "Internal cooldown (ICD)") },
    { "totem", L("Тотем", "Totem") },
    { "summon", L("Призванное существо", "Summon") },
}
CDM.kindNames = {}
for _, entry in ipairs(CDM.kinds) do CDM.kindNames[entry[1]] = entry[2] end

CDM.missingTypes = {
    { "aura", L("Бафф или аура", "Buff or aura") },
    { "form", L("Стойка, форма, аура паладина", "Stance, form, paladin aura") },
    { "weapon_mh", L("Чары правой руки", "Main hand enchant") },
    { "weapon_oh", L("Чары левой руки", "Off hand enchant") },
    { "food", L("Еда (сытость)", "Food (Well Fed)") },
    { "flask", L("Настой / эликсир", "Flask / elixir") },
}

local FLASKS = { 53755, 53758, 53760, 54212, 62380, 67016, 67017, 67018, 17628, 17627, 17626, 28518, 28519,
    28520, 28521, 28540, 33721, 53747, 53748, 53749, 53751, 53752, 53763, 53764, 60340, 60341, 60343,
    60344, 60345, 60346, 60347 }
local WELL_FED = { 57399, 57079, 57097, 57102, 57107, 57111, 57139, 57286, 57291, 57325, 57327, 57329,
    57332, 57334, 57356, 57358, 57360, 57363, 57365, 57367, 57371, 57373, 59230, 65247, 66623, 46899, 19705 }

---------------------------------------------------------------------------------------------------
-- Defaults and presets
---------------------------------------------------------------------------------------------------
local GROUP_DEFAULTS = {
    enabled = true, kind = "icons",
    size = 36, spacing = 4, perRow = 8, grow = "RIGHT", wrap = "DOWN", alpha = 1, inactiveAlpha = 0.45,
    layout = "dynamic", cdShow = "always", desaturate = true, showGCD = false, showSwipe = true,
    showTimer = true, showCount = true, fontSize = 12, timerSize = 13,
    borderColor = { 0.85, 0.72, 0.45, 1 },
    barWidth = 200, barHeight = 20, barFormat = "full", barTexture = "WoW Forever Raid",
    barColor = { 0.86, 0.62, 0.24, 1 }, barBackground = { 0, 0, 0, 0.55 },
    -- state clarity: buff of the spell itself on the icon, timer colours, range tint, look of the border
    showActive = true, activeColor = { 0.35, 1, 0.45, 1 }, timerColors = true, rangeTint = true,
    borderStyle = "forever", categoryBorder = false, oocAlpha = 1, sort = "manual",
    load = { when = "always", group = "any", talentGroup = 0, tree = 0, form = 0, class = "",
        zone = { none = true, party = true, raid = true, pvp = true, arena = true } },
}
CDM.groupDefaults = GROUP_DEFAULTS

local ITEM_DEFAULTS = {
    kind = "cooldown", spell = "", unit = "player", mine = true, missingType = "aura",
    duration = 45, warn = 3, procAura = "", glowUsable = false, hideUnknown = true,
    onlyCombat = false, onlyGroup = false, requires = "", class = "", spec = 0,
    glowReady = false, soundReady = "", stacks = 0, glowStacks = true, soundStacks = "",
    expire = 0, glowExpire = true, soundExpire = "", glowMissing = true,
    category = "", showActive = true, activeAura = "",
}
CDM.itemDefaults = ITEM_DEFAULTS

local function item(kind, spell, extra)
    local entry = { kind = kind, spell = spell }
    for k, v in pairs(extra or {}) do entry[k] = v end
    return entry
end
local function cds(list) local t = {} for i, id in ipairs(list) do t[i] = item("cooldown", id) end return t end
local function buffs(list) local t = {} for i, id in ipairs(list) do t[i] = item("buff", id) end return t end
local function dots(list, unit)
    local t = {}
    for i, id in ipairs(list) do t[i] = item("debuff", id, { unit = unit or "target", warn = 3 }) end
    return t
end

-- Class presets (WotLK spell ids; unknown spells hide themselves). For each class: `all` holds what every
-- spec tracks, [1]..[3] what only that talent tree (in the order of the talent tabs) tracks. Starting
-- groups put the spec entries first, then the common ones; every entry is tagged with its class and
-- tree, so the groups change with the primary talent tree. A spell may repeat in several trees.
local presets = {
    WARRIOR = {
        trees = { L("Оружие", "Arms"), L("Неистовство", "Fury"), L("Защита", "Protection") },
        all = { essential = cds({ 1719, 871 }),
            utility = cds({ 6552, 100, 20252, 5246, 23920, 3411, 18499, 57755, 55694, 64382 }),
            bars = { item("buff", 6673, { warn = 10 }) },
            missing = { item("missing", "6673, 469", { onlyCombat = true }) } },
        { essential = cds({ 12294, 7384, 46924, 12328 }), buffs = buffs({ 52437, 60503 }),
            bars = { item("debuff", 772, { unit = "target", warn = 3 }), item("debuff", 12294, { unit = "target" }) } },
        { essential = cds({ 23881, 1680, 12292, 60970 }), buffs = buffs({ 46916, 12292 }),
            bars = { item("buff", 12292) } },
        { essential = cds({ 23922, 6572, 46968, 12809, 12975, 2565 }), utility = cds({ 355, 694, 1161, 72 }),
            buffs = buffs({ 50227, 2565, 871, 12975 }), bars = dots({ 7386, 6343, 1160 }) },
    },
    PALADIN = {
        trees = { L("Свет", "Holy"), L("Защита", "Protection"), L("Воздаяние", "Retribution") },
        all = { essential = cds({ 31884, 642, 498 }),
            utility = cds({ 853, 1022, 633, 1044, 6940 }),
            buffs = buffs({ 31884 }),
            missing = { item("missing", "20166, 20165, 21084, 20375, 31801, 53736"),
                item("missing", "", { missingType = "form" }) } },
        { essential = cds({ 20473, 31842, 54428, 31821, 20216 }), buffs = buffs({ 54149, 31842, 53601 }),
            bars = { item("buff", 53601), item("buff", 54428) } },
        { essential = cds({ 31935, 53595, 20925, 26573, 53600, 20271 }), utility = cds({ 62124, 31789, 64205 }),
            buffs = buffs({ 20925 }), bars = { item("buff", 20925) },
            missing = { item("missing", 25780, { onlyCombat = true }) } },
        { essential = cds({ 35395, 53385, 20271, 879, 26573, 24275 }), utility = cds({ 20066 }),
            buffs = buffs({ 59578 }) },
    },
    PRIEST = {
        trees = { L("Послушание", "Discipline"), L("Свет", "Holy"), L("Тьма", "Shadow") },
        all = { utility = cds({ 6346, 8122, 586, 34433, 64843, 64901 }),
            missing = { item("missing", 588), item("missing", "1243, 21562", { onlyGroup = true }) } },
        { essential = cds({ 47540, 17, 33206, 10060, 14751 }), buffs = buffs({ 59889, 14751, 10060 }),
            bars = { item("buff", 10060) } },
        { essential = cds({ 34861, 33076, 47788, 724, 14751 }), buffs = buffs({ 33151, 63735 }),
            bars = { item("buff", 63735) } },
        { essential = cds({ 8092, 32379, 47585, 64044 }), utility = cds({ 15487 }), buffs = buffs({ 15258 }),
            bars = dots({ 589, 34914, 2944 }), missing = { item("missing", 15473) } },
    },
    DRUID = {
        trees = { L("Баланс", "Balance"), L("Сила зверя", "Feral Combat"), L("Исцеление", "Restoration") },
        all = { essential = cds({ 22812, 29166 }),
            utility = cds({ 1850, 20484, 33786 }),
            buffs = buffs({ 16870 }),
            missing = { item("missing", "1126, 21849", { onlyGroup = true }), item("missing", "", { missingType = "form" }) } },
        { essential = cds({ 48505, 33831, 50516 }), buffs = buffs({ 48517, 48518 }),
            bars = dots({ 8921, 5570, 770 }) },
        { essential = cds({ 5217, 50334, 33878, 61336, 5229 }), utility = cds({ 5211, 22842, 16979, 49376 }),
            buffs = buffs({ 52610, 50334, 69369 }), bars = dots({ 1079, 1822, 33745 }) },
        { essential = cds({ 18562, 17116, 48438, 740 }), bars = { item("buff", 29166) } },
    },
    SHAMAN = {
        trees = { L("Стихии", "Elemental"), L("Совершенствование", "Enhancement"), L("Исцеление", "Restoration") },
        all = { utility = cds({ 57994, 51514, 8177, 32182, 2825, 2484, 2894, 2062 }),
            bars = { item("totem", 1), item("totem", 2), item("totem", 3), item("totem", 4) },
            missing = { item("missing", "", { missingType = "weapon_mh" }) } },
        { essential = cds({ 51505, 8050, 16166, 51490 }), buffs = buffs({ 16246, 324 }),
            bars = dots({ 8050 }), missing = { item("missing", 324) } },
        { essential = cds({ 17364, 60103, 51533, 30823, 8042, 1535 }), buffs = buffs({ 53817, 30823 }),
            missing = { item("missing", 324), item("missing", "", { missingType = "weapon_oh" }) } },
        { essential = cds({ 61295, 16188, 16190, 55198 }), buffs = buffs({ 53390, 52127 }),
            missing = { item("missing", 52127) } },
    },
    MAGE = {
        trees = { L("Тайная магия", "Arcane"), L("Огонь", "Fire"), L("Лёд", "Frost") },
        all = { essential = cds({ 12051, 55342, 45438 }),
            utility = cds({ 1953, 2139, 122, 66 }),
            missing = { item("missing", "1459, 23028, 61316", { onlyGroup = true }),
                item("missing", "30482, 6117, 7302, 168") } },
        { essential = cds({ 12042, 12043, 44425 }), buffs = { item("buff", 44401), item("buff", 12042), item("buff", 12043),
            item("debuff", 36032, { unit = "player" }) } },
        { essential = cds({ 11129, 31661, 11113, 2136 }), buffs = buffs({ 48108 }), bars = dots({ 44457, 12654, 22959 }) },
        { essential = cds({ 12472, 11958, 31687, 44572, 120, 11426 }), buffs = buffs({ 44544, 57761, 12472 }),
            bars = { item("buff", 11426) } },
    },
    WARLOCK = {
        trees = { L("Колдовство", "Affliction"), L("Демонология", "Demonology"), L("Разрушение", "Destruction") },
        all = { utility = cds({ 29858, 18708, 698, 29893, 6789, 5484, 48020, 19647 }),
            missing = { item("missing", "28176, 706, 687") } },
        { essential = cds({ 48181, 18220 }), buffs = buffs({ 17941, 64371 }), bars = dots({ 172, 980, 30108, 48181 }) },
        { essential = cds({ 47193, 47241, 50589, 54785 }), buffs = buffs({ 63167, 71165, 47241 }),
            bars = dots({ 172, 348, 603 }) },
        { essential = cds({ 17962, 50796, 17877, 30283 }), buffs = buffs({ 54277, 34936 }), bars = dots({ 348, 1490, 980 }) },
    },
    HUNTER = {
        trees = { L("Чувство зверя", "Beast Mastery"), L("Стрельба", "Marksmanship"), L("Выживание", "Survival") },
        all = { essential = cds({ 3045, 53351, 2643 }),
            utility = cds({ 34477, 5384, 781, 19263, 1499, 13813, 60192, 19503, 53271 }),
            buffs = buffs({ 3045 }),
            bars = dots({ 1978 }),
            missing = { item("missing", "61846, 13165, 34074") } },
        { essential = cds({ 19574, 34026, 19577, 3044 }), buffs = buffs({ 19574, 34471, 53257 }),
            bars = { item("buff", 136, { unit = "pet" }) } },
        { essential = cds({ 53209, 19434, 3044, 23989, 34490 }), buffs = buffs({ 53220, 6150 }) },
        { essential = cds({ 53301, 3674, 19306 }), buffs = buffs({ 56453 }), bars = dots({ 3674 }) },
    },
    ROGUE = {
        trees = { L("Ликвидация", "Assassination"), L("Бой", "Combat"), L("Скрытность", "Subtlety") },
        all = { utility = cds({ 1766, 5277, 31224, 1856, 2094, 408, 57934, 2983, 1776 }),
            buffs = buffs({ 5171 }),
            bars = { item("buff", 5171, { warn = 3 }), item("debuff", 1943, { unit = "target" }) },
            missing = { item("missing", "", { missingType = "weapon_mh" }), item("missing", "", { missingType = "weapon_oh" }) } },
        { essential = cds({ 14177, 51662 }), buffs = buffs({ 51662, 32645, 14177 }), bars = dots({ 2818 }) },
        { essential = cds({ 13750, 13877, 51690 }), buffs = buffs({ 13750, 13877, 51690 }), bars = dots({ 8647 }) },
        { essential = cds({ 14185, 51713, 36554, 14183 }), buffs = buffs({ 51713, 36554 }), bars = dots({ 703, 16511 }) },
    },
    DEATHKNIGHT = {
        trees = { L("Кровь", "Blood"), L("Лёд", "Frost"), L("Нечестивость", "Unholy") },
        all = { essential = cds({ 48792, 48707, 47568, 42650 }),
            utility = cds({ 47528, 47476, 49576, 56222, 48743, 46584, 49039 }),
            buffs = buffs({ 53365 }),
            bars = dots({ 55078, 55095 }),
            missing = { item("missing", 57330, { onlyCombat = true }), item("missing", "", { missingType = "form" }) } },
        { essential = cds({ 55233, 49028, 48982, 49005, 49016 }), buffs = buffs({ 55233 }) },
        { essential = cds({ 49184, 51271, 49203, 49796 }), buffs = buffs({ 51124, 59052, 51271 }) },
        { essential = cds({ 49206, 43265, 49222, 51052 }), buffs = buffs({ 49222 }) },
    },
}
CDM.presets = presets

---------------------------------------------------------------------------------------------------
-- Categories, roles and display modes
---------------------------------------------------------------------------------------------------
-- What a cooldown is for. Drives the order inside a group (by role), the optional border colour and
-- what a display mode hides. An entry may override it (entry.category); "" = from this table.
CDM.categories = {
    { "offensive", L("Бурст", "Offensive"), { 1.00, 0.55, 0.15 } },
    { "defensive", L("Защита / иммунитет", "Defensive / immunity"), { 0.35, 0.75, 1.00 } },
    { "control", L("Прерывание и контроль", "Interrupt and control"), { 0.80, 0.50, 1.00 } },
    { "utility", L("Мобильность и утилити", "Mobility and utility"), { 0.60, 0.85, 0.50 } },
    { "raid", L("На группу / рейд", "Externals / raid"), { 1.00, 0.85, 0.30 } },
}
CDM.categoryColors, CDM.categoryNames = {}, {}
for _, entry in ipairs(CDM.categories) do
    CDM.categoryNames[entry[1]], CDM.categoryColors[entry[1]] = entry[2], entry[3]
end

local CATEGORY_SPELLS = {
    offensive = { 1719, 12292, 46924, 12328, 31884, 20216, 31842, 10060, 14751, 34433, 48505, 33831, 50334, 5217,
        17116, 16166, 51533, 16188, 2894, 12042, 12043, 11129, 12472, 55342, 31687, 47241, 3045, 19574, 23989,
        34026, 14177, 13750, 13877, 51690, 51713, 14185, 49016, 49028, 49206, 47568, 42650 },
    defensive = { 871, 12975, 2565, 23920, 55694, 642, 498, 633, 47585, 586, 22812, 61336, 22842, 30823, 45438,
        11426, 19263, 5384, 5277, 31224, 1856, 48792, 48707, 55233, 48982, 49222, 51271, 49039, 48743 },
    control = { 6552, 72, 5246, 46968, 12809, 853, 20066, 8122, 15487, 64044, 33786, 5211, 16979, 50516, 57994,
        51514, 8177, 2139, 122, 44572, 31661, 19647, 6789, 5484, 30283, 34490, 19577, 1499, 19503, 1766, 2094,
        408, 1776, 47528, 47476, 49203, 49576 },
    utility = { 100, 20252, 3411, 18499, 57755, 355, 694, 1161, 1044, 62124, 31789, 6346, 1850, 49376, 2484, 2062,
        1953, 66, 12051, 11958, 18708, 698, 29893, 48020, 34477, 781, 13813, 60192, 57934, 2983, 36554, 56222,
        46584, 29858, 53271 },
    raid = { 6940, 1022, 31821, 64205, 33206, 47788, 64843, 64901, 724, 29166, 20484, 740, 2825, 32182, 16190,
        51052, 20707 },
}
local categoryById, categoryByName = {}, nil
for category, ids in pairs(CATEGORY_SPELLS) do
    for _, id in ipairs(ids) do categoryById[id] = category end
end
CDM.categoryById = categoryById

-- Role of each talent tree (order of the talent tabs). Feral druids and death knights are resolved at
-- run time: see resolveRole().
local ROLES = {
    WARRIOR = { "MELEE", "MELEE", "TANK" }, PALADIN = { "HEALER", "TANK", "MELEE" },
    PRIEST = { "HEALER", "HEALER", "RANGED" }, DRUID = { "RANGED", "MELEE", "HEALER" },
    SHAMAN = { "RANGED", "MELEE", "HEALER" }, MAGE = { "RANGED", "RANGED", "RANGED" },
    WARLOCK = { "RANGED", "RANGED", "RANGED" }, HUNTER = { "RANGED", "RANGED", "RANGED" },
    ROGUE = { "MELEE", "MELEE", "MELEE" }, DEATHKNIGHT = { "MELEE", "MELEE", "MELEE" },
}
CDM.treeRoles = ROLES
CDM.roles = {
    { "auto", L("Авто (по талантам)", "Auto (from talents)") },
    { "TANK", L("Танк", "Tank") }, { "HEALER", L("Лекарь", "Healer") },
    { "MELEE", L("Ближний бой", "Melee DPS") }, { "RANGED", L("Дальний бой", "Ranged DPS") },
}
CDM.roleNames = {}
for _, entry in ipairs(CDM.roles) do CDM.roleNames[entry[1]] = entry[2] end

-- Order of the categories inside a group sorted by role (lower first); entries without a category
-- (rotation spells) sit after the two leading categories.
local ROLE_ORDER = {
    TANK = { defensive = 1, control = 2, offensive = 3, raid = 4, utility = 5 },
    HEALER = { raid = 1, defensive = 2, offensive = 3, control = 4, utility = 5 },
    MELEE = { offensive = 1, control = 2, defensive = 3, utility = 4, raid = 5 },
}
ROLE_ORDER.RANGED = ROLE_ORDER.MELEE
local UNCATEGORISED_RANK = 2.5

-- Display modes: which starting groups a mode shows ("custom" = the user's own groups) and which
-- cooldown categories it hides. A group may override its own visibility per mode (group.modes).
local ALL_GROUPS = { essential = true, utility = true, buffs = true, bars = true, missing = true, custom = true }
CDM.modes = {
    { "full", L("Полный", "Full") }, { "combat", L("Только бой", "Combat") }, { "raid", L("Рейд", "Raid") },
    { "dungeon", L("Подземелье", "Dungeon") }, { "pvp", "PvP" }, { "minimal", L("Минимум", "Minimal") },
}
CDM.modeNames = { auto = L("Авто", "Auto") }
for _, entry in ipairs(CDM.modes) do CDM.modeNames[entry[1]] = entry[2] end
local MODE_RULES = {
    full = { groups = ALL_GROUPS },
    combat = { groups = { essential = true, utility = true, buffs = true, bars = true, custom = true }, combatOnly = true },
    raid = { groups = ALL_GROUPS, hide = { utility = true } },
    dungeon = { groups = ALL_GROUPS },
    pvp = { groups = { essential = true, utility = true, buffs = true, custom = true }, hide = { raid = true } },
    minimal = { groups = { essential = true }, hide = { utility = true, raid = true, control = true } },
}
CDM.modeRules = MODE_RULES
local AUTO_MODES = { none = "full", party = "dungeon", raid = "raid", pvp = "pvp", arena = "pvp" }
CDM.autoModeDefaults = AUTO_MODES

-- The five starting groups; `preset` marks a group as one of them, so a deleted group can be restored.
local PRESET_GROUPS = {
    { key = "essential", name = "Essential Cooldowns", kind = "icons",
        extra = { size = 42, perRow = 8, sort = "role", grow = "CENTER" } },
    { key = "utility", name = "Utility Cooldowns", kind = "icons",
        extra = { size = 30, perRow = 10, sort = "role", grow = "CENTER" } },
    { key = "buffs", name = "Tracked Buffs", kind = "icons", extra = { size = 32, perRow = 8, cdShow = "always", grow = "CENTER" } },
    { key = "bars", name = "Tracked Bars", kind = "bars", extra = { perRow = 1, grow = "DOWN" } },
    { key = "missing", name = L("Напоминания", "Reminders"), names = { "Напоминания", "Reminders" }, kind = "icons",
        extra = { size = 34, perRow = 6, grow = "CENTER" }, zone = { none = true, party = true, raid = true, pvp = false, arena = false },
        -- class-free entries every character gets
        tail = { item("missing", "", { missingType = "flask", onlyGroup = true }),
            item("missing", "", { missingType = "food", onlyGroup = true }) } },
}
CDM.presetGroups = PRESET_GROUPS

local function playerClass()
    local _, class = UnitClass("player")
    return class
end

-- Talent tree names of a class: the client's own names for the player's class, the preset names otherwise.
function CDM.TreeNames(class)
    class = class and class ~= "" and class or playerClass()
    if class == playerClass() and Suite.TreeNames then
        local names = Suite.TreeNames()
        if #names > 0 then return names end
    end
    return presets[class] and presets[class].trees or {}
end

-- Default entries of one preset group for a class, tagged with class and tree: spec entries first
-- (tree 1, 2, 3; only one of them is ever shown), then the common ones, then the class-free tail.
local function presetItems(key, class)
    local preset, list = presets[class or ""], {}
    local function add(source, spec, tagClass)
        for _, entry in ipairs(source or {}) do
            local copy = Suite.Copy(entry)
            copy.class, copy.spec = tagClass or "", spec
            list[#list + 1] = copy
        end
    end
    if preset then
        for tree = 1, 3 do add(preset[tree] and preset[tree][key], tree, class) end
        add(preset.all and preset.all[key], 0, class)
    end
    for _, def in ipairs(PRESET_GROUPS) do
        if def.key == key then add(def.tail, 0, nil) end
    end
    return list
end
CDM.PresetItems = presetItems

local function newGroup(name, kind, extra)
    local group = Suite.Copy(GROUP_DEFAULTS)
    group.name, group.kind, group.items = name, kind or "icons", {}
    for k, v in pairs(extra or {}) do group[k] = v end
    return group
end

local function presetGroup(def, class)
    local extra = Suite.Copy(def.extra or {})
    extra.items, extra.preset = presetItems(def.key, class), def.key
    local group = newGroup(def.name, def.kind, extra)
    if def.zone then group.load.zone = Suite.Copy(def.zone) end
    return group
end

local function starterGroups(class)
    local list = {}
    for _, def in ipairs(PRESET_GROUPS) do list[#list + 1] = presetGroup(def, class or playerClass()) end
    return list
end

-- Identity of an entry for restoring defaults: what is tracked, not how it looks.
local function entryKey(entry)
    return (entry.kind or "") .. "|" .. tostring(entry.spell or "") .. "|"
        .. (entry.kind == "missing" and (entry.missingType or "aura") or "")
end
CDM.EntryKey = entryKey

local function insertGroup(db, group, position)
    local id = db.nextId
    db.nextId = id + 1
    group.id = id
    db.groups[id] = group
    table.insert(db.order, min(position or #db.order + 1, #db.order + 1), id)
    return id
end

local function presetGroupOf(db, key)
    for _, id in ipairs(db.order) do
        local group = db.groups[id]
        if group and group.preset == key then return group end
    end
end

-- Profiles from before the spec split: the starting groups are found by name and their default
-- entries get the class and tree tags of the matching preset entries; the user's own entries stay
-- for every spec. Runs once per class and profile.
local function tagLegacy(db, class)
    for _, def in ipairs(PRESET_GROUPS) do
        if not presetGroupOf(db, def.key) then
            for _, id in ipairs(db.order) do
                local group = db.groups[id]
                local names = def.names or { def.name }
                local matches = false
                for _, name in ipairs(names) do if group and group.name == name then matches = true end end
                if matches and not group.preset then group.preset = def.key break end
            end
        end
        local group = presetGroupOf(db, def.key)
        if group then
            local byKey = {}
            for _, entry in ipairs(presetItems(def.key, class)) do
                byKey[entryKey(entry)] = byKey[entryKey(entry)] or entry
            end
            for _, entry in ipairs(group.items or {}) do
                local default = byKey[entryKey(entry)]
                if default and (entry.class or "") == "" and (entry.spec or 0) == 0 then
                    entry.class, entry.spec = default.class, default.spec
                    byKey[entryKey(entry)] = nil
                end
            end
        end
    end
end

Suite.RegisterProfilePart("cdm", function(db)
    if type(db.specTagged) ~= "table" then db.specTagged = {} end
    if type(db.groups) ~= "table" then
        db.groups, db.order, db.nextId = {}, {}, 1
        local class = playerClass()
        for _, group in ipairs(starterGroups(class)) do insertGroup(db, group) end
        if class then db.specTagged[class] = true end
    end
    if type(db.order) ~= "table" then db.order = {} end
    db.nextId = tonumber(db.nextId) or 1
    for id, group in pairs(db.groups) do
        if type(group) == "table" then
            group.id = id
            Suite.Merge(group, GROUP_DEFAULTS)
            if type(group.items) ~= "table" then group.items = {} end
            for _, entry in ipairs(group.items) do Suite.Merge(entry, ITEM_DEFAULTS) end
            if id >= db.nextId then db.nextId = id + 1 end
        else
            db.groups[id] = nil
        end
    end
    -- Order holds every group once.
    local seen, order = {}, {}
    for _, id in ipairs(db.order) do
        if db.groups[id] and not seen[id] then seen[id] = true order[#order + 1] = id end
    end
    for id in pairs(db.groups) do if not seen[id] then order[#order + 1] = id end end
    db.order = order
    local class = playerClass()
    if class and not db.specTagged[class] then
        tagLegacy(db, class)
        db.specTagged[class] = true
    end
    -- Auto-adaptation, role, display mode and per-spec positions.
    if db.autoAdapt == nil then db.autoAdapt = true end
    if db.modeButton == nil then db.modeButton = true end
    if not CDM.roleNames[db.role or ""] then db.role = "auto" end
    if not CDM.modeNames[db.mode or ""] then db.mode = "auto" end
    if type(db.autoModes) ~= "table" then db.autoModes = {} end
    for zone, mode in pairs(AUTO_MODES) do
        if not MODE_RULES[db.autoModes[zone] or ""] then db.autoModes[zone] = mode end
    end
    if type(db.specSpots) ~= "table" then db.specSpots = {} end
    -- Profiles from before the role sort: the two cooldown groups get it once.
    if (tonumber(db.version) or 0) < 2 then
        for _, group in pairs(db.groups) do
            if group.preset == "essential" or group.preset == "utility" then group.sort = "role" end
        end
        db.version = 2
    end
    -- Starting icon groups still growing to the right are centred: the visible icons then sit in the
    -- middle of the box placed in Edit Mode, however many of them are hidden.
    if db.version < 3 then
        for _, group in pairs(db.groups) do
            if group.preset and group.kind == "icons" and group.grow == "RIGHT" then group.grow = "CENTER" end
        end
        db.version = 3
    end
end)

local function data() return Suite.Part("cdm") end
CDM.Data = data

---------------------------------------------------------------------------------------------------
-- Group and item operations (used by the options page)
---------------------------------------------------------------------------------------------------
function CDM.Groups()
    local db, list = data(), {}
    for _, id in ipairs(db.order) do list[#list + 1] = db.groups[id] end
    return list
end

function CDM.Group(id) return data().groups[id] end

function CDM.CreateGroup(name, kind)
    local db = data()
    local id = db.nextId
    db.nextId = id + 1
    local group = newGroup(name or (L("Группа ", "Group ") .. id), kind)
    if kind == "bars" then group.perRow, group.grow = 1, "DOWN" end
    group.id = id
    db.groups[id] = group
    db.order[#db.order + 1] = id
    CDM.Rebuild()
    return id
end

function CDM.DuplicateGroup(id)
    local db = data()
    local source = db.groups[id]
    if not source then return end
    local newId = db.nextId
    db.nextId = newId + 1
    local group = Suite.Copy(source)
    group.id, group.name = newId, (source.name or "") .. L(" (копия)", " (copy)")
    db.groups[newId] = group
    for index, existing in ipairs(db.order) do
        if existing == id then table.insert(db.order, index + 1, newId) break end
    end
    CDM.Rebuild()
    return newId
end

function CDM.DeleteGroup(id)
    local db = data()
    if not db.groups[id] then return end
    db.groups[id] = nil
    for index, existing in ipairs(db.order) do
        if existing == id then table.remove(db.order, index) break end
    end
    CDM.Rebuild()
end

function CDM.MoveGroup(id, delta)
    local order = data().order
    for index, existing in ipairs(order) do
        if existing == id then
            local target = index + delta
            if target >= 1 and target <= #order then
                order[index], order[target] = order[target], order[index]
            end
            return
        end
    end
end

function CDM.AddItem(groupId, kind, spell)
    local group = CDM.Group(groupId)
    if not group then return end
    local entry = Suite.Merge({ kind = kind or "cooldown", spell = spell or "" }, ITEM_DEFAULTS)
    if kind == "debuff" then entry.unit = "target" end
    -- With auto-adaptation the user's own entries belong to the spec they were added on.
    if data().autoAdapt and CDM.CurrentSpec then
        local class, tree = CDM.CurrentSpec()
        entry.class, entry.spec = class or "", tree or 0
    end
    group.items[#group.items + 1] = entry
    CDM.Refresh()
    return #group.items
end

function CDM.RemoveItem(groupId, index)
    local group = CDM.Group(groupId)
    if group and group.items[index] then
        table.remove(group.items, index)
        CDM.Refresh()
    end
end

function CDM.MoveItem(groupId, index, delta)
    local group = CDM.Group(groupId)
    if not group then return end
    local target = index + delta
    if group.items[index] and group.items[target] then
        group.items[index], group.items[target] = group.items[target], group.items[index]
        CDM.Refresh()
        return target
    end
    return index
end

-- Restores the starting groups. mode "missing": deleted starting groups come back where they were
-- and deleted default entries return into the starting groups (the user's own groups and entries stay);
-- mode "all": every group is replaced by the starting set. Returns groups and entries added.
function CDM.RestoreDefaults(mode)
    local db, class = data(), playerClass()
    if mode == "all" then
        db.groups, db.order, db.nextId = {}, {}, 1
        for _, group in ipairs(starterGroups(class)) do insertGroup(db, group) end
        if class then db.specTagged[class] = true end
        CDM.selectedGroup = nil
        if CDM.RefreshCombatLog then CDM.RefreshCombatLog() end
        CDM.Rebuild()
        return #db.order, 0
    end
    local addedGroups, addedItems = 0, 0
    local position = 0          -- order index of the last starting group seen
    for _, def in ipairs(PRESET_GROUPS) do
        local group = presetGroupOf(db, def.key)
        if not group then
            local id = insertGroup(db, presetGroup(def, class), position + 1)
            addedGroups, addedItems = addedGroups + 1, addedItems + #db.groups[id].items
            position = position + 1
        else
            for index, id in ipairs(db.order) do if id == group.id then position = index end end
            -- An entry is present when it tracks the same thing for the same tree, or for every tree.
            local cursor = 0
            for _, default in ipairs(presetItems(def.key, class)) do
                local key, found = entryKey(default), nil
                for index, entry in ipairs(group.items) do
                    local sameSpec = (entry.spec or 0) == 0 or (entry.spec == default.spec
                        and ((entry.class or "") == "" or entry.class == default.class))
                    if entryKey(entry) == key and sameSpec then found = index break end
                end
                if found then
                    cursor = max(cursor, found)
                else
                    cursor = min(cursor, #group.items) + 1
                    table.insert(group.items, cursor, Suite.Merge(Suite.Copy(default), ITEM_DEFAULTS))
                    addedItems = addedItems + 1
                end
            end
        end
    end
    if CDM.RefreshCombatLog then CDM.RefreshCombatLog() end
    CDM.Rebuild()
    return addedGroups, addedItems
end

---------------------------------------------------------------------------------------------------
-- Aura cache: one scan per UNIT_AURA per unit, then O(1) lookups by name and id.
---------------------------------------------------------------------------------------------------
local auraCache = {}
local auraDirty = {}
local recordPool = {}

local function cacheFor(unit)
    local cache = auraCache[unit]
    if not cache then
        cache = { help = { name = {}, id = {}, mineName = {}, mineId = {} },
            harm = { name = {}, id = {}, mineName = {}, mineId = {} }, records = {} }
        auraCache[unit] = cache
    end
    return cache
end

local function wipeIndex(index)
    for _, map in pairs(index) do for k in pairs(map) do map[k] = nil end end
end

local function scanUnit(unit)
    local cache = cacheFor(unit)
    for i = #cache.records, 1, -1 do
        recordPool[#recordPool + 1] = cache.records[i]
        cache.records[i] = nil
    end
    wipeIndex(cache.help)
    wipeIndex(cache.harm)
    auraDirty[unit] = nil
    if not UnitExists(unit) then return end
    for pass = 1, 2 do
        local filter = pass == 1 and "HELPFUL" or "HARMFUL"
        local index = pass == 1 and cache.help or cache.harm
        for i = 1, 40 do
            local name, _, icon, count, debuffType, duration, expiration, caster, _, _, spellId = UnitAura(unit, i, filter)
            if not name then break end
            local record = table.remove(recordPool) or {}
            record.name, record.icon, record.count, record.type = name, icon, count or 0, debuffType
            record.duration, record.expiration, record.caster, record.id = duration or 0, expiration or 0, caster, spellId
            cache.records[#cache.records + 1] = record
            local mine = caster == "player" or caster == "pet" or caster == "vehicle"
            if not index.name[name] then index.name[name] = record end
            if spellId and not index.id[spellId] then index.id[spellId] = record end
            if mine then
                if not index.mineName[name] then index.mineName[name] = record end
                if spellId and not index.mineId[spellId] then index.mineId[spellId] = record end
            end
        end
    end
end

local function findAura(unit, list, harmful, mine)
    if auraDirty[unit] or not auraCache[unit] then scanUnit(unit) end
    local index = harmful and auraCache[unit].harm or auraCache[unit].help
    local byName = mine and index.mineName or index.name
    local byId = mine and index.mineId or index.id
    for _, spell in ipairs(list) do
        local record
        if type(spell) == "number" then
            record = byId[spell]
            if not record then
                local name = GetSpellInfo(spell)
                record = name and byName[name]
            end
        else
            record = byName[spell]
        end
        if record then return record end
    end
end
CDM.FindAura = findAura

local function auraFromIds(unit, ids)
    for _, id in ipairs(ids) do
        local record = findAura(unit, { id }, false, false)
        if record then return record end
    end
end

---------------------------------------------------------------------------------------------------
-- Runtime state per item (never saved)
---------------------------------------------------------------------------------------------------
local runtime = setmetatable({}, { __mode = "k" })
local function stateOf(entry)
    local state = runtime[entry]
    if not state then
        state = {}
        runtime[entry] = state
    end
    return state
end

-- Parsed spell lists are cached by the source text.
local parsedCache = {}
local function spellList(text)
    local key = tostring(text)
    local list = parsedCache[key]
    if not list then
        list = Suite.ParseSpellList(text)
        parsedCache[key] = list
    end
    return list
end

local icdStarts, summonStarts = {}, {}
local playerGUID

local function itemKey(entry)
    return tostring(entry.spell or "")
end

local inCombat = false

-- Class and primary talent tree of the player, cached: entries and groups are checked many times a
-- second. Without talent points (low level) the tree is 0 and entries of every tree are allowed.
local currentClass, currentTree, currentRole
local autoAdapt = true

-- Role of the current spec. A feral druid is a tank with Protector of the Pack or in bear form, a
-- death knight in Frost Presence; the user's choice (db.role) wins over all of it.
local function resolveRole()
    local db = data()
    autoAdapt = db.autoAdapt ~= false
    if db.role and db.role ~= "auto" then return db.role end
    local class, tree = currentClass, currentTree or 0
    local role = ROLES[class or ""] and ROLES[class][tree] or (class and ROLES[class] and ROLES[class][1]) or "MELEE"
    if tree == 0 and (class == "PALADIN" or class == "PRIEST") then role = "MELEE" end
    local form = GetShapeshiftForm and GetShapeshiftForm() or 0
    if class == "DRUID" and tree == 2 then
        local talent = GetSpellInfo(57877)
        if form == 1 or (talent and Suite.TalentRank(talent) > 0) then role = "TANK" end
    elseif class == "DEATHKNIGHT" and form == 2 then
        role = "TANK"
    end
    return role
end

local function refreshSpec()
    currentClass, currentTree = playerClass(), Suite.PrimaryTree()
    currentRole = resolveRole()
end
local function specNow()
    if currentTree == nil then refreshSpec() end
    return currentClass, currentTree
end
function CDM.Role()
    if currentTree == nil then refreshSpec() end
    return currentRole
end
-- Key of the per-spec data ("PRIEST-2"; tree 0 = no talent points yet).
local function specKey()
    local class, tree = specNow()
    return (class or "?") .. "-" .. (tree or 0)
end
CDM.SpecKey = specKey

-- Whether an entry belongs to the current class and talent tree. With auto-adaptation switched off
-- the tree is ignored: every entry of the class is allowed.
local function entryActive(entry)
    local class, tree = specNow()
    if (entry.class or "") ~= "" and entry.class ~= class then return false end
    local spec = entry.spec or 0
    if autoAdapt and spec > 0 and tree > 0 and spec ~= tree then return false end
    return true
end
CDM.EntryActive = entryActive
function CDM.CurrentSpec() return specNow() end

-- Category of an entry: its own choice, else the table by spell id, else by spell name (other ranks).
local function categoryOf(entry)
    local own = entry.category
    if own and own ~= "" then return own ~= "none" and own or nil end
    local state = stateOf(entry)
    if state.catKey ~= entry.spell then
        state.catKey = entry.spell
        local first = spellList(entry.spell)[1]
        local category = type(first) == "number" and categoryById[first] or nil
        if not category and first then
            if not categoryByName then
                categoryByName = {}
                for id, value in pairs(categoryById) do
                    local name = GetSpellInfo(id)
                    if name then categoryByName[name] = value end
                end
            end
            local name = Suite.SpellInfo(first)
            category = name and categoryByName[name] or nil
        end
        state.cat = category or false
    end
    return state.cat or nil
end
CDM.CategoryOf = categoryOf

-- Display mode: the user's choice, or the mode bound to the kind of zone ("auto").
local currentMode
function CDM.ActiveMode()
    local db = data()
    local mode = db.mode
    if mode == "auto" or not MODE_RULES[mode or ""] then
        mode = db.autoModes[Suite.ZoneType()] or "full"
    end
    return MODE_RULES[mode] and mode or "full"
end
local function modeNow()
    if not currentMode then currentMode = CDM.ActiveMode() end
    return currentMode
end
-- Whether a mode shows a group: the group's own choice, else the rule of the mode.
function CDM.ModeShows(group, mode)
    local own = group.modes and group.modes[mode]
    if own ~= nil then return own and true or false end
    local rule = MODE_RULES[mode] or MODE_RULES.full
    return rule.groups[group.preset or "custom"] and true or false
end

local function conditionsBlock(entry)
    if not entryActive(entry) then return true end
    if entry.kind == "cooldown" then
        local hide = MODE_RULES[modeNow()].hide
        if hide then
            local category = categoryOf(entry)
            if category and hide[category] then return true end
        end
    end
    if entry.onlyCombat and not inCombat then return true end
    if entry.onlyGroup and Suite.GroupType() == "solo" then return true end
    if entry.requires and entry.requires ~= "" then
        for _, spell in ipairs(spellList(entry.requires)) do
            if not Suite.IsKnown(spell) then return true end
        end
    end
end

-- Resolves an item into a display result. r is reused per element.
-- r: show, icon, name, start, duration, count, desaturate, tint, glow, ready, expiration, missing
local oneName = {}
local needPoll = false     -- something on screen depends on the range to the target: no event for that

local function evaluate(group, entry, r, now)
    r.show, r.icon, r.name, r.start, r.duration, r.count = false, nil, nil, nil, nil, nil
    r.desaturate, r.tint, r.glow, r.ready, r.expiration, r.inactive, r.warn = false, nil, false, false, nil, false, false
    r.active = false
    local kind = entry.kind
    if conditionsBlock(entry) then return r end
    local list = spellList(entry.spell)

    if kind == "cooldown" then
        local spec = list[1]
        local start, duration, enabled
        local spellName, recharging
        if type(spec) == "string" and spec:match("^item:%d+$") then
            local id = tonumber(spec:match("%d+"))
            local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
            r.name, r.icon = name or spec, icon or GetItemIcon and GetItemIcon(id)
            start, duration, enabled = GetItemCooldown(id)
            local count = GetItemCount(id, nil, true)
            if count and count > 1 then r.count = count end
            if entry.hideUnknown and (GetItemCount(id) or 0) == 0 and not IsEquippedItem(id) then return r end
        elseif type(spec) == "string" and spec:match("^slot:%d+$") then
            local slot = tonumber(spec:match("%d+"))
            local id = GetInventoryItemID("player", slot)
            if not id then return r end
            r.icon = GetInventoryItemTexture("player", slot)
            r.name = GetItemInfo(id)
            start, duration, enabled = GetInventoryItemCooldown("player", slot)
            if entry.hideUnknown and enabled == 0 and (duration or 0) == 0 then
                local _, spell = GetItemSpell(id)
                if not spell then return r end
            end
        else
            local chosen
            for _, spell in ipairs(list) do
                if Suite.IsKnown(spell) then chosen = spell break end
            end
            if not chosen then
                if entry.hideUnknown then return r end
                chosen = spec
            end
            local name, icon = Suite.SpellInfo(chosen)
            if not name then return r end
            r.name, r.icon = name, icon
            spellName = name
            start, duration, enabled = GetSpellCooldown(name)
            -- Charges exist only on clients that have the API (not stock 3.3.5a): with a charge left
            -- the spell is ready and the spiral shows the next charge coming back.
            if GetSpellCharges then
                local charges, maxCharges, chargeStart, chargeDuration = GetSpellCharges(name)
                if maxCharges and maxCharges > 1 then
                    r.count = charges
                    if charges and charges > 0 and charges < maxCharges then
                        start, duration, recharging = chargeStart, chargeDuration, true
                    end
                end
            end
            local usable, noMana = IsUsableSpell(name)
            if noMana then
                r.tint = 1
            elseif not usable then
                r.tint = 2
            end
            if group.rangeTint and IsSpellInRange and UnitExists("target") then
                local inRange = IsSpellInRange(name, "target")
                if inRange ~= nil then needPoll = true end
                if inRange == 0 then r.tint = 3 end
            end
            if entry.glowUsable and usable then r.glow = true end
        end
        duration = duration or 0
        local isGCD = duration > 0 and duration <= 1.51
        if isGCD and not group.showGCD and not recharging then duration = 0 end
        if enabled == 0 then duration = 0 end
        local running = duration > 0 and (start or 0) + duration > now
        r.ready = not running or recharging or false
        if running then
            r.start, r.duration = start, duration
            r.expiration = start + duration
            if not recharging then
                if group.desaturate then r.desaturate = true end
                r.glow = false
            end
        end
        if entry.procAura and entry.procAura ~= "" and findAura("player", spellList(entry.procAura), false, false) then
            r.glow = true
        end
        -- Active: while the spell's own buff is on the player the icon counts the buff down, bright
        -- and with the active border; the cooldown takes over when the buff ends.
        if group.showActive and entry.showActive ~= false then
            local auras
            if entry.activeAura and entry.activeAura ~= "" then
                auras = spellList(entry.activeAura)
            elseif spellName then
                oneName[1] = spellName
                auras = oneName
            end
            local record = auras and findAura("player", auras, false, true)
            if record and record.duration > 0 and record.expiration > now then
                r.active, r.desaturate = true, false
                r.start, r.duration, r.expiration = record.expiration - record.duration, record.duration, record.expiration
            end
        end
        if not r.active then
            if group.cdShow == "ready" and not r.ready then return r end
            if group.cdShow == "cooldown" and r.ready then return r end
        end
        r.show = true
        return r

    elseif kind == "buff" or kind == "debuff" then
        local unit = entry.unit or (kind == "debuff" and "target" or "player")
        if unit ~= "player" and not UnitExists(unit) then
            if group.layout == "fixed" and group.kind == "icons" then
                local name, icon = Suite.SpellInfo(list[1])
                r.name, r.icon, r.show, r.inactive = name, icon, true, true
            end
            return r
        end
        local record = findAura(unit, list, kind == "debuff", entry.mine)
        if record then
            r.show, r.name, r.icon = true, record.name, record.icon
            if record.count and record.count > 1 then r.count = record.count end
            if record.duration and record.duration > 0 then
                r.start, r.duration = record.expiration - record.duration, record.duration
                r.expiration = record.expiration
                local remaining = record.expiration - now
                if kind == "debuff" and entry.warn and entry.warn > 0 and remaining <= entry.warn then r.warn = true end
            end
        elseif group.layout == "fixed" then
            local name, icon = Suite.SpellInfo(list[1])
            r.name, r.icon, r.show, r.inactive = name, icon, true, true
        end
        return r

    elseif kind == "missing" then
        local present, icon, name = false, nil, nil
        local mtype = entry.missingType or "aura"
        if mtype == "aura" then
            present = findAura("player", list, false, false) ~= nil
            name, icon = Suite.SpellInfo(list[1])
        elseif mtype == "form" then
            local form = GetShapeshiftForm and GetShapeshiftForm() or 0
            present = form and form > 0
            if #list > 0 and present then
                local _, formName = GetShapeshiftFormInfo(form)
                present = false
                for _, spell in ipairs(list) do
                    if Suite.SpellInfo(spell) == formName then present = true end
                end
            end
            if (GetNumShapeshiftForms() or 0) == 0 then return r end
            local _, firstName = GetShapeshiftFormInfo(1)
            icon = GetShapeshiftFormInfo(1)
            name = L("Нет стойки / ауры", "No stance / aura")
            if #list > 0 then name, icon = Suite.SpellInfo(list[1]) end
            if firstName == nil then return r end
        elseif mtype == "weapon_mh" or mtype == "weapon_oh" then
            local mh, _, _, oh = GetWeaponEnchantInfo()
            local slot = mtype == "weapon_mh" and 16 or 17
            if not GetInventoryItemID("player", slot) then return r end
            if mtype == "weapon_oh" then
                local id = GetInventoryItemID("player", 17)
                local _, _, _, _, _, _, _, _, equip = GetItemInfo(id)
                if equip == "INVTYPE_SHIELD" or equip == "INVTYPE_HOLDABLE" then return r end
            end
            present = (mtype == "weapon_mh" and mh) or (mtype == "weapon_oh" and oh)
            icon = GetInventoryItemTexture("player", slot)
            name = mtype == "weapon_mh" and L("Чары правой руки", "Main hand enchant") or L("Чары левой руки", "Off hand enchant")
        elseif mtype == "food" then
            present = auraFromIds("player", WELL_FED) ~= nil
            name, icon = L("Нет еды", "No food buff"), "Interface\\Icons\\INV_Misc_Food_14"
        elseif mtype == "flask" then
            present = auraFromIds("player", FLASKS) ~= nil or (#list > 0 and findAura("player", list, false, false) ~= nil)
            name, icon = L("Нет настоя", "No flask"), "Interface\\Icons\\INV_Alchemy_EndlessFlask_06"
        end
        if present then return r end
        r.show, r.name, r.icon, r.glow = true, name, icon or "Interface\\Icons\\INV_Misc_QuestionMark", entry.glowMissing
        return r

    elseif kind == "icd" then
        local name, icon = Suite.SpellInfo(list[1])
        r.name, r.icon, r.show = name, icon, true
        local started = icdStarts[entry]
        if started and started + (entry.duration or 0) > now then
            r.start, r.duration, r.expiration = started, entry.duration, started + entry.duration
            r.desaturate = group.desaturate
        else
            r.ready = true
        end
        return r

    elseif kind == "totem" then
        for slot = 1, 4 do
            local have, name, start, duration, icon = GetTotemInfo(slot)
            local match = false
            if type(list[1]) == "number" and list[1] >= 1 and list[1] <= 4 then
                match = slot == list[1]
            else
                for _, spell in ipairs(list) do
                    local wanted = Suite.SpellInfo(spell)
                    if wanted and name and name ~= "" and name:find(wanted, 1, true) then match = true end
                end
            end
            if match and have and name and name ~= "" and duration and duration > 0 then
                r.show, r.name, r.icon = true, name, icon
                r.start, r.duration, r.expiration = start, duration, start + duration
                return r
            end
        end
        return r

    elseif kind == "summon" then
        local started = summonStarts[entry]
        if started and started + (entry.duration or 0) > now then
            local name, icon = Suite.SpellInfo(list[1])
            r.show, r.name, r.icon = true, name, icon
            r.start, r.duration, r.expiration = started, entry.duration, started + entry.duration
        end
        return r
    end
    return r
end
CDM.Evaluate = evaluate

---------------------------------------------------------------------------------------------------
-- Display: containers, icons and bars
---------------------------------------------------------------------------------------------------
local containers = {}
local previewing, editing = false, false
local dirty, elapsedSinceDraw, tickElapsed = true, 0, 0
local focusGroup

local function mediaPath(name)
    return ui.MediaPath and ui.MediaPath("statusbar", name, true) or Suite.art.bar
end

local function createBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:EnableMouse(false)
    bar.icon = Suite.CreateIcon(bar, 20)
    bar.icon:SetPoint("LEFT", 0, 0)
    bar.status = CreateFrame("StatusBar", nil, bar)
    bar.status:SetMinMaxValues(0, 1)
    bar.back = bar.status:CreateTexture(nil, "BACKGROUND")
    bar.back:SetAllPoints(bar.status)
    bar.back:SetTexture(Suite.art.white)
    bar.edge = CreateFrame("Frame", nil, bar.status)
    bar.edge:SetPoint("TOPLEFT", -1, 1)
    bar.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.edge:SetBackdrop({ edgeFile = Suite.art.white, edgeSize = 1 })
    bar.edge:SetBackdropBorderColor(0, 0, 0, 0.9)
    bar.label = bar.status:CreateFontString(nil, "OVERLAY")
    bar.label:SetPoint("LEFT", 4, 0)
    bar.label:SetJustifyH("LEFT")
    bar.time = bar.status:CreateFontString(nil, "OVERLAY")
    bar.time:SetPoint("RIGHT", -4, 0)
    bar.time:SetJustifyH("RIGHT")
    bar.label:SetPoint("RIGHT", bar.time, "LEFT", -4, 0)
    return bar
end

local function styleElement(group, element)
    local font = Suite.art.font
    if group.kind == "bars" then
        local height, width = group.barHeight, group.barWidth
        element:SetWidth(width)
        element:SetHeight(height)
        local format = group.barFormat
        local showIcon = format ~= "bar"
        element.icon:SetWidth(height)
        element.icon:SetHeight(height)
        Suite.Shown(element.icon, showIcon)
        element.status:ClearAllPoints()
        element.status:SetPoint("TOPLEFT", showIcon and (height + 2) or 0, 0)
        element.status:SetPoint("BOTTOMRIGHT", 0, 0)
        element.status:SetStatusBarTexture(mediaPath(group.barTexture))
        local back = group.barBackground
        element.back:SetVertexColor(back[1], back[2], back[3], back[4] or 1)
        element.label:SetFont(font, group.fontSize, "OUTLINE")
        element.time:SetFont(font, group.timerSize, "OUTLINE")
        Suite.Shown(element.label, format ~= "icon")
        element.icon.border:SetVertexColor(unpack(group.borderColor))
    else
        element:SetWidth(group.size)
        element:SetHeight(group.size)
        element.count:SetFont(font, group.fontSize, "OUTLINE")
        element.timer:SetFont(font, group.timerSize, "OUTLINE")
        Suite.Shown(element.cooldown, group.showSwipe)
        -- Border: the WoW Forever icon frame, or a flat one-pixel line around the full icon.
        local pixel = group.borderStyle == "pixel"
        if pixel and not element.pixel then
            element.pixel = CreateFrame("Frame", nil, element)
            element.pixel:SetAllPoints(element)
            element.pixel:SetBackdrop({ edgeFile = Suite.art.white, edgeSize = 1 })
            element.pixel:SetFrameLevel(element.cooldown:GetFrameLevel() + 1)
        end
        if element.pixel then Suite.Shown(element.pixel, pixel) end
        Suite.Shown(element.border, not pixel)
        local inset = pixel and 1 or 2
        for _, region in ipairs({ element.texture, element.cooldown }) do
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", inset, -inset)
            region:SetPoint("BOTTOMRIGHT", -inset, inset)
        end
        element.pixelBorder = pixel
    end
end

local function setBorder(el, r, g, b, a)
    if el.pixelBorder then
        el.pixel:SetBackdropBorderColor(r, g, b, a or 1)
    else
        el.border:SetVertexColor(r, g, b, a or 1)
    end
end

local function getContainer(group)
    local container = containers[group.id]
    if not container then
        container = CreateFrame("Frame", "ForeverStockUICDM" .. group.id, UIParent)
        container:SetMovable(true)
        container:SetClampedToScreen(true)
        container:SetWidth(40)
        container:SetHeight(40)
        -- The real default spot comes from placeDefaults() once the group has its size.
        container:SetPoint("TOP", UIParent, "CENTER", 0, -110)
        container.elements = {}
        container.results = {}
        container.placeholder = container:CreateTexture(nil, "BACKGROUND")
        container.placeholder:SetAllPoints(container)
        container.placeholder:SetTexture(Suite.art.editHighlight)
        container.placeholder:SetVertexColor(0.9, 0.75, 0.45, 0.35)
        container.placeholder:Hide()
        containers[group.id] = container
    end
    container.groupId = group.id
    local registered = container.editEntry
    if ui.RegisterEditFrame and (not registered or registered.removed) then
        local entry = ui.RegisterEditFrame(container, group.name, "cooldowns")
        if entry then
            entry.removed = nil
            entry.onRightClick = function() CDM.OpenGroup(container.groupId) end
            -- After "reset position" in Edit Mode the group goes back into the default stack.
            entry.resetPosition = function()
                container.defaultSpot = nil
                dirty = true
            end
            container.editEntry = entry
        end
    end
    return container
end

local function element(container, group, index)
    local list = container.elements
    local el = list[index]
    local wanted = group.kind == "bars" and "bar" or "icon"
    if el and el.kind ~= wanted then
        el:Hide()
        container.spare = container.spare or {}
        container.spare[#container.spare + 1] = el
        el = nil
    end
    if not el then
        if container.spare then
            for i, spare in ipairs(container.spare) do
                if spare.kind == wanted then
                    el = table.remove(container.spare, i)
                    break
                end
            end
        end
        el = el or (wanted == "bar" and createBar(container) or Suite.CreateIcon(container, group.size))
        el.kind = wanted
        list[index] = el
    end
    return el
end

local function loadAllowed(group)
    if not group.enabled then return false end
    local mode = modeNow()
    if MODE_RULES[mode].combatOnly and not inCombat then return false end
    if not CDM.ModeShows(group, mode) then return false end
    local load = group.load or {}
    local when = load.when or "always"
    if when == "combat" and not inCombat then return false end
    if when == "ooc" and inCombat then return false end
    if when == "target" and not UnitExists("target") then return false end
    if when == "hostile" and not (UnitExists("target") and UnitCanAttack("player", "target")) then return false end
    local groupType = Suite.GroupType()
    local wantGroup = load.group or "any"
    if wantGroup == "solo" and groupType ~= "solo" then return false end
    if wantGroup == "group" and groupType == "solo" then return false end
    if wantGroup == "party" and groupType ~= "party" then return false end
    if wantGroup == "raid" and groupType ~= "raid" then return false end
    local zone = Suite.ZoneType()
    if type(load.zone) == "table" and load.zone[zone] == false then return false end
    if (load.talentGroup or 0) > 0 and Suite.TalentGroup() ~= load.talentGroup then return false end
    local class, tree = specNow()
    if (load.class or "") ~= "" and load.class ~= class then return false end
    if (load.tree or 0) > 0 and tree ~= load.tree then return false end
    if (load.form or 0) > 0 and (GetShapeshiftForm() or 0) ~= load.form - 1 then return false end
    return true
end
CDM.LoadAllowed = loadAllowed

-- Edge-triggered alerts: glow while the condition holds, a sound when it starts.
local function alerts(entry, r, now)
    local state = stateOf(entry)
    local glow = false
    if r.show and not r.inactive then
        local ready = entry.kind == "cooldown" and r.ready or (entry.kind == "icd" and r.ready)
        if ready and (entry.glowReady or entry.soundReady ~= "") then
            if state.ready == false then Suite.PlayAlert(entry.soundReady) end
            if entry.glowReady then glow = true end
        end
        state.ready = ready and true or false
        local stacks = (entry.stacks or 0) > 0 and (r.count or 0) >= entry.stacks
        if stacks and not state.stacks then Suite.PlayAlert(entry.soundStacks) end
        state.stacks = stacks
        if stacks and entry.glowStacks then glow = true end
        local expiring = (entry.expire or 0) > 0 and r.expiration and r.expiration - now <= entry.expire
            and r.expiration > now
        if expiring and not state.expiring then Suite.PlayAlert(entry.soundExpire) end
        state.expiring = expiring
        if expiring and entry.glowExpire then glow = true end
    else
        state.ready, state.stacks, state.expiring = nil, nil, nil
    end
    return glow
end

local animating = {}

local function drawIcon(group, el, r, now)
    el.texture:SetTexture(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    el.texture:SetDesaturated(r.desaturate and 1 or nil)
    -- Light tints that keep the icon and the timer readable: blue = no resource, red = out of range,
    -- grey = not usable now.
    if r.tint == 1 then
        el.texture:SetVertexColor(0.45, 0.55, 1)
    elseif r.tint == 3 then
        el.texture:SetVertexColor(1, 0.4, 0.4)
    elseif r.tint == 2 then
        el.texture:SetVertexColor(0.45, 0.45, 0.45)
    else
        el.texture:SetVertexColor(1, 1, 1)
    end
    local category = group.categoryBorder and r.category and CDM.categoryColors[r.category]
    if r.warn then
        setBorder(el, 1, 0.25, 0.2)
    elseif r.active then
        local c = group.activeColor
        setBorder(el, c[1], c[2], c[3])
    elseif category then
        setBorder(el, category[1], category[2], category[3])
    else
        setBorder(el, group.borderColor[1], group.borderColor[2], group.borderColor[3], group.borderColor[4])
    end
    el:SetAlpha(r.inactive and group.inactiveAlpha or 1)
    if group.showSwipe then Suite.SetCooldown(el.cooldown, r.start, r.duration) end
    el.count:SetText(group.showCount and r.count and r.count > 0 and r.count or "")
    el.expiration = r.expiration
    local remaining = r.expiration and r.expiration - now
    el.timer:SetText(group.showTimer and remaining and Suite.FormatTime(remaining) or "")
    -- Timer colour: the buff colour while active, else white -> yellow (10 s) -> red (3 s).
    local tr, tg, tb = 1, 1, 1
    if group.timerColors and remaining then
        if r.active then
            tr, tg, tb = group.activeColor[1], group.activeColor[2], group.activeColor[3]
        elseif remaining <= 3 then
            tr, tg, tb = 1, 0.25, 0.2
        elseif remaining <= 10 then
            tr, tg, tb = 1, 0.85, 0.2
        end
    end
    if el.timerShade ~= tr + tg * 2 + tb * 4 then
        el.timerShade = tr + tg * 2 + tb * 4
        el.timer:SetTextColor(tr, tg, tb)
    end
    Suite.SetGlow(el, r.glow)
end

local function drawBar(group, el, r, entry, now)
    el.icon.texture:SetTexture(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    el.label:SetText(entry.label and entry.label ~= "" and entry.label or r.name or "")
    local color = entry.color or group.barColor
    if r.warn then color = { 1, 0.25, 0.2, 1 } end
    el.status:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
    el:SetAlpha(r.inactive and group.inactiveAlpha or 1)
    el.expiration, el.total = r.expiration, r.duration
    if r.expiration and r.duration and r.duration > 0 then
        el.status:SetValue(max(0, min(1, (r.expiration - now) / r.duration)))
        el.time:SetText(Suite.FormatTime(r.expiration - now))
        animating[el] = true
    else
        el.status:SetValue(r.inactive and 0 or 1)
        el.time:SetText(entry.kind == "cooldown" and r.ready and L("Готово", "Ready") or "")
        animating[el] = nil
    end
    Suite.SetGlow(el.icon, r.glow)
end

-- Grid placement: perRow elements per line, grow along the line, wrap to the next one.
-- `footprint`: number of entries the group shows in Edit Mode. A group with a saved spot keeps at least
-- that box, so the icons stay where they were placed: Edit Mode pins the top right corner, and a box
-- that shrank with the number of visible icons used to drag them to the right.
local function place(group, container, shownList, footprint)
    local isBars = group.kind == "bars"
    local w = isBars and group.barWidth or group.size
    local h = isBars and group.barHeight or group.size
    local gap = group.spacing
    local perRow = max(1, group.perRow)
    local grow, wrap = group.grow, group.wrap
    local centred = grow == "CENTER"     -- rows grow from the middle: every line is centred
    local horizontal = grow == "LEFT" or grow == "RIGHT" or centred
    local count = #shownList
    local lines = max(1, math.ceil(count / perRow))
    local along = min(max(count, 1), perRow)
    local width = horizontal and along * w + (along - 1) * gap or lines * w + (lines - 1) * gap
    local height = horizontal and lines * h + (lines - 1) * gap or along * h + (along - 1) * gap
    if footprint and footprint > count then
        local fullLines = math.ceil(footprint / perRow)
        local fullAlong = min(footprint, perRow)
        local fullWidth = horizontal and fullAlong * w + (fullAlong - 1) * gap or fullLines * w + (fullLines - 1) * gap
        local fullHeight = horizontal and fullLines * h + (fullLines - 1) * gap or fullAlong * h + (fullAlong - 1) * gap
        width, height = max(width, fullWidth), max(height, fullHeight)
    end
    container:SetWidth(max(width, 8))
    container:SetHeight(max(height, 8))
    for i, el in ipairs(shownList) do
        local pos, line = (i - 1) % perRow, floor((i - 1) / perRow)
        local x, y
        if horizontal then
            x = pos * (w + gap)
            y = line * (h + gap)
        else
            x = line * (w + gap)
            y = pos * (h + gap)
        end
        local anchor
        if centred then
            local onLine = line < lines - 1 and perRow or count - perRow * (lines - 1)
            x = x + (width - (onLine * w + (onLine - 1) * gap)) / 2
        end
        if horizontal then
            local fromLeft = grow ~= "LEFT"
            local fromTop = wrap ~= "UP"
            anchor = (fromTop and "TOP" or "BOTTOM") .. (fromLeft and "LEFT" or "RIGHT")
            x = fromLeft and x or -x
            y = fromTop and -y or y
        else
            local fromTop = grow == "DOWN"
            local fromLeft = wrap ~= "LEFT"
            anchor = (fromTop and "TOP" or "BOTTOM") .. (fromLeft and "LEFT" or "RIGHT")
            x = fromLeft and x or -x
            y = fromTop and -y or y
        end
        el:ClearAllPoints()
        el:SetPoint(anchor, container, anchor, x, y)
        el:Show()
    end
end

local hasTimers = false
local testing, testStart = false, 0

-- Test mode: every entry of the current spec runs a fake loop (ready -> active -> cooldown), so the
-- whole layout can be judged and dragged without waiting for real cooldowns. The cycle is derived
-- from the moment the test started, so the spiral gets the same start on every redraw.
local function fakeState(group, entry, r, index, now)
    local period = 14 + (index % 4) * 4
    local shifted = now - testStart + index * 3.7
    local cycleStart = now - shifted % period
    local t = now - cycleStart
    r.show, r.inactive, r.desaturate, r.tint, r.warn, r.active, r.glow = true, false, false, nil, false, false, false
    r.start, r.duration, r.expiration, r.ready = nil, nil, nil, true
    local kind = entry.kind
    if kind == "cooldown" or kind == "icd" then
        local activeFor = (kind == "cooldown" and index % 3 == 0 and group.showActive) and 4 or 0
        if t < 3 then
            r.glow = index % 4 == 1
        elseif t < 3 + activeFor then
            r.active = true
            r.start, r.duration, r.expiration = cycleStart + 3, activeFor, cycleStart + 3 + activeFor
        else
            r.ready, r.desaturate = false, group.desaturate
            r.start, r.duration, r.expiration = cycleStart + 3, period - 3, cycleStart + period
        end
    elseif kind ~= "missing" then
        r.start, r.duration, r.expiration = cycleStart, period, cycleStart + period
        r.warn = kind == "debuff" and period - t <= 3
    end
end

local function bySortKey(a, b) return a.sortKey < b.sortKey end

local function saveSpot(container)
    local entry = container.editEntry
    if not entry or not entry.config then return end
    local right, top = container:GetRight(), container:GetTop()
    if not right or not top then return end
    local ratio = container:GetEffectiveScale() / UIParent:GetEffectiveScale()
    entry.config.position = { right * ratio - UIParent:GetRight(), top * ratio - UIParent:GetTop() }
    container.defaultSpot = nil
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
end

local function drawGroup(group, now)
    local container = getContainer(group)
    local unlocked = testing and not editing
    -- Unlocked in test mode: the group is dragged by itself, like in Edit Mode.
    if container.unlocked ~= unlocked then
        container.unlocked = unlocked
        container:EnableMouse(unlocked)
        if unlocked and not container.dragScripts then
            container.dragScripts = true
            container:RegisterForDrag("LeftButton")
            container:SetScript("OnDragStart", function(self)
                if testing and not InCombatLockdown() then
                    self.dragging = true
                    self:StartMoving()
                end
            end)
            container:SetScript("OnDragStop", function(self)
                if not self.dragging then return end
                self.dragging = nil
                self:StopMovingOrSizing()
                saveSpot(self)
            end)
        end
    end
    local forced = editing or testing or (previewing and (not focusGroup or focusGroup == group.id))
    if testing and not group.enabled then forced = false end
    if not forced and not loadAllowed(group) then
        container:Hide()
        for _, el in ipairs(container.elements) do animating[el] = nil end
        return
    end
    container:SetAlpha((inCombat or forced) and group.alpha or (group.oocAlpha or 1))
    local shownList, used = {}, 0
    local results = container.results
    local sorted = autoAdapt and group.sort == "role" and group.layout ~= "fixed"
    local order = sorted and (ROLE_ORDER[CDM.Role() or "MELEE"] or ROLE_ORDER.MELEE)
    for index, entry in ipairs(group.items) do
        local r = results[index] or {}
        results[index] = r
        evaluate(group, entry, r, now)
        r.category = (sorted or group.categoryBorder) and entry.kind == "cooldown" and categoryOf(entry) or nil
        -- Test mode fills in only what the current spec really has: no foreign trees, no unlearned spells.
        if forced and not r.show and (not testing
            or (entryActive(entry) and (entry.kind ~= "cooldown" or r.name ~= nil))) then
            local name, icon = Suite.SpellInfo(spellList(entry.spell)[1])
            r.show, r.inactive, r.name = true, true, r.name or name or CDM.kindNames[entry.kind]
            r.icon = r.icon or icon
        end
        if testing then
            if r.show then fakeState(group, entry, r, index, now) end
        elseif r.show then
            local glow = alerts(entry, r, now)
            r.glow = r.glow or glow
        else
            alerts(entry, r, now)
        end
        local el = element(container, group, index)
        el.sortKey = ((order and (order[r.category or ""] or UNCATEGORISED_RANK)) or 0) * 1000 + index
        if el.styledFor ~= group or el.styleStamp ~= group.styleStamp then
            styleElement(group, el)
            el.styledFor, el.styleStamp = group, group.styleStamp
        end
        el.emptySlot = nil
        if r.show then
            used = used + 1
            if group.kind == "bars" then drawBar(group, el, r, entry, now) else drawIcon(group, el, r, now) end
            if r.expiration then hasTimers = true end
            shownList[#shownList + 1] = el
        elseif group.layout == "fixed" and group.kind == "icons" then
            -- fixed slots keep an empty cell: placed like the others, hidden after placement
            el.emptySlot = true
            shownList[#shownList + 1] = el
            animating[el] = nil
            Suite.SetGlow(el, false)
        else
            el:Hide()
            animating[el] = nil
            if el.kind == "icon" then Suite.SetGlow(el, false) else Suite.SetGlow(el.icon, false) end
        end
    end
    for index = #group.items + 1, #container.elements do
        local el = container.elements[index]
        el:Hide()
        animating[el] = nil
        if el.kind == "icon" then Suite.SetGlow(el, false) elseif el.icon then Suite.SetGlow(el.icon, false) end
    end
    if sorted then table.sort(shownList, bySortKey) end
    local edit = container.editEntry
    local pinned = not editing and edit and edit.config and type(edit.config.position) == "table"
    place(group, container, shownList, pinned and #group.items or nil)
    for _, el in ipairs(shownList) do
        if el.emptySlot then el:Hide() end
    end
    Suite.Shown(container.placeholder, (editing and used == 0) or unlocked)
    if used == 0 and (editing or testing) then
        container:SetWidth(group.kind == "bars" and group.barWidth or group.size)
        container:SetHeight(group.kind == "bars" and group.barHeight or group.size)
    end
    container:Show()
end

local driver = CreateFrame("Frame")

-- Default layout for groups the user never moved in Edit Mode: icon groups in one centred column
-- under the screen centre (in list order, each below the previous one by its real height), bar
-- groups in a column to the left. Moved groups keep their saved spot.
local DEFAULT_TOP, DEFAULT_GAP, BAR_COLUMN_X = -110, 8, -230
local function hasSavedSpot(container)
    local entry = container.editEntry
    return entry and entry.config and type(entry.config.position) == "table"
end

local function placeDefaults()
    -- tracker containers are plain frames: placing them is allowed in combat too
    local iconY, barY = DEFAULT_TOP, DEFAULT_TOP
    for _, group in ipairs(CDM.Groups()) do
        local container = containers[group.id]
        if container and group.enabled then
            local height = container:GetHeight() or 40
            local bars = group.kind == "bars"
            local x, y = bars and BAR_COLUMN_X or 0, bars and barY or iconY
            if bars then barY = barY - height - DEFAULT_GAP else iconY = iconY - height - DEFAULT_GAP end
            if not hasSavedSpot(container) and not (container.editEntry and container.editEntry.moving) then
                local spot = (bars and "TOPRIGHT" or "TOP") .. ":" .. x .. ":" .. y
                if container.defaultSpot ~= spot then
                    container.defaultSpot = spot
                    container:ClearAllPoints()
                    if bars then
                        container:SetPoint("TOPRIGHT", UIParent, "CENTER", x, y)
                    else
                        container:SetPoint("TOP", UIParent, "CENTER", x, y)
                    end
                end
            elseif hasSavedSpot(container) then
                container.defaultSpot = nil
            end
        end
    end
end
CDM.PlaceDefaults = placeDefaults

local function drawAll()
    if not ui.IsModuleEnabled or not ui.IsModuleEnabled("cooldowns") then
        for _, container in pairs(containers) do container:Hide() end
        return
    end
    local now = GetTime()
    hasTimers, needPoll = testing, false
    local active = {}
    for _, group in ipairs(CDM.Groups()) do
        active[group.id] = true
        drawGroup(group, now)
    end
    for id, container in pairs(containers) do
        if not active[id] then
            container:Hide()
            if container.editEntry then container.editEntry.removed = true end
        end
    end
    placeDefaults()
    dirty = false
    if ui.RefreshEditLayout and editing then ui.RefreshEditLayout() end
end

-- Smooth bars every frame (only animated ones); text and alerts at 10 Hz.
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceDraw = elapsedSinceDraw + elapsed
    tickElapsed = tickElapsed + elapsed
    if next(animating) then
        local now = GetTime()
        for el in pairs(animating) do
            if el.expiration and el.total and el.total > 0 and el:IsVisible() then
                el.status:SetValue(max(0, min(1, (el.expiration - now) / el.total)))
            end
        end
    end
    if dirty and elapsedSinceDraw >= 0.05 then
        elapsedSinceDraw = 0
        tickElapsed = 0
        drawAll()
    elseif (hasTimers and tickElapsed >= 0.1) or (needPoll and tickElapsed >= 0.25) then
        tickElapsed = 0
        elapsedSinceDraw = 0
        drawAll()
    end
end)

function CDM.Refresh() dirty = true end

-- Restyle every element (geometry or font changed), then redraw.
function CDM.Rebuild()
    for _, group in ipairs(CDM.Groups()) do group.styleStamp = (group.styleStamp or 0) + 1 end
    for k in pairs(parsedCache) do parsedCache[k] = nil end
    for _, container in pairs(containers) do
        local group = CDM.Group(container.groupId)
        if group and container.editEntry then container.editEntry.label = group.name end
    end
    dirty = true
    drawAll()
end
CDM.Apply = CDM.Rebuild

function CDM.SetPreview(on, groupId)
    previewing, focusGroup = on and true or false, groupId
    dirty = true
end

---------------------------------------------------------------------------------------------------
-- Display mode switcher: a small button (left click: next mode, right click: automatic).
---------------------------------------------------------------------------------------------------
local modeButton

local function refreshModeButton()
    local db = data()
    local enabled = ui.IsModuleEnabled and ui.IsModuleEnabled("cooldowns")
    if not (enabled and (db.modeButton or testing)) then
        if modeButton then modeButton:Hide() end
        return
    end
    if not modeButton then
        modeButton = CreateFrame("Button", "ForeverStockUICDMMode", UIParent)
        modeButton:SetWidth(96)
        modeButton:SetHeight(16)
        modeButton:SetPoint("BOTTOM", UIParent, "CENTER", 0, -104)
        modeButton:SetBackdrop({ bgFile = Suite.art.white, edgeFile = Suite.art.white, edgeSize = 1 })
        modeButton:SetBackdropColor(0, 0, 0, 0.55)
        modeButton:SetBackdropBorderColor(0, 0, 0, 0.9)
        modeButton.text = modeButton:CreateFontString(nil, "OVERLAY")
        modeButton.text:SetFont(Suite.art.font, 10, "OUTLINE")
        modeButton.text:SetPoint("CENTER", 0, 0)
        modeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        modeButton:SetAlpha(0.55)
        modeButton:SetScript("OnClick", function(_, mouse)
            if testing then
                CDM.SetTest(false)
            elseif mouse == "RightButton" then
                CDM.SetMode("auto")
            else
                CDM.NextMode()
            end
        end)
        modeButton:SetScript("OnEnter", function(self)
            self:SetAlpha(1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Cooldown Manager")
            if testing then
                GameTooltip:AddLine(L("Идёт тест: группы можно перетаскивать мышью. Клик — закончить.",
                    "Test is running: drag the groups with the mouse. Click to finish."), 1, 1, 1, true)
            else
                GameTooltip:AddLine(L("Режим показа панелей. ЛКМ — следующий режим, ПКМ — авто по типу зоны.",
                    "Display mode of the panels. Left click: next mode, right click: automatic by zone."), 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        modeButton:SetScript("OnLeave", function(self)
            self:SetAlpha(0.55)
            GameTooltip:Hide()
        end)
        if ui.RegisterEditFrame then
            ui.RegisterEditFrame(modeButton, L("Cooldown Manager: режим", "Cooldown Manager: mode"), "cooldowns")
        end
    end
    if testing then
        modeButton.text:SetText(L("ТЕСТ — закончить", "TEST - finish"))
        modeButton.text:SetTextColor(1, 0.82, 0.2)
    else
        local name = CDM.modeNames[modeNow()] or modeNow()
        modeButton.text:SetText(db.mode == "auto" and (CDM.modeNames.auto .. ": " .. name) or name)
        modeButton.text:SetTextColor(0.9, 0.86, 0.75)
    end
    modeButton:Show()
end

-- Re-reads the mode (zone or setting changed). Tracker frames are not protected, so the switch is
-- safe in combat too and needs no queue.
function CDM.UpdateMode()
    local mode = CDM.ActiveMode()
    if mode ~= currentMode then
        currentMode = mode
        dirty = true
        ui.Fire("CooldownManagerMode", mode)
    end
    refreshModeButton()
end

function CDM.SetMode(mode)
    if mode ~= "auto" and not MODE_RULES[mode or ""] then return false end
    data().mode = mode
    CDM.UpdateMode()
    return true
end

function CDM.NextMode()
    local current = data().mode
    local list = { "auto" }
    for _, entry in ipairs(CDM.modes) do list[#list + 1] = entry[1] end
    for index, mode in ipairs(list) do
        if mode == current then return CDM.SetMode(list[index % #list + 1]) end
    end
    return CDM.SetMode("auto")
end

---------------------------------------------------------------------------------------------------
-- Test mode, role and per-spec layout
---------------------------------------------------------------------------------------------------
function CDM.SetTest(on)
    on = on and true or false
    if on == testing then return end
    testing, testStart = on, GetTime()
    refreshModeButton()
    ui.Fire("CooldownManagerTest", on)
    CDM.Rebuild()
end
function CDM.IsTesting() return testing end

-- Settings of the module itself changed (auto-adaptation, role, mode, mode button).
function CDM.SettingsChanged()
    currentRole = resolveRole()
    CDM.UpdateMode()
    CDM.Rebuild()
end

-- Positions per spec: the spots of the groups saved in Edit Mode are remembered under the spec key
-- when the spec is left and put back when it returns. A spec seen for the first time keeps the
-- layout that is on screen.
local lastSpecKey
local function saveSpots(key)
    if not key then return end
    local spots = {}
    for id, container in pairs(containers) do
        local entry = container.editEntry
        local position = entry and entry.config and entry.config.position
        if type(position) == "table" and CDM.Group(id) then spots[id] = { position[1], position[2] } end
    end
    data().specSpots[key] = spots
end
local function loadSpots(key)
    local spots = data().specSpots[key]
    if type(spots) ~= "table" then return end
    for id, container in pairs(containers) do
        local entry = container.editEntry
        if entry and entry.config then
            local spot = spots[id]
            entry.config.position = type(spot) == "table" and { spot[1], spot[2] } or nil
            container.defaultSpot = nil
        end
    end
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
end

local function specChanged()
    local previous = lastSpecKey
    refreshSpec()
    local key = specKey()
    if previous and previous ~= key and autoAdapt then
        saveSpots(previous)
        loadSpots(key)
    end
    lastSpecKey = key
end

-- Factory layout of the current spec: its entries (default and the user's own) are replaced by the
-- default set, the saved positions of the spec are dropped and the groups return to the default stack.
-- Entries of other specs and the user's own groups stay. Returns groups and entries added.
function CDM.ResetSpec()
    local db = data()
    local class, tree = specNow()
    if tree and tree > 0 then
        for _, group in pairs(db.groups) do
            for index = #group.items, 1, -1 do
                local entry = group.items[index]
                if entry.class == class and (entry.spec or 0) == tree then table.remove(group.items, index) end
            end
        end
    end
    db.specSpots[specKey()] = nil
    for _, container in pairs(containers) do
        local entry = container.editEntry
        if entry and entry.config then entry.config.position = nil end
        container.defaultSpot = nil
    end
    for _, group in pairs(db.groups) do
        if group.preset == "essential" or group.preset == "utility" then group.sort = "role" end
    end
    local addedGroups, addedItems = CDM.RestoreDefaults("missing")
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
    return addedGroups, addedItems
end

---------------------------------------------------------------------------------------------------
-- Options hooks
---------------------------------------------------------------------------------------------------
CDM.selectedGroup = nil
function CDM.OpenGroup(id)
    CDM.selectedGroup = id
    ui.Fire("CooldownManagerSelect", id)
    if ui.OpenOptions then ui.OpenOptions("cooldowns") end
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame")
local watched = { player = true, target = true, focus = true, pet = true }
local cleuNeeded = false

local function refreshCombatLog()
    cleuNeeded = false
    for _, group in ipairs(CDM.Groups()) do
        for _, entry in ipairs(group.items) do
            if entry.kind == "icd" or entry.kind == "summon" then cleuNeeded = true end
        end
    end
    if cleuNeeded then
        events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        events:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end
CDM.RefreshCombatLog = refreshCombatLog

local icdEvents = { SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true, SPELL_ENERGIZE = true,
    SPELL_DAMAGE = true, SPELL_HEAL = true, SPELL_CAST_SUCCESS = true, SPELL_SUMMON = true }

local function onCombatLog(_, event, sourceGUID, _, _, _, _, _, spellId, spellName)
    if not icdEvents[event] then return end
    if sourceGUID ~= playerGUID then
        -- the pet's summons and procs count as ours too
        if not (UnitGUID("pet") and sourceGUID == UnitGUID("pet")) then return end
    end
    local now = GetTime()
    for _, group in ipairs(CDM.Groups()) do
        for _, entry in ipairs(group.items) do
            local kind = entry.kind
            if (kind == "icd" and event ~= "SPELL_SUMMON") or (kind == "summon" and event == "SPELL_SUMMON") then
                for _, spell in ipairs(spellList(entry.spell)) do
                    if spell == spellId or spell == spellName or Suite.SpellInfo(spell) == spellName then
                        if kind == "icd" then
                            local started = icdStarts[entry]
                            if not started or started + (entry.duration or 0) <= now then
                                icdStarts[entry] = now
                                dirty = true
                            end
                        else
                            summonStarts[entry] = now
                            dirty = true
                        end
                    end
                end
            end
        end
    end
end

for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
    "BAG_UPDATE_COOLDOWN", "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_INVENTORY_CHANGED",
    "PLAYER_TOTEM_UPDATE", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA",
    "UNIT_PET", "BAG_UPDATE", "ACTIONBAR_UPDATE_COOLDOWN", "PLAYER_LOGOUT" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        onCombatLog(...)
        return
    end
    if event == "UNIT_AURA" then
        local unit = ...
        if not watched[unit] then return end
        auraDirty[unit] = true
    elseif event == "PLAYER_TARGET_CHANGED" then
        auraDirty.target = true
    elseif event == "PLAYER_FOCUS_CHANGED" then
        auraDirty.focus = true
    elseif event == "UNIT_PET" then
        auraDirty.pet = true
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        if testing then CDM.SetTest(false) end      -- real cooldowns matter now
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    elseif event == "PLAYER_LOGIN" then
        refreshSpec()
        lastSpecKey = specKey()
        playerGUID = UnitGUID("player")
        inCombat = InCombatLockdown() and true or false
        refreshCombatLog()
        CDM.Rebuild()
        loadSpots(lastSpecKey)
        CDM.UpdateMode()
    elseif event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUID("player")
        for unit in pairs(watched) do auraDirty[unit] = true end
        if Suite.ready then CDM.UpdateMode() end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if Suite.ready then CDM.UpdateMode() end
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        -- bear form and Frost Presence change the role (and with it the order inside the groups)
        if Suite.ready then currentRole = resolveRole() end
    elseif event == "PLAYER_LOGOUT" then
        if Suite.ready and autoAdapt then saveSpots(lastSpecKey) end
        return
    end
    dirty = true
end)

ui.RegisterCallback("SuiteProfileChanged", function()
    refreshCombatLog()
    CDM.selectedGroup = nil
    refreshSpec()
    lastSpecKey = specKey()
    currentMode = nil
    CDM.UpdateMode()
    CDM.Rebuild()
end, "CooldownManagerProfile")
ui.RegisterCallback("SuiteSpellsChanged", function() dirty = true end, "CooldownManagerSpells")
-- Talents or the talent group changed: new tree, new role, new set of entries and positions. The
-- client does not allow that in combat, and the tracker frames are not protected anyway.
ui.RegisterCallback("SuiteTalentsChanged", function()
    specChanged()
    CDM.Rebuild()
end, "CooldownManagerTalents")

-- Edit Mode: show every group with placeholders while the editor is open.
if ForeverStockUIEditMode then
    ForeverStockUIEditMode:HookScript("OnShow", function()
        editing = true
        CDM.Rebuild()
    end)
    ForeverStockUIEditMode:HookScript("OnHide", function()
        editing = false
        CDM.Rebuild()
    end)
end

SLASH_FOREVERUICDM1 = "/fcdm"
-- /fcdm            options
-- /fcdm test       test mode on / off
-- /fcdm mode X     auto, full, combat, raid, dungeon, pvp, minimal (no X: next mode)
SlashCmdList.FOREVERUICDM = function(text)
    local command, argument = (text or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if command == "test" then
        CDM.SetTest(not testing)
    elseif command == "mode" then
        if argument == "" then
            CDM.NextMode()
        elseif not CDM.SetMode(argument) then
            ui.Print("Cooldown Manager: auto, full, combat, raid, dungeon, pvp, minimal")
            return
        end
        ui.Print("Cooldown Manager: " .. data().mode .. " -> " .. modeNow())
    else
        ui.OpenOptions("cooldowns")
    end
end
