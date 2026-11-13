local _, ui = ...
local art = "Interface\\AddOns\\ForeverUI\\Art\\"
local white = "Interface\\Buttons\\WHITE8X8"
local backpackChrome = art .. "Backpack-Chrome"
local backpackIcon = "Interface\\Buttons\\Button-Backpack-Up"
local questBadgeArt = art .. "Quest-Bang"
local backpackEdgeSize = 9
-- Set to false to return to the original bag window art (Backpack-Edge / Backpack-Chrome).
-- Bag window look: "forever" (bronze diamond frame from the WoW Forever backport),
-- "gold" (the previous gold frame) or "classic" (the original ForeverUI art).
local bagSkin = "forever"
local newBagSkin = bagSkin ~= "classic"
-- Extra header height (px) of the "forever" look; the search row and the item grid move down by the same amount.
local headerExtra = bagSkin == "forever" and 7 or 0
local backpackInset = {
    bgFile = white, edgeFile = art .. "UnitFrame-Edge", edgeSize = 3,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local lastBag = NUM_BAG_SLOTS or 4
local settings, inventory, bank
local relayout
local equipmentTooltip
local requirementsByLink = {}
local automatic
local poorColor = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[0] and ITEM_QUALITY_COLORS[0].hex or "|cff9d9d9d"
local requirementPrefixes = {}
for _, template in pairs({
    ITEM_CLASSES_ALLOWED, ITEM_RACES_ALLOWED, ITEM_MIN_LEVEL, ITEM_LEVEL_RANGE, ITEM_LEVEL_RANGE_CURRENT,
    ITEM_MIN_SKILL, ITEM_REQ_SKILL, ITEM_REQ_REPUTATION,
}) do
    local prefix = template:match("^(.-)%%") or template
    if prefix ~= "" then requirementPrefixes[#requirementPrefixes + 1] = prefix end
end

local cyrillicLower = { ["Ё"] = "ё" }
for index = 0, 31 do
    cyrillicLower[string.char(208, 144 + index)] = string.char(index < 16 and 208 or 209,
        index < 16 and 176 + index or 112 + index)
end

local function searchText(value)
    return (value:gsub("\208[\129\144-\175]", cyrillicLower):gsub("[A-Z]", string.lower))
end

local function updateHighlight(button, isQuest, quality)
    local glow, badge = button.qualityGlow, button.questBadge
    button.questBorder:Hide()
    if button.IconBorder then button.IconBorder:Hide() end
    if quality == 0 and settings.bagsJunkIcon ~= false then button.junk:Show() else button.junk:Hide() end

    if quality and quality > 1 and settings.bagsHighlightRare then
        local r, g, b = GetItemQualityColor(quality)
        glow:SetVertexColor(r, g, b, settings.bagsHighlightBrightness / 100)
        glow:Show()
    else
        glow:Hide()
    end

    if isQuest and settings.bagsHighlightQuest then
        local size = settings.bagsQuestBadgeSize
        badge:SetSize(size / 2, size)
        badge:Show()
    else
        badge:Hide()
    end
end

local function isRedRequirement(line, subtype, slotName)
    if not line then return false end
    local text = line:GetText()
    if not text then return false end
    local r, g, b = line:GetTextColor()
    if r <= 0.65 or g >= 0.30 or b >= 0.30 then return false end
    if text == subtype or text == slotName then return true end
    for _, prefix in ipairs(requirementPrefixes) do
        if text:find(prefix, 1, true) == 1 then return true end
    end
    return false
end

local function cannotEquip(link, requiredLevel, subtype, equipSlot)
    if requiredLevel and requiredLevel > UnitLevel("player") then return true end
    local cached = requirementsByLink[link]
    if cached ~= nil then return cached end

    local tooltip = equipmentTooltip
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:ClearLines()
    tooltip:SetHyperlink(link)
    local lines = tooltip:NumLines()
    local restricted = false
    local name = tooltip:GetName()
    local slotName = _G[equipSlot]
    for index = 2, lines do
        if isRedRequirement(_G[name .. "TextLeft" .. index], subtype, slotName)
            or isRedRequirement(_G[name .. "TextRight" .. index], subtype, slotName) then
            restricted = true
            break
        end
    end
    tooltip:Hide()
    if lines > 1 then requirementsByLink[link] = restricted end
    return restricted
end

local function refreshBag(bag, query)
    if bag.size == 0 then return end
    local id = bag:GetID()
    local durabilityColor = ui.DurabilityLabelColor("bagsDurability")
    local bagIcon = bag.inventorySlot and GetInventoryItemTexture("player", bag.inventorySlot) or backpackIcon
    if id ~= BANK_CONTAINER then ContainerFrame_Update(bag) end
    for i = 1, bag.size do
        local button = bag.items[i]
        if id == BANK_CONTAINER then BankFrameItemButton_Update(button) end
        local background = button.bagBackground
        if button.hasItem then
            background:Hide()
        else
            if background:GetTexture() ~= bagIcon then
                background:SetTexture(bagIcon)
                background:SetDesaturated(true)
            end
            background:Show()
        end
        local link = button.hasItem and GetContainerItemLink(id, i)
        local name, quality, level, requiredLevel, subtype, equipSlot, isQuestItem
        if button.hasItem then
            quality = select(4, GetContainerItemInfo(id, i))
            if link then
                local itemName, _, itemQuality, itemLevel, minimumLevel, _, itemSubtype, _, itemEquipSlot = GetItemInfo(link)
                name, level, requiredLevel, subtype, equipSlot = itemName, itemLevel, minimumLevel, itemSubtype, itemEquipSlot
                if link:sub(1, 10):lower() == poorColor:lower() then
                    quality = 0
                elseif not quality or quality < 0 then
                    quality = itemQuality
                end
            end
            local isQuest, questID, active = GetContainerItemQuestInfo(id, i)
            isQuestItem = isQuest or (questID and not active)
        end
        updateHighlight(button, isQuestItem, quality)
        local gear = equipSlot and equipSlot ~= ""
        if gear and cannotEquip(link, requiredLevel, subtype, equipSlot) then
            button.unusable:Show()
        else
            button.unusable:Hide()
        end
        local showStats = link and (not settings.bagsGearOnly or gear)
        local matches = query == "" or (name and searchText(name):find(query, 1, true))
        button:SetAlpha(matches and 1 or 0.25)
        button.level:SetText(showStats and settings.bagsItemLevel and level and level > 0 and level or "")
        local current, maximum
        if showStats and settings.bagsDurability then
            current, maximum = GetContainerItemDurability(id, i)
        end
        ui.SetDurabilityLabel(button.durability, current, maximum, durabilityColor)
    end
end

local function skinBackpackSlot(button)
    -- Empty slot: the WoW Forever bag cell (bagsitemslot2xc60, dark with a wing; its rounded corners are clear).
    local fill = button:CreateTexture(nil, "BACKGROUND", nil, -2)
    fill:SetTexture(art .. "Forever\\Bag-Slot")
    fill:SetTexCoord(1 / 64, 63 / 64, 1 / 64, 63 / 64)
    fill:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    local edge = button:CreateTexture(nil, "ARTWORK", nil, 2)
    edge:SetTexture(backpackChrome)
    edge:SetTexCoord(0, 0.25, 0, 0.5)
    edge:SetAllPoints(button)
end

local function prepareSlot(button)
    -- The bank's stock background has a fixed size and overlaps resized slots.
    if button.RetailSlotBackground then button.RetailSlotBackground:Hide() end
    local icon = _G[button:GetName() .. "IconTexture"]
    icon:ClearAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:GetNormalTexture():SetAlpha(0)
    skinBackpackSlot(button)
    return icon
end

local function sizeSlot(button, size)
    button:SetSize(size, size)
    local icon = _G[button:GetName() .. "IconTexture"]
    local inset = size * 0.07
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
end

local function createSlot(bag, index)
    local id = bag:GetID()
    local button
    if id == BANK_CONTAINER then
        button = _G["BankFrameItem" .. index]
        button:SetParent(bag)
    else
        button = CreateFrame("Button", bag:GetName() .. "Item" .. index, bag, "ContainerFrameItemButtonTemplate")
    end
    button:SetID(index)
    local icon = prepareSlot(button)
    local background = button:CreateTexture(nil, "BORDER")
    background:SetAllPoints(icon)
    background:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    background:SetAlpha(id == 0 and 0.45 or 0.30)
    background:Hide()
    button.bagBackground = background
    button.level = button:CreateFontString(nil, "OVERLAY")
    button.durability = button:CreateFontString(nil, "OVERLAY")
    local glow = button:CreateTexture(nil, "OVERLAY", nil, -1)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER", icon, "CENTER")
    glow:Hide()
    button.qualityGlow = glow
    local questBorder = _G[button:GetName() .. "IconQuestTexture"]
    questBorder:ClearAllPoints()
    questBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
    questBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    button.questBorder = questBorder
    local badge = button:CreateTexture(nil, "OVERLAY", nil, 2)
    badge:SetTexture(questBadgeArt)
    badge:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    badge:Hide()
    button.questBadge = badge
    if button.HighlightFrame then
        local flash = button.HighlightFrame.NewItemTexture
        if flash then
            flash:ClearAllPoints()
            flash:SetAllPoints(questBorder)
        end
    end
    button.unusable = button:CreateTexture(nil, "ARTWORK", nil, 1)
    button.unusable:SetAllPoints(icon)
    button.unusable:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.unusable:SetVertexColor(0.9, 0.025, 0.015, 0.48)
    button.unusable:Hide()
    button.junk = button:CreateTexture(nil, "OVERLAY", nil, 7)
    button.junk:SetPoint("RIGHT", button, "RIGHT", -1, 0)
    button.junk:SetTexture("Interface\\AddOns\\ForeverUI\\Art\\Bag-Junk")
    button.junk:SetVertexColor(1, 0.85, 0.20)
    button.junk:Hide()
    bag.items[index] = button
    return button
end

local function setChecked(checked)
    MainMenuBarBackpackButton:SetChecked(checked)
    for id = 1, lastBag do
        local button = _G["CharacterBag" .. (id - 1) .. "Slot"]
        if button then button:SetChecked(checked and GetContainerNumSlots(id) > 0) end
    end
end

local function toolbarButton(window, name, relative, label, texture, onClick)
    local button = CreateFrame("Button", window:GetName() .. name, window)
    button:SetFrameLevel(relative:GetFrameLevel())
    button:SetSize(21, 21)
    button:SetPoint("RIGHT", relative, "LEFT", -3, 0)
    skinBackpackSlot(button)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(texture)
    icon:SetTexCoord(0.09, 0.91, 0.09, 0.91)
    icon:SetSize(15, 15)
    icon:SetPoint("CENTER", button, "CENTER")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(label)
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function createInventory(panel, isBank)
    local window, content, money, searchBox, bagTray, buySlot
    local bags, query = {}, ""
    local slotCount = isBank and NUM_BANKBAGSLOTS or lastBag
    local traySlots = isBank and slotCount or slotCount + 1
    local keyring = not isBank and KEYRING_CONTAINER
    local showKeys
    local groupGap = 12
    local toolbarTop, footerHeight = 34 + headerExtra, 34
    local name = isBank and "ForeverStockBank" or "ForeverStockInventory"
    local titleText = ui.russian and "Объединённый рюкзак" or "Combined backpack"
    if isBank then
        titleText = BANK or (ui.russian and "Банк" or "Bank")
    end
    local bagIDs = { isBank and BANK_CONTAINER or 0 }
    for i = 1, slotCount do bagIDs[i + 1] = (isBank and lastBag or 0) + i end
    if keyring then bagIDs[#bagIDs + 1] = keyring end

    local function sizeOf(id)
        if id == BANK_CONTAINER then return NUM_BANKGENERIC_SLOTS end
        if id == keyring then return showKeys and GetKeyRingSize() or 0 end
        return GetContainerNumSlots(id)
    end

    local function closeWindow()
        if isBank then HideUIPanel(BankFrame) else window:Hide() end
    end

    local function inventoryWidth(gridWidth)
        return math.max(300, traySlots * 28 + 24, gridWidth + 24)
    end

    local function chooseColumns(pitch, top, width, height)
        local total, largest, groups = 0, 0, 0
        for _, id in ipairs(bagIDs) do
            local bag = bags[id]
            bag.size = sizeOf(id)
            total = total + bag.size
            largest = math.max(largest, bag.size)
            if bag.size > 0 then groups = groups + 1 end
        end
        local grouped = settings.bagsGrouped
        local gapHeight = grouped and math.max(0, groups - 1) * groupGap or 0
        local longestRow = grouped and largest or total
        local maxColumns = math.max(1, math.min(longestRow, math.floor((width - 20) / pitch)))
        local columns = math.min(settings.bagsColumns, maxColumns)
        local screenRows = math.floor((height - top - footerHeight - gapHeight + 3) / pitch)
        local preferredRows = settings.bagsRows
        local rowLimit = screenRows
        if preferredRows > 0 then rowLimit = math.min(rowLimit, math.max(preferredRows, grouped and groups or 1)) end
        local function rowsFor(count)
            if not grouped then return math.ceil(total / count) end
            local rows = 0
            for _, id in ipairs(bagIDs) do rows = rows + math.ceil(bags[id].size / count) end
            return rows
        end
        while columns < maxColumns and rowsFor(columns) > rowLimit do
            columns = columns + 1
        end
        if rowsFor(columns) > screenRows then
            local bestScale = 0
            for count = columns, longestRow do
                local widthScale = width / inventoryWidth(count * pitch - 4)
                if widthScale <= bestScale then break end
                local neededHeight = top + math.max(1, rowsFor(count) * pitch + gapHeight - 4) + footerHeight
                local scale = math.min(widthScale, height / neededHeight)
                if scale > bestScale then columns, bestScale = count, scale end
            end
        end
        return columns, total
    end

    local function layout()
        local cell = settings.bagsCellSize
        local levelStyle = ui.ItemLabelStyle("bagsLevel", cell)
        local durabilityStyle = ui.ItemLabelStyle("bagsDurability", cell)
        local pitch = cell + 4
        local top = toolbarTop + 30
        bagTray:SetPoint("TOPRIGHT", window, "TOPRIGHT", -10, -top)
        if bagTray:IsShown() then top = top + 32 end
        local availableWidth, availableHeight = GetScreenWidth() - 24, GetScreenHeight() - 24
        local columns, total = chooseColumns(pitch, top, availableWidth, availableHeight)
        local grouped = settings.bagsGrouped
        local x, y = 0, 0
        if not grouped then x = (columns - total % columns) % columns end
        for _, id in ipairs(bagIDs) do
            local bag = bags[id]
            local newGroup = grouped and bag.size > 0 and y > 0
            if bag.separator then
                if newGroup then
                    local lineY = -(y + groupGap / 2 - 2)
                    bag.separator:SetPoint("TOPLEFT", content, "TOPLEFT", 0, lineY)
                    bag.separator:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, lineY)
                    bag.separator:Show()
                else
                    bag.separator:Hide()
                end
            end
            if newGroup then y = y + groupGap end
            for index = 1, bag.size do
                local button = bag.items[index] or createSlot(bag, index)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", content, "TOPLEFT", x * pitch, -y)
                sizeSlot(button, cell)
                local glowSize = cell * 67 / 37
                button.qualityGlow:SetSize(glowSize, glowSize)
                local badgeSize = math.max(15, math.floor(cell * 0.5))
                button.junk:SetSize(badgeSize, badgeSize)
                ui.ApplyItemLabel(button.level, button, levelStyle)
                ui.ApplyItemLabel(button.durability, button, durabilityStyle)
                button:Show()
                x = x + 1
                if x == columns then x, y = 0, y + pitch end
            end
            for index = bag.size + 1, #bag.items do bag.items[index]:Hide() end
            if grouped and x > 0 then x, y = 0, y + pitch end
        end
        if x > 0 then y = y + pitch end
        local gridWidth, gridHeight = columns * pitch - 4, math.max(1, y - 4)
        content:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -top)
        content:SetSize(gridWidth, gridHeight)
        local width = inventoryWidth(gridWidth)
        local height = top + gridHeight + footerHeight
        window:SetScale(math.min(1, availableWidth / width, availableHeight / height))
        window:SetSize(width, height)
    end

    local function refresh()
        if not window:IsShown() then return end
        for _, id in ipairs(bagIDs) do
            if bags[id].size ~= sizeOf(id) then layout(); break end
        end
        for _, id in ipairs(bagIDs) do refreshBag(bags[id], query) end
        if buySlot then
            if GetNumBankSlots() < slotCount then buySlot:Show() else buySlot:Hide() end
        end
        if not isBank and bagTray:IsShown() then
            for _, slot in ipairs(bagTray.slots) do
                if slot.inventoryID then
                    SetItemButtonTexture(slot, GetInventoryItemTexture("player", slot.inventoryID) or slot.emptyTexture)
                end
            end
        end
        money:SetText(GetCoinTextureString(GetMoney()))
    end

    local function open()
        if not CanOpenPanels() then
            if UnitIsDead("player") then NotWhileDeadError() end
            return
        end
        window:Show()
    end

    local function toggleKeys(forceOpen)
        if forceOpen ~= true and IsOptionFrameOpen() then return end
        if window:IsShown() then
            showKeys = forceOpen == true or not showKeys
        else
            open()
            if not window:IsShown() then return end
            showKeys = true
        end
        refresh()
    end

    local function createToolbar(close, panel)
        local ru = ui.russian
        searchBox = CreateFrame("EditBox", name .. "SearchBox", window)
        searchBox:SetPoint("TOPLEFT", window, "TOPLEFT", 58, -toolbarTop)
        searchBox:SetHeight(21)
        searchBox:EnableMouse(true)
        searchBox:SetFontObject(GameFontHighlightSmall)
        searchBox:SetBackdrop(backpackInset)
        searchBox:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
        searchBox:SetBackdropBorderColor(0.67, 0.77, 0.98)
        local magnifier = searchBox:CreateTexture(nil, "OVERLAY")
        magnifier:SetTexture(backpackChrome)
        magnifier:SetTexCoord(132 / 256, 156 / 256, 4 / 128, 28 / 128)
        magnifier:SetSize(12, 12)
        magnifier:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
        magnifier:SetVertexColor(0.6, 0.6, 0.6)

        searchBox:SetTextInsets(22, 6, 0, 0)
        searchBox:SetAutoFocus(false)
        searchBox:SetMaxLetters(64)
        local hint = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        hint:SetPoint("LEFT", searchBox, "LEFT", 22, 0)
        hint:SetText(ru and "Поиск" or "Search")
        searchBox:SetScript("OnEditFocusGained", function() hint:Hide() end)
        searchBox:SetScript("OnEditFocusLost", function(self)
            if self:GetText() == "" then hint:Show() end
        end)
        searchBox:SetScript("OnTextChanged", function(self)
            query = searchText(self:GetText():match("^%s*(.-)%s*$"))
            if query == "" and not self:HasFocus() then hint:Show() else hint:Hide() end
            refresh()
        end)
        searchBox:SetScript("OnEnterPressed", searchBox.ClearFocus)
        searchBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            self:SetText("")
        end)

        bagTray = CreateFrame("Frame", name .. "BagTray", window)
        bagTray:SetSize(traySlots * 28, 24)
        bagTray.slots = {}
        bagTray:Hide()
        local function putItem(self)
            if not CursorHasItem() then return end
            if self.inventoryID then PutItemInBag(self.inventoryID) else PutItemInBackpack() end
        end
        for index = 1, traySlots do
            local id = index - 1
            local slot
            if isBank then
                slot = _G["BankFrameBag" .. index]
                slot:SetParent(bagTray)
            else
                slot = CreateFrame("Button", name .. "BagSlot" .. id, bagTray, "ItemButtonTemplate")
            end
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", bagTray, "TOPLEFT", (index - 1) * 28, 0)
            prepareSlot(slot)
            sizeSlot(slot, 24)
            if isBank then
                slot:Show()
            elseif id == 0 then
                SetItemButtonTexture(slot, backpackIcon)
            else
                slot.inventoryID, slot.emptyTexture = GetInventorySlotInfo("Bag" .. (id - 1) .. "Slot")
                slot:RegisterForDrag("LeftButton")
                slot:SetScript("OnDragStart", function(self) PickupBagFromSlot(self.inventoryID) end)
            end
            if not isBank then
                slot:SetScript("OnClick", putItem)
                slot:SetScript("OnReceiveDrag", putItem)
                slot:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    if not self.inventoryID then
                        GameTooltip:SetText(BACKPACK_TOOLTIP)
                    elseif not GameTooltip:SetInventoryItem("player", self.inventoryID) then
                        GameTooltip:SetText(EQUIP_CONTAINER)
                    end
                    GameTooltip:Show()
                end)
                slot:SetScript("OnLeave", GameTooltip_Hide)
            end
            bagTray.slots[#bagTray.slots + 1] = slot
        end

        local options = toolbarButton(window, "Options", close, ru and "Настройки сумок" or "Bag settings",
            "Interface\\Icons\\Trade_Engineering", function()
                closeWindow()
                ui.OpenOptions("bags")
            end)
        local labels = toolbarButton(window, "Labels", options, ru and "Настроить уровень предметов и прочность" or "Configure item level and durability",
            "Interface\\Icons\\INV_Misc_Note_01", function()
                ui.ToggleItemLabelEditor(window, "bags", relayout, not isBank)
            end)
        local search = toolbarButton(window, "Search", labels, ru and "Поиск по названию" or "Search by name",
            "Interface\\Icons\\INV_Misc_Spyglass_03", function()
                if searchBox:IsShown() then
                    searchBox:GetScript("OnEscapePressed")(searchBox)
                    searchBox:Hide()
                    layout()
                else
                    searchBox:Show()
                    layout()
                    searchBox:SetFocus()
                end
            end)
        local toggleBags = toolbarButton(window, "ToggleBags", search, ru and "Сумки" or "Bags",
            backpackIcon, function()
                if bagTray:IsShown() then bagTray:Hide() else bagTray:Show() end
                layout()
                refresh()
            end)
        local leftmost = search
        if keyring then
            leftmost = toolbarButton(window, "KeyRing", search, ru and "Ключи" or "Keyring",
                "Interface\\Icons\\INV_Misc_Key_03", toggleKeys)
        end
        toggleBags:ClearAllPoints()
        toggleBags:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -toolbarTop)
        options:ClearAllPoints()
        options:SetPoint("RIGHT", toggleBags, "LEFT", -3, 0)
        searchBox:SetPoint("TOPRIGHT", leftmost, "TOPLEFT", -7, 0)
    end

    local function createWindow(panel)
        window = CreateFrame("Frame", name, isBank and BankFrame or UIParent)
        window:SetFrameStrata(isBank and "HIGH" or "FULLSCREEN_DIALOG")
        window:SetToplevel(true)
        if isBank then
            window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 26, -80)
        else
            window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -38, 99)
        end
        window:SetClampedToScreen(true)
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        window:Hide()

        local edgeTexture = art .. "Backpack-Edge"
        local header = window:CreateTexture(nil, "BORDER")
        if bagSkin == "forever" then
            window:SetBackdrop({
                bgFile = white,
                edgeFile = art .. "BagForever-Edge", edgeSize = 14,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            window:SetBackdropColor(0.108, 0.098, 0.088, 0.97)
            header:SetTexture(art .. "BagForever-Header")
        elseif newBagSkin then
            window:SetBackdrop({
                bgFile = white,
                edgeFile = art .. "BagWindow-Edge", edgeSize = backpackEdgeSize + 2,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            window:SetBackdropColor(0.16, 0.15, 0.145, 0.97)
            header:SetTexture(art .. "BagWindow-Header")
        else
            window:SetBackdrop({
                bgFile = white, edgeFile = edgeTexture, edgeSize = backpackEdgeSize,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            window:SetBackdropColor(0.115, 0.109, 0.109, 0.90)
            header:SetTexture(backpackChrome)
            header:SetTexCoord(0, 1, 72 / 128, 120 / 128)
        end
        header:SetPoint("TOPLEFT", window, "TOPLEFT", 5, -5)
        header:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -5)
        header:SetHeight(18 + headerExtra)

        -- Stretch the middle of the rotated top strip so its highlight does not repeat across the header.
        -- (Only for the original art; the new frame texture already has its own top edge.)
        if not newBagSkin then
            local topEdge = window:CreateTexture(nil, "ARTWORK")
            topEdge:SetTexture(edgeTexture)
            topEdge:SetTexCoord(0.25, 15 / 32, 0.375, 15 / 32, 0.25, 17 / 32, 0.375, 17 / 32)
            topEdge:SetPoint("TOPLEFT", window, "TOPLEFT", backpackEdgeSize, 0)
            topEdge:SetPoint("TOPRIGHT", window, "TOPRIGHT", -backpackEdgeSize, 0)
            topEdge:SetHeight(backpackEdgeSize)
        end

        local divider = window:CreateTexture(nil, "ARTWORK")
        divider:SetTexture(white)
        divider:SetVertexColor(0.55, 0.39, 0.21)
        divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
        divider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
        divider:SetHeight(1)

        local portraitFrame = CreateFrame("Frame", nil, window)
        portraitFrame:SetFrameLevel(window:GetFrameLevel() + 1)
        portraitFrame:SetSize(55, 55)
        portraitFrame:SetPoint("CENTER", window, "TOPLEFT", 17, -20 - headerExtra / 2)
        local ring = portraitFrame:CreateTexture(nil, "BACKGROUND")
        ring:SetTexture(art .. "Level")
        ring:SetTexCoord(0, 78 / 128, 0, 78 / 128)
        ring:SetAllPoints(portraitFrame)
        local portrait = portraitFrame:CreateTexture(nil, "ARTWORK")
        SetPortraitToTexture(portrait, backpackIcon)
        portrait:SetSize(36, 36)
        portrait:SetPoint("CENTER", portraitFrame, "CENTER")

        local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetFont(STANDARD_TEXT_FONT, 14)
        title:SetPoint("LEFT", header, "LEFT", 44, 0)
        title:SetPoint("RIGHT", header, "RIGHT", -44, 0)
        title:SetText(titleText)
        title:SetJustifyH("CENTER")
        title:SetWordWrap(false)
        local close = CreateFrame("Button", name .. "CloseButton", window)
        close:SetSize(23, 23)
        close:SetPoint("RIGHT", header, "RIGHT", 6, 2)
        close:SetNormalTexture(backpackChrome)
        close:GetNormalTexture():SetTexCoord(0.25, 0.5, 0, 0.5)
        close:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        if not isBank then table.insert(UISpecialFrames, window:GetName()) end
        close:SetScript("OnClick", closeWindow)
        createToolbar(close, panel)
        local footerInset = backpackEdgeSize + 2
        local footer = CreateFrame("Frame", nil, window)
        footer:SetBackdrop(backpackInset)
        footer:SetBackdropColor(0.09, 0.087, 0.086, 0.98)
        footer:SetHeight(18)
        local footerLift = newBagSkin and 2 or 0
        footer:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", footerInset, footerInset + footerLift)
        footer:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -footerInset, footerInset + footerLift)
        money = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        money:SetPoint("RIGHT", footer, "RIGHT", -9, 0)
        if isBank then
            buySlot = CreateFrame("Button", name .. "BuySlot", footer, "UIPanelButtonTemplate")
            buySlot:SetSize(132, 18)
            buySlot:SetPoint("LEFT", footer, "LEFT", 3, 0)
            buySlot:SetText(BANKSLOTPURCHASE)
            buySlot:SetScript("OnClick", function()
                local popup = StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
                if not popup or popup.foreverBankPopupStrata then return end
                popup.foreverBankPopupStrata = popup:GetFrameStrata()
                popup:SetFrameStrata("TOOLTIP")
                if popup.foreverBankPopupHook then return end
                popup.foreverBankPopupHook = true
                popup:HookScript("OnHide", function(self)
                    if self.foreverBankPopupStrata then
                        self:SetFrameStrata(self.foreverBankPopupStrata)
                        self.foreverBankPopupStrata = nil
                    end
                end)
            end)
            buySlot:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(BANKSLOTPURCHASE)
                GameTooltip:AddLine(GetCoinTextureString(GetBankSlotCost(GetNumBankSlots())))
                GameTooltip:Show()
            end)
            buySlot:SetScript("OnLeave", GameTooltip_Hide)
        end

        content = CreateFrame("Frame", name .. "Grid", window)
        content:SetSize(1, 1)
        for index, id in ipairs(bagIDs) do
            local suffix = isBank and index or id
            local bag = CreateFrame("Frame", name .. "Bag" .. suffix, content)
            bag:SetID(id)
            if id > lastBag then
                bag.inventorySlot = _G["BankFrameBag" .. (id - lastBag)]:GetInventorySlot()
            elseif id > 0 then
                bag.inventorySlot = GetInventorySlotInfo("Bag" .. (id - 1) .. "Slot")
            end
            bag:SetAllPoints(content)
            if index > 1 then
                bag.separator = bag:CreateTexture(nil, "BACKGROUND")
                bag.separator:SetTexture("Interface\\Buttons\\WHITE8X8")
                bag.separator:SetVertexColor(0.56, 0.49, 0.37, 0.78)
                bag.separator:SetHeight(1)
            end
            bag.items = {}
            bags[id] = bag
        end
        window:SetScript("OnShow", function()
            requirementsByLink = {}
            layout()
            refresh()
            if not isBank then setChecked(true) end
            window:Raise()
        end)
        window:SetScript("OnHide", function()
            if not isBank then automatic = nil end
            searchBox:ClearFocus()
            searchBox:SetText("")
            if not isBank then setChecked(false) end
        end)
    end

    local function toggle()
        if IsOptionFrameOpen() then return end
        if window:IsShown() then window:Hide() else open() end
    end

    createWindow(panel)
    return { window = window, layout = layout, refresh = refresh, open = open, toggle = toggle, toggleKeys = toggleKeys }
end

local function connectBank(panel)
    if not (BankFrame and BANK_CONTAINER and NUM_BANKGENERIC_SLOTS and NUM_BANKBAGSLOTS
        and _G["BankFrameItem" .. NUM_BANKGENERIC_SLOTS] and _G["BankFrameBag" .. NUM_BANKBAGSLOTS]) then
        return
    end
    -- Keep the native bank panel and its events active while replacing its presentation.
    local stockChildren = { BankFrame:GetChildren() }
    local stock = CreateFrame("Frame", nil, BankFrame)
    stock:Hide()
    for _, child in ipairs(stockChildren) do child:SetParent(stock) end
    for _, region in ipairs({ BankFrame:GetRegions() }) do region:SetAlpha(0) end
    BankFrame:SetBackdrop(nil)
    BankFrame:EnableMouse(false)

    bank = createInventory(panel, true)
    BankFrame:HookScript("OnShow", function() bank.window:Show() end)
    BankFrame:HookScript("OnHide", function() bank.window:Hide() end)
    if BankFrame:IsShown() then bank.window:Show() end
end

local function connectButtons()
    local stockToggle, stockOpen = ToggleBag, OpenBag
    local window = inventory.window
    local open, toggle = inventory.open, inventory.toggle
    local function usesBankGrid(id)
        return bank and bank.window:IsShown() and id > lastBag and id <= lastBag + NUM_BANKBAGSLOTS
    end
    local function hideStockBag(frame, _, id)
        if frame:IsShown() and (id == KEYRING_CONTAINER or (id >= 0 and id <= lastBag) or usesBankGrid(id)) then
            frame:Hide()
            if window:IsShown() then setChecked(true) end
        end
    end
    hooksecurefunc("ContainerFrame_GenerateFrame", hideStockBag)
    for index = 1, NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame" .. index]
        if frame:IsShown() then hideStockBag(frame, nil, frame:GetID()) end
    end
    if KEYRING_CONTAINER and ToggleKeyRing then ToggleKeyRing = inventory.toggleKeys end
    ToggleBackpack = toggle
    ToggleBag = function(id)
        if id == KEYRING_CONTAINER then return inventory.toggleKeys() end
        if id >= 0 and id <= lastBag then return toggle() end
        if usesBankGrid(id) then return end
        return stockToggle(id)
    end
    OpenBag = function(id)
        if id == KEYRING_CONTAINER then return inventory.toggleKeys(true) end
        if id >= 0 and id <= lastBag then return open() end
        if usesBankGrid(id) then return end
        return stockOpen(id)
    end
    OpenBackpack = function()
        if not window:IsShown() then
            open()
            automatic = window:IsShown()
        end
    end
    OpenAllBags = function(force)
        if not UIParent:IsShown() then return end
        if force then open() else toggle() end
        if not bank and BankFrame:IsShown() then
            for id = lastBag + 1, lastBag + NUM_BANKBAGSLOTS do
                if window:IsShown() then stockOpen(id) else CloseBag(id) end
            end
        end
    end
    hooksecurefunc("CloseBackpack", function() if automatic then window:Hide() end end)
    hooksecurefunc("CloseAllBags", function() window:Hide() end)
    hooksecurefunc("CloseBag", function(id) if id >= 0 and id <= lastBag then window:Hide() end end)
    hooksecurefunc("BackpackButton_UpdateChecked", function(button) button:SetChecked(window:IsShown()) end)
    hooksecurefunc("BagSlotButton_UpdateChecked", function(button)
        local bagID = button:GetID() - CharacterBag0Slot:GetID() + 1
        button:SetChecked(window:IsShown() and GetContainerNumSlots(bagID) > 0)
    end)
end

local function refresh()
    inventory.refresh()
    if bank then bank.refresh() end
end

relayout = function()
    if inventory.window:IsShown() then inventory.layout() end
    if bank and bank.window:IsShown() then bank.layout() end
    refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then
        if event == "PLAYER_LEVEL_UP" or event == "SKILL_LINES_CHANGED" or event == "UPDATE_FACTION"
            or event == "PLAYER_EQUIPMENT_CHANGED" then requirementsByLink = {} end
        if event == "DISPLAY_SIZE_CHANGED" then relayout() else refresh() end
        return
    end
    self:UnregisterEvent(event)
    settings = ui.Settings()
    if IsAddOnLoaded("Bagnon") or settings.bagsEnabled == false then return end
    equipmentTooltip = CreateFrame("GameTooltip", "ForeverStockInventoryEquipmentTooltip", UIParent, "GameTooltipTemplate")
    equipmentTooltip:Hide()
    if ui.RegisterEditFrame then ui.RegisterEditFrame(MainMenuBarBackpackButton, nil, "bags") end
    inventory = createInventory(nil, false)
    connectBank(nil)
    ui.Bags.active = true
    connectButtons()
    for _, name in ipairs({ "DISPLAY_SIZE_CHANGED", "BAG_UPDATE", "UNIT_INVENTORY_CHANGED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY",
        "UPDATE_INVENTORY_DURABILITY", "QUEST_ACCEPTED", "UNIT_QUEST_LOG_CHANGED", "PLAYER_LEVEL_UP",
        "SKILL_LINES_CHANGED", "UPDATE_FACTION", "PLAYER_EQUIPMENT_CHANGED" }) do
        self:RegisterEvent(name)
    end
    if bank then
        self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
        self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
    end
    pcall(self.RegisterEvent, self, "GET_ITEM_INFO_RECEIVED")
end)

ui.Bags = {
    Relayout = function() if inventory then relayout() end end,
    Refresh = function() if inventory then refresh() end end,
}
