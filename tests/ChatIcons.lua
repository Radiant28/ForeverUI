-- Item icons in chat: run from the addon root (see INDEX.md for the lupa command).
local ui = { Settings = function() return {} end, russian = false }
local filters = {}
function ChatFrame_AddMessageEventFilter(event, fn) filters[event] = fn end
function GetChatWindowInfo() end
function CreateFrame() return { SetScript = function() end, RegisterEvent = function() end } end
NUM_CHAT_WINDOWS = 0
function GetItemIcon(id) if id == 1 then return "Interface\\Icons\\A" end end
function GetItemInfo(id) if id == 2 then return 1, 2, 3, 4, 5, 6, 7, 8, 9, "Interface\\Icons\\B" end end
assert(loadfile("Chat.lua"))("ForeverUI", ui)

local filter = filters.CHAT_MSG_LOOT
assert(filter and filters.CHAT_MSG_RAID and filters.CHAT_MSG_WHISPER)

local message = "You receive |cff1eff00|Hitem:1:0:0|h[A]|h|r and |cff1eff00|Hitem:2::|h[B]|h|r"
    .. " and |cff1eff00|Hitem:3::|h[C]|h|r."
local stop, result = filter(nil, "e", message)
assert(stop == false)
assert(result:find("|TInterface\\Icons\\A:15|t|cff1eff00|Hitem:1", 1, true), "GetItemIcon path")
assert(result:find("|TInterface\\Icons\\B:15|t|cff1eff00|Hitem:2", 1, true), "GetItemInfo fallback")
assert(result:find(" and |cff1eff00|Hitem:3", 1, true), "uncached item must stay untouched")

-- no double icon
assert(filter(nil, "e", "|TX:15|t|cff1eff00|Hitem:1:0:0|h[A]|h|r") == nil)
-- no links, non-string
assert(filter(nil, "e", "hello") == nil)
assert(filter(nil, "e", nil) == nil)
-- toggle and size
ui.Settings = function() return { chatLootIcons = false } end
assert(filter(nil, "e", message) == nil)
ui.Settings = function() return { chatLootIconSize = 20 } end
assert(select(2, filter(nil, "e", message)):find("A:20|t", 1, true))
print("ChatIcons OK")
