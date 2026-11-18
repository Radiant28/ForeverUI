local addonName, ui = ...
-- Enchanting helpers: (1) a disenchant button in the bags: the disenchant cursor, with every item that cannot be
-- disenchanted dimmed while it is up; (2) repeat the selected enchant on one remembered item N times; while that
-- session runs the session key presses "Yes" on REPLACE_ENCHANT.
--
-- Protected-API notes (3.3.5a):
--  * Casting a spell from addon code is forbidden; it needs a hardware event on a secure button. Disenchant
--    therefore goes through ForeverStockUIDisenchantSecure (SecureActionButtonTemplate, type "spell"). The
--    secure button is parented to UIParent and only *placed* over the bag button by absolute coordinates, so
--    the bag window never gets protected children or anchors.
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
    -- Returns the dialog's frame name (the session key presses its first button).
    local name = StaticPopup_Visible and StaticPopup_Visible(which)
    if name then return name end
    -- Clients may give the enchant popups their own names: any shown dialog about an enchant counts.
    for i = 1, STATICPOPUP_NUMDIALOGS or 4 do
        local popup = _G["StaticPopup" .. i]
        local kind = popup and popup:IsShown() and popup.which
        if type(kind) == "string" and kind:find("ENCHANT", 1, true)
            and ((which == "REPLACE_ENCHANT" and kind:find("REPLACE", 1, true))
                or (which == "BIND_ENCHANT" and kind:find("BIND", 1, true))) then
            return "StaticPopup" .. i
        end
    end
    return false
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

local skipSlots = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true,
    INVTYPE_AMMO = true }

-- Returns ok, link. Uncommon..epic weapons and armour only: an item with an equipment slot (ForeverUI does not
-- touch the auction house, so its class list is not used); shirts, tabards, bags, ammo and quest items are out.
function E.CanDisenchant(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return false end
    local _, _, quality, _, _, _, _, _, equipLoc = GetItemInfo(link)
    if not quality or quality < 2 or quality > 4 then return false, link end
    if type(equipLoc) ~= "string" or equipLoc == "" or skipSlots[equipLoc] then return false, link end
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
-- Feature 1: disenchant button in the bags
----------------------------------------------------------------------------------------------------------
-- A click on the button casts Disenchant like the spell from the spellbook: the cursor waits for an item and
-- the player clicks it. The cast needs a hardware click on a secure button, so a secure spell button
-- (ForeverStockUIDisenchantSecure) lies over the visible one. While the disenchant cursor is up (from this
-- button or the spellbook) every bag item that cannot be disenchanted is dimmed; the dim layer takes no clicks.
local de = { dimmed = false }
E.disenchant = de
local overlays = {}
local ctrl, deButton, deIcon, secure

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

-- The dim layer of a bag cell: a plain frame that takes no mouse, so the click reaches the item underneath.
function E.Overlay(button)
    local overlay = overlays[button]
    if overlay then return overlay end
    overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 6)
    overlay:EnableMouse(false)
    overlay.dim = overlay:CreateTexture(nil, "OVERLAY")
    overlay.dim:SetTexture(white)
    overlay.dim:SetVertexColor(0, 0, 0)
    overlay.dim:SetPoint("TOPLEFT", overlay, "TOPLEFT", 2, -2)
    overlay.dim:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -2, 2)
    overlay.dim:SetAlpha(0)
    overlay:Hide()
    overlays[button] = overlay
    return overlay
end

-- The cursor waits for a disenchant target (cast from the button, or Disenchant from the spellbook).
local function disenchantTargeting()
    if not SpellIsTargeting() then return false end
    if de.armed then return true end
    local name = spellName(DISENCHANT_ID)
    return (name and IsCurrentSpell and IsCurrentSpell(name)) and true or false
end
E.DisenchantTargeting = disenchantTargeting

local function refreshDim()
    de.dirty = nil
    -- Stock container buttons are reused for other bags, so every layer is hidden and re-bound each pass.
    for _, overlay in pairs(overlays) do overlay:Hide() end
    if not de.dimmed then return end
    eachBagButton(function(button, bag, slot)
        local overlay = E.Overlay(button)
        local link = GetContainerItemLink(bag, slot)
        overlay.dim:SetAlpha((link and not E.CanDisenchant(bag, slot)) and 0.7 or 0)
        overlay:Show()
    end)
