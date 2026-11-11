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

-- Item icons in front of item links (port of ChatLootIcons). Registered after the
-- loot-tab filter above, so it only runs for messages that survive it.
local gsub, tostring, tonumber = string.gsub, tostring, tonumber
local GetItemIcon, GetItemInfo = GetItemIcon, GetItemInfo
local iconText = {}
local iconSize

local function itemIcon(link)
    local id = tonumber(link:match("|Hitem:(%d+)"))
    if not id then return end
    local key = id * 100 + iconSize
    local text = iconText[key]
    if text then return text end
    -- Both calls return nil for items the client has not cached yet; do not cache that.
    local texture = GetItemIcon(id) or select(10, GetItemInfo(id))
    if not texture then return end
    text = "|T" .. texture .. ":" .. iconSize .. "|t"
    iconText[key] = text
    return text
end

local function addIcon(position, link, message)
    -- Skip links that already follow an inline texture (another addon got there first).
    if position > 2 and message:sub(position - 2, position - 1) == "|t" then return end
    local icon = itemIcon(link)
    if icon then return icon .. link end
end

local function addLootIcons(_, _, message, ...)
    if type(message) ~= "string" then return end
    local settings = ui.Settings()
    if settings.chatLootIcons == false then return end
    iconSize = tonumber(settings.chatLootIconSize) or 15
    local result, count = gsub(message, "()(|c%x+|Hitem:.-|h|r)", function(position, link)
        return addIcon(position, link, message)
    end)
    if count > 0 and result ~= message then return false, result, ... end
end

for _, event in ipairs({ "LOOT", "CHANNEL", "SAY", "YELL", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER",
    "RAID_WARNING", "GUILD", "OFFICER", "BATTLEGROUND", "BATTLEGROUND_LEADER", "WHISPER", "WHISPER_INFORM",
    "SYSTEM" }) do
    ChatFrame_AddMessageEventFilter("CHAT_MSG_" .. event, addLootIcons)
end

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

-- Retail look of the input box (DragonUI chatmods.lua): the stock border textures go, a flat dark box 22 px high
-- sits 6 px under the chat frame. The stock textures, anchors and height are saved and restored for Classic.
local editParts = { "Left", "Mid", "Right" }
local editSaved = {}
local flatEdit = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = false, edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 },
}
local function applyEditLook()
    local retail = ui.Settings().barLayout == "retail" and ui.Settings().chatManage ~= false
    for id = 1, NUM_CHAT_WINDOWS do
        local frame, box = _G["ChatFrame" .. id], _G["ChatFrame" .. id .. "EditBox"]
        if frame and box then
            local saved = editSaved[id]
            if retail then
                if not saved then
                    saved = { textures = {}, focus = {}, points = {}, height = box:GetHeight() }
                    for _, part in ipairs(editParts) do
                        local tex, focus = _G["ChatFrame" .. id .. "EditBox" .. part], _G["ChatFrame" .. id .. "EditBoxFocus" .. part]
                        if tex then saved.textures[part] = tex:GetTexture() end
                        if focus then saved.focus[part] = { focus:GetTexture(), focus:GetHeight() } end
                    end
                    for i = 1, box:GetNumPoints() do saved.points[i] = { box:GetPoint(i) } end
                    editSaved[id] = saved
                end
                for _, part in ipairs(editParts) do
                    local tex, focus = _G["ChatFrame" .. id .. "EditBox" .. part], _G["ChatFrame" .. id .. "EditBoxFocus" .. part]
                    if tex then tex:SetTexture(0, 0, 0, 0) end
                    if focus then focus:SetTexture(0, 0, 0, 0) end
                end
                box:ClearAllPoints()
                box:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -3, -6)
                box:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 2, -6)
                box:SetHeight(22)
                box:SetBackdrop(flatEdit)
                box:SetBackdropColor(0.03, 0.03, 0.04, 0.8)
                box:SetBackdropBorderColor(0, 0, 0, 0)
            elseif saved then
                for _, part in ipairs(editParts) do
                    local tex, focus = _G["ChatFrame" .. id .. "EditBox" .. part], _G["ChatFrame" .. id .. "EditBoxFocus" .. part]
                    if tex and saved.textures[part] then tex:SetTexture(saved.textures[part]) end
                    if focus and saved.focus[part] then
                        focus:SetTexture(saved.focus[part][1])
                        focus:SetHeight(saved.focus[part][2])
                    end
                end
                box:SetBackdrop(nil)
                box:ClearAllPoints()
                for _, point in ipairs(saved.points) do box:SetPoint(unpack(point, 1, 5)) end
                box:SetHeight(saved.height)
                editSaved[id] = nil
            end
        end
    end
end

ui.Chat = { Apply = configureAll, ApplyLayout = applyEditLook }

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then self:RegisterEvent("UPDATE_CHAT_WINDOWS") end
    -- Chat settings can arrive from the server after login.
    configureAll()
    if event == "PLAYER_LOGIN" then applyEditLook() end
end)
