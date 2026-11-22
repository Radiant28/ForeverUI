-- ForeverUI low healer mana alert. A healer with ForeverUI tells the group when its mana drops below
-- the threshold (addon message "FUI_MANA"); everyone else shows a banner. The local watch (HM.CheckUnit,
-- UnitMana of the own subgroup) needs a known healer that sends no messages, so with roles never guessed
-- it stays silent: healers without ForeverUI are not watched. The healer never sees its own alert.
-- WotLK 3.3.5a: SendAddonMessage takes prefix, text, channel (prefixes need no registration), the
-- roster events are PARTY_MEMBERS_CHANGED / RAID_ROSTER_UPDATE, timers run on OnUpdate.
--
-- Healer role, no guessing (2026-11-22: mana, class and buffs made damage hybrids "healers"): the
-- player by the talent tree with the most points (Holy paladin, Restoration druid and shaman,
-- Discipline / Holy priest); everybody else only by the role their own ForeverUI announced. Healers
-- without ForeverUI are not known and not watched.
--
-- Packet: "<version>:<type>:<mana %>:<role>", e.g. "1:L:18:H". Types: L = low mana, R = role
-- announcement (sent after roster and talent changes, at most once per 10 s). Roles: H, T, D, N.
-- Spam protection (sender and local watch alike): an alert fires below the threshold only when armed,
-- disarms, and arms again above max(40%, threshold + 5%); at least COOLDOWN seconds lie between two
-- alerts for one healer, and the receiver drops a second alert for the same name inside COOLDOWN.
local _, ui = ...
local L, Suite = ui.L, ui.Suite
local floor, max, min, format = math.floor, math.max, math.min, string.format

local HM = {}
ui.HealerMana = HM

HM.PREFIX = "FUI_MANA"
HM.VERSION = 1
HM.COOLDOWN = 18          -- seconds between two alerts for one healer
HM.REARM = 40             -- mana % to climb above before the next alert
HM.ANNOUNCE_GAP = 10      -- seconds between two role announcements

local function setting(key, fallback)
    local value = ui.Settings()[key]
    if value == nil then return fallback end
    return value
end

local function enabled() return setting("hmEnabled", true) and true or false end
local function threshold() return tonumber(setting("hmThreshold", 25)) or 25 end

local function plainName(name)
    if type(name) ~= "string" then return nil end
    return (name:gsub("%-.*$", ""))
end

local function manaPercent(unit)
    local most = UnitManaMax(unit) or 0
    if most <= 0 then return nil end
    return floor((UnitMana(unit) or 0) / most * 100 + 0.5)
end

---------------------------------------------------------------------------------------------------
-- Roster: names of the group, their unit tokens and raid subgroups
---------------------------------------------------------------------------------------------------
local roster = {}       -- name -> { unit, subgroup, class }
local localNames = {}   -- name -> unit: healers of the own subgroup the local watch may check
local mySubgroup = 1
HM.roster, HM.localNames = roster, localNames

function HM.RebuildRoster()
    for k in pairs(roster) do roster[k] = nil end
    for k in pairs(localNames) do localNames[k] = nil end
    local me = UnitName("player")
    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    mySubgroup = 1
    if raidCount > 0 then
        for i = 1, raidCount do
            local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
            name = plainName(name)
            if name then
                roster[name] = { unit = "raid" .. i, subgroup = subgroup or 1, class = class }
                if name == me then mySubgroup = subgroup or 1 end
            end
        end
        for name, entry in pairs(roster) do
            if name ~= me and entry.subgroup == mySubgroup then localNames[name] = entry.unit end
        end
    else
        for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
            local unit = "party" .. i
            local name = plainName(UnitName(unit))
            if name then
                local _, class = UnitClass(unit)
                roster[name] = { unit = unit, subgroup = 1, class = class }
                localNames[name] = unit
            end
        end
    end
end

