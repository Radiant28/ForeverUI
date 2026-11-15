local addonName, ui = ...
-- Enchanting helpers: (1) disenchant a hand-picked list of bag items, one key press or click per item;
-- (2) repeat the selected enchant on one remembered item N times; while that session runs the session key
-- presses "Yes" on REPLACE_ENCHANT.
--
-- Protected-API notes (3.3.5a):
--  * Casting a spell from addon code is forbidden; it needs a hardware event on a secure button. Disenchant
--    therefore goes through ForeverStockUIDisenchantSecure (SecureActionButtonTemplate, type "spell" plus
--    "target-bag"/"target-slot"). Each click casts on the next queued item; between casts the attributes are
--    rewritten out of combat. The secure button is parented to UIParent and only *placed* over the bag
--    button by absolute coordinates, so the bag window never gets protected children or anchors.
--  * DoTradeSkill and Pickup*/Use*Item while SpellIsTargeting are not protected: the repeat button is a
--    plain button. Whether the client lets DoTradeSkill run outside a click is checked at run time: if the
--    targeting cursor does not appear (or the client reports ADDON_ACTION_FORBIDDEN), the session falls back
--    to one press per repeat.
--  * ReplaceEnchant() is Blizzard-only in this client (ADDON_ACTION_FORBIDDEN), and calling StaticPopup_*
--    from addon code taints the dialog so that even a manual "Yes" gets blocked. The addon never touches the
--    popup: during a session one key is bound (SetOverrideBindingClick) to the dialog's own Button1, so the
--    key press is a hardware click on Blizzard's button and Blizzard's OnAccept runs untainted.
local L = ui.L
local white = "Interface\\Buttons\\WHITE8X8"
local DISENCHANT_ID, ENCHANTING_ID = 13262, 7411
local E = {}
ui.Enchanting = E

local function setting(key, fallback)
    local value = ui.Settings()[key]
    if value == nil then return fallback end
    return value
end

local function enabled(key)
    return setting("enchantEnabled", true) ~= false and setting(key, true) ~= false
end

local function say(message, force)
    if force or setting("enchantChat", true) then ui.Print(message) end
end

local function spellName(id) return (GetSpellInfo(id)) end

-- Read-only check (never call StaticPopup_Show/Hide from here: that taints Blizzard's dialogs).
local function popupVisible(which)
    return StaticPopup_Visible and StaticPopup_Visible(which)
end

local function knowsSpell(id)
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, id)
        if ok and known then return true end
    end
    -- GetSpellInfo by *name* only answers for spells in the player's spellbook.
    local name = spellName(id)
    return name ~= nil and GetSpellInfo(name) ~= nil
end

-- Item identity without the enchant and gem fields: re-enchanting changes the link (enchant id), and a
-- disenchant target must still be "the same item" after it was moved. Fields of item:...: 1 id, 2 enchant,
-- 3-6 gems, 7 suffix, 8 unique id.
function E.ItemKey(link)
    local body = link and link:match("item:([%-%d:]+)")
    if not body then return end
    local fields = {}
    for value in (body .. ":"):gmatch("(%-?%d*):") do fields[#fields + 1] = value end
    local function field(i) local v = fields[i]; return (v and v ~= "") and v or "0" end
    return field(1) .. ":" .. field(7) .. ":" .. field(8)
end

local weaponClass, armorClass
local skipSlots = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true,
    INVTYPE_AMMO = true }

