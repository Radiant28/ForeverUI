local history = LootHistory
if not (history and history.RegisterListener and history.GetEntryByRollID and history.Model) then return end

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
        local button = frame[key]
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