function HM.MySubgroup() return mySubgroup end

-- Whether an alert about this group member belongs to the chosen area.
function HM.InScope(name)
    local entry = roster[name]
    if not entry then return false end
    if not (GetNumRaidMembers and GetNumRaidMembers() > 0) then return true end
    if setting("hmScope", "group") == "raid" then return true end
    return entry.subgroup == mySubgroup
end

-- Addon channel for the current group: BATTLEGROUND, RAID, PARTY or nil when alone.
function HM.Channel()
    local _, kind = IsInInstance()
    if kind == "pvp" or (UnitInBattleground and UnitInBattleground("player")) then return "BATTLEGROUND" end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then return "RAID" end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then return "PARTY" end
    return nil
end

---------------------------------------------------------------------------------------------------
-- Healer role
---------------------------------------------------------------------------------------------------
local peers = {}   -- name -> { role, time }: group members whose ForeverUI announced itself
HM.peers = peers

-- Talent trees that heal, by tab index (locale independent).
HM.healerTrees = { PALADIN = { [1] = true }, PRIEST = { [1] = true, [2] = true }, DRUID = { [3] = true },
    SHAMAN = { [3] = true } }
local tankTrees = { WARRIOR = { [3] = true }, PALADIN = { [2] = true } }

function HM.TalentRole()
    if not GetNumTalentTabs then return nil end
    local group = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    local best, bestPoints = 0, 0
    for i = 1, GetNumTalentTabs() or 0 do
        local _, _, points = GetTalentTabInfo(i, false, false, group)
        if (points or 0) > bestPoints then best, bestPoints = i, points end
    end
    if bestPoints == 0 then return nil end
    local _, class = UnitClass("player")
    if HM.healerTrees[class] and HM.healerTrees[class][best] then return "HEALER" end
    if tankTrees[class] and tankTrees[class][best] then return "TANK" end
    return "DAMAGER"
end

HM.healerClasses = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }

-- Role of a unit and where it came from: "talents" (the player), "sync" (announced) or nil.
function HM.Role(unit)
    if not unit or not UnitExists(unit) then return nil end
    if UnitIsUnit(unit, "player") then
        local role = HM.TalentRole()
        if role then return role, "talents" end
        return nil
    end
    local peer = peers[plainName(UnitName(unit))]
    if peer and peer.role then return peer.role, "sync" end
    return nil
end

---------------------------------------------------------------------------------------------------
-- Packet
---------------------------------------------------------------------------------------------------
local roleLetters = { HEALER = "H", TANK = "T", DAMAGER = "D" }
local lettersRole = { H = "HEALER", T = "TANK", D = "DAMAGER" }

function HM.Encode(kind, pct, role)
    return format("%d:%s:%d:%s", HM.VERSION, kind, max(0, min(100, floor(pct or 0))), roleLetters[role] or "N")
end

-- Returns kind, pct, role (nil role for "N") or nil for anything malformed or from another version.
function HM.Decode(text)
    if type(text) ~= "string" then return nil end
    local version, kind, pct, letter = text:match("^(%d+):(%u):(%d+):(%u)$")
    if tonumber(version) ~= HM.VERSION or (kind ~= "L" and kind ~= "R") then return nil end
    pct = tonumber(pct)
    if pct > 100 then return nil end
    return kind, pct, lettersRole[letter]
end

HM.sent = 0
local function send(kind, pct, role)
    local channel = HM.Channel()
    if not channel or not SendAddonMessage then return false end
    SendAddonMessage(HM.PREFIX, HM.Encode(kind, pct, role), channel)
    HM.sent = HM.sent + 1
    return channel
end