-- Returns ok, link. Uncommon..epic weapons and armour only (localized class names come from the auction
-- house list: first two entries are Weapon and Armor in every locale); shirts, tabards and quest items are out.
function E.CanDisenchant(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return false end
    if not weaponClass then weaponClass, armorClass = GetAuctionItemClasses() end
    local _, _, quality, _, _, class, _, _, equipLoc = GetItemInfo(link)
    if not quality or quality < 2 or quality > 4 then return false, link end
    if class ~= weaponClass and class ~= armorClass then return false, link end
    if skipSlots[equipLoc] then return false, link end
    if GetContainerItemQuestInfo then
        local isQuest, questID = GetContainerItemQuestInfo(bag, slot)
        if isQuest or questID then return false, link end
    end
    return true, link
end

-- Free slots that can take dust, essences and shards (general bags and enchanting bags, family 64).
function E.FreeSlots()
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local count, family = GetContainerNumFreeSlots(bag)
        if count and count > 0 and (not family or family == 0 or bit.band(family, 64) ~= 0) then
            free = free + count
        end
    end
    return free
end

local driver = CreateFrame("Frame")
driver:Hide()

----------------------------------------------------------------------------------------------------------
-- Feature 1: disenchant selection and queue
----------------------------------------------------------------------------------------------------------
-- mode: "idle" | "select" | "run"; phase (run only): "ready" | "sent" | "casting" | "loot"
local de = { mode = "idle", queue = {}, index = 0, done = 0 }
E.disenchant = de
local overlays = {}
local ctrl, deButton, deIcon, deText, deCancel, secure
local dirty

local function eachBagButton(fn)
    if ui.Bags and ui.Bags.Window and ui.Bags.Window() then
        ui.Bags.EachItem(fn)
        return
    end
    for index = 1, NUM_CONTAINER_FRAMES or 0 do
        local frame = _G["ContainerFrame" .. index]
        if frame and frame:IsShown() then
            local bag = frame:GetID()
            if bag >= 0 and bag <= (NUM_BAG_SLOTS or 4) then
                for i = 1, frame.size or 0 do
                    local button = _G[frame:GetName() .. "Item" .. i]
                    if button then fn(button, bag, button:GetID()) end
                end
            end
        end
    end
end

-- The frame the disenchant control lives on: the combined backpack, else the stock backpack container.
local function bagHost()
    local window = ui.Bags and ui.Bags.Window and ui.Bags.Window()
    if window then return window, ui.Bags.Footer() end
    local frame = ContainerFrame1
    if frame and frame:IsShown() and frame:GetID() == 0 then return frame end
end

local function queued(bag, slot)
    for i, item in ipairs(de.queue) do
        if item.bag == bag and item.slot == slot then return i end
    end
end

local function findByKey(key, skip)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            if not (skip and skip[bag .. ":" .. slot]) and E.ItemKey(GetContainerItemLink(bag, slot)) == key then
                return bag, slot
            end
        end
    end
end

local function setSecure(bag, slot)
    if not secure or InCombatLockdown() then return end
    if bag then
        secure:SetAttribute("type", "spell")
        secure:SetAttribute("spell", spellName(DISENCHANT_ID))
        secure:SetAttribute("target-bag", bag)
        secure:SetAttribute("target-slot", slot)
    else
        secure:SetAttribute("type", nil)
        secure:SetAttribute("spell", nil)
        secure:SetAttribute("target-bag", nil)
        secure:SetAttribute("target-slot", nil)
    end
end

local function updateControl()
    if not deButton then return end
    local known = knowsSpell(DISENCHANT_ID)
    deIcon:SetDesaturated(not known)
    if known then deButton:Enable() else deButton:Disable() end
    local text = ""
    if de.mode == "select" then
        text = (L("Подтвердить (%d)", "Confirm (%d)")):format(#de.queue)
    elseif de.mode == "run" then
        local total = #de.queue
        if de.phase == "ready" then
            text = (L("Распылить %d/%d", "Disenchant %d/%d")):format(de.index, total)
            local key = E.KeyLabel and E.KeyLabel()
            if key then text = text .. " [" .. key .. "]" end
        else
            text = (L("Ждём… %d/%d", "Waiting… %d/%d")):format(de.index, total)
        end
    end
    deText:SetText(text)
    deButton:SetWidth(deIcon:GetWidth() + (text ~= "" and deText:GetStringWidth() + 8 or 0))
    if de.mode == "idle" then deCancel:Hide() else deCancel:Show() end
end

local function refreshOverlays()
    dirty = nil
    -- Stock container buttons are reused for other bags, so every overlay is hidden and re-bound each pass.
    for _, overlay in pairs(overlays) do overlay:Hide() end
    if de.mode == "idle" then return updateControl() end
    eachBagButton(function(button, bag, slot)
        local overlay = E.Overlay(button)
        overlay.bag, overlay.slot = bag, slot
        local index = queued(bag, slot)
        if de.mode == "select" and index then
            -- Drop a selection whose slot no longer holds the chosen item (moved, sold, destroyed).
            local item = de.queue[index]
            if E.ItemKey(GetContainerItemLink(bag, slot)) ~= item.key then
                table.remove(de.queue, index)
                index = nil
            end
        end
        local ok = E.CanDisenchant(bag, slot)
        local current = de.mode == "run" and index == de.index
        overlay:EnableMouse(de.mode == "select")
        overlay.dim:SetAlpha((de.mode == "select" and not ok and not index) and 0.65 or 0)
        if index then
            local r, g, b = 0.72, 0.45, 1
            if current then r, g, b = 1, 0.82, 0.2 end
            overlay:SetBackdropBorderColor(r, g, b, 1)
            overlay.check:Show()
            overlay.number:SetText(index)
            overlay.check:SetAlpha((de.mode == "run" and index < de.index) and 0.35 or 1)
        else
            overlay:SetBackdropBorderColor(0, 0, 0, 0)
            overlay.check:Hide()
            overlay.number:SetText("")
        end
        overlay:Show()
    end)
    updateControl()
end

local function markDirty() dirty = true end

local function stopDisenchant(reason)
    local wasRunning = de.mode ~= "idle"
    de.mode, de.phase, de.index, de.done = "idle", nil, 0, 0
    wipe(de.queue)
    if not InCombatLockdown() and secure then
        setSecure(nil)
        secure:Hide()
    end
    refreshOverlays()
    updateControl()
    if wasRunning and reason then say(reason, true) end
end

local function toggleItem(bag, slot)
    local index = queued(bag, slot)
    if index then
        table.remove(de.queue, index)
    else
        local ok, link = E.CanDisenchant(bag, slot)
        local _, _, locked = GetContainerItemInfo(bag, slot)
        if not ok or locked then return end
        de.queue[#de.queue + 1] = { bag = bag, slot = slot, link = link, key = E.ItemKey(link), tries = 0 }
    end
    refreshOverlays()
end

local function selectAll()
    eachBagButton(function(_, bag, slot)
        if not queued(bag, slot) and E.CanDisenchant(bag, slot) then toggleItem(bag, slot) end
    end)
end

function E.Overlay(button)
    local overlay = overlays[button]
    if overlay then return overlay end
    overlay = CreateFrame("Button", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 6)
    overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    overlay:SetBackdrop({ edgeFile = white, edgeSize = 2 })
    overlay:SetBackdropBorderColor(0, 0, 0, 0)
    overlay.dim = overlay:CreateTexture(nil, "OVERLAY")
    overlay.dim:SetTexture(white)
    overlay.dim:SetVertexColor(0, 0, 0)
    overlay.dim:SetPoint("TOPLEFT", overlay, "TOPLEFT", 2, -2)
    overlay.dim:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -2, 2)
    overlay.check = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
    overlay.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    overlay.check:SetSize(18, 18)
    overlay.check:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 2, 2)
    overlay.check:Hide()
    overlay.number = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    overlay.number:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 3, 2)
    overlay:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            stopDisenchant()
        elseif de.mode == "select" then
            toggleItem(self.bag, self.slot)
        end
    end)
    overlay:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.bag, self.slot)
        GameTooltip:AddLine(L("ЛКМ — выбрать/снять, ПКМ — отменить режим", "Left-click: select/unselect, right-click: cancel"),
            0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    overlay:SetScript("OnLeave", GameTooltip_Hide)
    overlay:Hide()
    overlays[button] = overlay
    return overlay
end

local function finishDisenchant()
    local done = de.done
    stopDisenchant()
    say((L("Распыление завершено: %d предм.", "Disenchanting finished: %d item(s).")):format(done), true)
end

-- Points the secure button at the next queued item (out of combat only). Skips items that disappeared.
local function prepareStep()
    if de.mode ~= "run" or InCombatLockdown() then return end
    local claimed = {}
    for i = de.index + 1, #de.queue do
        local other = de.queue[i]
        claimed[other.bag .. ":" .. other.slot] = true
    end
    while true do
        local item = de.queue[de.index]
        if not item then return finishDisenchant() end
        if E.ItemKey(GetContainerItemLink(item.bag, item.slot)) ~= item.key then
            local bag, slot = findByKey(item.key, claimed)
            if bag then
                item.bag, item.slot = bag, slot
            else
                say((L("Пропущен (исчез из сумки): %s", "Skipped (no longer in bags): %s")):format(item.link))
                de.index = de.index + 1
                item = nil
            end
        end
        if item then
            if E.FreeSlots() < 1 then
                return stopDisenchant(L("Распыление остановлено: нет места в сумках.", "Disenchanting stopped: bags are full."))
            end
            setSecure(item.bag, item.slot)
            de.phase, de.lootOpen = "ready", nil
            refreshOverlays()
            return
        end
    end
end

local function advance()
    de.done = de.done + 1
    de.index = de.index + 1
    de.phase = "next"
    de.nextAt = GetTime() + 0.2
    setSecure(nil)
    updateControl()
end

local function startRun()
    if InCombatLockdown() then return end
    if #de.queue == 0 then
        say(L("Выберите предметы для распыления.", "Select items to disenchant first."), true)
        return
    end
    de.mode, de.index, de.done = "run", 1, 0
    secure:Show()
    driver:Show()
    local key = E.KeyLabel()
    if key then
        say((L("Жмите %s (или кнопку) — каждый раз распыляется следующий предмет.",
            "Press %s (or the button): each press disenchants the next item.")):format(key))
    end
    prepareStep()
end

local function enterSelect()
    if InCombatLockdown() then
        say(L("В бою распыление недоступно.", "Not available in combat."), true)
        return
    end
    if not knowsSpell(DISENCHANT_ID) then return end
    de.mode = "select"
    wipe(de.queue)
    driver:Show()
    refreshOverlays()
end

local function placeControl()
    if not ctrl then return end
    local host, footer = bagHost()
    if not host or not enabled("enchantDisenchantButton") then
        ctrl:Hide()
        return
    end
    ctrl:SetParent(footer or host)
    ctrl:ClearAllPoints()
    if footer then
        ctrl:SetPoint("LEFT", footer, "LEFT", 3, 0)
    else
        ctrl:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 12, 2)
    end
    ctrl:SetFrameLevel((footer or host):GetFrameLevel() + 3)
    ctrl:Show()
    updateControl()
