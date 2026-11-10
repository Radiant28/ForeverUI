local _, ui = ...
local data = { history = {} }
ui.CombatMeterData = data

local band = bit.band
local groupMask = 0x07
local playerType = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local friendly = COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x10
local damageEvents = {
    SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true,
    DAMAGE_SHIELD = true, DAMAGE_SPLIT = true, SPELL_BUILDING_DAMAGE = true,
}
local members, pets, summons = {}, {}, {}
local active, latest, entered, leftAt
local overall = { {}, {}, elapsed = 0 }
local fighting = false

local function updateRoster()
    wipe(members)
    wipe(pets)
    local function add(unit, pet)
        local guid = UnitGUID(unit)
        local name = UnitName(unit)
        if not guid or not name then return end
        local _, class = UnitClass(unit)
        local member = { guid = guid, name = name, class = class }
        members[guid] = member
        local petGUID = UnitGUID(pet)
        if petGUID then pets[petGUID] = member end
    end
    for i = 1, GetNumRaidMembers() do add("raid" .. i, "raidpet" .. i) end
    for i = 1, GetNumPartyMembers() do add("party" .. i, "partypet" .. i) end
    add("player", "pet")
    local player = UnitGUID("player")
    if player and members[player] then
        local vehicle = UnitGUID("vehicle")
        if vehicle and vehicle ~= player then pets[vehicle] = members[player] end
    end
end

local function memberFor(guid, name, flags)
    if not guid or guid == "" then return end
    local member = members[guid] or pets[guid] or members[summons[guid]]
    if member then return member end
    if not name or type(flags) ~= "number" or band(flags, groupMask) == 0 or band(flags, playerType) == 0 then return end
    local _, class
    if GetPlayerInfoByGUID then _, class = GetPlayerInfoByGUID(guid) end
    member = { guid = guid, name = name, class = class }
    members[guid] = member
    return member
end

local function finishCombat(now)
    if not active then return end
    active.ended = math.max(active.last, now)
    overall.elapsed = overall.elapsed + math.max(0, active.ended - active.started)
    table.insert(data.history, 1, active)
    data.history[11] = nil
    latest, active, leftAt = active, nil, nil
end

function data.Update()
    local now = GetTime()
    if leftAt and now - leftAt >= 0.3 then
        finishCombat(leftAt)
    elseif active and not leftAt and not fighting and now - active.last >= 5 then
        finishCombat(active.last)
    end
end

function data.GetSegment(id)
    if id == -1 then return overall end
    return active or latest
end

local function duration(segment)
    if not segment then return 0 end
    local now = fighting and GetTime() or math.max(segment.last, leftAt or 0)
    return math.max(0, (segment.ended or now) - segment.started)
end

function data.GetDuration(segment)
    if segment == overall then return overall.elapsed + duration(active) end
    return duration(segment)
end

function data.GetLiveDuration()
    if active and not leftAt then return duration(active) end
    if entered then return math.max(0, GetTime() - entered) end
end

function data.Reset()
    active, latest, leftAt = nil, nil, nil
    entered = fighting and GetTime() or nil
    overall = { {}, {}, elapsed = 0 }
    wipe(data.history)
end

local function addAmount(segment, kind, member, id, spellName, amount)
    local actors = segment[kind]
    local actor = actors[member.guid]
    if not actor then
        actor = { name = member.name, class = member.class, total = 0, spells = {} }
        actors[member.guid] = actor
    end
    actor.class = member.class or actor.class
    actor.total = actor.total + amount
    local spell = actor.spells[id]
    if not spell then
        spell = { name = spellName, total = 0 }
        actor.spells[id] = spell
    end
    spell.total = spell.total + amount
end

local function onCombatLog(_, token, source, sourceName, sourceFlags, target, targetName, targetFlags, ...)
    if token == "UNIT_DIED" or token == "UNIT_DESTROYED" then
        if target then summons[target] = nil end
        return
    end
    if token == "SPELL_SUMMON" or token == "SPELL_CREATE" then
        local owner = memberFor(source, sourceName, sourceFlags)
        if owner and target and target ~= owner.guid then summons[target] = owner.guid end
        return
    end
    local healing = token == "SPELL_HEAL" or token == "SPELL_PERIODIC_HEAL"
    if not healing and token ~= "SWING_DAMAGE" and not damageEvents[token] then return end
    if not target or not source then return end
    local member = memberFor(source, sourceName, sourceFlags)
    if not member then return end
    local isFriendly = members[target] or pets[target] or members[summons[target]]
        or type(targetFlags) == "number" and band(targetFlags, friendly) ~= 0
    if (healing and not isFriendly) or (not healing and isFriendly) then return end

    local id, spellName, amount, excess
    if token == "SWING_DAMAGE" then
        id, spellName = 0, ui.russian and "Атака ближнего боя" or "Melee"
        amount, excess = ...
    else
        id, spellName, _, amount, excess = ...
    end
    if type(amount) ~= "number" or not id or not spellName then return end
    amount = amount - math.max(0, tonumber(excess) or 0)
    if amount <= 0 then return end

    local now = GetTime()
    data.Update()
    if not active then
        if healing and not fighting then return end
        active = { {}, {}, started = entered or now, last = now }
    end
    active.last = now
    if not active.name and not healing then active.name = targetName end
    local kind = healing and 2 or 1
    addAmount(active, kind, member, id, spellName, amount)
    addAmount(overall, kind, member, id, spellName, amount)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
    "UNIT_PET", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        onCombatLog(...)
    elseif event == "PLAYER_REGEN_DISABLED" then
        data.Update()
        fighting, entered, leftAt = true, GetTime(), nil
    elseif event == "PLAYER_REGEN_ENABLED" then
        fighting, entered = false, nil
        if active then leftAt = GetTime() end
    elseif event == "PLAYER_LEAVING_WORLD" then
        if active then finishCombat(leftAt or active.last) end
        fighting, entered = false, nil
        wipe(summons)
    else
        updateRoster()
        if event == "PLAYER_ENTERING_WORLD" then
            fighting = UnitAffectingCombat("player") and true or false
            entered = fighting and GetTime() or nil
        end
    end
end)
