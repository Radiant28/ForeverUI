-- Tank detection for the raid frames (role icon, tanks first when sorting). Only tanks are recognised
-- (2026-11-22, the user's decision): healers and damage dealers get no role at all, nothing is guessed
-- from mana, class or inspected talents. The first source that answers wins:
--   mark      set by hand on the options page (by name, kept between sessions): "TANK" or "NONE"
--   assigned  the raid's main tank (MAINTANK) or the dungeon finder tank role
--   talents   the player's own talents (Protection warrior or paladin); another tree means no tank
--   stance    Defensive Stance, Righteous Fury, (Dire) Bear Form, Frost Presence; the role is kept
--             R.HOLD seconds after the stance drops (Disarm, a battle res out of form), so it does not blink
-- Pets have no role, and their tokens are never passed to the role API (the client answers
-- "raidpet1 is not in your group" in chat).
-- Suite.GroupRole(unit) -> "TANK", source  or nil.
local _, ui = ...
local Suite = ui.Suite

local R = {}
Suite.Roles = R

R.sources = { "mark", "assigned", "talents", "stance" }
-- Sources that are a reasoned guess rather than a fact (the icon may be drawn faded).
R.guessed = { stance = true }
R.HOLD = 10   -- seconds a tank keeps the role after leaving the stance

-- Talent tree of the tanks among the player's own trees (by tab index). Druids and death knights tank
-- from a tree that also deals damage: their form or presence decides.
R.tankTrees = { WARRIOR = 3, PALADIN = 2 }

-- Tank stances, forms and presences (names through GetSpellInfo, so any locale).
-- Frost Presence is the tank presence in 3.3.5.
R.stanceSpells = {
    25780,   -- Righteous Fury
    5487,    -- Bear Form
    9634,    -- Dire Bear Form
    48263,   -- Frost Presence
    71,      -- Defensive Stance
}
local stanceNames
local function stanceTable()
    if stanceNames then return stanceNames end
    local names = {}
    for _, id in ipairs(R.stanceSpells) do
        local name = GetSpellInfo and GetSpellInfo(id)
        if name then names[name] = true end
    end
    if next(names) then stanceNames = names end
    return names
end

-- Names are resolved once GetSpellInfo knows them; forget them to resolve again.
function R.ResetNames() stanceNames = nil end

-- True when the unit stands in a tank stance, form or presence right now.
function R.InTankStance(unit)
    local names = stanceTable()
    for index = 1, 40 do
        local name = UnitAura(unit, index, "HELPFUL")
        if not name then break end
        if names[name] then return true end
    end
    return false
end

local function db()
    local settings = ui.Settings()
    if type(settings.roleMarks) ~= "table" then settings.roleMarks = {} end
    -- The inspection cache of the old role chain is not used any more.
    settings.roleCache = nil
    return settings
end

local function nameOf(unit)
    local name = UnitName(unit)
    if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
    return name
end
R.NameOf = nameOf

-- Pet and vehicle tokens: "pet", "partypet2", "raidpet1", "arenapet3"...
function R.IsPetToken(unit)
    return type(unit) == "string" and unit:find("pet%d*$") ~= nil
end

-- true = Protection, false = another tree, nil = the talents do not tell (druid, death knight, no points).
function R.OwnTank()
    local _, class = UnitClass("player")
    local tree = R.tankTrees[class]
    if not tree or not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
    local group = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    local best, bestPoints = 0, 0
    for i = 1, GetNumTalentTabs() or 0 do
        local _, _, spent = GetTalentTabInfo(i, false, false, group)
        if (spent or 0) > bestPoints then best, bestPoints = i, spent end
    end
    if bestPoints == 0 then return nil end
    return best == tree
end

-- Marks: "TANK" (always a tank) or "NONE" (never, e.g. a damage warrior in Defensive Stance).
function R.Mark(name)
    local mark = name and db().roleMarks[name]
    if mark == "TANK" or mark == "NONE" then return mark end
    return nil
end
function R.SetMark(name, mark)
    if not name then return end
    if mark ~= "TANK" and mark ~= "NONE" then mark = nil end
    db().roleMarks[name] = mark
    ui.Fire("SuiteRolesChanged")
end

-- Stance hold: GUID -> { time the tank stance was last seen, unit }. The driver below drops holds that
-- ran out and refreshes the icons then (no aura event comes when nothing changes).
local seen = {}
R.seen = seen

local function clock() return GetTime and GetTime() or 0 end

local function stanceTank(unit)
    local guid = UnitGUID and UnitGUID(unit) or unit
    if R.InTankStance(unit) then
        if guid then seen[guid] = { time = clock(), unit = unit } end
        return true
    end
    local hold = guid and seen[guid]
    return hold ~= nil and clock() - hold.time < R.HOLD
end

-- "TANK", source  or nil
function Suite.GroupRole(unit)
    if not unit or R.IsPetToken(unit) or not UnitExists(unit) then return nil end
    local name = nameOf(unit)
    local mark = R.Mark(name)
    if mark == "TANK" then return "TANK", "mark" end
    if mark == "NONE" then return nil end
    if Suite.UnitRole(unit) == "TANK" then return "TANK", "assigned" end
    if UnitIsUnit and UnitIsUnit(unit, "player") then
        local own = R.OwnTank()
        if own then return "TANK", "talents" end
        if own == false then return nil end   -- the spec wins over the stance
    end
    if stanceTank(unit) then return "TANK", "stance" end
    return nil
end

-- Drops stance holds that ran out; returns true when one did (the icons must be refreshed). A tank
-- still in the stance (no aura event since) just gets a fresh time.
function R.ExpireHolds(at)
    at = at or clock()
    local expired = false
    for guid, hold in pairs(seen) do
        if at - hold.time >= R.HOLD then
            local unit = hold.unit
            if unit and UnitGUID and UnitGUID(unit) == guid and R.InTankStance(unit) then
                hold.time = at
            else
                seen[guid] = nil
                expired = true
            end
        end
    end
    return expired
end

function R.Reset()
    for k in pairs(seen) do seen[k] = nil end
end

local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed < 0.5 then return end
    elapsed = 0
    if next(seen) and R.ExpireHolds() then ui.Fire("SuiteRolesChanged") end
end)

for _, event in ipairs({ "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PLAYER_TALENT_UPDATE",
    "ACTIVE_TALENT_GROUP_CHANGED" }) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function() ui.Fire("SuiteRolesChanged") end)

R.labels = { TANK = ui.L("Танк", "Tank"), NONE = ui.L("Не танк", "Not a tank") }
R.sourceLabels = {
    assigned = ui.L("назначен", "assigned"), mark = ui.L("метка", "mark"), talents = ui.L("таланты", "talents"),
    stance = ui.L("стойка", "stance"),
}