end

local function hostHidden()
    if de.mode ~= "idle" then
        stopDisenchant(L("Распыление отменено: сумка закрыта.", "Disenchanting cancelled: bags closed."))
    end
end

local function createSecure()
    secure = CreateFrame("Button", "ForeverStockUIDisenchantSecure", UIParent, "SecureActionButtonTemplate")
    secure:SetFrameStrata("TOOLTIP")
    secure:RegisterForClicks("LeftButtonUp")
    secure:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    secure:Hide()
    -- Last insecure look before the secure handler casts: re-check the slot, refuse stale or busy clicks.
    secure:SetScript("PreClick", function()
        if InCombatLockdown() then return end
        local item = de.queue[de.index]
        if de.mode ~= "run" or de.phase ~= "ready" or not item
            or E.ItemKey(GetContainerItemLink(item.bag, item.slot)) ~= item.key or UnitCastingInfo("player") then
            setSecure(nil)
            if de.mode == "run" and de.phase == "ready" then de.pending = true end
            return
        end
        de.phase, de.sentAt = "sent", GetTime()
        updateControl()
    end)
    -- Fallback for a SecureActionButton without target-bag support: the click's hardware event is still
    -- current, and using a bag item while the cursor targets applies the spell to it.
    secure:SetScript("PostClick", function()
        local item = de.queue[de.index]
        local canTarget = SpellCanTargetItem or SpellIsTargeting
        if de.phase == "sent" and item and canTarget() then
            UseContainerItem(item.bag, item.slot)
            if SpellIsTargeting() then SpellStopTargeting() end
        end
        if de.pending then
            de.pending = nil
            prepareStep()
        end
    end)
    secure:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local item = de.queue[de.index]
        GameTooltip:SetText(spellName(DISENCHANT_ID) or "Disenchant")
        if item then GameTooltip:AddLine(item.link) end
        GameTooltip:AddLine(L("Каждый клик распыляет следующий предмет.", "Each click disenchants the next item."), 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    secure:SetScript("OnLeave", GameTooltip_Hide)
end

local function createControl()
    ctrl = CreateFrame("Frame", "ForeverStockUIDisenchantControl", UIParent)
    ctrl:SetSize(160, 18)
    ctrl:Hide()
    deButton = CreateFrame("Button", "ForeverStockUIDisenchantButton", ctrl)
    deButton:SetHeight(18)
    deButton:SetPoint("LEFT", ctrl, "LEFT", 0, 0)
    deButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    deButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    deIcon = deButton:CreateTexture(nil, "ARTWORK")
    deIcon:SetSize(18, 18)
    deIcon:SetPoint("LEFT", deButton, "LEFT", 0, 0)
    deIcon:SetTexture(select(3, GetSpellInfo(DISENCHANT_ID)) or "Interface\\Icons\\INV_Enchant_Disenchant")
    deIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    deText = deButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    deText:SetPoint("LEFT", deIcon, "RIGHT", 4, 0)
    deButton:SetWidth(18)
    deButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then return stopDisenchant() end
        if de.mode == "idle" then
            enterSelect()
        elseif de.mode == "select" then
            if IsShiftKeyDown() then selectAll() else startRun() end
        end
    end)
    deButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(spellName(DISENCHANT_ID) or "Disenchant")
        if not knowsSpell(DISENCHANT_ID) then
            GameTooltip:AddLine((L("Нужна профессия «%s».", "Requires %s.")):format(spellName(ENCHANTING_ID) or "Enchanting"),
                1, 0.3, 0.3)
        elseif de.mode == "idle" then
            GameTooltip:AddLine(L("Выбрать предметы для распыления.", "Pick items to disenchant."), 1, 1, 1)
        else
            GameTooltip:AddLine(L("ЛКМ — запустить, Shift+ЛКМ — выбрать всё подходящее, ПКМ — отмена.",
                "Left-click: start, Shift-click: select every eligible item, right-click: cancel."), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    deButton:SetScript("OnLeave", GameTooltip_Hide)
    deCancel = CreateFrame("Button", nil, ctrl)
    deCancel:SetSize(16, 16)
    deCancel:SetPoint("LEFT", deButton, "RIGHT", 4, 0)
    deCancel:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    deCancel:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
    deCancel:SetScript("OnClick", function() stopDisenchant() end)
    deCancel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(CANCEL)
        GameTooltip:Show()
    end)
    deCancel:SetScript("OnLeave", GameTooltip_Hide)
    deCancel:Hide()
    createSecure()

    local window = ui.Bags and ui.Bags.Window and ui.Bags.Window()
    if window then
        window:HookScript("OnShow", placeControl)
        window:HookScript("OnHide", hostHidden)
    elseif ContainerFrame1 then
        ContainerFrame1:HookScript("OnShow", placeControl)
        ContainerFrame1:HookScript("OnHide", hostHidden)
    end
    placeControl()
