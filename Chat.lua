local _, ui = ...
local groupName = ui.russian and "Группа/Рейд" or "Party/Raid"
local lootName = ui.russian and "Добыча" or "Loot"
local guildName = ui.russian and "Гильдия" or "Guild"
-- The old setup wizard moved the server channels out of the general window into a tab of this name.
local channelsName = ui.russian and "Каналы" or "Channels"
local windows = {
    { groupName, { SAY = true, EMOTE = true, TEXT_EMOTE = true, YELL = true, WHISPER = true, PARTY = true,
        PARTY_LEADER = true, RAID = true, RAID_LEADER = true, RAID_WARNING = true, BATTLEGROUND = true,
        BATTLEGROUND_LEADER = true }, "chatGroupWindow" },
    { lootName, { LOOT = true, MONEY = true }, "chatLootWindow" },
    { guildName, { WHISPER = true, GUILD = true, GUILD_ACHIEVEMENT = true, OFFICER = true }, "chatGuildWindow" },
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

-- The general window keeps everything of its own and loses only what the party/raid and loot tabs show.
local generalDrop = { PARTY = true, PARTY_LEADER = true, RAID = true, RAID_LEADER = true, RAID_WARNING = true,
    BATTLEGROUND = true, BATTLEGROUND_LEADER = true, MONSTER_PARTY = true, LOOT = true, MONEY = true }

local function cleanGeneral(frame)
    local drop = {}
    for _, group in pairs(frame.messageTypeList or {}) do
        if generalDrop[group] then drop[#drop + 1] = group end
    end
    for _, group in ipairs(drop) do ChatFrame_RemoveMessageGroup(frame, group) end
end

-- Zone channels can come as "General - Zone"; the window lists them by the base name.
local function baseName(name)
    return name:match("^(.-) %- ") or name
end

local function hasChannel(frame, name)
    local base = baseName(name)
    for _, channel in pairs(frame.channelList or {}) do
        if type(channel) == "string" and (channel == name or baseName(channel) == base) then return true end
    end
end

-- Our own channel calls: the hooks below must not take them for the user's choice.
local busy
local function addChannel(frame, name)
    if type(name) == "string" and name ~= "" and not hasChannel(frame, name) then
        busy = true
        ChatFrame_AddChannel(frame, name)
        busy = false
    end
end

-- GetChannelList gives id, name pairs (later clients add a flag); only the names matter.
local function joinedChannels()
    local list = {}
    if GetChannelList then
        for _, value in ipairs({ GetChannelList() }) do
            if type(value) == "string" then list[#list + 1] = value end
        end
    end
    return list
end

local function serverChannels()
    local list = {}
    if EnumerateServerChannels then
        for _, name in ipairs({ EnumerateServerChannels() }) do list[#list + 1] = name end
    end
    return list
end

-- Chat windows are kept per character, ForeverStockUIDB per account: the one-time merge and the channels the
-- user took out of the general window are remembered per character (chatChannelChars["Name - Realm"]).
-- The old account flag chatChannelsMerged is no longer read: set on one character, it skipped the others.
local function charState()
    local settings = ui.Settings()
    if type(settings.chatChannelChars) ~= "table" then settings.chatChannelChars = {} end
    local name = UnitName and UnitName("player") or "?"
    local key = name .. " - " .. (GetRealmName and GetRealmName() or "?")
    local state = settings.chatChannelChars[key]
    if type(state) ~= "table" then
        state = {}
        settings.chatChannelChars[key] = state
    end
    if type(state.removed) ~= "table" then state.removed = {} end
    return state
end

-- The old Channels tab, also when it is already closed (its channels may still be listed there).
local function channelsTab()
    for id = 2, NUM_CHAT_WINDOWS do
        local title, _, _, _, _, _, shown = GetChatWindowInfo(id)
        local frame = _G["ChatFrame" .. id]
        if frame and title == channelsName then return frame, shown or frame.isDocked end
    end
end

-- Once per character: every channel (the server ones, the joined ones and those of the old Channels tab) goes
-- back to the general window, and a shown Channels tab is closed.
local function mergeChannels(general)
    local state = charState()
    local tab, visible = channelsTab()
    if state.merged and not visible then return end
    for _, name in ipairs(serverChannels()) do addChannel(general, name) end
    for _, name in ipairs(joinedChannels()) do addChannel(general, name) end
    if tab then
        for _, name in pairs(tab.channelList or {}) do addChannel(general, name) end
        if visible and FCF_Close then FCF_Close(tab) end
    end
    state.merged = true
end

-- Is any open tab listening to the channel?
local function listened(name)
    for id = 1, NUM_CHAT_WINDOWS do
        local _, _, _, _, _, _, shown = GetChatWindowInfo(id)
        local frame = _G["ChatFrame" .. id]
        if frame and (id == 1 or shown or frame.isDocked) and hasChannel(frame, name) then return true end
    end
end

-- Every check: a channel the character is in, that no open tab shows and that the user did not take out of the
-- general window by hand goes back there. After a loading screen the client rejoins the zone channels, so the
-- check also runs a few seconds later (scheduleKeep). One try per channel in RETRY seconds: a channel the client
-- refuses must not loop with UPDATE_CHAT_WINDOWS.
local RETRY = 10
local tried, lastRestore = {}, nil
local function keepChannels(general)
    if not general or not enabled("chatKeepChannels") then return end
    local state = charState()
    local now, added = GetTime(), {}
    for _, name in ipairs(joinedChannels()) do
        if not state.removed[name] and not listened(name) and (not tried[name] or now - tried[name] >= RETRY) then
            tried[name] = now
            addChannel(general, name)
            if hasChannel(general, name) then added[#added + 1] = name end
        end
    end
    if #added > 0 then
        lastRestore = { at = now, names = added }
        ui.Print((ui.russian and "Каналы снова в «Общем»: %s" or "Channels back in General: %s")
            :format(table.concat(added, ", ")))
    end
end

-- The user's own choice in the chat settings: a channel unticked in the general window stays out, ticked again
-- it is kept again.
local loggedIn
if hooksecurefunc and ChatFrame_RemoveChannel and ChatFrame_AddChannel then
    hooksecurefunc("ChatFrame_RemoveChannel", function(frame, name)
        if busy or not loggedIn or frame ~= ChatFrame1 or type(name) ~= "string" then return end
        charState().removed[name] = true
    end)
    hooksecurefunc("ChatFrame_AddChannel", function(_, name)
        if busy or not loggedIn or type(name) ~= "string" then return end
        charState().removed[name] = nil
    end)
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
local windowsReady
local function configureAll()
    events:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        if not enabled() then return end
        local settings = ui.Settings()
        -- 1.3.5 turned "rolls only" off by default, but a saved true stayed and hid all the loot.
        if not settings.chatLootRollsReset then
            settings.chatLootRollsOnly = false
            settings.chatLootRollsReset = true
        end
        local selected = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
        local general = ChatFrame1
        -- Not before PLAYER_LOGIN: the chat windows are not loaded yet.
        if general and windowsReady then
            mergeChannels(general)
            keepChannels(general)
            if enabled("chatGeneralClean") then cleanGeneral(general) end
            -- The selected tab may have been the closed Channels tab.
            if selected and selected ~= general and not selected.isDocked then selected = nil end
        end
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

-- Money in the loot tab when the server sends no CHAT_MSG_MONEY (looting alone on 3.3.5). A rise of the
-- money while the loot window is open (or just closed) is written to the tab, unless the server reported it.
local money = CreateFrame("Frame")
local MONEY_GRACE, MONEY_WAIT = 2, 0.7
local lastMoney, lootUntil, serverMoneyAt = nil, 0, -100
local pending, pendingAt = 0, 0

local function coinText(amount)
    if GetCoinTextureString then return GetCoinTextureString(amount) end
    local gold, silver, copper = math.floor(amount / 10000), math.floor(amount / 100) % 100, amount % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. (ui.russian and " з" or "g") end
    if silver > 0 then parts[#parts + 1] = silver .. (ui.russian and " с" or "s") end
    if copper > 0 or #parts == 0 then parts[#parts + 1] = copper .. (ui.russian and " м" or "c") end
    return table.concat(parts, " ")
end

local function flushMoney(self)
    if GetTime() - pendingAt < MONEY_WAIT then return end
    self:SetScript("OnUpdate", nil)
    local amount = pending
    pending = 0
    if amount <= 0 or serverMoneyAt >= pendingAt - MONEY_WAIT then return end
    if not enabled("chatLootWindow") or not enabled("chatLootMoney") then return end
    if not lootFrame or GetChatWindowInfo(lootFrame:GetID()) ~= lootName then return end
    local info = ChatTypeInfo and ChatTypeInfo.MONEY
    local format = YOU_LOOT_MONEY or (ui.russian and "Вы получаете добычу: %s." or "You loot %s.")
    lootFrame:AddMessage(format:format(coinText(amount)), info and info.r or 1, info and info.g or 1, info and info.b or 0)
end

money:RegisterEvent("PLAYER_ENTERING_WORLD")
money:RegisterEvent("PLAYER_MONEY")
money:RegisterEvent("LOOT_OPENED")
money:RegisterEvent("LOOT_CLOSED")
money:RegisterEvent("CHAT_MSG_MONEY")
money:SetScript("OnEvent", function(self, event)
    local now = GetTime()
    if event == "LOOT_OPENED" then
        lootUntil = math.huge
    elseif event == "LOOT_CLOSED" then
        lootUntil = now + MONEY_GRACE
    elseif event == "CHAT_MSG_MONEY" then
        serverMoneyAt = now
        pending = 0
    elseif event == "PLAYER_MONEY" then
        local current = GetMoney()
        local gain = lastMoney and current - lastMoney or 0
        lastMoney = current
        if gain > 0 and now <= lootUntil and now - serverMoneyAt > MONEY_WAIT then
            pending = pending + gain
            pendingAt = now
            self:SetScript("OnUpdate", flushMoney)
        end
    else
        lastMoney = GetMoney()
    end
end)

-- The channel check after events that change the joined channels. The client rejoins the zone channels a moment
-- after a loading screen, so PLAYER_ENTERING_WORLD checks a few times; close requests are merged into one.
local keeper = CreateFrame("Frame")
local keepAt = {}
local function keeperStep(self)
    local now, due = GetTime(), false
    for i = #keepAt, 1, -1 do
        if keepAt[i] <= now then
            table.remove(keepAt, i)
            due = true
        end
    end
    if #keepAt == 0 then self:SetScript("OnUpdate", nil) end
    if due and windowsReady and enabled() then keepChannels(ChatFrame1) end
end
local function scheduleKeep(delay)
    local at = GetTime() + delay
    for _, other in ipairs(keepAt) do
        if math.abs(other - at) < 0.5 then return end
    end
    keepAt[#keepAt + 1] = at
    keeper:SetScript("OnUpdate", keeperStep)
end
keeper:RegisterEvent("PLAYER_ENTERING_WORLD")
keeper:RegisterEvent("CHANNEL_UI_UPDATE")
keeper:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
keeper:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        scheduleKeep(2)
        scheduleKeep(6)
        scheduleKeep(15)
    else
        scheduleKeep(0.5)
    end
end)

-- /fuichat: what every shown tab receives, the joined channels and the loot tab switches.
local function report()
    local print = ui.Print
    for id = 1, NUM_CHAT_WINDOWS do
        local title, _, _, _, _, _, shown = GetChatWindowInfo(id)
        local frame = _G["ChatFrame" .. id]
        if frame and (shown or frame.isDocked) then
            local groups, channels = {}, {}
            for _, group in pairs(frame.messageTypeList or {}) do groups[#groups + 1] = group end
            for index, channel in pairs(frame.channelList or {}) do
                local zone = frame.zoneChannelList and frame.zoneChannelList[index]
                channels[#channels + 1] = zone and zone ~= 0 and ("%s#%s"):format(tostring(channel), tostring(zone))
                    or tostring(channel)
            end
            table.sort(groups)
            print(("%d «%s»: %s | %s"):format(id, tostring(title), table.concat(groups, " "),
                #channels > 0 and table.concat(channels, ", ") or "-"))
        end
    end
    local joined, missing = joinedChannels(), {}
    for _, name in ipairs(joined) do
        if not listened(name) then missing[#missing + 1] = name end
    end
    print((ui.russian and "Каналы: %s" or "Channels: %s"):format(table.concat(joined, ", ")))
    print((ui.russian and "Не показывает ни одна вкладка: %s" or "Shown by no tab: %s")
        :format(#missing > 0 and table.concat(missing, ", ") or "-"))
    local state, removed = charState(), {}
    for name in pairs(state.removed) do removed[#removed + 1] = name end
    table.sort(removed)
    print((ui.russian and "Убраны вами из «Общего»: %s | вернуть сами: %s | последний возврат: %s"
        or "Removed by you from General: %s | keep: %s | last restore: %s"):format(
        #removed > 0 and table.concat(removed, ", ") or "-", tostring(enabled("chatKeepChannels")),
        lastRestore and ("%s, %.0f s ago"):format(table.concat(lastRestore.names, ", "), GetTime() - lastRestore.at)
            or "-"))
    print(("rollsOnly=%s money=%s serverMoney=%s"):format(tostring(enabled("chatLootRollsOnly")),
        tostring(enabled("chatLootMoney")), serverMoneyAt > 0 and ("%.0f s ago"):format(GetTime() - serverMoneyAt) or "never"))
end

SLASH_FOREVERUICHAT1 = "/fuichat"
SlashCmdList.FOREVERUICHAT = report

ui.Chat = { Apply = configureAll, ApplyLayout = applyEditLook, Report = report }

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then self:RegisterEvent("UPDATE_CHAT_WINDOWS") end
    windowsReady, loggedIn = true, true
    -- Chat settings can arrive from the server after login.
    configureAll()
    if event == "PLAYER_LOGIN" then applyEditLook() end
end)
