-- Low healer mana alert on mocks (HealerMana.lua with the real Suite.lua): packet format, channel
-- choice, healer role chain, hysteresis and cooldown of the sender and of the local watch, the healer
-- never alerted about itself, raid subgroup filter, addon messages winning over the local watch,
-- banner fade, and drink recognition (Suite.DrinkAura). Run from the addon root (see INDEX.md).
local forbidden = { "C_Timer", "BackdropTemplate", "SetShown(", "RegisterAddonMessagePrefix", "C_ChatInfo",
    "GROUP_ROSTER_UPDATE", "IsInGroup", "IsInRaid" }

---------------------------------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------------------------------
local objects = {}
local methods = {}
local function new(name)
    local f = setmetatable({ shown = true, alpha = 1, scripts = {}, width = 0, height = 0, name = name },
        { __index = function(_, key)
            if methods[key] then return methods[key] end
            if type(key) == "string" and key:match("^%u") then return function() end end
        end })
    objects[#objects + 1] = f
    if name then _G[name] = f end
    return f
end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetAlpha(a) self.alpha = a end
function methods:GetAlpha() return self.alpha end
function methods:SetScript(n, fn) self.scripts[n] = fn end
function methods:HookScript(n, fn) local old = self.scripts[n]; self.scripts[n] = function(...) if old then old(...) end fn(...) end end
function methods:CreateTexture() return new() end
function methods:CreateFontString() return new() end
function methods:SetText(t) self.text = t end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #(self.text or "") * 6 end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:SetTexture(t) self.texture = t end
function methods:GetName() return self.name end
local events = {}
function methods:RegisterEvent(event) events[event] = events[event] or {}; events[event][self] = true end
function CreateFrame(_, name) return new(name) end
UIParent = new("UIParent")
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
SlashCmdList = {}
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 }, SHAMAN = { r = 0, g = 0.44, b = 0.87 },
    DRUID = { r = 1, g = 0.49, b = 0.04 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 } }
CLASS_ICON_TCOORDS = { PRIEST = { 0.5, 0.75, 0.25, 0.5 } }

