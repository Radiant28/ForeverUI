-- Group roles for the raid frames (role icons, sorting by role). In a raid built by hand the 3.3.5
-- client knows no roles (UnitGroupRolesAssigned only answers in a dungeon finder group), so the role is
-- worked out; the first source that answers wins:
--   assigned  the dungeon finder role or the raid's main tank
--   mark      set by hand on the options page (by name, kept between sessions)
--   talents   the player's own talents
--   addon     the role another ForeverUI announced (Healer mana, FUI_MANA "R" packets)
--   stance    tank stances and forms, Tree of Life; Shadowform, Moonkin and Cat Form mean damage
--   inspect   talents read by inspecting the player (one at a time, out of combat, cached by name)
--   class     classes that only deal damage
-- Suite.GroupRole(unit) -> role, source. Suite.UnitRole (assigned only) stays for Healer mana.
local _, ui = ...
local Suite = ui.Suite

local R = {}
Suite.Roles = R

R.sources = { "assigned", "mark", "talents", "addon", "stance", "inspect", "class" }
-- Sources that are a reasoned guess rather than a fact (the icon may be drawn faded).
R.guessed = { stance = true, inspect = true, class = true }
R.CACHE_TIME = 3600          -- an inspected role is trusted for an hour (dual specs change roles)
R.INSPECT_GAP = 1.5          -- seconds between two inspections
R.INSPECT_TIMEOUT = 4        -- no answer: try somebody else, this one later
R.RETRY_TIME = 60

-- Role of each talent tree by tab index; false = the tree does not tell (feral druids tank or deal
-- damage, death knights tank in any tree): the form or presence decides.
R.trees = {
    WARRIOR = { "DAMAGER", "DAMAGER", "TANK" }, PALADIN = { "HEALER", "TANK", "DAMAGER" },
    PRIEST = { "HEALER", "HEALER", "DAMAGER" }, SHAMAN = { "DAMAGER", "DAMAGER", "HEALER" },
    DRUID = { "DAMAGER", false, "HEALER" }, DEATHKNIGHT = { false, false, false },
    MAGE = { "DAMAGER", "DAMAGER", "DAMAGER" }, WARLOCK = { "DAMAGER", "DAMAGER", "DAMAGER" },
    ROGUE = { "DAMAGER", "DAMAGER", "DAMAGER" }, HUNTER = { "DAMAGER", "DAMAGER", "DAMAGER" },
}
R.damageClasses = { MAGE = true, WARLOCK = true, ROGUE = true, HUNTER = true }

-- Stances, forms and presences that tell the role (names through GetSpellInfo, so any locale).
-- Frost Presence is the tank presence in 3.3.5.
R.stanceSpells = {
    { 25780, "TANK" },     -- Righteous Fury
    { 5487, "TANK" },      -- Bear Form
    { 9634, "TANK" },      -- Dire Bear Form
    { 48263, "TANK" },     -- Frost Presence
    { 71, "TANK" },        -- Defensive Stance
    { 33891, "HEALER" },   -- Tree of Life
    { 15473, "DAMAGER" },  -- Shadowform
    { 24858, "DAMAGER" },  -- Moonkin Form
    { 768, "DAMAGER" },    -- Cat Form
}
local stanceNames
local function stanceTable()
    if stanceNames then return stanceNames end
    local names = {}
    for _, entry in ipairs(R.stanceSpells) do
        local name = GetSpellInfo and GetSpellInfo(entry[1])
        if name then names[name] = entry[2] end
    end
    if next(names) then stanceNames = names end
    return names
end

-- Names are resolved once GetSpellInfo knows them; forget them to resolve again.
function R.ResetNames() stanceNames = nil end

function R.StanceRole(unit)
    local names = stanceTable()
    local found
    for index = 1, 40 do
        local name = UnitAura(unit, index, "HELPFUL")
        if not name then break end
        local role = names[name]
        if role == "TANK" then return "TANK" end
        found = found or role
    end
    return found
end

local function db()
    local settings = ui.Settings()
    if type(settings.roleMarks) ~= "table" then settings.roleMarks = {} end
    if type(settings.roleCache) ~= "table" then settings.roleCache = {} end
    return settings
end

local function nameOf(unit)
    local name = UnitName(unit)
    if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
    return name
end
R.NameOf = nameOf

local function now() return time and time() or 0 end

-- Role from a list of points per tree.
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

function R.OwnRole()
    if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
    local group = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    local points = {}
    for i = 1, GetNumTalentTabs() or 0 do
        local _, _, spent = GetTalentTabInfo(i, false, false, group)
        points[i] = spent or 0
    end
    local _, class = UnitClass("player")
    return R.TreeRole(class, points) or nil
end

function R.Mark(name) return name and db().roleMarks[name] or nil end
function R.SetMark(name, role)
    if not name then return end
    if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then role = nil end
    db().roleMarks[name] = role
    ui.Fire("SuiteRolesChanged")
end

function R.Cached(name)
    local entry = name and db().roleCache[name]
    if type(entry) ~= "table" then return nil end
    if now() - (entry.time or 0) > R.CACHE_TIME then return nil end
    return entry
end