end

-- Keep the secure button exactly over the visible one (absolute UIParent coordinates, never an anchor).
local placed = {}
local function syncSecure()
    if InCombatLockdown() or not secure:IsShown() then return end
    if not deButton:IsVisible() then
        secure:Hide()
        return
    end
    local scale = deButton:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = deButton:GetLeft(), deButton:GetBottom()
    if not x then return end
    x, y = x * scale, y * scale
    local w, h = deButton:GetWidth() * scale, deButton:GetHeight() * scale
    if placed.x ~= x or placed.y ~= y or placed.w ~= w or placed.h ~= h then
        placed.x, placed.y, placed.w, placed.h = x, y, w, h
        secure:ClearAllPoints()
        secure:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
        secure:SetSize(w, h)
    end
end

local function disenchantTick(now)
    if de.mode ~= "run" then return end
    syncSecure()
    if de.phase == "sent" and now - de.sentAt > 1.5 then
        -- The click produced no cast (e.g. silently refused); offer the same item again.
        prepareStep()
    elseif de.phase == "loot" and not de.lootOpen and now - de.succeededAt > 2.5 then
        advance()
    elseif de.phase == "next" and now >= de.nextAt and not UnitCastingInfo("player") then
        prepareStep()
    end
end

local function disenchantEvent(event, unit, spell)
    if de.mode ~= "run" then return end
    local deName = spellName(DISENCHANT_ID)
    if event == "LOOT_OPENED" then
        if de.phase == "loot" or de.phase == "casting" then de.lootOpen = true end
        return
    elseif event == "LOOT_CLOSED" then
        if de.phase == "loot" then de.lootOpen = nil; advance() end
        return
    end
    if unit ~= "player" or spell ~= deName then return end
    if event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_START" then
        if de.phase == "sent" then de.phase = "casting"; updateControl() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if de.phase == "sent" or de.phase == "casting" then
            de.phase, de.succeededAt = "loot", GetTime()
            updateControl()
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if de.phase == "casting" then
            stopDisenchant(L("Распыление остановлено: каст прерван.", "Disenchanting stopped: cast interrupted."))
        end
    elseif event == "UNIT_SPELLCAST_FAILED" then
        if de.phase == "sent" or de.phase == "casting" then
            local item = de.queue[de.index]
            item.tries = item.tries + 1
            if item.tries >= 2 then
                say((L("Не удалось распылить, пропускаю: %s", "Could not disenchant, skipping: %s")):format(item.link))
                de.index = de.index + 1
            end
            de.phase = "next"
            de.nextAt = GetTime() + 0.3
            setSecure(nil)
            updateControl()
        end
    end
