-- Roll buttons differ between clients, so look them up by field, by global name and finally by button art.
local buttonHints = {
    needButton = { names = { "RollButton", "NeedButton" }, art = "dice" },
    greedButton = { names = { "GreedButton" }, art = "coin" },
    disenchantButton = { names = { "DisenchantButton" }, art = "%-de%-" },
    passButton = { names = { "PassButton" }, art = "pass" },
}
local function findRollButton(frame, key)
    if frame[key] then return frame[key] end
    local hint = buttonHints[key]
    local name = frame:GetName()
    if name then
        for _, suffix in ipairs(hint.names) do
            if _G[name .. suffix] then return _G[name .. suffix] end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        local texture = child.GetNormalTexture and child:GetNormalTexture()
        local path = texture and texture:GetTexture()
        if type(path) == "string" and path:lower():find(hint.art) then return child end
    end
end

local history = LootHistory
if not (history and history.RegisterListener and history.GetEntryByRollID and history.Model) then
    -- WotLK client: there is no loot history, so count the group's choices from the roll chat messages.
    local STATE_NEED, STATE_GREED, STATE_DE, STATE_PASS = 1, 2, 3, 4
    local slots = {
        { state = STATE_NEED, key = "needButton", names = { "RollButton", "NeedButton" } },
        { state = STATE_GREED, key = "greedButton", names = { "GreedButton" } },
        { state = STATE_DE, key = "disenchantButton", names = { "DisenchantButton" } },
        { state = STATE_PASS, key = "passButton", names = { "PassButton" } },
    }
    -- Chat format strings (global names) and which state each one means. Self messages carry no player name.
    local sources = {
        { "LOOT_ROLL_NEED", STATE_NEED }, { "LOOT_ROLL_NEED_SELF", STATE_NEED, true },
        { "LOOT_ROLL_GREED", STATE_GREED }, { "LOOT_ROLL_GREED_SELF", STATE_GREED, true },
        { "LOOT_ROLL_DISENCHANT", STATE_DE }, { "LOOT_ROLL_DISENCHANT_SELF", STATE_DE, true },
        { "LOOT_ROLL_PASSED", STATE_PASS }, { "LOOT_ROLL_PASSED_SELF", STATE_PASS, true },
        { "LOOT_ROLL_PASSED_AUTO", STATE_PASS }, { "LOOT_ROLL_PASSED_AUTO_FEMALE", STATE_PASS },
        { "LOOT_ROLL_PASSED_SELF_AUTO", STATE_PASS, true },
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
            compiled[#compiled + 1] = { pattern = pattern, order = order, state = source[2], self = source[3] }
        end
    end

    local function itemKey(link)
        return link and tonumber(link:match("item:(%d+)"))
    end

    local tallies = {} -- itemID -> { players = { name = state }, order = { name, ... } }

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
                    tally.players[player] = entry.state
                    return true
                end
            end
        end
    end

    local rolls = {}
    local unmatched
    local function findButton(frame, slot)
        return findRollButton(frame, slot.key)
    end

    local function tallyFor(frame)
        local rollID = frame.rollID
        return rollID and tallies[itemKey(GetLootRollItemLink(rollID)) or 0]
    end

    local function refreshAll()
        for _, roll in ipairs(rolls) do
            if roll.frame:IsShown() then
                local tally = tallyFor(roll.frame)
                local totals = {}
                if tally then
                    for _, state in pairs(tally.players) do totals[state] = (totals[state] or 0) + 1 end
                end
                local active = roll.frame.rollID ~= nil
                for state, label in pairs(roll.labels) do
                    label:SetText(active and (totals[state] or 0) or "")
                end
            end
        end
    end

    for index = 1, NUM_GROUP_LOOT_FRAMES or 0 do
        local frame = _G["GroupLootFrame" .. index]
        if frame then
            local roll = { frame = frame, labels = {} }
            -- Keep counts legible when the stock client dims a disabled button.
            local overlay = CreateFrame("Frame", nil, frame)
            overlay:SetAllPoints(frame)
            overlay:EnableMouse(false)
            overlay:SetFrameLevel(frame:GetFrameLevel() + 2)
            for _, slot in ipairs(slots) do
                local button = findButton(frame, slot)
                if button then
                    local label = overlay:CreateFontString(nil, "OVERLAY")
                    label:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
                    label:SetTextColor(1, 0.89, 0.63)
                    label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
                    roll.labels[slot.state] = label
                    button:HookScript("OnEnter", function(self)
                        local tally = tallyFor(frame)
                        if not tally or not GameTooltip:IsOwned(self) then return end
                        local any
                        for _, name in ipairs(tally.order) do
                            if tally.players[name] == slot.state then
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

    -- /fuiroll prints what the roll counter sees, to help when the digits do not appear.
    SLASH_FUIROLL1 = "/fuiroll"
    SlashCmdList["FUIROLL"] = function()
        local function say(text) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100ForeverUI rolls:|r " .. text) end
        say("mode = chat messages, patterns = " .. #compiled .. ", frames = " .. (NUM_GROUP_LOOT_FRAMES or 0))
        for index, roll in ipairs(rolls) do
            local found = 0
            for _ in pairs(roll.labels) do found = found + 1 end
            say(("frame %d: rollID=%s, shown=%s, buttons found=%d"):format(index, tostring(roll.frame.rollID),
                tostring(roll.frame:IsShown()), found))
        end
        say("last unmatched loot message: " .. tostring(unmatched))
    end
    return
end

local states = {
    needButton = LH_STATE_NEED,
    greedButton = LH_STATE_GREED,
    disenchantButton = LH_STATE_DISENCHANT,
    passButton = LH_STATE_PASS,
}
local visible, claimed = {}, {}

local function findHistoryID(rollID)
    local link = GetLootRollItemLink(rollID)
    local itemID = link and tonumber(link:match("item:(%d+)"))
    if not itemID then return end
    local suffix = tonumber((select(8, strsplit(":", link)))) or 0
    local _, _, count = GetLootRollItemInfo(rollID)
    local player = UnitName("player")
    local order = history.Model.order

    -- Match active rolls in start order when the client and history use different IDs.
    local oldest
    for index = #order, 1, -1 do
        local id = order[index]
        local entry = history.GetEntryByRollID(id)
        if entry and not claimed[id] and not entry.done and entry.players[player]
            and entry.itemID == itemID and entry.randProp == suffix and entry.count == count then
            if id == rollID then return id end
            oldest = oldest or id
        end
    end
    return oldest
end

local function refresh()
    for id in pairs(claimed) do
        local entry = history.GetEntryByRollID(id)
        if not entry or entry.done then claimed[id] = nil end
    end

    for _, roll in ipairs(visible) do
        if not roll.historyID then
            roll.historyID = findHistoryID(roll.frame.rollID)
            if roll.historyID then claimed[roll.historyID] = true end
        end
        local entry = roll.historyID and history.GetEntryByRollID(roll.historyID)
        local totals = {}
        if entry then
            for _, player in pairs(entry.players) do
                totals[player.state] = (totals[player.state] or 0) + 1
            end
        end
        for state, label in pairs(roll.labels) do
            label:SetText(entry and (totals[state] or 0) or "")
        end
    end
end

for index = 1, NUM_GROUP_LOOT_FRAMES or 0 do
    local frame = _G["GroupLootFrame" .. index]
    local roll = { frame = frame, labels = {} }
    -- Keep counts legible when the stock client dims a disabled button.
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:EnableMouse(false)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 2)

    for key, state in pairs(states) do
        local button = findRollButton(frame, key)
        if button then
        local label = overlay:CreateFontString(nil, "OVERLAY")
        label:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        label:SetTextColor(1, 0.89, 0.63)
        label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        roll.labels[state] = label
        button:HookScript("OnEnter", function(self)
            local entry = roll.historyID and history.GetEntryByRollID(roll.historyID)
            if not entry or not GameTooltip:IsOwned(self) then return end
            local any
            for _, name in ipairs(entry.playerOrder) do
                if entry.players[name].state == state then
                    if not any then GameTooltip:AddLine(" ") end
                    GameTooltip:AddLine(name, 1, 0.89, 0.63)
                    any = true
                end
            end
            if any then GameTooltip:Show() end
        end)
        end
    end

    local function onShow(self)
        if roll.active or not self:IsShown() then return end
        roll.active = true
        visible[#visible + 1] = roll
        refresh()
    end
    frame:HookScript("OnShow", onShow)
    frame:HookScript("OnHide", function(self)
        if self:IsShown() then return end
        for i, active in ipairs(visible) do
            if active == roll then
                table.remove(visible, i)
                break
            end
        end
        roll.active, roll.historyID = nil, nil
    end)
    onShow(frame)
end

history.RegisterListener(refresh)
