-- Mock check for LootRolls.lua (WotLK branch): rollID set after Show must still get digits.
local frames = {}
local strings = {}
local function newFrame(name, parent)
    local f = { scripts = {}, shown = false, level = parent and (parent.level + 1) or 1, children = {} }
    function f:GetName() return name end
    function f:HookScript(event, fn)
        local old = self.scripts[event]
        self.scripts[event] = old and function(...) old(...); fn(...) end or fn
    end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:RegisterEvent() end
    function f:Fire(event, ...) if self.scripts[event] then self.scripts[event](self, ...) end end
    function f:Show() self.shown = true; self:Fire("OnShow") end
    function f:Hide() self.shown = false; self:Fire("OnHide") end
    function f:IsShown() return self.shown end
    function f:SetAllPoints() end
    function f:EnableMouse() end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetChildren() return unpack(self.children) end
    function f:CreateFontString()
        local s = { text = nil }
        strings[#strings + 1] = s
        function s:SetFont() end
        function s:SetTextColor() end
        function s:SetPoint(_, rel) self.anchor = rel end
        function s:SetText(t) self.text = t end
        return s
    end
    if parent then parent.children[#parent.children + 1] = f end
    if name then _G[name] = f end
    frames[#frames + 1] = f
    return f
end
function CreateFrame(_, name, parent) return newFrame(name, parent) end
NUM_GROUP_LOOT_FRAMES = 2
STANDARD_TEXT_FONT = "font"
LOOT_ROLL_GREED = "%s выбирает \"Не откажусь\" для: %s"
LOOT_ROLL_PASSED = "%s отказывается от: %s"
GameTooltip = { IsOwned = function() return false end }
UnitName = function() return "Me" end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
strsplit = function(sep, text)
    local out = {}
    for part in (text .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = part end
    return unpack(out)
end
GetLootRollItemInfo = function() return "icon", "name", 1 end
local links = { [7] = "|cff1eff00|Hitem:111:0|h[Цепь]|h|r", [8] = "|cff1eff00|Hitem:222:0|h[Арбалет]|h|r" }
GetLootRollItemLink = function(id) return links[id] end

local lootFrames = {}
for i = 1, 3 do
    local f = newFrame("GroupLootFrame" .. i)
    lootFrames[i] = f
    for _, suffix in ipairs({ "RollButton", "GreedButton", "DisenchantButton", "PassButton" }) do
        newFrame("GroupLootFrame" .. i .. suffix, f)
    end
end

assert(loadfile(arg and arg[1] or "LootRolls.lua"))()
local watcher
for _, f in ipairs(frames) do if f.scripts.OnEvent then watcher = f end end

-- Client: Show first, rollID after (the case from the screenshot).
watcher:Fire("OnEvent", "START_LOOT_ROLL", 7)
lootFrames[1]:Show(); lootFrames[1].rollID = 7
watcher:Fire("OnEvent", "START_LOOT_ROLL", 8)
lootFrames[2]:Show(); lootFrames[2].rollID = 8
local function texts(i) local t = {} for k = 1, 4 do t[k] = tostring(strings[(i - 1) * 4 + k].text) end return table.concat(t, ',') end
assert(texts(2) == ',,,', 'mock reproduces the late rollID')
for _, f in ipairs(lootFrames) do f:Fire("OnUpdate", 0.01) end
assert(texts(1) == '0,0,0,0' and texts(2) == '0,0,0,0', 'digits after rollID set late')

SlashCmdList.FUIROLL()
watcher:Fire("OnEvent", "CHAT_MSG_LOOT", "Bob отказывается от: " .. links[8])
watcher:Fire("OnEvent", "CHAT_MSG_LOOT", "Ann выбирает \"Не откажусь\" для: " .. links[8])
SlashCmdList.FUIROLL()
-- client raises buttons above our overlay
_G.GroupLootFrame2PassButton:SetFrameLevel(50)
lootFrames[2]:Fire("OnUpdate", 0.01)
watcher:Fire("OnEvent", "CHAT_MSG_LOOT", "Cid отказывается от: " .. links[8])
SlashCmdList.FUIROLL()
assert(texts(2) == "0,1,0,2", texts(2))
assert(lootFrames[2].children[5]:GetFrameLevel() > 50, "overlay above raised buttons")

-- Nozdor client: LootHistory exists. Green items with a random suffix ("со знаком медведя") must still
-- find their history entry, even when the history keeps the suffix with the other sign.
frames, strings = {}, {}
for k = 1, 2 do _G["GroupLootFrame" .. k] = nil end
LH_STATE_NEED, LH_STATE_GREED, LH_STATE_DISENCHANT, LH_STATE_PASS = 1, 2, 3, 4
local entries = {}
local listeners = {}
LootHistory = {
    Model = { order = {} },
    GetEntryByRollID = function(id) return entries[id] end,
    RegisterListener = function(fn) listeners[#listeners + 1] = fn end,
}
local function addEntry(id, entry) entries[id] = entry; table.insert(LootHistory.Model.order, id) end
links = {
    [21] = "|cff1eff00|Hitem:333:0:0:0:0:0:-39:12345:80|h[Арбалет-самострел со знаком медведя]|h|r",
    [22] = "|cffa335ee|Hitem:444:0:0:0:0:0:0:0:80|h[Зловещее пламя]|h|r",
    [5] = "|cff1eff00|Hitem:36038:0:0:0:0:0:-38:777:80|h[Золотая цепь с застежками с меткой старца]|h|r",
}
NUM_GROUP_LOOT_FRAMES = 3
GetLootRollItemLink = function(id) return links[id] end
GetLootRollItemInfo = function() return "icon", "name", 1 end
lootFrames = {}
for i = 1, 3 do
    local f = newFrame("GroupLootFrame" .. i)
    lootFrames[i] = f
    for _, suffix in ipairs({ "RollButton", "GreedButton", "DisenchantButton", "PassButton" }) do
        newFrame("GroupLootFrame" .. i .. suffix, f)
    end
end
assert(loadfile(arg and arg[1] or "LootRolls.lua"))()
local function digit(button)
    for _, label in ipairs(strings) do
        if label.anchor == _G[button] then return label.text end
    end
end
-- history uses its own IDs (101, 102) and keeps the suffix as a positive number
addEntry(101, { itemID = 333, randProp = 39, count = 1, players = { Me = { state = 0 }, Bob = { state = 4 } } })
addEntry(102, { itemID = 444, randProp = 0, count = 1, players = { Me = { state = 0 }, Ann = { state = 1 } } })
lootFrames[1]:Show(); lootFrames[1].rollID = 21
lootFrames[2]:Show(); lootFrames[2].rollID = 22
for _, f in ipairs(lootFrames) do f:Fire("OnUpdate", 0.01) end
assert(digit("GroupLootFrame1PassButton") == 1, "suffix item finds its entry: " .. tostring(digit("GroupLootFrame1PassButton")))
assert(digit("GroupLootFrame1RollButton") == 0)
assert(digit("GroupLootFrame2RollButton") == 1, "plain item still counted")
entries[101].players.Cid = { state = 2 }
for _, fn in ipairs(listeners) do fn() end
assert(digit("GroupLootFrame1GreedButton") == 1, "listener refreshes")

-- The case from /fuiroll in game: rollID=5 item=36038 suffix=-38, no history entry at all -> chat count.
local watcher2
for _, f in ipairs(frames) do if f.scripts.OnEvent then watcher2 = f end end
watcher2:Fire("OnEvent", "START_LOOT_ROLL", 5)
lootFrames[3]:Show(); lootFrames[3].rollID = 5
lootFrames[3]:Fire("OnUpdate", 0.01)
assert(digit("GroupLootFrame3PassButton") == 0, "no history entry still shows zeros")
watcher2:Fire("OnEvent", "CHAT_MSG_LOOT", "Bob отказывается от: " .. links[5])
watcher2:Fire("OnEvent", "CHAT_MSG_LOOT", "Ann выбирает \"Не откажусь\" для: " .. links[5])
assert(digit("GroupLootFrame3PassButton") == 1 and digit("GroupLootFrame3GreedButton") == 1, "chat fallback counts")
-- history entry that appears later with real choices wins over the chat count
addEntry(103, { itemID = "36038", randProp = 38, count = 1, players = { Me = { state = 0 }, Zed = { state = 1 } } })
for _, fn in ipairs(listeners) do fn() end
assert(digit("GroupLootFrame3RollButton") == 1 and digit("GroupLootFrame3PassButton") == 0, "history entry (string id) wins")
assert(SlashCmdList.FUIROLL, "/fuiroll exists in the LootHistory branch")
SlashCmdList.FUIROLL()
print("ok")
