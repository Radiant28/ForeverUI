local _, ui = ...
local ru = ui.russian
local settings, button

local function canSell()
    return MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 and not InRepairMode() and not GetCursorInfo()
end

local function sellJunk()
    if not canSell() then return end
    local stacks, items, total = 0, 0, 0
    local limit = settings.junkMax12 and (settings.junkLimit or 12) or math.huge
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bag) do
            local _, count, locked = GetContainerItemInfo(bag, slot)
            local link = not locked and GetContainerItemLink(bag, slot)
            if link then
                local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
                local id = tonumber(link:match("|Hitem:(%d+)"))
                local exception = id and settings.junkExceptions[id] == true
                local quest, questID = GetContainerItemQuestInfo(bag, slot)
                local junk = quality == 0 and not exception or quality and quality > 0 and exception
                if id and junk and price and price > 0 and not quest and not questID then
                    if not canSell() then return end
                    UseContainerItem(bag, slot)
                    count = count or 1
                    local stackPrice = price * count
                    stacks, items, total = stacks + 1, items + count, total + stackPrice
                    if settings.junkVerbose then
                        local label = ru and "На продажу: %s ×%d за %s" or "Selling %s ×%d for %s"
                        DEFAULT_CHAT_FRAME:AddMessage(label:format(link, count, GetCoinTextureString(stackPrice)))
                    end
                    if stacks >= limit then break end
                end
            end
        end
        if stacks >= limit then break end
    end
    if stacks > 0 and settings.junkSummary then
        local label = ru and "Мусор на продажу: %d предм. на сумму %s." or "Junk sent for sale: %d items worth %s."
        DEFAULT_CHAT_FRAME:AddMessage(label:format(items, GetCoinTextureString(total)))
    end
end

local function placeButton()
    if not button or not MerchantFrame:IsShown() or MerchantFrame.selectedTab ~= 1 then return end
    local repair = MerchantRepairAllButton
    local size = repair:IsShown() and repair:GetWidth() or 36
    button:SetSize(size, size)
    if not repair:IsShown() then return end

    local last = MerchantGuildBankRepairButton:IsShown() and MerchantGuildBankRepairButton or repair
    local left, right = button:GetLeft(), last:GetRight()
    if left and right and right + 4 > left then
        -- Make room before buyback while keeping the repair buttons linked to one another.
        local point, relative, relativePoint, x, y = repair:GetPoint(1)
        repair:SetPoint(point, relative, relativePoint, x - math.ceil(right + 4 - left), y)
    end
end

local function updateButton()
    if not MerchantFrame:IsShown() then return end
    if not button then
        button = CreateFrame("Button", "ForeverStockSellJunkButton", MerchantFrame)
        button:SetPoint("RIGHT", MerchantBuyBackItem, "LEFT", -9, 0)
        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetTexture("Interface\\Buttons\\WHITE8X8")
        background:SetVertexColor(0.12, 0.09, 0.06)
        background:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        background:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\AddOns\\ForeverUI\\Art\\Bag-Junk")
        icon:SetSize(33, 33)
        icon:SetPoint("CENTER")
        local edge = button:CreateTexture(nil, "OVERLAY")
        ui.ApplySlotEdge(edge)
        edge:SetAllPoints(button)
        button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:SetScript("OnClick", sellJunk)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(ru and "Продать мусор" or "Sell Junk")
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
    end
    if MerchantFrame.selectedTab == 1 and settings.junkButton ~= false then button:Show() else button:Hide() end
    placeButton()
end

local function junkCommand(message)
    local command, arg = message:match("^%s*(%S+)%s*(.-)%s*$")
    if command == "sell" then
        sellJunk()
        return
    end
    local id = arg and (tonumber(arg:match("|Hitem:(%d+)")) or tonumber(arg:match("^(%d+)$")))
    if id and id > 0 and (command == "add" or command == "rem") then
        settings.junkExceptions[id] = command == "add" or nil
        local label = command == "add" and (ru and "Добавлено правило продажи для предмета %d." or "Added sale rule for item %d.")
            or (ru and "Удалено правило продажи для предмета %d." or "Removed sale rule for item %d.")
        DEFAULT_CHAT_FRAME:AddMessage(label:format(id))
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage(ru
        and "/fujunk sell — продать мусор. /fujunk add или rem + ссылка или ID — изменить правило. Для серых предметов правило запрещает продажу, для остальных разрешает."
        or "/fujunk sell sells junk. /fujunk add or rem plus an item link or ID changes its rule. Rules keep grey items and sell other items.")
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        self:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            updateButton()
            if settings.junkAuto and not IsAddOnLoaded("SellJunk") then
                sellJunk()
            end
        end)
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("MERCHANT_SHOW")
    settings = ui.Settings()
    if type(settings.junkExceptions) ~= "table" then settings.junkExceptions = {} end
    SLASH_FOREVERSTOCKJUNK1 = "/fujunk"
    SlashCmdList.FOREVERSTOCKJUNK = junkCommand
    hooksecurefunc("MerchantFrame_Update", updateButton)
    hooksecurefunc("MerchantFrame_UpdateRepairButtons", placeButton)
    updateButton()
end)

ui.Merchant = {
    Apply = function() if settings then updateButton() end end,
    Sell = function() if settings then sellJunk() end end,
}