end

----------------------------------------------------------------------------------------------------------
-- Feature 2: repeat an enchant on one item
----------------------------------------------------------------------------------------------------------
-- phase: "picking" (cursor waits for the user's one target click) | "casting" (target applied, waiting for
-- the cast; a REPLACE_ENCHANT/BIND_ENCHANT popup may sit in between) | "channel" (cast bar running) |
-- "next" (auto-chain delay) | "wait_click" (client needs a click for each repeat)
local re = { active = false, done = 0, total = 1 }
E.reenchant = re
local reRow, reButton, reCount

local function isEnchanting()
    if not TradeSkillFrame or not TradeSkillFrame:IsShown() then return false end
    if IsTradeSkillLinked and IsTradeSkillLinked() then return false end
    local line = GetTradeSkillLine()
    return line ~= nil and line == spellName(ENCHANTING_ID)
end

local function selectedRecipe()
    local index = GetTradeSkillSelectionIndex()
    if not index or index == 0 then return end
    local name, kind, available, _, verb = GetTradeSkillInfo(index)
    if not name or kind == "header" then return end
    return index, name, available or 0, verb
end

local function targetLink(target)
    if target.type == "inv" then return GetInventoryItemLink("player", target.slot) end
    return GetContainerItemLink(target.bag, target.slot)
end

local function targetValid(target)
    return target ~= nil and E.ItemKey(targetLink(target)) == target.key
end

local function repeatCount()
    local value = tonumber(setting("enchantRepeatCount", 1)) or 1
    return math.max(1, math.min(99, math.floor(value)))
end

local function updateRepeat()
    if not reRow then return end
    local index, _, _, verb = selectedRecipe()
    local show = enabled("enchantReenchant") and isEnchanting() and (re.active or (index and verb))
    if not show then
        reRow:Hide()
        return
    end
    reRow:Show()
    if re.active then
        local key = E.KeyLabel and E.KeyLabel()
        if key and setting("enchantKeyConfirm", true) and popupVisible("REPLACE_ENCHANT") then
            reButton:SetText((L("%s — заменить", "%s: replace")):format(key))
        elseif re.phase == "wait_click" then
            reButton:SetText((L("Дальше %d/%d", "Next %d/%d")):format(re.done + 1, re.total)
                .. (key and " [" .. key .. "]" or ""))
        else
            reButton:SetText((L("Стоп %d/%d", "Stop %d/%d")):format(re.done, re.total))
        end
        reButton:Enable()
    else
        reButton:SetText((L("Повторить ×%d", "Repeat ×%d")):format(repeatCount()))
        if index and verb then reButton:Enable() else reButton:Disable() end
    end
end

local function stopRepeat(reason, quiet)
    if not re.active then return end
    re.active, re.phase = false, nil
    if SpellIsTargeting() then SpellStopTargeting() end
    updateRepeat()
    if reason and not quiet then say(reason, true) end
end

-- After a target click the cursor may stay in targeting mode while a confirmation popup is up.
local function awaitingConfirm()
    return popupVisible("REPLACE_ENCHANT") or popupVisible("BIND_ENCHANT")
end

local function applyTarget()
    if not SpellIsTargeting() then return end
    local target = re.target
    re.applying = true
    if target.type == "inv" then PickupInventoryItem(target.slot) else PickupContainerItem(target.bag, target.slot) end
    re.applying = nil
    -- Safety: if targeting had ended, Pickup* would have put the item on the cursor; put it back.
    if CursorHasItem() then ClearCursor() end
end

-- One repeat. fromClick: called from a real click (hardware event).
local function step(fromClick)
    if not re.active then return end
    if InCombatLockdown() then return stopRepeat(L("Переналожение остановлено: бой.", "Re-enchanting stopped: combat.")) end
    local index, name, available, verb = selectedRecipe()
    if not index or name ~= re.recipe or not verb then
        return stopRepeat(L("Переналожение остановлено: сменён рецепт.", "Re-enchanting stopped: recipe changed."))
    end
    if available < 1 then
        return stopRepeat(L("Переналожение остановлено: нет реагентов.", "Re-enchanting stopped: out of reagents."))
    end
    if re.target and not targetValid(re.target) then
        return stopRepeat(L("Переналожение остановлено: предмет исчез или заменён.", "Re-enchanting stopped: the item is gone or was replaced."))
    end
    if SpellIsTargeting() then SpellStopTargeting() end
    re.castName = nil
    DoTradeSkill(index, 1)
    -- Enchants on items open the targeting cursor synchronously; no cursor means the client refused the call.
    if not SpellIsTargeting() then
        if fromClick then
            stopRepeat(L("Клиент не начал наложение чар.", "The client did not start the enchant."))
        end
        return false
    end
    if re.target then
        applyTarget()
        if SpellIsTargeting() and not awaitingConfirm() then
            SpellStopTargeting()
            return stopRepeat(L("Эти чары нельзя наложить на выбранный предмет.", "This enchant cannot go on the remembered item."))
        end
        re.phase, re.castStarted = "casting", GetTime()
    else
        re.phase, re.pickStarted = "picking", GetTime()
        say(L("Кликните по предмету в сумке или на персонаже — он будет запомнен.",
            "Click the item in your bags or on your character; it will be remembered."), true)
    end
    updateRepeat()
    return true
