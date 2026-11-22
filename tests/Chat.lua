-- Chat tabs on mocks (the real Chat.lua): the general window loses party, raid and loot, the channels come back
-- from the old Channels tab, the party/raid and loot tabs, the "rolls only" reset and the money fallback.
-- Run from the addon root (see INDEX.md for the lupa command).
-- The old account flag is set (another character merged before): this character must still merge.
local settings = { chatLootRollsOnly = true, chatChannelsMerged = true }
local ui = { Settings = function() return settings end, russian = true, Print = function() end }
local now = 0
function GetTime() return now end

local frames, scripts = {}, {}
function CreateFrame()
    local frame = { scripts = {} }
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:RegisterEvent() end
    frames[#frames + 1] = frame
    return frame
end
function ChatFrame_AddMessageEventFilter() end
SlashCmdList = {}

NUM_CHAT_WINDOWS = 7
local titles = { "Общий", "Журнал боя", "Каналы" }
local closed = {}
local function chatFrame(id, groups, channels)
    local frame = { id = id, messageTypeList = groups, channelList = channels, isDocked = titles[id] ~= nil, lines = {} }
    function frame:GetID() return self.id end
    function frame:AddMessage(text) self.lines[#self.lines + 1] = text end
    _G["ChatFrame" .. id] = frame
    return frame
end
local general = chatFrame(1, { "SAY", "WHISPER", "PARTY", "RAID", "RAID_WARNING", "LOOT", "MONEY", "SYSTEM", "GUILD" }, {})
chatFrame(2, { "COMBAT" }, {})
local channels = chatFrame(3, {}, { "Общий", "Торговля", "ПоискСпутников", "мой" })
chatFrame(4, {}, {})
chatFrame(5, {}, {})
chatFrame(6, {}, {})
chatFrame(7, {}, {})
function GetChatWindowInfo(id)
    local frame = _G["ChatFrame" .. id]
    return titles[id], 14, 1, 1, 1, 1, frame and frame.isDocked
end
function FCF_OpenNewWindow(name)
    for id = 2, NUM_CHAT_WINDOWS do
        if not titles[id] then
            titles[id] = name
            _G["ChatFrame" .. id].isDocked = true
            return _G["ChatFrame" .. id]
        end
    end
end
function FCF_Close(frame) closed[#closed + 1] = frame; frame.isDocked = false; titles[frame.id] = nil end
function FCFDock_GetSelectedWindow() return channels end
local selectedTo
function FCF_SelectDockFrame(frame) selectedTo = frame end
GENERAL_CHAT_DOCK = {}
local function remove(list, value)
    for i = #list, 1, -1 do if list[i] == value then table.remove(list, i) end end
end
function ChatFrame_RemoveMessageGroup(frame, group) remove(frame.messageTypeList, group) end
function ChatFrame_AddMessageGroup(frame, group) table.insert(frame.messageTypeList, group) end
function ChatFrame_RemoveAllChannels(frame) frame.channelList = {} end
local refused = {}
function ChatFrame_AddChannel(frame, name)
    if not refused[name] then table.insert(frame.channelList, name) end
end
function ChatFrame_RemoveChannel(frame, name) remove(frame.channelList, name) end
function hooksecurefunc(name, fn)
    local original = _G[name]
    _G[name] = function(...) original(...); fn(...) end
end
local player = "Zerotwo"
function UnitName() return player end
function GetRealmName() return "Dune" end
function EnumerateServerChannels() return "Общий", "Торговля", "ЗащитаЛокальная", "ПоискСпутников" end
local joined = { 1, "Общий", 2, "Торговля", 5, "мой" }
function GetChannelList() return unpack(joined) end
local wallet = 1000
function GetMoney() return wallet end
YOU_LOOT_MONEY = "Вы получаете добычу: %s."
ChatTypeInfo = { MONEY = { r = 1, g = 1, b = 0 } }

assert(loadfile("Chat.lua"))("ForeverUI", ui)
local events, money, keeper = frames[1], frames[2], frames[3]
local function update()
    events.scripts.OnEvent(events, "UPDATE_CHAT_WINDOWS")
    events.scripts.OnUpdate(events)
end
local function runKeeper(untilTime)
    while keeper.scripts.OnUpdate and now < untilTime do
        now = now + 0.5
        keeper.scripts.OnUpdate(keeper)
    end
end
local function has(list, value) for _, v in ipairs(list) do if v == value then return true end end end
local function count(list, value) local n = 0 for _, v in ipairs(list) do if v == value then n = n + 1 end end return n end

-- PLAYER_LOGIN → configure on the next frame
events.scripts.OnEvent(events, "PLAYER_LOGIN")
events.scripts.OnUpdate(events)

-- General: party, raid and loot go, the rest stays; every channel is back once, the Channels tab is closed.
for _, group in ipairs({ "PARTY", "RAID", "RAID_WARNING", "LOOT", "MONEY" }) do
    assert(not has(general.messageTypeList, group), "general without " .. group)
end
for _, group in ipairs({ "SAY", "WHISPER", "SYSTEM", "GUILD" }) do assert(has(general.messageTypeList, group), group) end
for _, name in ipairs({ "Общий", "Торговля", "ЗащитаЛокальная", "ПоискСпутников", "мой" }) do
    assert(count(general.channelList, name) == 1, "channel back once: " .. name)
end
assert(closed[1] == channels and #closed == 1, "Channels tab closed")
assert(settings.chatChannelChars["Zerotwo - Dune"].merged, "merge remembered per character")
assert(selectedTo ~= channels, "the closed tab is not selected again")

-- Party/Raid tab: whisper and battleground in, no channels; loot tab: loot and money.
local group, loot
for id = 2, NUM_CHAT_WINDOWS do
    if titles[id] == "Группа/Рейд" then group = _G["ChatFrame" .. id] end
    if titles[id] == "Добыча" then loot = _G["ChatFrame" .. id] end
end
assert(group and loot, "tabs opened")
for _, g in ipairs({ "WHISPER", "PARTY", "RAID", "BATTLEGROUND", "BATTLEGROUND_LEADER", "SAY" }) do
    assert(has(group.messageTypeList, g), "party/raid tab: " .. g)
end
assert(has(loot.messageTypeList, "LOOT") and has(loot.messageTypeList, "MONEY"), "loot tab")
assert(settings.chatLootRollsOnly == false and settings.chatLootRollsReset, "rolls only reset once")
settings.chatLootRollsOnly = true
events.scripts.OnEvent(events, "UPDATE_CHAT_WINDOWS")
events.scripts.OnUpdate(events)
assert(settings.chatLootRollsOnly == true, "the user's later choice stays")

-- A channel the user unticks in the general window is not forced back; the general window stays clean.
ChatFrame_RemoveChannel(general, "мой")
table.insert(general.messageTypeList, "PARTY")
update()
assert(not has(general.channelList, "мой"), "the user's removal stays")
assert(settings.chatChannelChars["Zerotwo - Dune"].removed["мой"], "removal remembered")
assert(not has(general.messageTypeList, "PARTY"), "general cleaned on every update")

-- The bug: after /reload or a loading screen the general window lists no channel (ZONECHANNELS 0) although the
-- character is still in them. The check after PLAYER_ENTERING_WORLD brings them back, not the removed one.
general.channelList = {}
keeper.scripts.OnEvent(keeper, "PLAYER_ENTERING_WORLD")
runKeeper(now + 3)
assert(has(general.channelList, "Общий") and has(general.channelList, "Торговля"), "channels back after loading")
assert(not has(general.channelList, "мой"), "removed channel stays out after loading")
runKeeper(now + 20)
assert(count(general.channelList, "Общий") == 1, "no doubles from the later checks")
assert(not keeper.scripts.OnUpdate, "keeper timer stopped")

-- A new channel the character joins (LFG after the queue) shows up in the general window.
joined[#joined + 1] = 6
joined[#joined + 1] = "Мир"
keeper.scripts.OnEvent(keeper, "CHANNEL_UI_UPDATE")
runKeeper(now + 1)
assert(has(general.channelList, "Мир"), "joined channel shown")

-- A channel another tab shows is left alone; a zone name with the zone part counts as the base name.
local guildTab
for id = 2, NUM_CHAT_WINDOWS do if titles[id] == "Гильдия" then guildTab = _G["ChatFrame" .. id] end end
remove(general.channelList, "Торговля")
table.insert(guildTab.channelList, "Торговля")
joined[2] = "Общий - Штормград"
keeper.scripts.OnEvent(keeper, "CHANNEL_UI_UPDATE")
runKeeper(now + 1)
assert(not has(general.channelList, "Торговля"), "shown by another tab")
assert(count(general.channelList, "Общий") == 1, "zone name matches the base name")
joined[2] = "Общий"
guildTab.channelList = {}

-- Ticked again by the user: kept again.
ChatFrame_AddChannel(general, "мой")
assert(not settings.chatChannelChars["Zerotwo - Dune"].removed["мой"], "tick clears the removal")

-- A channel the client refuses is tried once in 10 s, not on every update.
refused["Торговля"] = true
local before = #general.channelList
update()
update()
assert(#general.channelList == before and not has(general.channelList, "Торговля"), "refused channel")
local tries = 0
local add = ChatFrame_AddChannel
ChatFrame_AddChannel = function(...) tries = tries + 1; return add(...) end
update()
assert(tries == 0, "no retry within 10 s")
now = now + 11
update()
assert(tries == 1, "retry after 10 s")
ChatFrame_AddChannel = add
refused["Торговля"] = nil

-- Turned off: nothing comes back.
settings.chatKeepChannels = false
general.channelList = {}
now = now + 11
update()
assert(#general.channelList == 0, "keep channels off")
settings.chatKeepChannels = nil

-- Another character of the account with the old Channels tab already closed: merged once for it as well.
player = "Другой"
titles[6] = "Каналы"
_G.ChatFrame6.isDocked = false
_G.ChatFrame6.channelList = { "Старый" }
local closedBefore = #closed
update()
assert(settings.chatChannelChars["Другой - Dune"].merged, "second character merged")
for _, name in ipairs({ "Общий", "Торговля", "ЗащитаЛокальная", "ПоискСпутников", "мой", "Мир", "Старый" }) do
    assert(count(general.channelList, name) == 1, "second character channel: " .. name)
end
assert(#closed == closedBefore, "a closed Channels tab is not closed again")
titles[6] = nil
player = "Zerotwo"

-- Off: the general window is not touched.
settings.chatGeneralClean = false
table.insert(general.messageTypeList, "LOOT")
events.scripts.OnEvent(events, "UPDATE_CHAT_WINDOWS")
events.scripts.OnUpdate(events)
assert(has(general.messageTypeList, "LOOT"), "general clean off")

-- Money: looting alone (no CHAT_MSG_MONEY) writes to the loot tab.
local ev = money.scripts.OnEvent
ev(money, "PLAYER_ENTERING_WORLD")
ev(money, "LOOT_OPENED")
wallet = 1520
now = 10
ev(money, "PLAYER_MONEY")
now = 10.3
money.scripts.OnUpdate(money)
assert(#loot.lines == 0, "waits for the server message")
now = 11
money.scripts.OnUpdate(money)
assert(#loot.lines == 1 and loot.lines[1]:find("Вы получаете добычу: 5 с 20 м", 1, true), "fallback line")
assert(not money.scripts.OnUpdate, "timer stopped")

-- The server reports it (after the money changed): no second line.
wallet = 2520
now = 20
ev(money, "PLAYER_MONEY")
now = 20.1
ev(money, "CHAT_MSG_MONEY")
now = 21
if money.scripts.OnUpdate then money.scripts.OnUpdate(money) end
assert(#loot.lines == 1, "server message first wins")

-- The server reports it before the money changes: no line either.
now = 30
ev(money, "CHAT_MSG_MONEY")
wallet = 3000
now = 30.2
ev(money, "PLAYER_MONEY")
now = 31
if money.scripts.OnUpdate then money.scripts.OnUpdate(money) end
assert(#loot.lines == 1, "server message before the money")

-- Money outside looting (mail, vendor) is not loot.
ev(money, "LOOT_CLOSED")
now = 40
wallet = 9000
ev(money, "PLAYER_MONEY")
now = 41
if money.scripts.OnUpdate then money.scripts.OnUpdate(money) end
assert(#loot.lines == 1, "no loot window, no line")

-- Just after closing the loot window still counts; turned off it does not.
ev(money, "LOOT_OPENED")
ev(money, "LOOT_CLOSED")
now = 41.5
wallet = 9100
ev(money, "PLAYER_MONEY")
now = 42.5
money.scripts.OnUpdate(money)
assert(#loot.lines == 2 and loot.lines[2]:find("1 с", 1, true), "grace after close")
settings.chatLootMoney = false
ev(money, "LOOT_OPENED")
now = 50
wallet = 9200
ev(money, "PLAYER_MONEY")
now = 51
money.scripts.OnUpdate(money)
assert(#loot.lines == 2, "fallback off")

-- /fuichat runs
local printed = 0
ui.Print = function() printed = printed + 1 end
SlashCmdList.FOREVERUICHAT()
assert(printed >= 4, "report lines")
print("Chat OK: general window, channels back per character, kept after loading screens, party/raid and loot tabs, rolls only reset, money fallback, /fuichat")
