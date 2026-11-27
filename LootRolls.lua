-- Digits on the Need/Greed/Disenchant/Pass buttons of the group roll frames: how many players chose each.
-- Two sources: the Nozdor client's LootHistory (when it has an entry for the roll) and the roll chat
-- messages (CHAT_MSG_LOOT). The chat count always runs, because Nozdor's history has no entry for some
-- rolls (seen for green items with a random suffix, 2026-11-27).

-- Roll buttons differ between clients, so look them up by field, by global name and finally by button art.
local slots = {
    { key = "needButton", names = { "RollButton", "NeedButton" }, art = "dice" },
    { key = "greedButton", names = { "GreedButton" }, art = "coin" },
    { key = "disenchantButton", names = { "DisenchantButton" }, art = "%-de%-" },
    { key = "passButton", names = { "PassButton" }, art = "pass" },
}
local function findRollButton(frame, slot)
    if frame[slot.key] then return frame[slot.key] end
    local name = frame:GetName()
    if name then
        for _, suffix in ipairs(slot.names) do
            if _G[name .. suffix] then return _G[name .. suffix] end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        local texture = child.GetNormalTexture and child:GetNormalTexture()
        local path = texture and texture:GetTexture()
        if type(path) == "string" and path:lower():find(slot.art) then return child end
    end
end