local now = 100
function GetTime() return now end
function GetLocale() return "ruRU" end
local played = {}
function PlaySound(s) played[#played + 1] = s end
function PlaySoundFile() end
LibStub = nil

local function fire(event, ...)
    for frame in pairs(events[event] or {}) do frame.scripts.OnEvent(frame, event, ...) end
end
local function tick(seconds)
    now = now + seconds
    for _, f in ipairs(objects) do
        if f.scripts.OnUpdate then f.scripts.OnUpdate(f, seconds) end
    end
end

---------------------------------------------------------------------------------------------------
-- Units: the player is a priest; party/raid members are set per scenario
---------------------------------------------------------------------------------------------------
local units = {}
local function setUnit(unit, data) units[unit] = data end
local function reset()
    for k in pairs(units) do units[k] = nil end
end
local raidRoster = {}
local zone = "none"
local spellNames = { [33891] = "Древо Жизни", [15473] = "Облик Тьмы", [24858] = "Облик лунного совуха",
    [25780] = "Праведное неистовство", [324] = "Щит молний", [52127] = "Водный щит", [430] = "Питье", [27089] = "Питье" }
function GetSpellInfo(id) local n = spellNames[id] return n, "", n and "Interface\\Icons\\X" or nil end
function UnitExists(unit) return units[unit] ~= nil end
function UnitName(unit) return units[unit] and units[unit].name end
function UnitClass(unit) local u = units[unit]; return u and u.class, u and u.class end
function UnitIsUnit(a, b) return units[a] ~= nil and units[a] == units[b] end
function UnitMana(unit) return units[unit] and units[unit].mana or 0 end
function UnitManaMax(unit) return units[unit] and (units[unit].maxMana or 100) or 0 end
function UnitPowerType(unit) return units[unit] and units[unit].power or 0 end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost() return false end
function UnitGroupRolesAssigned(unit)
    local role = units[unit] and units[unit].assigned
    return role == "TANK", role == "HEALER", role == "DAMAGER"
end
function GetPartyAssignment() return false end
function UnitBuff(unit, index)
    local buffs = units[unit] and units[unit].buffs or {}
    local b = buffs[index]
    if not b then return nil end
    return b.name, "", "icon", 0, nil, b.duration or 30, (b.expiration or now + 20), "player", nil, nil, b.id
end
function UnitInBattleground() return zone == "pvp" and 1 or nil end
function IsInInstance() return zone ~= "none", zone end
function GetNumRaidMembers() return #raidRoster end
local partyCount = 0
function GetNumPartyMembers() return partyCount end
function GetRaidRosterInfo(i) local r = raidRoster[i]; if r then return r[1], 0, r[2], 80, r[3], r[3] end end
local talentPoints = { 0, 0, 0 }
function GetNumTalentTabs() return 3 end
function GetActiveTalentGroup() return 1 end
function GetTalentTabInfo(i) return "Tree" .. i, "", talentPoints[i] end
function GetNumTalents() return 0 end
local sent = {}
function SendAddonMessage(prefix, text, channel) sent[#sent + 1] = { prefix, text, channel } end

---------------------------------------------------------------------------------------------------
-- Load the real Suite.lua and HealerMana.lua
---------------------------------------------------------------------------------------------------
local settings = {}
local registered
local ui = { russian = true, Settings = function() return settings end, Fire = function() end, Print = function() end,
    RegisterCallback = function() end,
    RegisterEditFrame = function(frame, label, category) registered = { frame, label, category } end }
function ui.L(ru) return ru end
ForeverStockUIEditMode = new("ForeverStockUIEditMode")
ForeverStockUIEditMode.shown = false
for _, path in ipairs({ "Suite.lua", "HealerMana.lua", "Options/HealerMana.lua" }) do
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    for _, keyword in ipairs(forbidden) do assert(not source:find(keyword, 1, true), path .. ": " .. keyword) end
    if path ~= "Options/HealerMana.lua" then assert(loadfile(path))("ForeverUI", ui) end
end
local Suite, HM = ui.Suite, ui.HealerMana
assert(registered and registered[1] == HM.banner and registered[3] == "healermana", "banner registered in Edit Mode")
assert(HM.banner:GetName() == "ForeverStockUIHealerManaBanner")

---------------------------------------------------------------------------------------------------
-- Packet
---------------------------------------------------------------------------------------------------
assert(HM.Encode("L", 18, "HEALER") == "1:L:18:H")
assert(HM.Encode("R", 140, nil) == "1:R:100:N", "clamped, unknown role is N")
local kind, pct, role = HM.Decode("1:L:18:H")
assert(kind == "L" and pct == 18 and role == "HEALER")
assert(select(3, HM.Decode("1:R:50:N")) == nil)
for _, bad in ipairs({ "2:L:18:H", "1:X:18:H", "1:L:180:H", "1:L:-5:H", "garbage", "", "1:L:18" }) do
    assert(not HM.Decode(bad), "rejected: " .. bad)
end
assert(not HM.Decode(nil))

---------------------------------------------------------------------------------------------------
-- Channel
---------------------------------------------------------------------------------------------------
setUnit("player", { name = "Me", class = "PRIEST", mana = 100 })
assert(HM.Channel() == nil, "alone: no channel")
partyCount = 2
assert(HM.Channel() == "PARTY")
raidRoster = { { "Me", 1, "PRIEST" } }
assert(HM.Channel() == "RAID")
zone = "pvp"
assert(HM.Channel() == "BATTLEGROUND", "battlegrounds first")
zone, raidRoster, partyCount = "none", {}, 0

---------------------------------------------------------------------------------------------------
-- Hysteresis and cooldown (pure)
---------------------------------------------------------------------------------------------------
local s = {}
assert(not HM.Evaluate(s, 30, 0, 25), "above the threshold")
assert(HM.Evaluate(s, 24, 1, 25), "fires below the threshold")
assert(not HM.Evaluate(s, 10, 30, 25), "disarmed: no repeat while still low, even after the cooldown")
assert(not HM.Evaluate(s, 39, 31, 25) and s.armed == false, "39% does not re-arm")
assert(not HM.Evaluate(s, 41, 32, 25) and s.armed == true, "above 40% re-arms")
assert(not HM.Evaluate(s, 20, 10, 25), "re-armed but inside the cooldown")
assert(s.armed == true, "the cooldown keeps it armed")
assert(HM.Evaluate(s, 20, 1 + HM.COOLDOWN, 25), "fires once the cooldown has passed")
local high = {}
assert(HM.Evaluate(high, 45, 0, 50), "threshold 50")
assert(not HM.Evaluate(high, 52, 1, 50) and high.armed == false, "re-arm sits above a high threshold")
assert(not HM.Evaluate(high, 56, 2, 50) and high.armed == true)
assert(HM.COOLDOWN >= 15 and HM.COOLDOWN <= 20)

---------------------------------------------------------------------------------------------------
-- Healer role chain
---------------------------------------------------------------------------------------------------
-- 1. no assigned roles, no guessing: a dungeon finder role, class, mana and buffs tell nothing
setUnit("party1", { name = "Tank", class = "PALADIN", assigned = "TANK" })
assert(HM.Role("party1") == nil, "the assigned role is not used")
setUnit("party3", { name = "Resto", class = "SHAMAN", buffs = { { name = "Водный щит" } } })
assert(HM.Role("party3") == nil, "no healer guessed from Water Shield")
setUnit("party3", { name = "Holy", class = "PRIEST" })
assert(HM.Role("party3") == nil, "no healer guessed from a mana class")
-- 2. own talents: Discipline / Holy priest heals, Shadow does not
talentPoints = { 0, 51, 20 }
assert(HM.Role("player") == "HEALER" and select(2, HM.Role("player")) == "talents")
talentPoints = { 10, 5, 56 }
assert(HM.Role("player") == "DAMAGER")
talentPoints = { 0, 0, 0 }
assert(HM.Role("player") == nil, "no talents: unknown")
-- 3. the role another ForeverUI announced
setUnit("party2", { name = "Synced", class = "SHAMAN" })
HM.peers.Synced = { role = "HEALER", time = now }
assert(HM.Role("party2") == "HEALER" and select(2, HM.Role("party2")) == "sync")
HM.peers.Synced = nil

---------------------------------------------------------------------------------------------------
-- Sender: the player as a healer in a party
---------------------------------------------------------------------------------------------------
reset()
settings.hmThreshold = 25
setUnit("player", { name = "Me", class = "PRIEST", mana = 100 })
setUnit("party1", { name = "Bob", class = "WARRIOR", mana = 0, power = 1 })
partyCount = 1
fire("PARTY_MEMBERS_CHANGED")
talentPoints = { 0, 51, 0 }
local function mana(unit, value) units[unit].mana = value; fire("UNIT_MANA", unit) end
mana("player", 30)
assert(#sent == 0)
mana("player", 20)
assert(#sent == 1 and sent[1][1] == "FUI_MANA" and sent[1][2] == "1:L:20:H" and sent[1][3] == "PARTY", "low mana sent")
assert(not HM.banner.shown, "the healer never sees its own alert")
mana("player", 15)
assert(#sent == 1, "no repeat while low")
mana("player", 45)
now = now + 5
mana("player", 20)
assert(#sent == 1, "re-armed but inside the cooldown")
now = now + HM.COOLDOWN
mana("player", 19)
assert(#sent == 2 and sent[2][2] == "1:L:19:H", "after re-arm and cooldown")
-- a damage-dealing priest sends nothing
talentPoints = { 0, 0, 51 }
mana("player", 60)
now = now + 60
mana("player", 10)
assert(#sent == 2, "not a healer: no message")
-- the own message coming back over the channel is ignored
fire("CHAT_MSG_ADDON", "FUI_MANA", "1:L:10:H", "PARTY", "Me")
assert(not HM.banner.shown, "own message ignored")
fire("CHAT_MSG_ADDON", "FUI_MANA", "1:L:10:H", "PARTY", "Me-Realm")
assert(not HM.banner.shown, "own message with realm ignored")

---------------------------------------------------------------------------------------------------
-- Receiver: messages, scope in a raid, dedupe against the local watch
---------------------------------------------------------------------------------------------------
reset()
sent = {}
talentPoints = { 0, 0, 51 }
setUnit("player", { name = "Me", class = "MAGE", mana = 100 })
setUnit("raid1", { name = "Me", class = "MAGE", mana = 100 })
setUnit("raid2", { name = "Heal", class = "PRIEST", mana = 100 })
setUnit("raid3", { name = "Far", class = "SHAMAN", mana = 100 })
setUnit("raid4", { name = "Druid", class = "DRUID", mana = 100 })
raidRoster = { { "Me", 1, "MAGE" }, { "Heal", 1, "PRIEST" }, { "Far", 3, "SHAMAN" }, { "Druid", 1, "DRUID" } }
fire("RAID_ROSTER_UPDATE")
assert(HM.MySubgroup() == 1 and HM.localNames.Heal == "raid2" and not HM.localNames.Far and not HM.localNames.Me,
    "local watch covers the own subgroup without the player")
settings.hmScope = "group"
assert(not HM.OnMessage("FUI_MANA", "1:L:18:H", "RAID", "Far"), "another subgroup is filtered")
assert(HM.OnMessage("FUI_MANA", "1:L:18:H", "RAID", "Heal"), "own subgroup shows")
assert(HM.banner.shown and HM.last.name == "Heal" and HM.last.pct == 18 and HM.last.source == "sync")
assert(HM.banner.text.text:find("Heal", 1, true) and HM.banner.text.text:find("18%", 1, true), "banner text")
assert(#played == 1 and played[1] == "RaidWarning", "alert sound")
assert(not HM.OnMessage("FUI_MANA", "1:L:12:H", "RAID", "Heal"), "a second alert inside the cooldown is a duplicate")
settings.hmScope = "raid"
assert(HM.OnMessage("FUI_MANA", "1:L:18:H", "RAID", "Far"), "whole raid")
assert(not HM.OnMessage("FUI_MANA", "1:L:30:H", "RAID", "Druid"), "above the receiver's threshold")
assert(not HM.OnMessage("FUI_MANA", "1:L:10:H", "RAID", "Stranger"), "not in the group")
assert(not HM.OnMessage("OTHER", "1:L:10:H", "RAID", "Druid"), "other prefixes")
settings.hmScope = "group"
-- Heal has ForeverUI now: the local watch leaves it to its messages
units.raid2.mana = 5
assert(not HM.CheckUnit("raid2"), "peers are not watched locally")
-- Any message marks the sender as a ForeverUI peer, even one above the threshold
assert(HM.peers.Druid, "the sender is known to run ForeverUI")
units.raid4.mana = 20
assert(not HM.CheckUnit("raid4"), "so the local watch leaves it alone")
units.raid4.mana = 100
-- Druid without the addon: its role is not guessed, so it is not watched
HM.peers.Druid = nil
now = now + 100
units.raid4.mana = 20
assert(not HM.CheckUnit("raid4"), "healers without ForeverUI are not watched")
-- the local watch never alerts about the player
units.raid1.mana, units.player.mana = 1, 1
assert(not HM.CheckUnit("raid1") and not HM.CheckUnit("player"), "never about oneself")
-- a priest in the subgroup without ForeverUI is not taken for a healer either
HM.peers.Heal = nil
now = now + 100
units.raid2.mana = 3
assert(not HM.CheckUnit("raid2"), "a priest without the addon is not watched")
-- disabled module: nothing
settings.hmEnabled = false
now = now + 100
units.raid2.mana = 50; HM.CheckUnit("raid2"); units.raid2.mana = 2
assert(not HM.CheckUnit("raid2") and not HM.OnMessage("FUI_MANA", "1:L:5:H", "RAID", "Far"), "disabled")
settings.hmEnabled = nil

---------------------------------------------------------------------------------------------------
-- Role announcements: coalesced and rate-limited; a newcomer gets an answer
---------------------------------------------------------------------------------------------------
tick(HM.ANNOUNCE_GAP + 3)   -- announcements still pending from the roster changes above
tick(HM.ANNOUNCE_GAP + 3)
sent = {}
talentPoints = { 0, 51, 0 }
units.player.class = "PRIEST"
fire("RAID_ROSTER_UPDATE")
fire("RAID_ROSTER_UPDATE")
tick(1)
assert(#sent == 0, "waits for the burst to end")
tick(1.5)
assert(#sent == 1 and sent[1][2] == "1:R:1:H" and sent[1][3] == "RAID", "one role announcement")
fire("RAID_ROSTER_UPDATE")
tick(3)
assert(#sent == 1, "rate limited")
tick(HM.ANNOUNCE_GAP)
assert(#sent == 2)
HM.OnMessage("FUI_MANA", "1:R:90:D", "RAID", "Newbie")
assert(HM.peers.Newbie and HM.peers.Newbie.role == "DAMAGER", "roles are learned from announcements")
tick(HM.ANNOUNCE_GAP + 3)
assert(#sent == 3, "a newcomer is answered")

---------------------------------------------------------------------------------------------------
-- Banner animation: fade in, hold, fade out, hidden; test button; Edit Mode
---------------------------------------------------------------------------------------------------
local b = HM.banner
b:Hide()
settings.hmDuration, settings.hmFontSize = 2, 18
HM.Test()
assert(b.shown and b.alpha == 0 and HM.last.source == "test", "starts transparent")
tick(0.125)
assert(math.abs(b.alpha - 0.5) < 1e-6, "fading in")
tick(1)
assert(b.alpha == 1, "held")
tick(1.5)
assert(b.alpha < 1 and b.alpha > 0 and b.shown, "fading out")
tick(1)
assert(not b.shown and b.alpha == 1 and not b.scripts.OnUpdate, "hidden after the animation, OnUpdate removed")
ForeverStockUIEditMode.scripts.OnShow(ForeverStockUIEditMode)
assert(b.shown and b.alpha == 1 and not b.scripts.OnUpdate, "visible sample in Edit Mode")
HM.Show("X", 10, "PRIEST")
assert(not b.scripts.OnUpdate, "alerts do not fade the sample away")
ForeverStockUIEditMode.scripts.OnHide(ForeverStockUIEditMode)
assert(not b.shown)

---------------------------------------------------------------------------------------------------
-- Drink recognition
---------------------------------------------------------------------------------------------------
setUnit("party1", { name = "D", class = "MAGE", buffs = { { name = "Arcane Intellect" }, { name = "Питье" } } })
assert(Suite.DrinkAura("party1") == "Питье", "Russian name")
units.party1.buffs = { { name = "Drink" } }
assert(Suite.DrinkAura("party1"), "English name")
units.party1.buffs = { { name = "Потребление пищи и напитков" } }
assert(Suite.DrinkAura("party1"), "food and drink")
units.party1.buffs = { { name = "Food & Drink" } }
assert(Suite.DrinkAura("party1"))
units.party1.buffs = { { name = "Unbekannt", id = 27089 } }
assert(Suite.DrinkAura("party1"), "by spell id (conjured water)")
units.party1.buffs = { { name = "Unbekannt", id = 12345 } }
assert(not Suite.DrinkAura("party1"), "an unknown buff")
units.party1.buffs = { { name = "Food" } }
assert(not Suite.DrinkAura("party1"), "food alone is no drink")
assert(not Suite.DrinkAura("nobody"))

SlashCmdList.FOREVERUIMANA("")
print("HealerMana OK: packet, channel, role chain, hysteresis and cooldown, self exclusion, subgroup filter, "
    .. "message priority and dedupe, announcements, banner fade and Edit Mode, drink recognition")
