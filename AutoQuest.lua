-- AutoQuest.lua: accept and turn in quests at quest givers by itself. WotLK 3.3.5a (12340), Lua 5.1.
-- Only quest entries are touched, never gossip options (teleports, trainers, Nozdor service NPCs).
-- By default it works only when the NPC is clicked with Shift held (questTrigger "shift"); in the
-- "always" mode Shift cancels the visit instead. A reward with a choice is never
-- picked: the most valuable choice (vendor price) is highlighted and the choice is left to the player.
local _, ui = ...
local L = ui.L

local AQ = {}
ui.AutoQuest = AQ

local settings
local MAX_QUESTS = MAX_QUESTLOG_QUESTS or 25
local SESSION_GAP = 2      -- seconds after the last quest/gossip window closed before a visit ends
local SHIFT_GRACE = 1.5    -- seconds a released Shift still starts a visit (questTrigger "shift")
local PRICE_WAIT = 3      -- seconds to wait for reward item data before giving up on the highlight
local LOG_SIZE = 40

local log = {}
local function note(text)
    log[#log + 1] = date("%H:%M:%S") .. " " .. text
    if #log > LOG_SIZE then table.remove(log, 1) end
end

local function truthy(v) return v ~= nil and v ~= false and v ~= 0 end

local function chat(text)
    if settings.questChat then ui.Print(text) end
end

local function enabled()
    return settings and (settings.questAutoAccept or settings.questAutoTurnIn)
end

---------------------------------------------------------------------------------------------------
-- Visit: one talk with one quest giver, across the panels it opens and closes
---------------------------------------------------------------------------------------------------
local session
local lastShift = -100

local function giverKey()
    return UnitGUID("npc") or UnitName("npc") or "item"
end

-- The window opens a ping after the click, so a Shift released just before it still counts.
local function shiftRecently()
    return IsShiftKeyDown() or GetTime() - lastShift <= SHIFT_GRACE
end

-- questTrigger "shift": the visit runs only when it was started with Shift held (Shift + click on the NPC);
-- "always": every visit runs and Shift cancels it.
local function visit()
    local key = giverKey()
    local fresh = not session or session.key ~= key or (session.closedAt and GetTime() - session.closedAt > SESSION_GAP)
    if fresh then session = { key = key, tried = {}, progress = {} } end
    session.closedAt = nil
    local shift = fresh and shiftRecently() or IsShiftKeyDown()
    if settings.questTrigger == "always" then
        if shift and not session.skip then
            session.skip = true
            note("Shift: visit skipped")
        end
    else
        if shift and not session.armed then
            session.armed = true
            note("Shift: visit on")
        end
        session.skip = not session.armed
    end
    return session
end

local function try(s, id)
    if s.tried[id] then return false end
    s.tried[id] = true
    return true
end

---------------------------------------------------------------------------------------------------
-- Quest log: titles, completion and the number of quests (collapsed headers are opened for the scan)
---------------------------------------------------------------------------------------------------
local function questCount()
    local _, quests = GetNumQuestLogEntries()
    return quests or 0
end

local function questLog()
    local entries = GetNumQuestLogEntries() or 0
    local collapsed
    for i = 1, entries do
        local title, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
        if isHeader and isCollapsed and title then
            collapsed = collapsed or {}
            collapsed[title] = true
        end
    end
    local selected = GetQuestLogSelection and GetQuestLogSelection() or 0
    local selectedTitle = selected > 0 and GetQuestLogTitle(selected) or nil
    if collapsed then
        ExpandQuestHeader(0)
        entries = GetNumQuestLogEntries() or 0
    end

    local quests = {}
    for i = 1, entries do
        local title, _, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
        if title and not isHeader then
            local q = quests[title] or { count = 0 }
            quests[title] = q
            q.count = q.count + 1
            if isComplete == 1 or isComplete == true then
                q.complete = true
            elseif not isComplete and (GetNumQuestLeaderBoards(i) or 0) == 0 then
                -- No objectives ("talk to", "deliver"): listed by its ender, so it can be handed in.
                q.complete, q.noGoals = true, true
            end
        end
    end

    if collapsed then
        for i = entries, 1, -1 do
            local title, _, _, _, isHeader = GetQuestLogTitle(i)
            if isHeader and collapsed[title] then CollapseQuestHeader(i) end
        end
        if selectedTitle and SelectQuestLogEntry then
            for i = 1, GetNumQuestLogEntries() or 0 do
                if GetQuestLogTitle(i) == selectedTitle then SelectQuestLogEntry(i) break end
            end
        end
    end
    return quests
end
AQ.QuestLog = questLog

---------------------------------------------------------------------------------------------------
-- Quest lists at the giver
---------------------------------------------------------------------------------------------------
-- Gossip returns flat lists. The stride is worked out from the count, so a client that adds a field
-- (an isComplete flag on active quests, as later clients do) is still read correctly.
local function parse(stride, count, ...)
    local n = select("#", ...)
    if count and count > 0 and n >= count and n % count == 0 then stride = n / count end
    local list = { stride = stride }
    for i = 1, n, stride do
        local title, level, a, b, c = select(i, ...)
        if type(title) == "string" then
            list[#list + 1] = { title = title, level = level, trivial = truthy(a), flag4 = b, flag5 = c }
        end
    end
    return list
end

local function gossipActive()
    local list = parse(3, GetNumGossipActiveQuests and GetNumGossipActiveQuests(), GetGossipActiveQuests())
    for _, q in ipairs(list) do
        if list.stride >= 4 then q.complete = truthy(q.flag4) end
    end
    return list
end

local function gossipAvailable()
    local list = parse(5, GetNumGossipAvailableQuests and GetNumGossipAvailableQuests(), GetGossipAvailableQuests())
    for _, q in ipairs(list) do q.daily, q.repeatable = truthy(q.flag4), truthy(q.flag5) end
    return list
end

local function greetingActive()
    local list = {}
    for i = 1, GetNumActiveQuests() or 0 do
        list[i] = { title = GetActiveTitle(i), trivial = IsActiveQuestTrivial and truthy(IsActiveQuestTrivial(i)) }
    end
    return list
end

local function greetingAvailable()
    local list = {}
    for i = 1, GetNumAvailableQuests() or 0 do
        local q = { title = GetAvailableTitle(i) }
        if GetAvailableQuestInfo then
            local trivial, daily, repeatable = GetAvailableQuestInfo(i)
            q.trivial, q.daily, q.repeatable = truthy(trivial), truthy(daily), truthy(repeatable)
        elseif IsAvailableQuestTrivial then
            q.trivial = truthy(IsAvailableQuestTrivial(i))
        end
        list[i] = q
    end
    return list
end

-- Reason the quest is skipped, or nil when it may be opened.
local function availableRefusal(q)
    if q.trivial and not settings.questTrivial then return "grey" end
    if q.daily then
        if not settings.questDaily then return "daily" end
    elseif q.repeatable and not settings.questRepeatable then
        return "repeatable"
    end
end

local function activeRefusal(q, quests)
    local entry = q.title and quests[q.title]
    if not entry then
        -- Not in the log: a repeatable hand-in (reputation, cloth) the server never puts there.
        if not settings.questRepeatable then return "not in log" end
        return q.complete == false and "not complete" or nil
    end
    if q.complete == nil then q.complete = entry.complete or false end
    if not q.complete then return "not complete" end
end

local function warnFull(s)
    if s.fullWarned then return end
    s.fullWarned = true
    note("quest log full")
    ui.Print(L("Журнал заданий полон (" .. MAX_QUESTS .. ") — новые задания не принимаются.",
        "The quest log is full (" .. MAX_QUESTS .. ") — no new quests are accepted."))
end

-- Turn-ins first (a hand-in may unlock the next quest of a chain), then new quests.
local function pick(active, available, selectActive, selectAvailable, where)
    if not enabled() then return end
    local s = visit()
    if s.skip then return end
    if settings.questAutoTurnIn and #active > 0 then
        local quests = questLog()
        for i, q in ipairs(active) do
            local refusal = activeRefusal(q, quests)
            if not refusal and try(s, "active:" .. q.title) then
                note(where .. ": turn in " .. q.title)
                selectActive(i)
                return
            end
        end
    end
    if settings.questAutoAccept then
        for i, q in ipairs(available) do
            local refusal = availableRefusal(q)
            if not refusal and not s.tried["available:" .. q.title] then
                if questCount() >= MAX_QUESTS then warnFull(s) return end
                s.tried["available:" .. q.title] = true
                note(where .. ": open " .. q.title)
                selectAvailable(i)
                return
            elseif refusal and try(s, "skip:" .. q.title) then
                note(where .. ": skip " .. q.title .. " (" .. refusal .. ")")
            end
        end
    end
end

local function onGossip()
    pick(gossipActive(), gossipAvailable(), SelectGossipActiveQuest, SelectGossipAvailableQuest, "gossip")
end

local function onGreeting()
    pick(greetingActive(), greetingAvailable(), SelectActiveQuest, SelectAvailableQuest, "greeting")
end

---------------------------------------------------------------------------------------------------
-- Quest panels
---------------------------------------------------------------------------------------------------
-- Where the open quest came from. The client fills the "npc" unit with the talker; for a quest started
-- by an item it is empty or the player, for a quest shared by a group member it is that player.
local function source()
    if not UnitExists("npc") or UnitIsUnit("npc", "player") then return "item" end
    if UnitIsPlayer("npc") then return "shared" end
    return "npc"
end
AQ.Source = source

local function onDetail()
    if not settings or not settings.questAutoAccept then return end
    local s = visit()
    if s.skip then return end
    local title = GetTitleText() or "?"
    local from = source()
    if from == "item" and not settings.questFromItems then note("detail: " .. title .. " (item quests off)") return end
    if from == "shared" and not settings.questShared then note("detail: " .. title .. " (shared quests off)") return end
    if QuestGetAutoAccept and truthy(QuestGetAutoAccept()) then note("detail: " .. title .. " (accepted by the server)") return end
    if QuestIsDaily and truthy(QuestIsDaily()) and not settings.questDaily then note("detail: " .. title .. " (daily off)") return end
    if questCount() >= MAX_QUESTS then warnFull(s) return end
    if not try(s, "accept:" .. title) then return end
    note("accept " .. title .. " (" .. from .. ")")
    AcceptQuest()
    chat(L("Принято: ", "Accepted: ") .. title)
end

local function onProgress()
    if not settings then return end
    local s = visit()
    local title = GetTitleText() or "?"
    s.progress[title] = true
    if s.skip or not settings.questAutoTurnIn then return end
    if not truthy(IsQuestCompletable()) then note("progress: " .. title .. " (not completable)") return end
    if (GetQuestMoneyToGet and GetQuestMoneyToGet() or 0) > 0 then
        note("progress: " .. title .. " (needs money)")
        chat(L("Задание «" .. title .. "» требует золото — сдайте его сами.",
            "\"" .. title .. "\" asks for money — hand it in yourself."))
        return
    end
    if not settings.questRepeatable and not questLog()[title] then
        note("progress: " .. title .. " (repeatable hand-in off)")
        return
    end
    if not try(s, "progress:" .. title) then return end
    note("continue " .. title)
    CompleteQuest()
end

-- Reward highlight ---------------------------------------------------------------------------------
local glow, waiter

local function hideGlow()
    if glow then glow:Hide() end
    if waiter then waiter:SetScript("OnUpdate", nil) end
end
AQ.HideGlow = hideGlow

local function choiceButton(index)
    local fallback
    for i = 1, MAX_NUM_ITEMS or 10 do
        local button = _G["QuestInfoItem" .. i] or _G["QuestRewardItem" .. i]
        if button and button:IsShown() then
            if button.type == "choice" and button:GetID() == index then return button end
            if i == index and not button.type then fallback = button end
        end
    end
    return fallback
end

local function showGlow(button)
    if not glow then
        glow = CreateFrame("Frame", "ForeverStockUIQuestRewardGlow", UIParent)
        glow:EnableMouse(false)
        local light = glow:CreateTexture(nil, "OVERLAY")
        light:SetTexture("Interface\\QuestFrame\\UI-QuestItemHighlight")
        light:SetBlendMode("ADD")
        light:SetVertexColor(1, 0.8, 0.3)
        light:SetSize(256, 64)
        glow.light = light
        local coin = glow:CreateTexture(nil, "OVERLAY")
        coin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        coin:SetSize(14, 14)
        glow.coin = coin
    end
    glow:SetParent(button)
    glow:SetFrameLevel(button:GetFrameLevel() + 3)
    glow:ClearAllPoints()
    glow:SetAllPoints(button)
    glow.light:ClearAllPoints()
    glow.light:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 7)
    local icon = _G[(button:GetName() or "") .. "IconTexture"] or button
    glow.coin:ClearAllPoints()
    glow.coin:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 4, 4)
    glow.button = button
    glow:Show()
