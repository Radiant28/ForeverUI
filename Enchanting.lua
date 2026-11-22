local addonName, ui = ...
-- Enchanting helpers: (1) disenchant and prospect buttons in the bags: the spell's cursor, with every item it
-- cannot take dimmed while it is up; (2) repeat the selected enchant on one remembered item N times; while that
-- session runs the session key presses "Yes" on REPLACE_ENCHANT.
--
-- Protected-API notes (3.3.5a):
--  * Casting a spell from addon code is forbidden; it needs a hardware event on a secure button. Disenchant
--    and Prospecting therefore go through ForeverStockUIDisenchantSecure / ForeverStockUIProspectSecure
--    (SecureActionButtonTemplate, type "spell"). The secure buttons are parented to UIParent and only *placed*
--    over the bag buttons by absolute coordinates, so the bag window never gets protected children or anchors.
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
-- Feature 1: disenchant and prospect buttons in the bags
----------------------------------------------------------------------------------------------------------
-- A click on a button casts its spell like the spellbook does: the cursor waits for an item and the player
-- clicks it. The cast needs a hardware click on a secure button, so a secure spell button
-- (ForeverStockUI<Name>Secure) lies over each visible one. While a cursor is up (from the button or the
-- spellbook) every bag item that spell cannot take is dimmed; the dim layer takes no clicks.
-- Disenchant sits next to the close cross, Prospecting left of it; a spell the player does not know has no
-- button, and the other one moves up to the cross.
local PROSPECT_ID, JEWELCRAFTING_ID = 31252, 25229
-- Ores that Prospecting takes (five per cast).
local PROSPECT_ORES = { [2770] = true, [2771] = true, [2772] = true, [3858] = true, [10620] = true,
    [23424] = true, [23425] = true, [36909] = true, [36912] = true, [36910] = true }
E.prospectOres = PROSPECT_ORES