end

local function startRepeat()
    if re.active then return end
    if InCombatLockdown() then return say(L("В бою недоступно.", "Not available in combat."), true) end
    local index, name, available, verb = selectedRecipe()
    if not index or not verb then return end
    if available < 1 then return say(L("Не хватает реагентов.", "Missing reagents."), true) end
    re.active, re.recipe, re.done, re.total = true, name, 0, repeatCount()
    re.stepMode = not setting("enchantAutoChain", true) or setting("enchantAutoChainBlocked", false) == true
    re.autoFails = 0
    local key = E.KeyLabel()
    if key then
        say((L("%s подтверждает замену чар и запускает следующий повтор.",
            "%s confirms the enchant replacement and starts the next repeat.")):format(key))
    end
    if re.target and not targetValid(re.target) then re.target = nil end
    driver:Show()
    step(true)
end

-- Remember the item the user clicked while the cursor waited for the enchant target.
local function captured(kind, a, b)
    if not re.active or re.phase ~= "picking" or re.applying then return end
    if CursorHasItem() then return end -- a plain pickup, not a spell target
    if SpellIsTargeting() and not awaitingConfirm() then return end -- the client refused that item
    local target
    if kind == "inv" then
        local link = GetInventoryItemLink("player", a)
        if link then target = { type = "inv", slot = a, link = link, key = E.ItemKey(link) } end
    else
        local link = GetContainerItemLink(a, b)
        if link then target = { type = "bag", bag = a, slot = b, link = link, key = E.ItemKey(link) } end
    end
    if not target then return end
    re.target = target
    re.phase, re.castStarted = "casting", GetTime()
    say((L("Цель запомнена: %s", "Target remembered: %s")):format(target.link))
    updateRepeat()
end


local function repeatTick(now)
    if not re.active then return end
    if re.phase == "picking" and not SpellIsTargeting() and now - re.pickStarted > 0.1 then
        stopRepeat(L("Переналожение отменено: цель не выбрана.", "Re-enchanting cancelled: no target picked."))
    elseif re.phase == "casting" and now - re.castStarted > 2 then
        -- Waiting on a confirmation the user has to give (bind on enchant, or replace with auto-confirm off)?
        if popupVisible("BIND_ENCHANT") or popupVisible("REPLACE_ENCHANT") then
            re.castStarted = now
        else
            stopRepeat(L("Переналожение остановлено: наложение не началось.", "Re-enchanting stopped: the enchant did not start."))
        end
    elseif re.phase == "next" and now >= re.nextAt and not UnitCastingInfo("player") then
        if re.target and not targetValid(re.target) then
            return stopRepeat(L("Переналожение остановлено: предмет исчез или заменён.",
                "Re-enchanting stopped: the item is gone or was replaced."))
        end
        if re.stepMode then
            re.phase = "wait_click"
            updateRepeat()
        elseif not step(false) then
            if not re.active then return end
            re.autoFails = re.autoFails + 1
            if re.autoFails >= 2 then
                re.stepMode = true
                re.phase = "wait_click"
                say(L("Клиент требует клик для каждого повтора: нажимайте «Дальше».",
                    "The client needs a click per repeat: press \"Next\"."), true)
                updateRepeat()
            else
                re.nextAt = now + 0.6
            end
        end
    end
end

local function repeatEvent(event, unit, spell)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        return updateRepeat()
    elseif event == "TRADE_SKILL_CLOSE" then
        stopRepeat(L("Переналожение остановлено: окно профессии закрыто.", "Re-enchanting stopped: profession window closed."))
        return updateRepeat()
    end
    if not re.active or unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_START" then
        if re.phase == "casting" then
            re.phase, re.castName = "channel", spell
            updateRepeat()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local ours = spell == re.recipe or (re.castName and spell == re.castName)
        if ours and (re.phase == "channel" or re.phase == "casting") then
            re.done = re.done + 1
            if re.done >= re.total then
                local done = re.done
                stopRepeat(nil)
                say((L("Переналожение завершено: %d из %d.", "Re-enchanting finished: %d of %d.")):format(done, done), true)
            else
                re.phase, re.nextAt = "next", GetTime() + 0.35
                updateRepeat()
            end
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        local ours = spell == re.recipe or (re.castName and spell == re.castName)
        if ours and (re.phase == "channel" or re.phase == "casting") then
            stopRepeat(L("Переналожение остановлено: каст прерван.", "Re-enchanting stopped: cast interrupted."))
        end
    end
end