end

-- Index, price and link of the most valuable choice; `missing` when some item data has not arrived yet.
local function bestChoice(choices)
    local best, bestPrice, bestLink, missing = nil, 0, nil, false
    for i = 1, choices do
        local link = GetQuestItemLink("choice", i)
        local price = link and select(11, GetItemInfo(link))
        if not price then
            missing = true
        elseif price > bestPrice then
            best, bestPrice, bestLink = i, price, link
        end
    end
    return best, bestPrice, bestLink, missing
end
AQ.BestChoice = bestChoice

local function highlight(choices, title)
    local started = GetTime()
    local function settle(final)
        local best, price, link, missing = bestChoice(choices)
        if missing and not final then return false end
        if best then
            local button = choiceButton(best)
            if button then showGlow(button) end
            note("reward choice: " .. title .. " -> " .. best)
            chat(L("Выберите награду. Самая дорогая у торговца: ", "Pick a reward. Most valuable at a vendor: ")
                .. (link or "?") .. " (" .. GetCoinTextureString(price) .. ")")
        else
            note("reward choice: " .. title .. " (no prices)")
            chat(L("Выберите награду.", "Pick a reward."))
        end
        return true
    end
    if settle(false) then return end
    waiter = waiter or CreateFrame("Frame")
    local elapsed = 0
    waiter:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed < 0.2 then return end
        elapsed = 0
        if QuestFrameRewardPanel and not QuestFrameRewardPanel:IsShown() then self:SetScript("OnUpdate", nil) return end
        if settle(GetTime() - started >= PRICE_WAIT) then self:SetScript("OnUpdate", nil) end
    end)