end
E.RefreshDim = refreshDim

local function setSecure()
    if not secure or InCombatLockdown() then return end
    if knowsSpell(DISENCHANT_ID) then
        secure:SetAttribute("type", "spell")
        secure:SetAttribute("spell", spellName(DISENCHANT_ID))
    else
        secure:SetAttribute("type", nil)
        secure:SetAttribute("spell", nil)
    end
end

local function updateControl()
    if not deButton then return end
    local known = knowsSpell(DISENCHANT_ID)
    deIcon:SetDesaturated(not known)
    if known then deButton:Enable() else deButton:Disable() end
    setSecure()
end

-- Keep the secure button exactly over the visible one (absolute UIParent coordinates, never an anchor: the
-- bag window must not get protected children). Shown only out of combat, while the visible button is.
local placed = {}
local function syncSecure()
    if not secure or InCombatLockdown() then return end
    if not (deButton and deButton:IsVisible() and knowsSpell(DISENCHANT_ID)) then
        if secure:IsShown() then secure:Hide() end
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
    if not secure:IsShown() then secure:Show() end
end

local function placeControl()
    if not ctrl then return end
    local host, footer = bagHost()
    if not host or not enabled("enchantDisenchantButton") then
        ctrl:Hide()
        syncSecure()
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
    syncSecure()
    driver:Show()
end

local function hostHidden()
    syncSecure()
end

