-- AutoQuest.lua: auto accept and turn in on a mocked quest giver. Run from the addon root (see INDEX.md).
local settings = {}
local printed, calls = {}, {}
local now = 100
local shift = false

local ui = { russian = true }
function ui.L(ru) return ru end
function ui.Settings() return settings end
function ui.Print(text) printed[#printed + 1] = text end
function ui.SafeCall(fn, ...) local ok, err = pcall(fn, ...) if not ok then error(err, 0) end end

local function call(name, ...) calls[#calls + 1] = { name, ... } end
local function last(name)
    for i = #calls, 1, -1 do if calls[i][1] == name then return calls[i] end end
end
local function count(name)
    local n = 0
    for _, c in ipairs(calls) do if c[1] == name then n = n + 1 end end
    return n
end
local function reset() calls, printed = {}, {} end
local function said(pattern)
    for _, line in ipairs(printed) do if line:find(pattern, 1, true) then return true end end
end

-- Frames ------------------------------------------------------------------------------------------
local frames = {}
local function region()
    local r = { shown = true, points = {} }
    function r:SetTexture(t) self.texture = t end
    function r:SetBlendMode() end function r:SetVertexColor() end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:SetAllPoints(to) self.all = to end
    function r:Show() self.shown = true end function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    return r
end
function CreateFrame(_, name)
    local f = region()
    f.name, f.scripts, f.events, f.level = name, {}, {}, 1
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(n, fn) self.scripts[n] = fn end
    function f:GetScript(n) return self.scripts[n] end
    function f:CreateTexture() return region() end
    function f:SetParent(p) self.parent = p end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end
    function f:EnableMouse() end
    function f:GetName() return self.name end
    function f:GetID() return self.id end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = CreateFrame("Frame")
SlashCmdList = {}

local function fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
local function tick(seconds)
    for _ = 1, math.ceil(seconds / 0.25) do
        now = now + 0.25
        for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.25) end end
    end
end

-- Client world ------------------------------------------------------------------------------------
local npc, gossip, greeting, questLog, panel, items
local function world()
    npc = { exists = true, guid = "0xF130000001", name = "Квестодатель" }
    gossip = { active = {}, available = {}, activeStride = 3 }
    greeting = { active = {}, available = {} }
    questLog = {}
    panel = { title = "", completable = true, money = 0, choices = {}, xp = 0, rewardMoney = 0 }
    items = {}
    shift = false
    reset()
end
world()

function GetTime() return now end
function date() return "12:00:00" end
function IsShiftKeyDown() return shift end
function UnitGUID(u) return u == "npc" and npc.exists and npc.guid or nil end
function UnitName(u) return u == "npc" and npc.exists and npc.name or nil end
function UnitExists(u) return u == "npc" and npc.exists end
function UnitIsUnit(a, b) return a == "npc" and b == "player" and npc.self or false end
function UnitIsPlayer(u) return u == "npc" and npc.player or false end

local function flatten(list, fields)
    local out = {}
    for _, q in ipairs(list) do for _, k in ipairs(fields) do out[#out + 1] = q[k] or false end end
    return unpack(out, 1, #out)
end
function GetNumGossipActiveQuests() return #gossip.active end
function GetNumGossipAvailableQuests() return #gossip.available end
function GetGossipActiveQuests()
    return flatten(gossip.active, gossip.activeStride == 4 and { "title", "level", "trivial", "complete" }
        or { "title", "level", "trivial" })
end
function GetGossipAvailableQuests()
    return flatten(gossip.available, { "title", "level", "trivial", "daily", "repeatable" })
end
function SelectGossipActiveQuest(i) call("SelectGossipActiveQuest", i, gossip.active[i].title) end
function SelectGossipAvailableQuest(i) call("SelectGossipAvailableQuest", i, gossip.available[i].title) end

function GetNumActiveQuests() return #greeting.active end
function GetActiveTitle(i) return greeting.active[i].title end
function IsActiveQuestTrivial(i) return greeting.active[i].trivial and 1 or nil end
function GetNumAvailableQuests() return #greeting.available end
function GetAvailableTitle(i) return greeting.available[i].title end
function GetAvailableQuestInfo(i)
    local q = greeting.available[i]
    return q.trivial and 1 or nil, q.daily and 1 or nil, q.repeatable and 1 or nil
end
function SelectActiveQuest(i) call("SelectActiveQuest", i) end
function SelectAvailableQuest(i) call("SelectAvailableQuest", i) end

-- Quest log with headers: `collapsed` hides the quests under a header from the visible entries.
local function visible()
    local list, hidden = {}, false
    for _, e in ipairs(questLog) do
        if e.header then hidden = e.collapsed list[#list + 1] = e
        elseif not hidden then list[#list + 1] = e end
    end
    return list
end
local selection = 0
function GetNumQuestLogEntries()
    local quests = 0
    for _, e in ipairs(questLog) do if not e.header then quests = quests + 1 end end
    return #visible(), quests
end
function GetQuestLogTitle(i)
    local e = visible()[i]
    if not e then return nil end
    if e.header then return e.title, 0, nil, 0, 1, e.collapsed and 1 or nil end
    return e.title, 70, nil, 0, nil, nil, e.complete, nil, e.id
end
function GetNumQuestLeaderBoards(i) local e = visible()[i] return e and e.goals or 0 end
function ExpandQuestHeader(i)
    call("ExpandQuestHeader", i)
    for _, e in ipairs(questLog) do if e.header then e.collapsed = false end end
end
function CollapseQuestHeader(i) call("CollapseQuestHeader", i) visible()[i].collapsed = true end
function GetQuestLogSelection() return selection end
function SelectQuestLogEntry(i) selection = i end

function GetTitleText() return panel.title end
function IsQuestCompletable() return panel.completable and 1 or nil end
function GetQuestMoneyToGet() return panel.money end
function GetNumQuestChoices() return #panel.choices end
function GetQuestItemLink(kind, i) return kind == "choice" and panel.choices[i] or nil end
function GetRewardXP() return panel.xp end
function GetRewardMoney() return panel.rewardMoney end
function GetCoinTextureString(m) return m .. "c" end
function GetItemInfo(link) local price = items[link] return link, link, 2, 70, 70, "", "", 1, "", "", price end
function AcceptQuest() call("AcceptQuest", panel.title) end
function CompleteQuest() call("CompleteQuest", panel.title) end
function GetQuestReward(i) call("GetQuestReward", i, panel.title) end
QuestIsDaily = function() return panel.daily and 1 or nil end
QuestGetAutoAccept = function() return panel.autoAccept and 1 or nil end

-- Reward buttons of the quest frame (QuestInfoItem1..10, as in the Nozdor frame dump).
for i = 1, 10 do
    local b = CreateFrame("Button", "QuestInfoItem" .. i)
    b.id, b.shown = i, false
    CreateFrame("Frame", "QuestInfoItem" .. i .. "IconTexture")
end
local function showChoices(n)
    for i = 1, 10 do
        local b = _G["QuestInfoItem" .. i]
        b.shown, b.type = i <= n, i <= n and "choice" or nil
    end
end
QuestFrameRewardPanel = CreateFrame("Frame", "QuestFrameRewardPanel")

-- Load ------------------------------------------------------------------------------------------
local source = assert(io.open("AutoQuest.lua", "rb")):read("*a")
for _, banned in ipairs({ "C_Timer", "SetShown%(", "C_GossipInfo", "C_QuestLog", "StaticPopup_" }) do
    assert(not source:find(banned), "AutoQuest.lua must not use " .. banned)
end
assert(not source:find("SelectGossipOption"), "gossip options are never clicked")
assert(loadfile("AutoQuest.lua"))("ForeverUI", ui)
fire("PLAYER_LOGIN")
local AQ = ui.AutoQuest
assert(AQ and SlashCmdList.FOREVERSTOCKQUEST, "module and /fuiquest are published")

-- Toc and schema defaults.
local toc = assert(io.open("ForeverUI.toc", "rb")):read("*a")
assert(toc:find("Merchant.lua\nAutoQuest.lua", 1, true), "AutoQuest.lua is in the toc")
assert(toc:find("Options\\Quests.lua", 1, true), "the schema is in the toc")
local schema
ui.RegisterOptions = function(id, spec) schema = { id = id, spec = spec } end
assert(loadfile("Options/Quests.lua"))("ForeverUI", ui)
assert(schema.id == "quests")
local defaults = {}
for _, section in ipairs(schema.spec.sections) do
    for _, opt in ipairs(section.options) do defaults[opt[2]] = opt.default end
end
local expected = { questTrigger = "shift", questAutoAccept = true, questAutoTurnIn = true, questDaily = true, questTrivial = false,
    questRepeatable = false, questShared = true, questFromItems = true, questChat = true }
for key, value in pairs(expected) do
    assert(defaults[key] == value, "default of " .. key)
    settings[key] = value
end
-- Sections 1-11 run in the "always" mode (Shift cancels); the default Shift + click mode is section 12.
settings.questTrigger = "always"

-- Moves the visit on: the frame closes and enough time passes for the next talk to be a new visit.
local function leave() fire("GOSSIP_CLOSED") fire("QUEST_FINISHED") now = now + 5 end

-- 1. Full visit: turn in first, take the only reward, then the chain quest, then a new one; grey skipped.
questLog = { { header = true, title = "Зона" }, { title = "Волки", complete = 1, goals = 1 } }
gossip.active = { { title = "Волки", level = 70 } }
gossip.available = { { title = "Серое", level = 10, trivial = 1 }, { title = "Медведи", level = 70 } }
fire("GOSSIP_SHOW")
assert(last("SelectGossipActiveQuest")[3] == "Волки", "completed quest opened first")
assert(count("SelectGossipAvailableQuest") == 0, "one action per window")
panel.title = "Волки"
fire("QUEST_PROGRESS")
assert(last("CompleteQuest")[2] == "Волки", "progress continued")
panel.choices, items["[Плащ]"] = { "[Плащ]" }, 500
panel.xp, panel.rewardMoney = 1200, 300
fire("QUEST_COMPLETE")
local reward = last("GetQuestReward")
assert(reward[2] == 1 and reward[3] == "Волки", "a single reward is taken as choice 1")
assert(said("Сдано: Волки ([Плащ], 1200 опыта, 300c)"), "turn-in line in chat")
-- Chain: the next quest opens straight away.
fire("QUEST_FINISHED")
table.remove(questLog, 2)
panel = { title = "Волки II", completable = true, money = 0, choices = {}, xp = 0, rewardMoney = 0 }
fire("QUEST_DETAIL")
assert(last("AcceptQuest")[2] == "Волки II", "chain quest accepted")
assert(said("Принято: Волки II"), "accept line in chat")
table.insert(questLog, { title = "Волки II", goals = 2 })
fire("QUEST_FINISHED")
gossip.active = { { title = "Волки II", level = 70 } }
fire("GOSSIP_SHOW")
assert(count("SelectGossipActiveQuest") == 1, "an incomplete quest is not opened")
assert(last("SelectGossipAvailableQuest")[3] == "Медведи", "grey quest skipped, next new quest opened")
panel.title = "Медведи"
fire("QUEST_DETAIL")
assert(last("AcceptQuest")[2] == "Медведи")
-- The same list again in the same visit: nothing is opened twice.
fire("QUEST_FINISHED")
reset()
fire("GOSSIP_SHOW")
assert(count("SelectGossipAvailableQuest") == 0 and count("SelectGossipActiveQuest") == 0, "no repeats in one visit")
leave()

-- 2. Shift held: nothing at all for this visit, even after Shift is released.
world()
questLog = { { title = "Волки", complete = 1 } }
gossip.active = { { title = "Волки" } }
gossip.available = { { title = "Медведи" } }
shift = true
fire("GOSSIP_SHOW")
shift = false
panel.title = "Медведи"
fire("QUEST_DETAIL")
assert(#calls == 0, "Shift skips the visit")
leave()
fire("GOSSIP_SHOW")
assert(last("SelectGossipActiveQuest"), "next visit works again")
leave()

-- 3. Reward choice: nothing is taken, the most valuable choice is highlighted.
world()
questLog = { { title = "Выбор", complete = 1 } }
panel.title = "Выбор"
panel.choices = { "[Меч]", "[Щит]", "[Кольцо]" }
items["[Меч]"], items["[Щит]"], items["[Кольцо]"] = 100, 900, 400
showChoices(3)
fire("QUEST_COMPLETE")
assert(count("GetQuestReward") == 0, "a choice is never picked")
local glow = ForeverStockUIQuestRewardGlow
assert(glow and glow.shown and glow.parent == QuestInfoItem2, "most valuable choice highlighted")
assert(said("Самая дорогая у торговца: [Щит] (900c)"), "chat names the choice")
fire("QUEST_FINISHED")
assert(not glow.shown, "highlight hidden when the frame closes")
leave()
-- Item data arrives late: the highlight waits for it.
world()
questLog = { { title = "Выбор", complete = 1 } }
panel.title = "Выбор"
panel.choices = { "[Меч]", "[Щит]" }
items["[Меч]"] = 50
showChoices(2)
fire("QUEST_COMPLETE")
assert(not glow.shown, "waits for missing item data")
items["[Щит]"] = 70
tick(0.5)
assert(glow.shown and glow.parent == QuestInfoItem2, "highlight after the data arrives")
-- Prices never arrive: after the wait the known prices decide.
fire("QUEST_FINISHED")
leave()
world()
questLog = { { title = "Выбор", complete = 1 } }
panel.title = "Выбор"
panel.choices = { "[Меч]", "[Новое]" }
items["[Меч]"] = 50
showChoices(2)
fire("QUEST_COMPLETE")
tick(3.5)
assert(glow.shown and glow.parent == QuestInfoItem1, "known prices decide after the wait")
fire("QUEST_FINISHED")
leave()

-- 4. Money, repeatable hand-ins, incomplete progress.
world()
questLog = { { title = "Плата", complete = 1 } }
panel.title, panel.money = "Плата", 1000
fire("QUEST_PROGRESS")
assert(count("CompleteQuest") == 0 and said("требует золото"), "quests asking for money are left to the player")
leave()
world()
panel.title = "Ткань"   -- not in the log: repeatable hand-in
fire("QUEST_PROGRESS")
assert(count("CompleteQuest") == 0, "repeatable hand-ins off: not continued")
leave()
world()
panel.title = "Ткань"   -- a hand-in that opens straight on the reward panel
fire("QUEST_COMPLETE")
assert(count("GetQuestReward") == 0, "repeatable hand-ins off: reward not taken")
leave()
world()
settings.questRepeatable = true
panel.title = "Ткань"
fire("QUEST_PROGRESS")
assert(count("CompleteQuest") == 1, "repeatable hand-ins on")
fire("QUEST_COMPLETE")
assert(count("GetQuestReward") == 1)
settings.questRepeatable = false
leave()
-- The player continued a repeatable hand-in by hand: the reward is still taken.
world()
panel.title = "Ткань"
fire("QUEST_PROGRESS")
assert(count("CompleteQuest") == 0)
fire("QUEST_COMPLETE")
assert(count("GetQuestReward") == 1, "reward after a manual continue")
leave()
world()
questLog = { { title = "Волки", goals = 1 } }
panel.title, panel.completable = "Волки", false
fire("QUEST_PROGRESS")
assert(count("CompleteQuest") == 0, "incomplete quest not continued")
leave()

-- 5. Gossip filters: daily on, repeatable off, daily off; full log.
world()
gossip.available = { { title = "Повтор", repeatable = 1 }, { title = "Ежедневное", daily = 1, repeatable = 1 } }
fire("GOSSIP_SHOW")
assert(last("SelectGossipAvailableQuest")[3] == "Ежедневное", "daily taken, repeatable skipped")
leave()
world()
settings.questDaily = false
gossip.available = { { title = "Ежедневное", daily = 1 } }
fire("GOSSIP_SHOW")
panel.title, panel.daily = "Ежедневное", true
fire("QUEST_DETAIL")
assert(#calls == 0, "dailies off")
settings.questDaily = true
leave()
world()
for i = 1, 25 do questLog[i] = { title = "Q" .. i, goals = 1 } end
gossip.available = { { title = "Ещё" } }
fire("GOSSIP_SHOW")
fire("GOSSIP_SHOW")
assert(count("SelectGossipAvailableQuest") == 0, "full log: nothing opened")
local fullLines = 0
for _, line in ipairs(printed) do if line:find("Журнал заданий полон", 1, true) then fullLines = fullLines + 1 end end
assert(fullLines == 1, "full log reported once per visit")
panel.title = "Ещё"
fire("QUEST_DETAIL")
assert(count("AcceptQuest") == 0, "full log: not accepted")
leave()
-- A full log does not stop turn-ins.
gossip.active = { { title = "Q1" } }
questLog[1].complete = 1
fire("GOSSIP_SHOW")
assert(last("SelectGossipActiveQuest"), "turn-in with a full log")
leave()

-- 6. Client with an isComplete flag on active quests (stride 4).
world()
gossip.activeStride = 4
questLog = { { title = "A", goals = 1 }, { title = "B", goals = 1 } }
gossip.active = { { title = "A", complete = false }, { title = "B", complete = 1 } }
fire("GOSSIP_SHOW")
assert(last("SelectGossipActiveQuest")[3] == "B", "client isComplete flag is used")
leave()

-- 7. Quest log: collapsed header, no-objective quests, failed quests; the header is collapsed back.
world()
questLog = { { header = true, title = "Север", collapsed = true }, { title = "Письмо", goals = 0 },
    { title = "Провал", complete = -1, goals = 1 } }
local quests = AQ.QuestLog()
assert(quests["Письмо"] and quests["Письмо"].complete, "quest under a collapsed header, no objectives = complete")
assert(quests["Провал"] and not quests["Провал"].complete, "failed quest is not complete")
assert(questLog[1].collapsed == true and last("CollapseQuestHeader"), "header collapsed back")
leave()

-- 8. Old-style greeting window.
world()
questLog = { { title = "Старое", complete = 1 } }
greeting.active = { { title = "Старое" } }
greeting.available = { { title = "Серое", trivial = true }, { title = "Новое" } }
fire("QUEST_GREETING")
assert(last("SelectActiveQuest")[2] == 1, "greeting: turn in")
fire("QUEST_FINISHED")
greeting.active = {}
fire("QUEST_GREETING")
assert(last("SelectAvailableQuest")[2] == 2, "greeting: grey skipped")
leave()

-- 9. Quest sources: item and shared quests by their switches; server auto accept.
world()
npc.exists = false
panel.title = "С предмета"
fire("QUEST_DETAIL")
assert(count("AcceptQuest") == 1, "item quest accepted")
leave()
world()
settings.questFromItems = false
npc.exists = false
panel.title = "С предмета"
fire("QUEST_DETAIL")
assert(count("AcceptQuest") == 0, "item quests off")
settings.questFromItems = true
leave()
world()
settings.questShared = false
npc.player, npc.guid = true, "0x0000000000000042"
panel.title = "Эскорт"
fire("QUEST_DETAIL")
assert(count("AcceptQuest") == 0, "shared quests off")
settings.questShared = true
reset()
fire("QUEST_FINISHED")
now = now + 5
fire("QUEST_DETAIL")
assert(count("AcceptQuest") == 1, "shared quest accepted")
leave()
world()
panel.title, panel.autoAccept = "Авто", true
fire("QUEST_DETAIL")
assert(count("AcceptQuest") == 0, "server auto accept is not accepted twice")
leave()

-- 10. Switches off; chat off.
world()
settings.questAutoAccept, settings.questAutoTurnIn = false, false
questLog = { { title = "Волки", complete = 1 } }
gossip.active, gossip.available = { { title = "Волки" } }, { { title = "Медведи" } }
fire("GOSSIP_SHOW")
panel.title = "Волки"
fire("QUEST_DETAIL") fire("QUEST_PROGRESS") fire("QUEST_COMPLETE")
assert(#calls == 0, "both switches off: nothing")
settings.questAutoAccept, settings.questAutoTurnIn = true, true
leave()
world()
settings.questChat = false
panel.title = "Тихо"
fire("QUEST_DETAIL")
assert(count("AcceptQuest") == 1 and #printed == 0, "chat lines off")
settings.questChat = true
leave()

-- 11. /fuiquest.
world()
questLog = { { title = "Волки", complete = 1 } }
gossip.active, gossip.available = { { title = "Волки" } }, { { title = "Серое", trivial = 1 } }
SlashCmdList.FOREVERSTOCKQUEST("")
assert(said("? Волки") and said("! Серое") and said("grey"), "/fuiquest lists the giver's quests")
SlashCmdList.FOREVERSTOCKQUEST("clear")
assert(#AQ.Log == 0, "/fuiquest clear")

-- 12. Default mode: only a talk started with Shift (Shift + click on the NPC) runs.
settings.questTrigger = "shift"
local function giver()
    world()
    questLog = { { title = "Волки", complete = 1 } }
    gossip.active = { { title = "Волки" } }
    gossip.available = { { title = "Медведи" } }
end
giver()
fire("GOSSIP_SHOW")
panel.title = "Медведи"
fire("QUEST_DETAIL")
panel.title = "Волки"
fire("QUEST_PROGRESS") fire("QUEST_COMPLETE")
assert(#calls == 0, "plain click: nothing")
leave()
-- Shift held when the window opens: the whole talk runs, also after Shift is released.
giver()
shift = true
fire("GOSSIP_SHOW")
assert(last("SelectGossipActiveQuest"), "Shift + click: turn in")
shift = false
panel.title = "Волки"
fire("QUEST_PROGRESS") fire("QUEST_COMPLETE")
assert(count("CompleteQuest") == 1 and count("GetQuestReward") == 1, "the talk goes on after Shift is released")
fire("QUEST_FINISHED")
gossip.active = {}
fire("GOSSIP_SHOW")
panel.title = "Медведи"
fire("QUEST_DETAIL")
assert(count("AcceptQuest") == 1, "Shift + click: new quest accepted in the same talk")
leave()
-- Shift released just before the window opened (ping): still counts.
giver()
fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
now = now + 0.4
fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
now = now + 0.8
fire("GOSSIP_SHOW")
assert(last("SelectGossipActiveQuest"), "Shift released 0.8 s before the window counts")
leave()
-- An old Shift press does not.
giver()
fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
now = now + 3
fire("GOSSIP_SHOW")
assert(#calls == 0, "Shift 3 s before the window does not count")
-- Shift pressed while the window is open: the talk starts on the next window of the same NPC.
shift = true
fire("QUEST_FINISHED")
fire("GOSSIP_SHOW")
assert(last("SelectGossipActiveQuest"), "Shift during the talk turns it on")
shift = false
leave()
-- A new talk after the gap is plain again.
giver()
fire("GOSSIP_SHOW")
assert(#calls == 0, "next plain talk: nothing")
leave()
-- Other modifiers are ignored.
giver()
fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
fire("GOSSIP_SHOW")
assert(#calls == 0, "Ctrl does not start a talk")
leave()

print("AutoQuest OK: Shift + click mode (grace, mid-talk, other keys), visit order, chains, Shift, reward highlight (late data), money, repeatable hand-ins, filters, full log, stride 4, collapsed log, greeting, sources, switches, /fuiquest")
