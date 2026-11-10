local _, ui = ...
local groupName = ui.russian and "Группа/Рейд" or "Party/Raid"
local lootName = ui.russian and "Добыча" or "Loot"
local guildName = ui.russian and "Гильдия" or "Guild"
local windows = {
    { groupName, { SAY = true, PARTY = true, PARTY_LEADER = true, RAID = true, RAID_LEADER = true, RAID_WARNING = true },
        "chatGroupWindow" },
    { lootName, { LOOT = true }, "chatLootWindow" },
    { guildName, { GUILD = true }, "chatGuildWindow" },
}

local function enabled(key)
    local settings = ui.Settings()
    return settings.chatManage ~= false and (not key or settings[key] ~= false)
end

local function findWindow(name)
    local available
    for id = 2, NUM_CHAT_WINDOWS do
        local title, _, _, _, _, _, shown = GetChatWindowInfo(id)
        local frame = _G["ChatFrame" .. id]
        if shown or frame.isDocked then
            if title == name then return frame end
        else
            available = true
        end
    end
    -- The stock open function reuses the last tab when all slots are occupied.
    if available then return FCF_OpenNewWindow(name) end
end

local function configureWindow(frame, groups)
    if next(frame.channelList) then ChatFrame_RemoveAllChannels(frame) end
    local current = {}
    for _, group in pairs(frame.messageTypeList) do
        if groups[group] then
            current[group] = true
        else
            ChatFrame_RemoveMessageGroup(frame, group)
        end
    end
    for group in pairs(groups) do
        if not current[group] then ChatFrame_AddMessageGroup(frame, group) end
    end
end

local rollPatterns = {}
for key, format in pairs(_G) do
    if type(key) == "string" and type(format) == "string"
        and key:match("^LOOT_ROLL_") and not key:match("^LOOT_ROLL_INELIGIBLE") then
        local pattern = format:gsub("|3%-%d%((.-)%)", "%1"):gsub("%%%d+%$([sd])", "%%%1")
        pattern = pattern:gsub("([%%%.%+%-%*%?%[%]%(%)%^%$])", "%%%1")
        pattern = pattern:gsub("%%%%s", ".-"):gsub("%%%%d", "%%d+")
        rollPatterns[#rollPatterns + 1] = "^" .. pattern .. "$"
    end
end

local groupFrame, lootFrame
ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_PARTY", function(frame)
    return enabled("chatGroupWindow") and frame == groupFrame and GetChatWindowInfo(frame:GetID()) == groupName
end)
ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", function(frame, _, message)
    if not enabled("chatLootRollsOnly") or not enabled("chatLootWindow") then return end
    if frame ~= lootFrame or GetChatWindowInfo(frame:GetID()) ~= lootName then return end
    message = message:gsub("|3%-%d%((.-)%)", "%1")
    for _, pattern in ipairs(rollPatterns) do
        if message:match(pattern) then return end
    end
    return true
end)

local events = CreateFrame("Frame")
local function configureAll()
    events:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        if not enabled() then return end
        local selected = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
        for _, window in ipairs(windows) do
            local name, groups, key = unpack(window)
            if enabled(key) then
                local frame = findWindow(name)
                if name == groupName then groupFrame = frame end
                if name == lootName then lootFrame = frame end
                if frame then configureWindow(frame, groups) end
            end
        end
        if selected and selected ~= FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) then
            FCF_SelectDockFrame(selected)
        end
    end)
end
ui.Chat = { Apply = configureAll }

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then self:RegisterEvent("UPDATE_CHAT_WINDOWS") end
    -- Chat settings can arrive from the server after login.
    configureAll()
end)
