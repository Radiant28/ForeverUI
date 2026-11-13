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
    load = { when = "always", group = "any", talentGroup = 0, tree = 0, form = 0,
        zone = { none = true, party = true, raid = true, pvp = true, arena = true } },
}
CDM.groupDefaults = GROUP_DEFAULTS

local ITEM_DEFAULTS = {
    kind = "cooldown", spell = "", unit = "player", mine = true, missingType = "aura",
    duration = 45, warn = 3, procAura = "", glowUsable = false, hideUnknown = true,
    onlyCombat = false, onlyGroup = false, requires = "",
    glowReady = false, soundReady = "", stacks = 0, glowStacks = true, soundStacks = "",
    expire = 0, glowExpire = true, soundExpire = "", glowMissing = true,
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

-- Class presets for the four starting groups (WotLK spell ids; unknown spells hide themselves).
local presets = {
    WARRIOR = { essential = cds({ 23881, 12294, 23922, 6572, 1680, 7384, 1719, 46924, 871, 12975 }),
        utility = cds({ 6552, 20252, 100, 5246, 23920, 57755, 3411, 18499 }),
        buffs = buffs({ 46916, 52437, 50227, 12292, 2565 }),
        bars = { item("buff", 6673, { warn = 10 }), item("debuff", 7386), item("debuff", 47467) },
        missing = { item("missing", "6673, 469", { onlyCombat = true }) } },
    PALADIN = { essential = cds({ 20473, 20271, 35395, 53385, 53595, 53600, 26573, 879, 31884, 54428 }),
        utility = cds({ 853, 642, 1022, 633, 1044, 6940, 31821, 498 }),
        buffs = buffs({ 54149, 59578, 20925, 53601, 31884 }),
        bars = { item("buff", 53601), item("buff", 20925) },
        missing = { item("missing", "20166, 20165, 21084, 20375, 31801, 53736"),
            item("missing", "", { missingType = "form" }) } },
    PRIEST = { essential = cds({ 47540, 17, 33076, 34861, 47788, 33206, 8092, 32379, 47585 }),
        utility = cds({ 6346, 8122, 586, 34433, 64901, 64843, 10060 }),
        buffs = buffs({ 33151, 63735, 59889, 15258, 47788 }),
        bars = dots({ 589, 34914, 2944 }),
        missing = { item("missing", 588), item("missing", "1243, 21562", { onlyGroup = true }) } },
    DRUID = { essential = cds({ 18562, 17116, 740, 29166, 22812, 48505, 33831, 33878, 50334, 5217, 61336 }),
        utility = cds({ 5211, 49377, 1850, 20484, 22842, 16979 }),
        buffs = buffs({ 48517, 48518, 16870, 69369, 52610 }),
        bars = dots({ 8921, 5570, 1079, 1822, 33745 }),
        missing = { item("missing", "1126, 21849", { onlyGroup = true }), item("missing", "", { missingType = "form" }) } },
    SHAMAN = { essential = cds({ 61295, 16188, 16190, 51505, 51490, 16166, 17364, 60103, 30823, 51533, 8042 }),
        utility = cds({ 57994, 51514, 8177, 32182, 2825, 2484 }),
        buffs = buffs({ 53817, 53390, 16246, 324, 52127, 974 }),
        bars = { item("totem", 1), item("totem", 2), item("totem", 3), item("totem", 4) },
        missing = { item("missing", "52127, 324"), item("missing", "", { missingType = "weapon_mh" }) } },
    MAGE = { essential = cds({ 12042, 12472, 11129, 12043, 55342, 12051, 44572, 2136, 120, 122 }),
        utility = cds({ 1953, 2139, 45438, 11958, 31687, 66 }),
        buffs = buffs({ 48108, 44401, 44544, 57761, 36032 }),
        bars = dots({ 44457, 12654 }),
        missing = { item("missing", "1459, 23028, 61316"), item("missing", "30482, 6117, 7302, 168") } },
    WARLOCK = { essential = cds({ 50796, 17962, 17877, 48181, 47241, 47193, 6789, 5484, 30283 }),
        utility = cds({ 29858, 18708, 47883, 698, 29893 }),
        buffs = buffs({ 54277, 71165, 63167, 64371, 17941 }),
        bars = dots({ 172, 348, 30108, 980, 603, 1490 }),
        missing = { item("missing", "28176, 706, 687") } },
    HUNTER = { essential = cds({ 53351, 53209, 19434, 53301, 34026, 19574, 3045, 23989, 2643, 3044, 3674 }),
        utility = cds({ 34490, 34477, 5384, 781, 19263, 1499, 19577 }),
        buffs = buffs({ 56453, 53220, 3045, 6150 }),
        bars = dots({ 1978, 1130, 3674 }),
        missing = { item("missing", "61846, 13165, 34074") } },
    ROGUE = { essential = cds({ 13750, 13877, 51690, 14177, 51713, 1856, 14185 }),
        utility = cds({ 5277, 31224, 1766, 408, 2094, 57934, 2983 }),
        buffs = buffs({ 5171, 51662, 32645, 13750 }),
        bars = { item("buff", 5171, { warn = 3 }), item("debuff", 1943), item("debuff", 703) },
        missing = { item("missing", "", { missingType = "weapon_mh" }), item("missing", "", { missingType = "weapon_oh" }) } },
    DEATHKNIGHT = { essential = cds({ 43265, 49184, 49028, 55233, 48792, 48707, 51271, 47568, 49206, 49016 }),
        utility = cds({ 47528, 47476, 49576, 46584, 49039, 48982, 42650 }),
        buffs = buffs({ 51124, 59052, 49222, 53365 }),
        bars = dots({ 55078, 55095 }),
        missing = { item("missing", 57330, { onlyCombat = true }), item("missing", "", { missingType = "form" }) } },
}

local function newGroup(name, kind, extra)
    local group = Suite.Copy(GROUP_DEFAULTS)
    group.name, group.kind, group.items = name, kind or "icons", {}
    for k, v in pairs(extra or {}) do group[k] = v end
    return group
end

local function starterGroups()
    local _, class = UnitClass("player")
    local preset = presets[class] or {}
    local list = {
        newGroup("Essential Cooldowns", "icons", { size = 42, perRow = 8, items = Suite.Copy(preset.essential or {}) }),
        newGroup("Utility Cooldowns", "icons", { size = 30, perRow = 10, items = Suite.Copy(preset.utility or {}) }),
        newGroup("Tracked Buffs", "icons", { size = 32, perRow = 8, cdShow = "always",
            items = Suite.Copy(preset.buffs or {}) }),
        newGroup("Tracked Bars", "bars", { perRow = 1, grow = "DOWN", items = Suite.Copy(preset.bars or {}) }),
    }
    local missing = Suite.Copy(preset.missing or {})
    missing[#missing + 1] = item("missing", "", { missingType = "flask", onlyGroup = true })
    missing[#missing + 1] = item("missing", "", { missingType = "food", onlyGroup = true })
    list[#list + 1] = newGroup(L("Напоминания", "Reminders"), "icons", { size = 34, perRow = 6, items = missing,
        load = { when = "always", group = "any", talentGroup = 0, tree = 0, form = 0,
            zone = { none = true, party = true, raid = true, pvp = false, arena = false } } })
    return list
end

Suite.RegisterProfilePart("cdm", function(db)
    if type(db.groups) ~= "table" then
        db.groups, db.order, db.nextId = {}, {}, 1
        for _, group in ipairs(starterGroups()) do
            local id = db.nextId
            db.nextId = id + 1
            group.id = id
            db.groups[id] = group
            db.order[#db.order + 1] = id
        end
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

local function conditionsBlock(entry)
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
local function evaluate(group, entry, r, now)
    r.show, r.icon, r.name, r.start, r.duration, r.count = false, nil, nil, nil, nil, nil
    r.desaturate, r.tint, r.glow, r.ready, r.expiration, r.inactive, r.warn = false, nil, false, false, nil, false, false
    local kind = entry.kind
    if conditionsBlock(entry) then return r end
    local list = spellList(entry.spell)

    if kind == "cooldown" then
        local spec = list[1]
        local start, duration, enabled
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
            start, duration, enabled = GetSpellCooldown(name)
            if GetSpellCharges then
                local charges, maxCharges, chargeStart, chargeDuration = GetSpellCharges(name)
                if maxCharges and maxCharges > 1 then
                    r.count = charges
                    if charges and charges > 0 then start, duration = chargeStart, chargeDuration end
                end
            end
            local usable, noMana = IsUsableSpell(name)
            if noMana then
                r.tint = 1
            elseif not usable then
                r.tint = 2
            end
            if entry.glowUsable and usable then r.glow = true end
        end
        duration = duration or 0
        local isGCD = duration > 0 and duration <= 1.51
        if isGCD and not group.showGCD then duration = 0 end
        if enabled == 0 then duration = 0 end
        r.ready = duration == 0 or (start or 0) + duration <= now
        if not r.ready then
            r.start, r.duration = start, duration
            r.expiration = start + duration
            if group.desaturate then r.desaturate = true end
            r.glow = false
        end
        if entry.procAura and entry.procAura ~= "" and findAura("player", spellList(entry.procAura), false, false) then
            r.glow = true
        end
        if group.cdShow == "ready" and not r.ready then return r end
        if group.cdShow == "cooldown" and r.ready then return r end
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
    if (load.tree or 0) > 0 and Suite.PrimaryTree() ~= load.tree then return false end
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
    if r.tint == 1 then
        el.texture:SetVertexColor(0.45, 0.55, 1)
    elseif r.tint == 2 then
        el.texture:SetVertexColor(0.45, 0.45, 0.45)
    else
        el.texture:SetVertexColor(1, 1, 1)
    end
    if r.warn then
        el.border:SetVertexColor(1, 0.25, 0.2)
    else
        el.border:SetVertexColor(group.borderColor[1], group.borderColor[2], group.borderColor[3])
    end
    el:SetAlpha(r.inactive and group.inactiveAlpha or 1)
    if group.showSwipe then Suite.SetCooldown(el.cooldown, r.start, r.duration) end
    el.count:SetText(group.showCount and r.count and r.count > 0 and r.count or "")
    el.expiration = r.expiration
    el.timer:SetText(group.showTimer and r.expiration and Suite.FormatTime(r.expiration - now) or "")
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
local function place(group, container, shownList)
    local isBars = group.kind == "bars"
    local w = isBars and group.barWidth or group.size
    local h = isBars and group.barHeight or group.size
    local gap = group.spacing
    local perRow = max(1, group.perRow)
    local grow, wrap = group.grow, group.wrap
    local horizontal = grow == "LEFT" or grow == "RIGHT"
    local count = #shownList
    local lines = max(1, math.ceil(count / perRow))
    local along = min(max(count, 1), perRow)
    local width = horizontal and along * w + (along - 1) * gap or lines * w + (lines - 1) * gap
    local height = horizontal and lines * h + (lines - 1) * gap or along * h + (along - 1) * gap
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
        if horizontal then
            local fromLeft = grow == "RIGHT"
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

local function drawGroup(group, now)
    local container = getContainer(group)
    local forced = editing or (previewing and (not focusGroup or focusGroup == group.id))
    if not forced and not loadAllowed(group) then
        container:Hide()
        for _, el in ipairs(container.elements) do animating[el] = nil end
        return
    end
    container:SetAlpha(group.alpha)
    local shownList, used = {}, 0
    local results = container.results
    for index, entry in ipairs(group.items) do
        local r = results[index] or {}
        results[index] = r
        evaluate(group, entry, r, now)
        if forced and not r.show then
            local name, icon = Suite.SpellInfo(spellList(entry.spell)[1])
            r.show, r.inactive, r.name = true, true, r.name or name or CDM.kindNames[entry.kind]
            r.icon = r.icon or icon
        end
        if r.show then
            local glow = alerts(entry, r, now)
            r.glow = r.glow or glow
        else
            alerts(entry, r, now)
        end
        local el = element(container, group, index)
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
    place(group, container, shownList)
    for _, el in ipairs(shownList) do
        if el.emptySlot then el:Hide() end
    end
    Suite.Shown(container.placeholder, editing and used == 0)
    if used == 0 and editing then
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
    hasTimers = false
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
    elseif hasTimers and tickElapsed >= 0.1 then
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
    "UNIT_PET", "BAG_UPDATE", "ACTIONBAR_UPDATE_COOLDOWN" }) do
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
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    elseif event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        inCombat = InCombatLockdown() and true or false
        refreshCombatLog()
        CDM.Rebuild()
    elseif event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUID("player")
        for unit in pairs(watched) do auraDirty[unit] = true end
    end
    dirty = true
end)

ui.RegisterCallback("SuiteProfileChanged", function()
    refreshCombatLog()
    CDM.selectedGroup = nil
    CDM.Rebuild()
end, "CooldownManagerProfile")
ui.RegisterCallback("SuiteSpellsChanged", function() dirty = true end, "CooldownManagerSpells")
ui.RegisterCallback("SuiteTalentsChanged", function() dirty = true end, "CooldownManagerTalents")

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
SlashCmdList.FOREVERUICDM = function() ui.OpenOptions("cooldowns") end