local function createRepeat()
    if reRow or not TradeSkillFrame then return end
    reRow = CreateFrame("Frame", "ForeverStockUIReenchant", TradeSkillFrame)
    reRow:SetSize(160, 22)
    reRow:Hide()
    reButton = CreateFrame("Button", "ForeverStockUIReenchantButton", reRow, "UIPanelButtonTemplate")
    reButton:SetSize(96, 22)
    reButton:SetPoint("RIGHT", TradeSkillCreateButton, "LEFT", -4, 0)
    reButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    reButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if re.active then
                stopRepeat(L("Переналожение остановлено.", "Re-enchanting stopped."))
            elseif re.target then
                re.target = nil
                say(L("Запомненная цель сброшена.", "Remembered target cleared."), true)
            end
        elseif re.active then
            if re.phase == "wait_click" then
                step(true)
            else
                stopRepeat(L("Переналожение остановлено.", "Re-enchanting stopped."))
            end
        else
            startRepeat()
        end
    end)
    reButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L("Переналожение чар", "Repeat enchant"))
        if re.target then
            GameTooltip:AddLine((L("Цель: %s", "Target: %s")):format(targetLink(re.target) or re.target.link), 1, 1, 1)
        else
            GameTooltip:AddLine(L("Цель не выбрана: после запуска кликните по предмету.", "No target yet: click the item after starting."),
                1, 1, 1, true)
        end
        if re.active then GameTooltip:AddLine((L("Выполнено: %d / %d", "Done: %d / %d")):format(re.done, re.total), 0.4, 1, 0.4) end
        GameTooltip:AddLine(L("ПКМ — остановить или забыть цель.", "Right-click: stop, or forget the target."), 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    reButton:SetScript("OnLeave", GameTooltip_Hide)

    local plus = CreateFrame("Button", "ForeverStockUIReenchantPlus", reRow, "UIPanelButtonTemplate")
    plus:SetSize(20, 22)
    plus:SetText("+")
    plus:SetPoint("RIGHT", reButton, "LEFT", -2, 0)
    reCount = CreateFrame("EditBox", "ForeverStockUIReenchantCount", reRow, "InputBoxTemplate")
    reCount:SetSize(24, 20)
    reCount:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    reCount:SetAutoFocus(false)
    reCount:SetNumeric(true)
    reCount:SetMaxLetters(2)
    reCount:SetJustifyH("CENTER")
    local minus = CreateFrame("Button", "ForeverStockUIReenchantMinus", reRow, "UIPanelButtonTemplate")
    minus:SetSize(20, 22)
    minus:SetText("-")
    minus:SetPoint("RIGHT", reCount, "LEFT", -6, 0)
    local function setCount(value)
        ui.Settings().enchantRepeatCount = math.max(1, math.min(99, value))
        reCount:SetText(repeatCount())
        updateRepeat()
    end
    plus:SetScript("OnClick", function() setCount(repeatCount() + 1) end)
    minus:SetScript("OnClick", function() setCount(repeatCount() - 1) end)
    reCount:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    reCount:SetScript("OnEditFocusLost", function(self) setCount(tonumber(self:GetText()) or 1) end)
    reCount:SetScript("OnEscapePressed", function(self) self:SetText(repeatCount()); self:ClearFocus() end)
    reCount:SetText(repeatCount())

    -- Changing the recipe ends the session; the row also hides for recipes that create items (rods, oils),
    -- where the client shows its own "Create all" row in the same place.
    hooksecurefunc("TradeSkillFrame_SetSelection", function(id)
        if re.active then
            local name = GetTradeSkillInfo(id)
            if name ~= re.recipe then
                stopRepeat(L("Переналожение остановлено: сменён рецепт.", "Re-enchanting stopped: recipe changed."))
            end
        end
        updateRepeat()
    end)
    if TradeSkillFrame_Update then hooksecurefunc("TradeSkillFrame_Update", updateRepeat) end
    TradeSkillFrame:HookScript("OnHide", function()
        stopRepeat(L("Переналожение остановлено: окно профессии закрыто.", "Re-enchanting stopped: profession window closed."))
    end)
    updateRepeat()
end

----------------------------------------------------------------------------------------------------------
-- Session key: one key drives whichever session runs. It is an override binding (cleared outside sessions
-- and before combat), so each press is a hardware click on the button it points at this frame:
--   disenchant run          -> the secure disenchant button (its PreClick ignores presses while busy);
--   REPLACE_ENCHANT shown   -> Blizzard's own "Yes" (StaticPopupNButton1);
--   repeat waits for a press -> the repeat button ("Next");
--   anything else            -> a no-op sink, so spamming the key never jumps and interrupts the cast.
----------------------------------------------------------------------------------------------------------
local keyOwner = CreateFrame("Frame", "ForeverStockUIEnchantKeyOwner", UIParent)
local keySink = CreateFrame("Button", "ForeverStockUIEnchantKeySink", UIParent)
keySink:SetSize(1, 1)
keySink:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
keySink:Show()
local boundKey, boundTarget

local function sessionKey()
    local key = setting("enchantKey", "SPACE")
    if type(key) ~= "string" or key == "" or key == "NONE" then return end
    return key
end

function E.KeyLabel()
    local key = sessionKey()
    if not key then return end
    return (GetBindingText and GetBindingText(key, "KEY_")) or key
end

-- StaticPopup_Visible returns the dialog name (3.3.5) or the dialog itself.
local function popupButton(which)
    local dialog = popupVisible(which)
    if type(dialog) == "table" then dialog = dialog.GetName and dialog:GetName() end
    if type(dialog) == "string" then return dialog .. "Button1" end
end

local function keyTarget()
    if de.mode == "run" and secure and secure:IsShown() then return "ForeverStockUIDisenchantSecure" end
    if re.active then
        local accept = setting("enchantKeyConfirm", true) and popupButton("REPLACE_ENCHANT")
        if accept then return accept end
        if re.phase == "wait_click" then return "ForeverStockUIReenchantButton" end
        return "ForeverStockUIEnchantKeySink"
    end
end

local function bindKey(target)
    if InCombatLockdown() then return end
    local key = target and sessionKey()
    if key == boundKey and (key and target) == boundTarget then return end
    ClearOverrideBindings(keyOwner)
    boundKey, boundTarget = key, key and target
    if key then SetOverrideBindingClick(keyOwner, true, key, target, "LeftButton") end
end
E.BoundKey = function() return boundKey, boundTarget end

----------------------------------------------------------------------------------------------------------
-- Wiring
----------------------------------------------------------------------------------------------------------
driver:SetScript("OnUpdate", function(self)
    local now = GetTime()
    if dirty then refreshOverlays() end
    disenchantTick(now)
    repeatTick(now)
    if de.mode == "idle" and not re.active then
        bindKey(nil)
        self:Hide()
    else
        bindKey(keyTarget())
        if re.active then updateRepeat() end
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, a, b)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        createControl()
        if TradeSkillFrame then createRepeat() end
        hooksecurefunc("PickupContainerItem", function(bag, slot) captured("bag", bag, slot) end)
        hooksecurefunc("UseContainerItem", function(bag, slot) captured("bag", bag, slot) end)
        hooksecurefunc("PickupInventoryItem", function(slot) captured("inv", slot) end)
        hooksecurefunc("UseInventoryItem", function(slot) captured("inv", slot) end)
        for _, name in ipairs({ "BAG_UPDATE", "ITEM_LOCK_CHANGED", "PLAYER_REGEN_DISABLED", "SPELLS_CHANGED",
            "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
            "UNIT_SPELLCAST_INTERRUPTED", "LOOT_OPENED", "LOOT_CLOSED", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE",
            "TRADE_SKILL_CLOSE", "UNIT_INVENTORY_CHANGED", "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
            self:RegisterEvent(name)
        end
        return
    elseif event == "ADDON_LOADED" then
        if a == "Blizzard_TradeSkillUI" and ctrl then createRepeat() end
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Handlers of this event still run before the lockdown: the last moment to clear the secure button.
        if de.mode ~= "idle" then
            setSecure(nil)
            if secure then secure:Hide() end
            stopDisenchant(L("Распыление остановлено: начался бой.", "Disenchanting stopped: entering combat."))
        end
        stopRepeat(L("Переналожение остановлено: бой.", "Re-enchanting stopped: combat."))
        bindKey(nil)
        return
    elseif event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
        if a ~= addonName then return end
        E.blocked = tostring(b)
        -- The client refused DoTradeSkill outside a click: remember it and stay on one press per repeat.
        if E.blocked:find("DoTradeSkill", 1, true) then
            ui.Settings().enchantAutoChainBlocked = true
            if re.active then
                re.stepMode = true
                if re.phase == "next" or re.phase == "casting" then re.phase = "wait_click" end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffe8c27aForever UI|r enchanting: client blocked " .. E.blocked
            .. " - switched to key press per step")
        return
    elseif event == "SPELLS_CHANGED" then
        updateControl()
        return
    elseif event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        if de.mode ~= "idle" then markDirty() end
        return
    end
    disenchantEvent(event, a, b)
    repeatEvent(event, a, b)
end)

function E.Apply()
    if not enabled("enchantDisenchantButton") then stopDisenchant() end
    if not enabled("enchantReenchant") then stopRepeat(nil, true) end
    placeControl()
    updateRepeat()
end

E.StartSelect = enterSelect
E.Stop = function() stopDisenchant(); stopRepeat(nil, true) end

-- Diagnostics in ASCII (the client chat font shows addon Cyrillic as "?").
SLASH_FOREVERUIENCHANT1 = "/fuienchant"
SlashCmdList.FOREVERUIENCHANT = function(msg)
    if msg == "de" then return enterSelect() end
    local host = bagHost()
    local p = function(s) DEFAULT_CHAT_FRAME:AddMessage("|cffe8c27aForever UI|r " .. s) end
    p(("disenchant known=%s spell=%s"):format(tostring(knowsSpell(DISENCHANT_ID)), tostring(GetSpellInfo(DISENCHANT_ID) ~= nil)))
    p(("bag host=%s combined=%s mode=%s queue=%d phase=%s"):format(host and (host:GetName() or "?") or "none",
        tostring(ui.Bags and ui.Bags.Window and ui.Bags.Window() ~= nil), de.mode, #de.queue, tostring(de.phase)))
    p(("tradeskill enchanting=%s repeat active=%s phase=%s done=%d/%d stepMode=%s target=%s"):format(
        tostring(isEnchanting()), tostring(re.active), tostring(re.phase), re.done, re.total, tostring(re.stepMode),
        re.target and (re.target.type .. " " .. (re.target.bag or "") .. " " .. re.target.slot) or "none"))
    p(("free slots=%d key=%s bound=%s blocked=%s autoChainBlocked=%s"):format(E.FreeSlots(), tostring(sessionKey()),
        tostring(boundTarget), tostring(E.blocked), tostring(setting("enchantAutoChainBlocked", false))))
    if msg == "reset" then
        ui.Settings().enchantAutoChainBlocked = nil
        p("auto chain block flag cleared")
    end
end