end

local function onComplete()
    hideGlow()
    if not settings or not settings.questAutoTurnIn then return end
    local s = visit()
    if s.skip then return end
    local title = GetTitleText() or "?"
    if not settings.questRepeatable and not s.progress[title] and not questLog()[title] then
        note("reward: " .. title .. " (repeatable hand-in off)")
        return
    end
    local choices = GetNumQuestChoices() or 0
    if choices > 1 then highlight(choices, title) return end
    if not try(s, "reward:" .. title) then return end
    local xp = GetRewardXP and GetRewardXP() or 0
    local money = GetRewardMoney and GetRewardMoney() or 0
    local link = choices == 1 and GetQuestItemLink("choice", 1) or nil
    note("reward " .. title)
    GetQuestReward(choices == 1 and 1 or 0)
    local parts = {}
    if link then parts[#parts + 1] = link end
    if xp > 0 then parts[#parts + 1] = xp .. L(" опыта", " XP") end
    if money > 0 then parts[#parts + 1] = GetCoinTextureString(money) end
    chat(L("Сдано: ", "Turned in: ") .. title .. (#parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or ""))
end

local function onClosed()
    if session then session.closedAt = GetTime() end
end

---------------------------------------------------------------------------------------------------
-- /fuiquest: what the client returned at the current quest giver, and the last decisions
---------------------------------------------------------------------------------------------------
local function yes(v) return v and "1" or "-" end

function AQ.Report(what)
    if what == "clear" then
        for i = #log, 1, -1 do log[i] = nil end
        ui.Print(L("Журнал автоквестов очищен.", "Auto quest log cleared."))
        return
    end
    ui.Print(L("Автоквесты: режим ", "Auto quests: mode ") .. tostring(settings.questTrigger)
        .. L(", принятие ", ", accept ") .. yes(settings.questAutoAccept)
        .. L(", сдача ", ", turn in ") .. yes(settings.questAutoTurnIn)
        .. L(", в журнале ", ", in log ") .. questCount() .. "/" .. MAX_QUESTS)
    if UnitExists("npc") or (GossipFrame and GossipFrame:IsShown()) or (QuestFrame and QuestFrame:IsShown()) then
        ui.Print(("npc: %s (%s), %s"):format(tostring(UnitName("npc")), tostring(UnitGUID("npc")), source()))
        local quests = questLog()
        local active, available = gossipActive(), gossipAvailable()
        if #active + #available == 0 then active, available = greetingActive(), greetingAvailable() end
        for _, q in ipairs(active) do
            local entry = quests[q.title]
            ui.Print(("  ? %s | trivial %s | client complete %s | log %s%s | %s"):format(q.title, yes(q.trivial),
                q.complete == nil and "n/a" or yes(q.complete), entry and "yes" or "no",
                entry and entry.complete and (entry.noGoals and ", no goals" or ", complete") or "",
                activeRefusal(q, quests) or "turn in"))
        end
        for _, q in ipairs(available) do
            ui.Print(("  ! %s | trivial %s | daily %s | repeatable %s | %s"):format(q.title, yes(q.trivial),
                yes(q.daily), yes(q.repeatable), availableRefusal(q) or "accept"))
        end
        if active.stride or available.stride then
            ui.Print(("  gossip stride: active %s, available %s"):format(tostring(active.stride), tostring(available.stride)))
        end
    end
    for i = math.max(1, #log - 14), #log do ui.Print("  " .. log[i]) end
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
local handlers = {
    GOSSIP_SHOW = onGossip,
    QUEST_GREETING = onGreeting,
    QUEST_DETAIL = onDetail,
    QUEST_PROGRESS = onProgress,
    QUEST_COMPLETE = onComplete,
    QUEST_FINISHED = function() hideGlow() onClosed() end,
    GOSSIP_CLOSED = onClosed,
    MODIFIER_STATE_CHANGED = function(key)
        if type(key) == "string" and key:find("SHIFT", 1, true) then lastShift = GetTime() end
    end,
}

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        settings = ui.Settings()
        for name in pairs(handlers) do self:RegisterEvent(name) end
        SLASH_FOREVERSTOCKQUEST1 = "/fuiquest"
        SlashCmdList.FOREVERSTOCKQUEST = function(message) AQ.Report((message or ""):match("^%s*(%S*)")) end
        return
    end
    local handler = handlers[event]
    if handler then ui.SafeCall(handler, ...) end
end)

AQ.Apply = function() if settings and not settings.questAutoTurnIn then hideGlow() end end
AQ.Log = log
AQ.Session = function() return session end