function E.CanProspect(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return false end
    local id = tonumber(link:match("item:(%d+)"))
    if not (id and PROSPECT_ORES[id]) then return false, link end
    local _, count = GetContainerItemInfo(bag, slot)
    return (count or 0) >= 5, link
end

local de = { dimmed = false, key = "disenchant", spell = DISENCHANT_ID, profession = ENCHANTING_ID,
    frame = "Disenchant", setting = "enchantDisenchantButton", can = E.CanDisenchant,
    icon = "Interface\\Icons\\INV_Enchant_Disenchant", fallbackName = "Disenchant", professionName = "Enchanting",
    combatText = { "В бою кнопка распыления недоступна.", "The disenchant button is not available in combat." },
    hint = { "Клик — затем кликните по предмету. Предметы, которые нельзя распылить, затемняются.",
        "Click, then click an item. Items that cannot be disenchanted are dimmed." } }
local pr = { dimmed = false, key = "prospect", spell = PROSPECT_ID, profession = JEWELCRAFTING_ID,
    frame = "Prospect", setting = "enchantProspectButton", can = E.CanProspect,
    icon = "Interface\\Icons\\INV_Misc_Gem_Bloodgem_01", fallbackName = "Prospecting", professionName = "Jewelcrafting",
    combatText = { "В бою кнопка просеивания недоступна.", "The prospecting button is not available in combat." },
    hint = { "Клик — затем кликните по руде (нужно 5 штук). Остальные предметы затемняются.",
        "Click, then click an ore (5 needed). Everything else is dimmed." } }
E.disenchant, E.prospect = de, pr
-- Right to left from the close cross.
local tools = { de, pr }
local overlays = {}
local ctrl, dimTool
local GAP = 3

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

-- The frame the controls live on: the combined backpack, else the stock backpack container.
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

-- The cursor waits for a target of this tool's spell (cast from its button, or from the spellbook).
local function toolTargeting(tool)
    if not SpellIsTargeting() then return false end
    if tool.armed then return true end
    local name = spellName(tool.spell)
    return (name and IsCurrentSpell and IsCurrentSpell(name)) and true or false
end
local function disenchantTargeting() return toolTargeting(de) end
E.DisenchantTargeting = disenchantTargeting
E.ProspectTargeting = function() return toolTargeting(pr) end

-- The tool whose cursor is up dims the bags (one cursor at a time).
local function refreshDim()
    de.dirty, pr.dirty = nil, nil
    -- Stock container buttons are reused for other bags, so every layer is hidden and re-bound each pass.
    for _, overlay in pairs(overlays) do overlay:Hide() end
    if not dimTool then return end
    local can = dimTool.can
    eachBagButton(function(button, bag, slot)
        local overlay = E.Overlay(button)
        local link = GetContainerItemLink(bag, slot)
        overlay.dim:SetAlpha((link and not can(bag, slot)) and 0.7 or 0)
        overlay:Show()
    end)
end
E.RefreshDim = refreshDim

local function setSecure(tool)
    local secure = tool.secure
    if not secure or InCombatLockdown() then return end
    if knowsSpell(tool.spell) then
        secure:SetAttribute("type", "spell")
        secure:SetAttribute("spell", spellName(tool.spell))
    else
        secure:SetAttribute("type", nil)
        secure:SetAttribute("spell", nil)
    end
end

local function updateControl()
    for _, tool in ipairs(tools) do
        if tool.button then
            local known = knowsSpell(tool.spell)
            tool.iconTexture:SetDesaturated(not known)
            if known then tool.button:Enable() else tool.button:Disable() end
            setSecure(tool)
        end
    end
end

-- Keep each secure button exactly over its visible one (absolute UIParent coordinates, never an anchor: the
-- bag window must not get protected children). Shown only out of combat, while the visible button is.
local function syncOne(tool)
    local secure, button = tool.secure, tool.button
    if not secure or InCombatLockdown() then return end
    if not (button and button:IsVisible() and knowsSpell(tool.spell)) then
        if secure:IsShown() then secure:Hide() end
        return
    end
    local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = button:GetLeft(), button:GetBottom()
    if not x then return end
    x, y = x * scale, y * scale
    local w, h = button:GetWidth() * scale, button:GetHeight() * scale
    local placed = tool.placed
    if placed.x ~= x or placed.y ~= y or placed.w ~= w or placed.h ~= h then
        placed.x, placed.y, placed.w, placed.h = x, y, w, h
        secure:ClearAllPoints()
        secure:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
        secure:SetSize(w, h)
    end
    if not secure:IsShown() then secure:Show() end
end
local function syncSecure()
    for _, tool in ipairs(tools) do syncOne(tool) end
end

-- The close cross of the bag window: the buttons sit just left of it, in its size (the header row has room
-- there: the title keeps 44 px from the edge).
local function closeButton(host)
    local close = ui.Bags and ui.Bags.CloseButton and ui.Bags.CloseButton()
    if close then return close, false end
    close = host and _G[(host:GetName() or "") .. "CloseButton"]
    return close, true
end

local function toolShown(tool)
    return tool.button ~= nil and enabled(tool.setting) and knowsSpell(tool.spell)
end

-- Lay the shown buttons out right to left inside the control (a moved button also moves its secure cover:
-- syncSecure compares the coordinates every tick).
local function layoutButtons(size)
    local x = 0
    for _, tool in ipairs(tools) do
        local button = tool.button
        if button then
            if toolShown(tool) then
                button:ClearAllPoints()
                button:SetPoint("RIGHT", ctrl, "RIGHT", -x, 0)
                button:Show()
                x = x + size + GAP
            else
                button:Hide()
            end
        end
    end
end

-- The WoW Forever window skin draws its frame over every inner frame of the bag and lifts only the cross above
-- it (WindowSkin.lua, lift(close)); the buttons go to the cross's level, or the frame hides them (only the
-- secure button over one answered: its tooltip showed, the icon did not). Checked again every tick, since the
-- skin may lift the cross after the buttons were placed.
-- The buttons take the cross's size. The window skin resizes the cross (WindowSkin.lua, skinClose) after the
-- bag opened or when its scale option changes, so the size is checked again whenever the cross changes and on
-- every tick; reading it only on OnShow left the button at the old cross's size ("the button sometimes grows").
local function fitSize(close, stock)
    local height = close and close:GetHeight() or 0
    if height < 8 then height = 18 end
    -- 0.85 of the ForeverUI bag's cross: a little smaller than the cross itself.
    local size = math.floor(height * (stock and 0.6 or 0.85) + 0.5)
    local count, key = 0, ""
    for _, tool in ipairs(tools) do
        if toolShown(tool) then count, key = count + 1, key .. tool.key end
    end
    local width = math.max(1, count) * size + math.max(0, count - 1) * GAP
    local changed = ctrl.layoutKey ~= key or math.abs((ctrl:GetHeight() or 0) - size) > 0.01
        or math.abs((ctrl:GetWidth() or 0) - width) > 0.01
    for _, tool in ipairs(tools) do
        local button = tool.button
        if button and (math.abs((button:GetHeight() or 0) - size) > 0.01
            or math.abs((button:GetWidth() or 0) - size) > 0.01) then
            changed = true
        end
    end
    if changed then
        ctrl.layoutKey = key
        ctrl:SetSize(width, size)
        for _, tool in ipairs(tools) do if tool.button then tool.button:SetSize(size, size) end end
        layoutButtons(size)
    end