---------------------------------------------------------------------------------------------------
-- Spam protection: hysteresis plus a cooldown
---------------------------------------------------------------------------------------------------
-- state = { armed, last }; true when an alert must go out now.
function HM.Evaluate(state, pct, now, limit)
    if not pct then return false end
    limit = limit or threshold()
    if pct > max(HM.REARM, limit + 5) then
        state.armed = true
        return false
    end
    if state.armed == false or pct >= limit then return false end
    -- Inside the cooldown the alert waits, still armed, for the next mana update.
    if state.last and now - state.last < HM.COOLDOWN then return false end
    state.armed, state.last = false, now
    return true
end

local selfState = {}      -- the player as a healer (sender)
local watchStates = {}    -- name -> state for the local watch
local shownAt = {}        -- name -> time of the last banner for that healer
HM.selfState, HM.watchStates, HM.shownAt = selfState, watchStates, shownAt

---------------------------------------------------------------------------------------------------
-- Banner
---------------------------------------------------------------------------------------------------
local FADE_IN, FADE_OUT = 0.25, 0.8
local white = "Interface\\Buttons\\WHITE8X8"
local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

local banner = CreateFrame("Frame", "ForeverStockUIHealerManaBanner", UIParent)
banner:SetWidth(340)
banner:SetHeight(40)
banner:SetPoint("TOP", UIParent, "TOP", 0, -190)
banner:SetFrameStrata("HIGH")
banner:SetClampedToScreen(true)
banner:EnableMouse(false)
banner:SetBackdrop({ bgFile = white, edgeFile = white, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
banner:SetBackdropColor(0.05, 0.05, 0.06, 0.88)
banner:SetBackdropBorderColor(0.85, 0.72, 0.45, 1)
banner:Hide()
HM.banner = banner

banner.glow = banner:CreateTexture(nil, "BORDER")
banner.glow:SetPoint("TOPLEFT", 1, -1)
banner.glow:SetPoint("BOTTOMRIGHT", -1, 1)
banner.glow:SetTexture(white)
banner.glow:SetGradientAlpha("HORIZONTAL", 0.2, 0.45, 1, 0.28, 0.2, 0.45, 1, 0)
banner.icon = banner:CreateTexture(nil, "ARTWORK")
banner.icon:SetWidth(28)
banner.icon:SetHeight(28)
banner.icon:SetPoint("LEFT", banner, "LEFT", 7, 0)
banner.text = banner:CreateFontString(nil, "OVERLAY")
banner.text:SetPoint("LEFT", banner.icon, "RIGHT", 9, 0)
banner.text:SetJustifyH("LEFT")

local function setIcon(class)
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        banner.icon:SetTexture(CLASS_ICONS)
        banner.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        return
    end
    local rf = ui.RaidFrames
    if not (rf and rf.SetRoleTexture and rf.SetRoleTexture(banner.icon, "HEALER", "blizzard2")) then
        banner.icon:SetTexture("Interface\\Icons\\Spell_Holy_FlashHeal")
        banner.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

-- The banner text: the name in its class colour, the percent in light blue.
function HM.Message(name, pct, class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local shown = color and format("|cff%02x%02x%02x%s|r", floor(color.r * 255), floor(color.g * 255),
        floor(color.b * 255), name) or name
    return format(L("У хила %s мало маны (|cff66b3ff%d%%|r)!", "Healer %s is low on mana (|cff66b3ff%d%%|r)!"), shown, pct)
end

local function layout(name, pct, class)
    local size = tonumber(setting("hmFontSize", 15)) or 15
    banner.text:SetFont(Suite and Suite.art.font or STANDARD_TEXT_FONT, size, "OUTLINE")
    banner.text:SetText(HM.Message(name, pct, class))
    setIcon(class)
    local iconSize = max(20, size + 12)
    banner.icon:SetWidth(iconSize)
    banner.icon:SetHeight(iconSize)
    banner:SetHeight(iconSize + 12)
    banner:SetWidth(max(220, (banner.text:GetStringWidth() or 0) + iconSize + 30))
end

-- Fade in, hold for the chosen time, fade out, hide: all on the banner's own OnUpdate.
local function animate(self, elapsed)
    self.clock = (self.clock or 0) + elapsed
    local t, hold = self.clock, self.hold or 4
    if t < FADE_IN then
        self:SetAlpha(t / FADE_IN)
    elseif t < FADE_IN + hold then
        self:SetAlpha(1)
    elseif t < FADE_IN + hold + FADE_OUT then
        self:SetAlpha(1 - (t - FADE_IN - hold) / FADE_OUT)
    else
        self:SetScript("OnUpdate", nil)
        self:Hide()
        self:SetAlpha(1)
    end
end
HM.Animate = animate

HM.last = nil   -- { name, pct, class, source }: the banner shown last (diagnostics, tests)
function HM.Show(name, pct, class, source)
    HM.last = { name = name, pct = pct, class = class, source = source }
    if HM.editing then return end
    layout(name, pct, class)
    banner.hold = tonumber(setting("hmDuration", 4)) or 4
    -- A banner already on screen restarts at full opacity instead of fading in again.
    banner.clock = banner:IsShown() and FADE_IN or 0
    banner:SetAlpha(banner:IsShown() and 1 or 0)
    banner:SetScript("OnUpdate", animate)
    banner:Show()
    local sound = setting("hmSound", "RaidWarning")
    if Suite and Suite.PlayAlert then
        Suite.PlayAlert(sound)
    elseif type(sound) == "string" and sound ~= "" then
        PlaySound(sound)
    end
end

-- One banner per healer per cooldown, whether the news came by addon message or the local watch.
function HM.Alert(name, pct, class, source)
    if not name or name == plainName(UnitName("player")) then return false end
    local now = GetTime()
    if shownAt[name] and now - shownAt[name] < HM.COOLDOWN then return false end
    shownAt[name] = now
    HM.Show(name, pct, class, source)
    return true
end

function HM.Test()
    local _, class = UnitClass("player")
    HM.Show(L("Лекарь", "Healer"), 18, HM.healerClasses[class] and class or "PRIEST", "test")
end

---------------------------------------------------------------------------------------------------
-- Sender (the player as a healer) and local watch (healers of the own subgroup)
---------------------------------------------------------------------------------------------------
function HM.CheckPlayer(now)
    if not enabled() or not HM.Channel() then return false end
    if UnitPowerType and UnitPowerType("player") ~= 0 then return false end
    if HM.Role("player") ~= "HEALER" then return false end
    if HM.Evaluate(selfState, manaPercent("player"), now or GetTime(), threshold()) then
        return send("L", manaPercent("player"), "HEALER")
    end
    return false
end

function HM.CheckUnit(unit, now)
    if not enabled() or not unit or UnitIsUnit(unit, "player") then return false end
    local name = plainName(UnitName(unit))
    local token = name and localNames[name]
    -- Healers with ForeverUI report themselves: their messages win over the local guess.
    if not token or peers[name] then return false end
    if not UnitIsConnected(token) or UnitIsDeadOrGhost(token) then return false end
    if UnitPowerType and UnitPowerType(token) ~= 0 then return false end
    if HM.Role(token) ~= "HEALER" then return false end
    local state = watchStates[name]
    if not state then
        state = {}
        watchStates[name] = state
    end
    local pct = manaPercent(token)
    if HM.Evaluate(state, pct, now or GetTime(), threshold()) then
        local _, class = UnitClass(token)
        return HM.Alert(name, pct, class, "local")
    end
    return false
end

function HM.OnMessage(prefix, text, channel, sender)
    if prefix ~= HM.PREFIX then return false end
    sender = plainName(sender)
    if not sender or sender == plainName(UnitName("player")) then return false end
    local kind, pct, role = HM.Decode(text)
    if not kind then return false end
    local known = peers[sender]
    peers[sender] = { role = role, time = GetTime() }
    -- A newcomer learns our role too.
    if not known and kind == "R" then HM.Announce() end
    if kind ~= "L" or not enabled() then return false end
    if not HM.InScope(sender) or pct >= threshold() then return false end
    local entry = roster[sender]
    return HM.Alert(sender, pct, entry and entry.class, "sync")
end

---------------------------------------------------------------------------------------------------
-- Role announcements: after roster and talent changes, coalesced, at most once per ANNOUNCE_GAP
---------------------------------------------------------------------------------------------------
local timer = CreateFrame("Frame")
local announceAt, lastAnnounce
local function tick()
    local now = GetTime()
    if announceAt and now >= announceAt then
        if lastAnnounce and now - lastAnnounce < HM.ANNOUNCE_GAP then
            announceAt = lastAnnounce + HM.ANNOUNCE_GAP
            return
        end
        announceAt = nil
        timer:SetScript("OnUpdate", nil)
        if enabled() and send("R", manaPercent("player") or 0, (HM.Role("player"))) then lastAnnounce = now end
    end
end

function HM.Announce(delay)
    if not enabled() then return end
    local at = GetTime() + (delay or 2)
    if not announceAt or at < announceAt then announceAt = at end
    timer:SetScript("OnUpdate", tick)
end
HM.Tick = tick

---------------------------------------------------------------------------------------------------
-- Events, Edit Mode, options
---------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
    "CHAT_MSG_ADDON", "UNIT_MANA", "UNIT_MAXMANA", "UNIT_DISPLAYPOWER" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        HM.OnMessage(...)
    elseif event == "UNIT_MANA" or event == "UNIT_MAXMANA" or event == "UNIT_DISPLAYPOWER" then
        local unit = ...
        if unit == "player" then HM.CheckPlayer() else HM.CheckUnit(unit) end
    else
        HM.RebuildRoster()
        HM.Announce()
    end
end)

if ui.RegisterCallback then
    ui.RegisterCallback("SuiteTalentsChanged", function() HM.Announce() end, "HealerManaTalents")
end

if ui.RegisterEditFrame then
    ui.RegisterEditFrame(banner, L("Мана хила", "Healer mana"), "healermana")
end

-- While Edit Mode is open the banner stays up with a sample text so it can be placed.
if ForeverStockUIEditMode then
    ForeverStockUIEditMode:HookScript("OnShow", function()
        HM.editing = true
        layout(L("Лекарь", "Healer"), 18, "PRIEST")
        banner:SetScript("OnUpdate", nil)
        banner:SetAlpha(1)
        banner:Show()
    end)
    ForeverStockUIEditMode:HookScript("OnHide", function()
        HM.editing = nil
        banner:Hide()
    end)
end

function HM.Apply()
    if HM.editing then layout(L("Лекарь", "Healer"), 18, "PRIEST") end
    if enabled() then HM.Announce() end
end

-- /fuimana: channel, own role, the group's healers and what is known about them (ASCII only: some
-- client chat fonts print Cyrillic as "?").
SLASH_FOREVERUIMANA1 = "/fuimana"
SlashCmdList.FOREVERUIMANA = function(input)
    if (input or ""):lower():match("test") then
        HM.Test()
        return
    end
    HM.RebuildRoster()
    local role, source = HM.Role("player")
    ui.Print(("channel=%s me=%s(%s) mana=%s subgroup=%d threshold=%d enabled=%s"):format(tostring(HM.Channel()),
        tostring(role), tostring(source), tostring(manaPercent("player")), mySubgroup, threshold(), tostring(enabled())))
    for name, entry in pairs(roster) do
        local r, s = HM.Role(entry.unit)
        ui.Print(("%s %s g%d role=%s(%s) mana=%s addon=%s local=%s"):format(name, entry.unit, entry.subgroup or 0,
            tostring(r), tostring(s), tostring(manaPercent(entry.unit)), peers[name] and "yes" or "no",
            localNames[name] and "yes" or "no"))
    end
end