local function itemKey(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function rollItem(rollID)
    local link = rollID and GetLootRollItemLink(rollID)
    local itemID = itemKey(link)
    if not itemID then return end
    local suffix = tonumber((select(8, strsplit(":", link)))) or 0
    local _, _, count = GetLootRollItemInfo(rollID)
    return itemID, suffix, count
end

---------------------------------------------------------------------------------------------------------
-- Chat messages: "%s selected Need for: %s" and friends.
local sources = {
    { "LOOT_ROLL_NEED", "needButton" }, { "LOOT_ROLL_NEED_SELF", "needButton", true },
    { "LOOT_ROLL_GREED", "greedButton" }, { "LOOT_ROLL_GREED_SELF", "greedButton", true },
    { "LOOT_ROLL_DISENCHANT", "disenchantButton" }, { "LOOT_ROLL_DISENCHANT_SELF", "disenchantButton", true },
    { "LOOT_ROLL_PASSED", "passButton" }, { "LOOT_ROLL_PASSED_SELF", "passButton", true },
    { "LOOT_ROLL_PASSED_AUTO", "passButton" }, { "LOOT_ROLL_PASSED_AUTO_FEMALE", "passButton" },
    { "LOOT_ROLL_PASSED_SELF_AUTO", "passButton", true },
}

-- Turn a chat format ("%s selected Need for: %s", also "%1$s") into a Lua pattern plus argument order.
local function compile(format)
    local pattern, order, position = "^", {}, 1
    while true do
        local first, last, index = format:find("%%(%d?)%$?s", position)
        if not first then break end
        pattern = pattern .. (format:sub(position, first - 1):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) .. "(.+)"
        order[#order + 1] = tonumber(index) or (#order + 1)
        position = last + 1
    end
    return pattern .. (format:sub(position):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) .. "$", order
end

local compiled = {}
for _, source in ipairs(sources) do
    local format = _G[source[1]]
    if type(format) == "string" then
        local pattern, order = compile(format)
        compiled[#compiled + 1] = { pattern = pattern, order = order, key = source[2], self = source[3] }
    end
end

local tallies = {} -- itemID -> { players = { name = slot key }, order = { name, ... } }
local unmatched

local function record(message)
    for _, entry in ipairs(compiled) do
        local c1, c2 = message:match(entry.pattern)
        if c1 then
            local args = { c1, c2 }
            local player, link
            if entry.self then
                player, link = UnitName("player"), args[entry.order[1] or 1]
            else
                player, link = args[entry.order[1] or 1], args[entry.order[2] or 2]
            end
            local id = itemKey(link)
            if id and player then
                local tally = tallies[id]
                if not tally then tally = { players = {}, order = {} }; tallies[id] = tally end
                if not tally.players[player] then tally.order[#tally.order + 1] = player end
                tally.players[player] = entry.key
                return true
            end
        end
    end
end

---------------------------------------------------------------------------------------------------------
-- LootHistory (Nozdor client).
local history = LootHistory
if not (history and history.RegisterListener and history.GetEntryByRollID and history.Model) then history = nil end
local historyKeys = {} -- LH_STATE_* -> slot key
if history then
    for state, key in pairs({ [LH_STATE_NEED or -1] = "needButton", [LH_STATE_GREED or -2] = "greedButton",
        [LH_STATE_DISENCHANT or -3] = "disenchantButton", [LH_STATE_PASS or -4] = "passButton" }) do
        historyKeys[state] = key
    end
end
local claimed = {}

-- Only the item ID must match; suffix (the history may keep it with the other sign), our own place in the
-- roll and the count only rank candidates.
local function historyScore(entry, itemID, suffix, count, player)
    if tonumber(entry.itemID) ~= itemID then return end
    local score = 0
    local randProp = tonumber(entry.randProp) or 0
    if math.abs(randProp) == math.abs(suffix) then score = score + 4 end
    if entry.players and entry.players[player] then score = score + 2 end
    if entry.count == count then score = score + 1 end
    return score
end

local function findHistoryID(rollID)
    local itemID, suffix, count = rollItem(rollID)
    if not itemID then return end
    local player = UnitName("player")
    local order = history.Model.order or {}
    local best, bestScore
    for index = #order, 1, -1 do
        local id = order[index]
        local entry = history.GetEntryByRollID(id)
        if entry and not claimed[id] and not entry.done then
            local score = historyScore(entry, itemID, suffix, count, player)
            if score then
                if id == rollID then return id end
                if not bestScore or score > bestScore then best, bestScore = id, score end
            end
        end
    end
    return best
end

---------------------------------------------------------------------------------------------------------
-- What one frame shows: { players = { name = slot key }, order = { name, ... } } and where it came from.
local rolls = {}

local function historyEntry(roll)
    if not history then return end
    if roll.historyID then
        local entry = history.GetEntryByRollID(roll.historyID)
        if entry and not entry.done then return entry end
        claimed[roll.historyID], roll.historyID = nil, nil
    end
    roll.historyID = findHistoryID(roll.frame.rollID)
    if roll.historyID then
        claimed[roll.historyID] = true
        return history.GetEntryByRollID(roll.historyID)
    end
end

local function votesFor(roll)
    local entry = historyEntry(roll)
    if entry and entry.players then
        local votes = { players = {}, order = {}, source = "history " .. tostring(roll.historyID) }
        local names = entry.playerOrder
        if type(names) ~= "table" or #names == 0 then
            names = {} -- never write into the client's own table
            for name in pairs(entry.players) do names[#names + 1] = name end
        end
        for _, name in ipairs(names) do
            local key = entry.players[name] and historyKeys[entry.players[name].state]
            if key then
                votes.players[name] = key
                votes.order[#votes.order + 1] = name
            end
        end
        -- A history entry that does not list the choices yet loses to the chat count.
        if #votes.order > 0 then return votes end
    end
    local tally = tallies[itemKey(roll.frame.rollID and GetLootRollItemLink(roll.frame.rollID)) or 0]
    if tally then
        return { players = tally.players, order = tally.order, source = "chat" }
    end
    return { players = {}, order = {}, source = entry and ("history " .. tostring(roll.historyID)) or "none" }
end

-- The client can raise the roll buttons after we built the overlay; keep the digits above them.
local function raiseOverlay(roll)
    local level = roll.frame:GetFrameLevel()
    for _, button in ipairs(roll.buttons) do
        level = math.max(level, button:GetFrameLevel())
    end
    if roll.overlay:GetFrameLevel() <= level then roll.overlay:SetFrameLevel(level + 1) end
end

local function refreshAll()
    for id in pairs(claimed) do
        local entry = history and history.GetEntryByRollID(id)
        if not entry or entry.done then claimed[id] = nil end
    end
    for _, roll in ipairs(rolls) do
        if roll.frame:IsShown() then
            raiseOverlay(roll)
            local votes = votesFor(roll)
            local totals = {}
            for _, key in pairs(votes.players) do totals[key] = (totals[key] or 0) + 1 end
            local active = roll.frame.rollID ~= nil
            for key, label in pairs(roll.labels) do
                label:SetText(active and (totals[key] or 0) or "")
            end
        end
    end
end

for index = 1, NUM_GROUP_LOOT_FRAMES or 0 do
    local frame = _G["GroupLootFrame" .. index]
    if frame then
        local roll = { frame = frame, labels = {}, buttons = {} }
        -- Keep counts legible when the stock client dims a disabled button.
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        overlay:EnableMouse(false)
        overlay:SetFrameLevel(frame:GetFrameLevel() + 2)
        roll.overlay = overlay
        for _, slot in ipairs(slots) do
            local button = findRollButton(frame, slot)
            if button then
                roll.buttons[#roll.buttons + 1] = button
                local label = overlay:CreateFontString(nil, "OVERLAY")
                label:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
                label:SetTextColor(1, 0.89, 0.63)
                label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
                roll.labels[slot.key] = label
                button:HookScript("OnEnter", function(self)
                    if not GameTooltip:IsOwned(self) then return end
                    local votes = votesFor(roll)
                    local any
                    for _, name in ipairs(votes.order) do
                        if votes.players[name] == slot.key then
                            if not any then GameTooltip:AddLine(" ") end
                            GameTooltip:AddLine(name, 1, 0.89, 0.63)
                            any = true
                        end
                    end
                    if any then GameTooltip:Show() end
                end)
            end
        end
        rolls[#rolls + 1] = roll
        frame:HookScript("OnShow", refreshAll)
        -- The client may set frame.rollID after Show, or reuse a frame that is already open, so OnShow alone
        -- misses the new roll. Watch the ID while the frame is open (OnUpdate runs only for shown frames).
        frame:HookScript("OnUpdate", function(self)
            if self.rollID ~= roll.seenID then
                roll.seenID = self.rollID
                if roll.historyID then claimed[roll.historyID] = nil end
                roll.historyID = nil
                refreshAll()
            end
        end)
        frame:HookScript("OnHide", function(self)
            if self:IsShown() then return end
            if roll.historyID then claimed[roll.historyID] = nil end
            roll.seenID, roll.historyID = nil, nil
        end)
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("START_LOOT_ROLL")
watcher:RegisterEvent("CHAT_MSG_LOOT")
watcher:SetScript("OnEvent", function(_, event, first)
    if event == "START_LOOT_ROLL" then
        -- A new roll for this item starts from zero (the same item can drop twice in a session).
        local id = itemKey(GetLootRollItemLink(first))
        if id then tallies[id] = nil end
        refreshAll()
    elseif type(first) == "string" then
        if record(first) then
            refreshAll()
        elseif first:find("|Hitem:", 1, true) then
            unmatched = first
        end
    end
end)
if history then history.RegisterListener(refreshAll) end

---------------------------------------------------------------------------------------------------------
-- /fuiroll prints what the roll counter sees, to help when the digits do not appear.
SLASH_FUIROLL1 = "/fuiroll"
SlashCmdList["FUIROLL"] = function()
    local function say(text) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100ForeverUI rolls:|r " .. text) end
    local order = history and history.Model.order or {}
    say(("history=%s, entries=%d, chat patterns=%d, frames=%d"):format(history and "yes" or "no", #order,
        #compiled, NUM_GROUP_LOOT_FRAMES or 0))
    for index, roll in ipairs(rolls) do
        if roll.frame:IsShown() then
            local itemID, suffix, count = rollItem(roll.frame.rollID)
            local votes = votesFor(roll)
            local top = 0
            for _, button in ipairs(roll.buttons) do top = math.max(top, button:GetFrameLevel()) end
            say(("frame %d: rollID=%s item=%s suffix=%s count=%s source=%s votes=%d buttons=%d digits %d/%d"):format(
                index, tostring(roll.frame.rollID), tostring(itemID), tostring(suffix), tostring(count),
                votes.source, #votes.order, #roll.buttons, roll.overlay:GetFrameLevel(), top))
        end
    end
    -- The newest history entries, whatever the item: shows how Nozdor keeps item IDs and suffixes.
    for index = #order, math.max(1, #order - 5), -1 do
        local id = order[index]
        local entry = history.GetEntryByRollID(id)
        if entry then
            local voters = 0
            for _ in pairs(entry.players or {}) do voters = voters + 1 end
            say(("  history %s: item=%s (%s) randProp=%s count=%s done=%s votes=%d claimed=%s"):format(tostring(id),
                tostring(entry.itemID), type(entry.itemID), tostring(entry.randProp), tostring(entry.count),
                tostring(entry.done), voters, tostring(claimed[id])))
        end
    end
    say("last unmatched loot message: " .. tostring(unmatched))
end