end

local sizeHooked = {}
local function watchClose(close, stock)
    if not close or sizeHooked[close] or not close.HookScript then return end
    sizeHooked[close] = true
    close:HookScript("OnSizeChanged", function(self)
        if ctrl and ctrl:IsShown() and closeButton(ctrl:GetParent()) == self then
            fitSize(self, stock)
            syncSecure()
        end
    end)
end

function E.Raise()
    if not (ctrl and ctrl:IsShown()) then return end
    local close, stock = closeButton(ctrl:GetParent())
    if not close then return end
    fitSize(close, stock)
    local level = close:GetFrameLevel() or 0
    local strata = close:GetFrameStrata()
    if ctrl:GetFrameStrata() ~= strata then ctrl:SetFrameStrata(strata) end
    if (ctrl:GetFrameLevel() or 0) < level then ctrl:SetFrameLevel(level) end
    for _, tool in ipairs(tools) do
        local button = tool.button
        if button then
            if button:GetFrameStrata() ~= strata then button:SetFrameStrata(strata) end
            if (button:GetFrameLevel() or 0) <= level then button:SetFrameLevel(level + 1) end
        end
    end
end

local function placeControl()
    if not ctrl then return end
    local host = bagHost()
    local any = false
    for _, tool in ipairs(tools) do if toolShown(tool) then any = true end end
    -- No profession: no button for it (it comes back with SPELLS_CHANGED once the profession is learned).
    if not host or not any then
        ctrl:Hide()
        updateControl()
        syncSecure()
        return
    end
    local close, stock = closeButton(host)
    ctrl.layoutKey = nil
    -- The stock cross is a 32 px texture with a smaller glyph in it.
    fitSize(close, stock)
    watchClose(close, stock)
    ctrl:SetParent(host)
    ctrl:ClearAllPoints()
    ctrl:Show()
    if close then
        -- A gap from the cross, so a click meant for the button does not close the bag.
        ctrl:SetPoint("RIGHT", close, "LEFT", stock and -2 or -9, stock and 0 or -2)
        E.Raise()
    else
        ctrl:SetPoint("TOPRIGHT", host, "TOPRIGHT", -30, -6)
        ctrl:SetFrameLevel(host:GetFrameLevel() + 3)
    end
    updateControl()
    syncSecure()
    driver:Show()
end

local function hostHidden()
    syncSecure()
end