-- role, source
function Suite.GroupRole(unit)
    if not unit or not UnitExists(unit) then return nil end
    local role = Suite.UnitRole(unit)
    if role then return role, "assigned" end
    local name = nameOf(unit)
    role = R.Mark(name)
    if role then return role, "mark" end
    if UnitIsUnit and UnitIsUnit(unit, "player") then
        role = R.OwnRole()
        if role then return role, "talents" end
    else
        local hm = ui.HealerMana
        local peer = hm and hm.peers and name and hm.peers[name]
        if peer and peer.role then return peer.role, "addon" end
    end
    role = R.StanceRole(unit)
    if role then return role, "stance" end
    local cached = R.Cached(name)
    if cached and cached.role then return cached.role, "inspect" end
    local _, class = UnitClass(unit)
    if R.damageClasses[class] then return "DAMAGER", "class" end
    return nil
end

---------------------------------------------------------------------------------------------------
-- Inspection: one group member at a time, only out of combat, in range, while nobody else inspects.
---------------------------------------------------------------------------------------------------
local pending, nextAt, ours = nil, 0, false
local tries = {}   -- name -> time of the last failed try

local function enabled()
    local rf = ui.RaidFrames
    local settings = rf and rf.Settings and rf.Settings()
    return not settings or settings.rfRoleInspect ~= false
end

local function groupUnits()
    local list = {}
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raid > 0 then
        for i = 1, raid do list[#list + 1] = "raid" .. i end
    else
        for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do list[#list + 1] = "party" .. i end
    end
    return list
end

-- Somebody worth inspecting: no answer from the quicker sources and a class whose talents tell.
function R.NeedsInspect(unit, at)
    if not UnitExists(unit) or (UnitIsUnit and UnitIsUnit(unit, "player")) then return false end
    if UnitIsConnected and not UnitIsConnected(unit) then return false end
    if Suite.GroupRole(unit) then return false end
    local name = nameOf(unit)
    if not name or R.Cached(name) then return false end
    if tries[name] and (at or GetTime()) - tries[name] < R.RETRY_TIME then return false end
    local _, class = UnitClass(unit)
    return R.trees[class] ~= nil and not R.damageClasses[class]
end

local function inspectBusy()
    return InspectFrame and InspectFrame:IsShown()
end

function R.Step(at)
    at = at or GetTime()
    if pending then
        if at - pending.started > R.INSPECT_TIMEOUT then
            tries[pending.name] = at
            pending = nil
        end
        return
    end
    if at < nextAt or not enabled() or InCombatLockdown() or inspectBusy() then return end
    if not (NotifyInspect and CanInspect) then return end
    for _, unit in ipairs(groupUnits()) do
        if R.NeedsInspect(unit, at) and CanInspect(unit)
            and (not CheckInteractDistance or CheckInteractDistance(unit, 1)) then
            pending = { unit = unit, name = nameOf(unit), guid = UnitGUID(unit), started = at }
            nextAt = at + R.INSPECT_GAP
            ours = true
            NotifyInspect(unit)
            ours = false
            return unit
        end
    end
    nextAt = at + R.INSPECT_GAP
end

function R.TalentsReady()
    local job = pending
    if not job then return end
    pending = nil
    if UnitGUID(job.unit) ~= job.guid then
        tries[job.name] = GetTime()
        return
    end
    local group = GetActiveTalentGroup and GetActiveTalentGroup(true) or 1
    local points, total = {}, 0
    for i = 1, 3 do
        local _, _, spent = GetTalentTabInfo(i, true, false, group)
        points[i] = spent or 0
        total = total + points[i]
    end
    if not inspectBusy() and ClearInspectPlayer then ClearInspectPlayer() end
    if total == 0 then
        tries[job.name] = GetTime()
        return
    end
    local _, class = UnitClass(job.unit)
    local role = R.TreeRole(class, points)
    -- false (feral, death knight): remembered too, so nobody is inspected again for an hour
    db().roleCache[job.name] = { role = role or nil, class = class, time = now(), points = points }
    ui.Fire("SuiteRolesChanged")
    return role
end

function R.Pending() return pending end
function R.Reset()
    pending, nextAt = nil, 0
    for k in pairs(tries) do tries[k] = nil end
end

if hooksecurefunc and NotifyInspect then
    -- Somebody else asked for an inspection: the answer will be theirs, not ours.
    hooksecurefunc("NotifyInspect", function()
        if not ours and pending then
            tries[pending.name] = GetTime()
            pending = nil
        end
    end)
end

local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed < 0.5 then return end
    elapsed = 0
    if (GetNumRaidMembers and GetNumRaidMembers() or 0) == 0 and (GetNumPartyMembers and GetNumPartyMembers() or 0) == 0 then
        return
    end
    R.Step()
end)

local announceDue
for _, event in ipairs({ "INSPECT_TALENT_READY", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "CHAT_MSG_ADDON",
    "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED" }) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function(_, event, prefix)
    if event == "INSPECT_TALENT_READY" then
        R.TalentsReady()
    elseif event == "CHAT_MSG_ADDON" then
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
}
R.sourceLabels = {
    assigned = ui.L("назначена", "assigned"), mark = ui.L("метка", "mark"), talents = ui.L("таланты", "talents"),
    addon = ui.L("аддон", "addon"), stance = ui.L("стойка", "stance"), inspect = ui.L("осмотр", "inspect"),
    class = ui.L("класс", "class"),
}