local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(spellName(DISENCHANT_ID) or "Disenchant")
    if not knowsSpell(DISENCHANT_ID) then
        GameTooltip:AddLine((L("Нужна профессия «%s».", "Requires %s.")):format(spellName(ENCHANTING_ID) or "Enchanting"),
            1, 0.3, 0.3)
    else
        GameTooltip:AddLine(L("Клик — затем кликните по предмету. Предметы, которые нельзя распылить, затемняются.",
            "Click, then click an item. Items that cannot be disenchanted are dimmed."), 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function createSecure()
    secure = CreateFrame("Button", "ForeverStockUIDisenchantSecure", UIParent, "SecureActionButtonTemplate")
    secure:SetFrameStrata("TOOLTIP")
    secure:RegisterForClicks("LeftButtonUp")
    secure:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    secure:Hide()
    -- The cast itself is the secure action ("spell" without a target): the cursor then waits for an item.
    secure:SetScript("PreClick", function()
        de.armed, de.armedAt = true, GetTime()
        driver:Show()
    end)
    secure:SetScript("OnEnter", showTooltip)
    secure:SetScript("OnLeave", GameTooltip_Hide)
    setSecure()
end

local function createControl()
    ctrl = CreateFrame("Frame", "ForeverStockUIDisenchantControl", UIParent)
    ctrl:SetSize(18, 18)
    ctrl:Hide()
    deButton = CreateFrame("Button", "ForeverStockUIDisenchantButton", ctrl)
    deButton:SetSize(18, 18)
    deButton:SetPoint("LEFT", ctrl, "LEFT", 0, 0)
    deButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    deIcon = deButton:CreateTexture(nil, "ARTWORK")
    deIcon:SetAllPoints(deButton)
    deIcon:SetTexture(select(3, GetSpellInfo(DISENCHANT_ID)) or "Interface\\Icons\\INV_Enchant_Disenchant")
    deIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Reached only while the secure button is not over it (combat).
    deButton:SetScript("OnClick", function()
        if InCombatLockdown() then
            say(L("В бою кнопка распыления недоступна.", "The disenchant button is not available in combat."), true)
        end
    end)
    deButton:SetScript("OnEnter", showTooltip)
    deButton:SetScript("OnLeave", GameTooltip_Hide)
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

local function disenchantTick(now)
    syncSecure()
    -- The cast from the button may take a moment to bring the cursor up; after that "armed" ends with it.
    if de.armed and not SpellIsTargeting() and now - (de.armedAt or 0) > 0.5 then de.armed = nil end
    local want = disenchantTargeting()
    if want ~= de.dimmed then
        de.dimmed = want
        refreshDim()
    elseif de.dirty then
        refreshDim()
    end
end

----------------------------------------------------------------------------------------------------------
-- Feature 2: repeat an enchant on one item
----------------------------------------------------------------------------------------------------------
-- phase: "picking" (cursor waits for the user's one target click) | "casting" (target applied, waiting for
-- the cast; a REPLACE_ENCHANT/BIND_ENCHANT popup may sit in between) | "channel" (cast bar running) |
-- "next" (auto-chain delay) | "wait_click" (client needs a click for each repeat)
local re = { active = false, done = 0, total = 1 }
-- Seconds the cast may take to start after the target is applied (Nozdor answers with some lag).
local CAST_WAIT = 3

-- What happened since the last repeat started (client errors, cast events, popups), told when a repeat fails.
local function trace(text)
    re.trace = re.trace or {}
    if #re.trace < 12 then re.trace[#re.trace + 1] = text end
end
local function shownPopups()
    local list = {}
    for i = 1, STATICPOPUP_NUMDIALOGS or 4 do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsShown() then list[#list + 1] = tostring(popup.which) end
    end
    return #list > 0 and table.concat(list, ",") or "-"
end
local function traceText()
    return " [" .. table.concat(re.trace or {}, "; ") .. "; popups: " .. shownPopups() .. "; targeting: "
        .. tostring(SpellIsTargeting() and true or false) .. "]"
end
E.TraceText = traceText
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

-- The count follows the number of enchants the reagents allow, until the player sets it by hand for this recipe.
local manualRecipe

local function autoCount(name, available)
    if re.active or not name or manualRecipe == name or (available or 0) < 1 then return end
    local want = math.min(99, available)
    if repeatCount() ~= want then ui.Settings().enchantRepeatCount = want end
    if reCount and not (reCount.HasFocus and reCount:HasFocus()) then reCount:SetText(want) end
end
E.AutoCount = autoCount

local function updateRepeat()
    if not reRow then return end
    local index, recipe, available, verb = selectedRecipe()
    if index and verb then autoCount(recipe, available) end
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
    -- With the replace or bind dialog up the cursor is left alone: stopping it from addon code closes Blizzard's
    -- dialog from tainted code, and the client blocks ForeverUI (checked in game). The dialog stays to the player.
    if SpellIsTargeting() and not popupVisible("REPLACE_ENCHANT") and not popupVisible("BIND_ENCHANT") then
        SpellStopTargeting()
    end
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
    trace(("target %s %s: targeting=%s"):format(target.type == "inv" and "inv" or tostring(target.bag), tostring(target.slot),
        tostring(SpellIsTargeting() and true or false)))
    -- Safety: if targeting had ended, Pickup* would have put the item on the cursor; put it back.
    if CursorHasItem() then ClearCursor() end
end

-- The macro line that uses the remembered item: with an enchant waiting for its target it applies the enchant.
local function useText(target)
    if target.type == "inv" then return "/use " .. target.slot end
    return "/use " .. target.bag .. " " .. target.slot
end
E.UseText = useText
-- True while the repeat button's PreClick runs: its secure action can apply the target.
local secureClick = false

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
    re.trace = {}
    trace(fromClick and "press" or "auto")
    DoTradeSkill(index, 1)
    trace("DoTradeSkill: targeting=" .. tostring(SpellIsTargeting() and true or false))
    -- Enchants on items open the targeting cursor synchronously; no cursor means the client refused the call.
    if not SpellIsTargeting() then
        if fromClick then
            stopRepeat(L("Клиент не начал наложение чар.", "The client did not start the enchant."))
        end
        return false
    end
    if re.target and secureClick then
        -- Nozdor ignores a target set by addon code (the cursor closes, nothing is cast): the press's own secure
        -- action uses the item instead ("/use bag slot" on the repeat button, see its PreClick), like a macro.
        re.secureUse = useText(re.target)
        trace("target by /use")
        re.phase, re.castStarted, re.auto = "casting", GetTime(), false
    elseif re.target then
        applyTarget()
        if SpellIsTargeting() and not awaitingConfirm() then
            SpellStopTargeting()
            return stopRepeat(L("Эти чары нельзя наложить на выбранный предмет.", "This enchant cannot go on the remembered item."))
        end
        re.phase, re.castStarted, re.auto = "casting", GetTime(), not fromClick
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
    re.phase, re.castStarted, re.auto = "casting", GetTime(), false
    say((L("Цель запомнена: %s", "Target remembered: %s")):format(target.link))
    updateRepeat()
end


local function repeatTick(now)
    if not re.active then return end
    if re.phase == "picking" and not SpellIsTargeting() and now - re.pickStarted > 0.1 then
        stopRepeat(L("Переналожение отменено: цель не выбрана.", "Re-enchanting cancelled: no target picked."))
    elseif re.phase == "casting" and now - re.castStarted > CAST_WAIT then
        -- Waiting on a confirmation the user has to give (bind on enchant, or replace with auto-confirm off)?
        if popupVisible("BIND_ENCHANT") or popupVisible("REPLACE_ENCHANT") then
            re.castStarted = now
        elseif re.auto and not re.stepMode then
            -- A repeat the addon started by itself was dropped silently by the client (the target taken from an
            -- OnUpdate is ignored here). The session goes on with a press per repeat: the button or the session key.
            if SpellIsTargeting() then SpellStopTargeting() end
            re.stepMode, re.phase = true, "wait_click"
            -- Remembered: later sessions go by presses at once (/fuienchant reset forgets it).
            ui.Settings().enchantAutoChainBlocked = true
            say(L("Клиент не запустил повтор сам: нажимайте «Дальше» или клавишу сессии.",
                "The client did not start the repeat by itself: press \"Next\" or the session key."), true)
            updateRepeat()
        else
            stopRepeat(L("Переналожение остановлено: наложение не началось.", "Re-enchanting stopped: the enchant did not start.")
                .. traceText())
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
    if re.active and event == "UI_ERROR_MESSAGE" then
        trace("error: " .. tostring(unit))
        return
    end
    if not re.active or unit ~= "player" then return end
    if event:find("^UNIT_SPELLCAST_") then trace(event:sub(16) .. " " .. tostring(spell)) end
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
    -- A secure action button: PreClick runs the session (DoTradeSkill opens the enchant cursor), then the button's
    -- own secure action uses the remembered item ("/use 0 16"), which the client takes as the enchant's target.
    reButton = CreateFrame("Button", "ForeverStockUIReenchantButton", reRow, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    reButton:SetSize(96, 22)
    reButton:SetPoint("RIGHT", TradeSkillCreateButton, "LEFT", -4, 0)
    reButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function clearAction(self)
        if InCombatLockdown() then return end
        self:SetAttribute("type", nil)
        self:SetAttribute("macrotext", nil)
        self:SetAttribute("clickbutton", nil)
    end
    local press
    reButton:SetScript("PreClick", function(self, button)
        clearAction(self)
        re.secureUse, re.clickedYes = nil, nil
        -- The replace dialog is up (the button reads "Space: replace"): a mouse click does what the key does,
        -- it presses Blizzard's own "Yes" through the secure "click" action. Addon code never touches the dialog.
        local dialog = button ~= "RightButton" and re.active and setting("enchantKeyConfirm", true)
            and popupVisible("REPLACE_ENCHANT")
        if dialog and not InCombatLockdown() then
            if type(dialog) == "table" then dialog = dialog.GetName and dialog:GetName() end
            local yes = type(dialog) == "string" and _G[dialog .. "Button1"]
            if yes then
                self:SetAttribute("type", "click")
                self:SetAttribute("clickbutton", yes)
                re.clickedYes = true
                return
            end
        end
        secureClick = true
        local ok, err = pcall(press, button)
        secureClick = false
        if not ok then geterrorhandler()(err) end
        -- Only with the enchant cursor up: "/use" on a shield without it would put the shield on.
        if re.secureUse and SpellIsTargeting() and not InCombatLockdown() then
            self:SetAttribute("type", "macro")
            self:SetAttribute("macrotext", re.secureUse)
        else
            re.secureUse = nil
        end
    end)
    reButton:SetScript("PostClick", function(self)
        if re.clickedYes then
            re.clickedYes = nil
            clearAction(self)
            updateRepeat()
            return
        end
        local used = re.secureUse
        re.secureUse = nil
        clearAction(self)
        if not used or not re.active then return end
        trace("after /use: targeting=" .. tostring(SpellIsTargeting() and true or false))
        if SpellIsTargeting() and not awaitingConfirm() then
            SpellStopTargeting()
            return stopRepeat(L("Эти чары нельзя наложить на выбранный предмет.", "This enchant cannot go on the remembered item.")
                .. traceText())
        end
        updateRepeat()
    end)
    press = function(button)
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
    end
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
        -- Set by hand: this recipe keeps the number until another recipe is picked.
        manualRecipe = select(2, selectedRecipe())
        ui.Settings().enchantRepeatCount = math.max(1, math.min(99, value))
        reCount:SetText(repeatCount())
        updateRepeat()
    end
    plus:SetScript("OnClick", function() setCount(repeatCount() + 1) end)
    minus:SetScript("OnClick", function() setCount(repeatCount() - 1) end)
    reCount:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    reCount:SetScript("OnEditFocusLost", function(self)
        local value = tonumber(self:GetText()) or 1
        if value ~= repeatCount() then setCount(value) else updateRepeat() end
    end)
    reCount:SetScript("OnEscapePressed", function(self) self:SetText(repeatCount()); self:ClearFocus() end)
    reCount:SetText(repeatCount())

    -- Changing the recipe ends the session; the row also hides for recipes that create items (rods, oils),
    -- where the client shows its own "Create all" row in the same place.
    hooksecurefunc("TradeSkillFrame_SetSelection", function(id)
        if GetTradeSkillInfo(id) ~= manualRecipe then manualRecipe = nil end
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
    disenchantTick(now)
    repeatTick(now)
    -- Runs while a repeat session, the disenchant cursor or the bag button (its secure cover follows it) is up.
    local busy = re.active or de.dimmed or de.armed or (secure and secure:IsShown()) or (deButton and deButton:IsVisible())
    if not busy then
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
            "TRADE_SKILL_CLOSE", "UNIT_INVENTORY_CHANGED", "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED",
            "UI_ERROR_MESSAGE", "PLAYER_REGEN_ENABLED", "CURRENT_SPELL_CAST_CHANGED" }) do
            self:RegisterEvent(name)
        end
        return
    elseif event == "ADDON_LOADED" then
        if a == "Blizzard_TradeSkillUI" and ctrl then createRepeat() end
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Handlers of this event still run before the lockdown: the last moment to hide the secure button.
        if secure then secure:Hide() end
        de.armed = nil
        stopRepeat(L("Переналожение остановлено: бой.", "Re-enchanting stopped: combat."))
        bindKey(nil)
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        placeControl()
        return
    elseif event == "CURRENT_SPELL_CAST_CHANGED" then
        -- Disenchant from the spellbook brings the cursor up too: the tick dims the bags.
        driver:Show()
        return
    elseif event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
        if a ~= addonName then return end
        E.blocked = tostring(b)
        if re.active then trace("blocked " .. E.blocked) end
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
        if de.dimmed then de.dirty = true end
        return
    end
    repeatEvent(event, a, b)
end)

function E.Apply()
    if not enabled("enchantReenchant") then stopRepeat(nil, true) end
    placeControl()
    updateRepeat()
end

E.Stop = function() stopRepeat(nil, true) end

-- Diagnostics in ASCII (the client chat font shows addon Cyrillic as "?").
SLASH_FOREVERUIENCHANT1 = "/fuienchant"
SlashCmdList.FOREVERUIENCHANT = function(msg)
    local host = bagHost()
    local p = function(s) DEFAULT_CHAT_FRAME:AddMessage("|cffe8c27aForever UI|r " .. s) end
    p(("disenchant known=%s spell=%s"):format(tostring(knowsSpell(DISENCHANT_ID)), tostring(GetSpellInfo(DISENCHANT_ID) ~= nil)))
    p(("bag host=%s combined=%s secure=%s targeting=%s dimmed=%s"):format(host and (host:GetName() or "?") or "none",
        tostring(ui.Bags and ui.Bags.Window and ui.Bags.Window() ~= nil), tostring(secure and secure:IsShown()),
        tostring(disenchantTargeting()), tostring(de.dimmed)))
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