local function tooltipFor(tool)
    return function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(spellName(tool.spell) or tool.fallbackName)
        if not knowsSpell(tool.spell) then
            GameTooltip:AddLine((L("Нужна профессия «%s».", "Requires %s.")):format(spellName(tool.profession)
                or tool.professionName), 1, 0.3, 0.3)
        else
            GameTooltip:AddLine(L(tool.hint[1], tool.hint[2]), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end
end

local function createSecure(tool)
    local secure = CreateFrame("Button", "ForeverStockUI" .. tool.frame .. "Secure", UIParent, "SecureActionButtonTemplate")
    tool.secure, tool.placed = secure, {}
    secure:SetFrameStrata("TOOLTIP")
    secure:RegisterForClicks("LeftButtonUp")
    secure:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    secure:Hide()
    -- The cast itself is the secure action ("spell" without a target): the cursor then waits for an item.
    secure:SetScript("PreClick", function()
        for _, other in ipairs(tools) do other.armed = nil end
        tool.armed, tool.armedAt = true, GetTime()
        driver:Show()
    end)
    secure:SetScript("OnEnter", tooltipFor(tool))
    secure:SetScript("OnLeave", GameTooltip_Hide)
    setSecure(tool)
end

local function createButton(tool)
    local button = CreateFrame("Button", "ForeverStockUI" .. tool.frame .. "Button", ctrl)
    tool.button = button
    button:SetSize(18, 18)
    button:SetPoint("RIGHT", ctrl, "RIGHT", 0, 0)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local icon = button:CreateTexture(nil, "ARTWORK")
    tool.iconTexture = icon
    -- A little inside the button, so it weighs like the cross next to it.
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    icon:SetTexture(select(3, GetSpellInfo(tool.spell)) or tool.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Reached only while the secure button is not over it (combat).
    button:SetScript("OnClick", function()
        if InCombatLockdown() then say(L(tool.combatText[1], tool.combatText[2]), true) end
    end)
    button:SetScript("OnEnter", tooltipFor(tool))
    button:SetScript("OnLeave", GameTooltip_Hide)
    createSecure(tool)
end

local function createControl()
    ctrl = CreateFrame("Frame", "ForeverStockUIDisenchantControl", UIParent)
    ctrl:SetSize(18, 18)
    ctrl:Hide()
    for _, tool in ipairs(tools) do createButton(tool) end

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
    E.Raise()
    syncSecure()
    local want
    for _, tool in ipairs(tools) do
        -- The cast from the button may take a moment to bring the cursor up; after that "armed" ends with it.
        if tool.armed and not SpellIsTargeting() and now - (tool.armedAt or 0) > 0.5 then tool.armed = nil end
        local on = toolTargeting(tool) and not want
        tool.dimmed = on
        if on then want = tool end
    end
    if want ~= dimTool then
        dimTool = want
        refreshDim()
    elseif de.dirty or pr.dirty then
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
        reButton:SetText((L("Повторить x%d", "Repeat x%d")):format(repeatCount()))
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
            stopRepeat(nil, true)
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
    -- Runs while a repeat session, a disenchant/prospect cursor or the bag buttons (their secure covers follow
    -- them) are up.
    local busy = re.active or dimTool or de.armed or pr.armed or (ctrl and ctrl:IsVisible())
    for _, tool in ipairs(tools) do
        if tool.secure and tool.secure:IsShown() then busy = true end
    end
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
        for _, tool in ipairs(tools) do
            if tool.secure then tool.secure:Hide() end
            tool.armed = nil
        end
        stopRepeat(L("Переналожение остановлено: бой.", "Re-enchanting stopped: combat."))
        bindKey(nil)
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        placeControl()
        return
    elseif event == "CURRENT_SPELL_CAST_CHANGED" then
        -- Disenchant or Prospecting from the spellbook brings the cursor up too: the tick dims the bags.
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
        -- Enchanting or Jewelcrafting learned or dropped: its button appears or goes away.
        placeControl()
        return
    elseif event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        if dimTool then dimTool.dirty = true end
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
    p(("prospecting known=%s spell=%s"):format(tostring(knowsSpell(PROSPECT_ID)), tostring(GetSpellInfo(PROSPECT_ID) ~= nil)))
    p(("bag host=%s combined=%s secure de=%s pr=%s targeting de=%s pr=%s dimmed=%s"):format(
        host and (host:GetName() or "?") or "none", tostring(ui.Bags and ui.Bags.Window and ui.Bags.Window() ~= nil),
        tostring(de.secure and de.secure:IsShown()), tostring(pr.secure and pr.secure:IsShown()),
        tostring(disenchantTargeting()), tostring(toolTargeting(pr)), tostring(dimTool and dimTool.key)))
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
