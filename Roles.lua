-- Group roles for the raid frames (role icons, sorting by role). Only sources that know the role are
-- used; nothing is worked out for a raid built by hand (2026-11-22, the user's decision: the old chain
-- of inspected talents, Tree of Life / Shadowform / Moonkin and damage-only classes made almost every
-- raid member a "healer"). The only guess left is the tank stance. The first source that answers wins:
--   mark      set by hand on the options page (by name, kept between sessions); "NONE" = no role
--   assigned  the client's role: dungeon finder roles, the raid's main tank (Suite.UnitRole)
--   talents   the player's own talents (any role); feral druid and death knight: the form decides
--   addon     the role another ForeverUI announced from its own talents (Healer mana, FUI_MANA "R")
--   stance    tanks only: Defensive Stance, Righteous Fury, (Dire) Bear Form, Frost Presence; the role
--             is kept R.HOLD seconds after the stance drops (Disarm, a battle res out of form)
-- Pets have no role, and their tokens are never passed to the role API (the client answers
-- "raidpet1 is not in your group" in chat).
-- Suite.GroupRole(unit) -> role, source  or nil.
local _, ui = ...
local Suite = ui.Suite

local R = {}
Suite.Roles = R

R.sources = { "mark", "assigned", "talents", "addon", "stance" }
-- Sources that are a reasoned guess rather than a fact (the icon may be drawn faded).
R.guessed = { stance = true }
R.HOLD = 10   -- seconds a tank keeps the role after leaving the stance

-- Role of each of the player's own talent trees by tab index; false = the tree does not tell (feral
-- druids tank or deal damage, death knights tank in any tree): the form or presence decides.
R.trees = {
    WARRIOR = { "DAMAGER", "DAMAGER", "TANK" }, PALADIN = { "HEALER", "TANK", "DAMAGER" },
    PRIEST = { "HEALER", "HEALER", "DAMAGER" }, SHAMAN = { "DAMAGER", "DAMAGER", "HEALER" },
    DRUID = { "DAMAGER", false, "HEALER" }, DEATHKNIGHT = { false, false, false },
    MAGE = { "DAMAGER", "DAMAGER", "DAMAGER" }, WARLOCK = { "DAMAGER", "DAMAGER", "DAMAGER" },
    ROGUE = { "DAMAGER", "DAMAGER", "DAMAGER" }, HUNTER = { "DAMAGER", "DAMAGER", "DAMAGER" },
}

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

-- Role from a list of points per tree: the role, false (the tree does not tell) or nil (no points).
function R.TreeRole(class, points)
    local best, bestPoints = 0, 0
    for i, value in ipairs(points) do
        if (value or 0) > bestPoints then best, bestPoints = i, value end
    end
    if bestPoints == 0 then return nil end
    local trees = R.trees[class]
    if not trees then return nil end
    return trees[best]
end

-- The player's role by the own talents (see R.TreeRole).
function R.OwnRole()
    if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
    local group = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    local points = {}
    for i = 1, GetNumTalentTabs() or 0 do
        local _, _, spent = GetTalentTabInfo(i, false, false, group)
        points[i] = spent or 0
    end
    local _, class = UnitClass("player")
    return R.TreeRole(class, points)
end

local markValues = { TANK = true, HEALER = true, DAMAGER = true, NONE = true }
-- Marks: a role, or "NONE" (no role, e.g. a damage warrior in Defensive Stance).
function R.Mark(name)
    local mark = name and db().roleMarks[name]
    if markValues[mark] then return mark end
    return nil
end
function R.SetMark(name, mark)
    if not name then return end
    if not markValues[mark] then mark = nil end
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

-- role, source  or nil
function Suite.GroupRole(unit)
    if not unit or R.IsPetToken(unit) or not UnitExists(unit) then return nil end
    local name = nameOf(unit)
    local mark = R.Mark(name)
    if mark == "NONE" then return nil end
    if mark then return mark, "mark" end
    local role = Suite.UnitRole(unit)
    if role then return role, "assigned" end
    if UnitIsUnit and UnitIsUnit(unit, "player") then
        role = R.OwnRole()
        if role then return role, "talents" end   -- the spec wins over the stance
    else
        local hm = ui.HealerMana
        local peer = hm and hm.peers and name and hm.peers[name]
        if peer and peer.role then return peer.role, "addon" end
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

local announceDue
for _, event in ipairs({ "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PLAYER_ROLES_ASSIGNED", "CHAT_MSG_ADDON",
    "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED" }) do
    pcall(driver.RegisterEvent, driver, event)
end
driver:SetScript("OnEvent", function(_, event, prefix)
    if event == "CHAT_MSG_ADDON" then
        -- a role announced by another ForeverUI (Healer mana stores it before this frame runs or after:
        -- the refresh comes on the next frame either way)
        if prefix == "FUI_MANA" then announceDue = true end
    else
        ui.Fire("SuiteRolesChanged")
    end
end)
local refresher = CreateFrame("Frame")
refresher:SetScript("OnUpdate", function()
    if announceDue then
        announceDue = nil
        ui.Fire("SuiteRolesChanged")
    end
end)

R.labels = {
    TANK = ui.L("Танк", "Tank"), HEALER = ui.L("Лекарь", "Healer"), DAMAGER = ui.L("Боец", "Damage"),
    NONE = ui.L("Без роли", "No role"),
}
R.sourceLabels = {
    assigned = ui.L("назначена", "assigned"), mark = ui.L("метка", "mark"), talents = ui.L("таланты", "talents"),
    addon = ui.L("аддон", "addon"), stance = ui.L("стойка", "stance"),
}
