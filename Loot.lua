local _, ui = ...
local max = math.max
local keepRowsOnTop     -- defined below; the button hook needs it first
local art = LootFrame.RetailArt

-- WoW Forever look of the loot rows (Art/Forever/Loot-Atlas.tga, cut from the Forever lootframe sheet):
-- card background, hover glow, card outline (item quality colour) and a dim outline for locked
-- slots, plus a soft shade over the lower half of the window. lootForeverCards off brings back the
-- client's own card textures.
local ATLAS = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Loot-Atlas.tga"
local cells = {
    bg = { 0, 300, 0, 78 }, glow = { 0, 300, 78, 156 }, stroke = { 0, 300, 156, 234 }, strokeDim = { 0, 300, 234, 312 },
    shade = { 0, 512, 320, 472 },
}
local CARD_TINT = { 1, 0.86, 0.7 }
local BORDER_TINT = { 0.86, 0.68, 0.45 }
local GLOW_TINT = { 1, 0.83, 0.55 }

local function setting(key)
    local value = ui.Settings()[key]
    if value == nil then return true end
    return value and true or false
end

local originals = {}
local function setCell(region, name)
    if not region then return end
    if not originals[region] then originals[region] = { region:GetTexture(), region:GetTexCoord() } end
    local c = cells[name]
    region:SetTexture(ATLAS)
    region:SetTexCoord(c[1] / 512, c[2] / 512, c[3] / 512, c[4] / 512)
end
local function restore(region)
    local saved = region and originals[region]
    if not saved then return end
    region:SetTexture(saved[1])
    if saved[2] then region:SetTexCoord(unpack(saved, 2)) end
    originals[region] = nil
end

local function skinCard(button)
    local card = button and button.RetailCard
    if not card then return end
    if not setting("lootForeverCards") then
        restore(card.Bg)
        restore(card.Border)
        restore(card.Highlight)
        card.Border:SetVertexColor(0.82, 0.64, 0.43)
        card.Highlight:SetVertexColor(unpack(GLOW_TINT))
        return
    end
    local quality, locked = button.quality, false
    if button.slot and GetLootSlotInfo then
        local _, _, _, slotQuality, slotLocked = GetLootSlotInfo(button.slot)
        quality, locked = slotQuality or quality, slotLocked and true or false
    end
    local color = setting("lootQualityBorder") and quality and quality >= 2 and ITEM_QUALITY_COLORS
        and ITEM_QUALITY_COLORS[quality]
    setCell(card.Bg, "bg")
    setCell(card.Highlight, "glow")
    setCell(card.Border, locked and "strokeDim" or "stroke")
    if color then
        card.Border:SetVertexColor(color.r, color.g, color.b)
        -- a hint of the quality colour in the card, mostly the warm Forever brown
        card.Bg:SetVertexColor(CARD_TINT[1] * 0.75 + color.r * 0.25, CARD_TINT[2] * 0.75 + color.g * 0.25,
            CARD_TINT[3] * 0.75 + color.b * 0.25, 1)
    else
        card.Border:SetVertexColor(unpack(BORDER_TINT))
        card.Bg:SetVertexColor(CARD_TINT[1], CARD_TINT[2], CARD_TINT[3], 1)
    end
    card.Highlight:SetVertexColor(unpack(GLOW_TINT))
end

local shade
local function applyFrame()
    if not art then return end
    art.Bg:SetTexture(0.12, 0.078, 0.045, 0.97)
    for _, region in ipairs({ art.MetalBorder:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetVertexColor(1, 0.84, 0.65) end
    end
    art.MetalBorder.TitleText:SetTextColor(1, 0.82, 0.46)
    if not shade then
        shade = art:CreateTexture(nil, "BORDER")
        shade:SetPoint("TOPLEFT", art.Bg, "LEFT", 0, 0)
        shade:SetPoint("BOTTOMRIGHT", art.Bg, "BOTTOMRIGHT", 0, 0)
    end
    if setting("lootForeverCards") then
        local c = cells.shade
        shade:SetTexture(ATLAS)
        shade:SetTexCoord(c[1] / 512, c[2] / 512, c[3] / 512, c[4] / 512)
        shade:SetAlpha(0.45)
        shade:Show()
    else
        shade:Hide()
    end
end

local function apply()
    applyFrame()
    for index = 1, LOOTFRAME_NUMBUTTONS do
        local button = _G["LootButton" .. index]
        if button and button.RetailIconHover then button.RetailIconHover:SetVertexColor(1, 0.76, 0.40) end
        skinCard(button)
    end
end
ui.Loot = { Apply = apply, cells = cells, atlas = ATLAS }
apply()

if art then
    hooksecurefunc("LootFrame_UpdateButton", function(index)
        local button = _G["LootButton" .. index]
        local card = button and button.RetailCard
        if not (card and button:IsShown() and button.slot) then return end
        keepRowsOnTop()
        if setting("lootForeverCards") then
            skinCard(button)    -- the client may reset textures and colours on every update
            return
        end
        -- Client cards: warm the colour the client set; skip if it is still our own, or it darkens on every update.
        local r, g, b, a = card.Bg:GetVertexColor()
        local tint = card.foreverTint
        if tint and math.abs(tint[1] - r) < 0.01 and math.abs(tint[2] - g) < 0.01 and math.abs(tint[3] - b) < 0.01 then
            return
        end
        g, b = g * 0.83, b * 0.65
        card.foreverTint = { r, g, b }
        card.Bg:SetVertexColor(r, g, b, a)
    end)
end

-- Items the character cannot use get a red icon (ItemUsability.lua); the client may reset the icon on
-- every update, so it is painted again after each one.
local function paintRow(index)
    local U = ui.ItemUsability
    local button = _G["LootButton" .. index]
    local icon = _G["LootButton" .. index .. "IconTexture"]
    if not (U and button and icon) then return end
    local link = button:IsShown() and button.slot and GetLootSlotLink and GetLootSlotLink(button.slot)
    local verdict = link and U.CannotUse(link)
    if verdict == nil and link then
        U.Retry("loot", function()
            for i = 1, LOOTFRAME_NUMBUTTONS do paintRow(i) end
        end)
    end
    U.Paint(icon, verdict == true)
end
if LootFrame_UpdateButton then hooksecurefunc("LootFrame_UpdateButton", paintRow) end
if ui.ItemUsability then
    ui.ItemUsability.OnChange(function()
        if LootFrame:IsShown() then for i = 1, LOOTFRAME_NUMBUTTONS do paintRow(i) end end
    end)
end
ui.Loot.PaintUnusable = paintRow

local rows = {}
local flyouts = {}
local closedAt, lastFlyout, backgroundAlpha
local openAlpha, revealElapsed
local function duration()
    local value = ui.Settings().lootFadeDuration
    return type(value) == "number" and value > 0.1 and value or 0.3
end
local fadingArt
local fadingRegions = {}
-- Strata and level of the retail art and every frame inside it, saved before the art is lent to the
-- fading background. Levels are kept relative to LootFrame: it is a toplevel window and the client
-- changes its level when it opens, so an absolute level restored later could lift the opaque art
-- background over the loot rows (the rows were still clickable through it, but invisible).
local savedLayers = {}
local background = CreateFrame("Frame", nil, UIParent)
background:SetAllPoints(LootFrame)
background:SetFrameStrata("HIGH")
background:Hide()

local function finishBackground()
    background:Hide()
    background:SetScript("OnUpdate", nil)
    if fadingArt then
        fadingArt:SetParent(LootFrame)
        for index, saved in ipairs(savedLayers) do
            saved[1]:SetFrameStrata(saved[2])
            saved[1]:SetFrameLevel(max(0, LootFrame:GetFrameLevel() + saved[3]))
            savedLayers[index] = nil
        end
        fadingArt = nil
    end
    for index, region in ipairs(fadingRegions) do
        region:SetParent(LootFrame)
        fadingRegions[index] = nil
    end
end

local function rememberLayers(frame)
    savedLayers[#savedLayers + 1] = { frame, frame:GetFrameStrata(), frame:GetFrameLevel() - LootFrame:GetFrameLevel() }
    for _, child in ipairs({ frame:GetChildren() }) do rememberLayers(child) end
end

-- The loot rows must be drawn over the retail art (its background is opaque).
function keepRowsOnTop()
    local art = LootFrame.RetailArt
    if not art or art:GetParent() ~= LootFrame then return end
    if art:GetFrameStrata() ~= LootFrame:GetFrameStrata() then art:SetFrameStrata(LootFrame:GetFrameStrata()) end
    local level = art:GetFrameLevel()
    for index = 1, LOOTFRAME_NUMBUTTONS do
        local button = _G["LootButton" .. index]
        if button and button:GetFrameStrata() == art:GetFrameStrata() and button:GetFrameLevel() <= level then
            button:SetFrameLevel(level + 2)
        end
    end
end

local function moveBackground()
    background:SetScale(LootFrame:GetEffectiveScale() / UIParent:GetEffectiveScale())
    background:SetFrameStrata(LootFrame:GetFrameStrata())
    if fadingArt then return end    -- still lent from the previous close
    local art = LootFrame.RetailArt
    if art and art:IsShown() then
        -- The client fits this frame to the visible loot rows and anchors it to LootFrame.
        for index = #savedLayers, 1, -1 do savedLayers[index] = nil end
        rememberLayers(art)
        fadingArt = art
        art:SetParent(background)
        return
    end
    for _, region in ipairs({ LootFrame:GetRegions() }) do
        if region:IsShown() and region:GetAlpha() > 0 then
            fadingRegions[#fadingRegions + 1] = region
            region:SetParent(background)
        end
    end
end

local function fadeAlpha(elapsed)
    local fade = math.max(0, (elapsed - 0.1) / (duration() - 0.1))
    return 1 - fade^2
end

local function restoreOpenAlpha()
    if openAlpha then
        LootFrame:SetAlpha(openAlpha)
        openAlpha = nil
    end
end

local function captureRows()
    rows = {}
    closedAt = nil
    if not LootFrame:IsVisible() then return end

    for index = 1, LOOTFRAME_NUMBUTTONS do
        local prefix = "LootButton" .. index
        local button = _G[prefix]
        if button:IsShown() and button.slot then
            local x, y = button:GetLeft(), button:GetTop()
            local icon = _G[prefix .. "IconTexture"]:GetTexture()
            local text = _G[prefix .. "Text"]:GetText()
            if x and y and icon and text then
                local count = _G[prefix .. "Count"]
                rows[button.slot] = {
                    button = button, x = x, y = y, scale = button:GetEffectiveScale(),
                    icon = icon, text = text, count = count:IsShown() and count:GetText(),
                    red = ui.ItemUsability and ui.ItemUsability.IsPainted(_G[prefix .. "IconTexture"]) or false,
                    quality = button.quality,
                }
            end
        end
    end
end

local function position(flyout, offset)
    flyout:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", flyout.x + offset, flyout.y)
end

local function animate(flyout, elapsed)
    flyout.elapsed = flyout.elapsed + elapsed
    if flyout.elapsed >= duration() then
        if flyout == lastFlyout then finishBackground() end
        flyout:Hide()
        return
    end
    position(flyout, (ui.Settings().lootFlyDistance or 100) * (flyout.elapsed / duration())^2)
    local alpha = fadeAlpha(flyout.elapsed)
    flyout:SetAlpha(alpha)
    if flyout == lastFlyout and background:IsShown() then
        background:SetAlpha(backgroundAlpha * alpha)
    end
end

local function acquireFlyout()
    for _, flyout in ipairs(flyouts) do
        if not flyout:IsShown() then return flyout end
    end

    local name = "ForeverStockLootFlyout" .. (#flyouts + 1)
    local flyout = CreateFrame("Button", name, UIParent, "LootButtonTemplate")
    flyout:EnableMouse(false)
    flyout:SetFrameStrata("DIALOG")
    flyout:SetScript("OnClick", nil)
    flyout:SetScript("OnEnter", nil)
    flyout:SetScript("OnLeave", nil)
    flyout:SetScript("OnUpdate", animate)
    _G[name .. "NameFrame"]:SetVertexColor(0.69, 0.48, 0.31)
    flyouts[#flyouts + 1] = flyout
    return flyout
end

local function play(row)
    local flyout = acquireFlyout()
    local name = flyout:GetName()
    _G[name .. "IconTexture"]:SetTexture(row.icon)
    if ui.ItemUsability then ui.ItemUsability.Paint(_G[name .. "IconTexture"], row.red) end
    local text = _G[name .. "Text"]
    local quality = ITEM_QUALITY_COLORS[row.quality]
    text:SetText(row.text)
    if quality then text:SetTextColor(quality.r, quality.g, quality.b) else text:SetTextColor(1, 1, 1) end
    local count = _G[name .. "Count"]
    count:SetText(row.count or "")
    if row.count then count:Show() else count:Hide() end

    local button = row.button
    local visible = LootFrame:IsVisible()
    flyout.x = visible and button:GetLeft() or row.x
    flyout.y = visible and button:GetTop() or row.y
    flyout.elapsed = 0
    flyout:SetScale(row.scale / UIParent:GetEffectiveScale())
    flyout:ClearAllPoints()
    position(flyout, 0)
    flyout:SetAlpha(1)
    flyout:Show()
    lastFlyout = flyout
    if closedAt and background:IsShown() then
        backgroundAlpha = background:GetAlpha()
        background:SetScript("OnUpdate", nil)
    end
end

hooksecurefunc("LootFrame_Show", function(frame)
    lastFlyout = nil
    captureRows()
    if frame ~= LootFrame or not frame:IsVisible() then return end
    restoreOpenAlpha()
    openAlpha = frame:GetAlpha()
    if openAlpha == 0 then openAlpha = 1 end
    revealElapsed = 0
    frame:SetAlpha(openAlpha * 0.6)
end)
LootFrameUpButton:HookScript("OnClick", captureRows)
LootFrameDownButton:HookScript("OnClick", captureRows)
LootFrame:HookScript("OnShow", function()
    finishBackground()
    keepRowsOnTop()
end)
LootFrame:HookScript("OnUpdate", function(frame, elapsed)
    if not openAlpha then return end
    revealElapsed = revealElapsed + elapsed
    if revealElapsed >= 0.1 then
        restoreOpenAlpha()
    else
        frame:SetAlpha(openAlpha * (0.6 + 4 * revealElapsed))
    end
end)
LootFrame:HookScript("OnHide", function()
    closedAt = GetTime()
    backgroundAlpha = LootFrame:GetAlpha()
    restoreOpenAlpha()
    moveBackground()
    if lastFlyout and lastFlyout:IsShown() then
        background:SetAlpha(backgroundAlpha * lastFlyout:GetAlpha())
    else
        background:SetAlpha(backgroundAlpha)
        background:SetScript("OnUpdate", function(self)
            local elapsed = GetTime() - closedAt
            if elapsed >= duration() then
                finishBackground()
            else
                self:SetAlpha(backgroundAlpha * fadeAlpha(elapsed))
            end
        end)
    end
    background:Show()
end)
LootFrame:HookScript("OnEvent", function(_, event, slot)
    if event == "LOOT_SLOT_CLEARED" then
        local row = rows[slot]
        if row and (not closedAt or GetTime() - closedAt <= duration()) then play(row) end
        rows[slot] = nil
        if LootFrame:IsVisible() then captureRows() end
    elseif event == "LOOT_SLOT_CHANGED" and LootFrame:IsVisible() then
        captureRows()
    end
end)

-- /fuiloot: strata and levels of the loot window parts (ASCII, the client chat shows Cyrillic as "?").
SLASH_FOREVERUILOOT1 = "/fuiloot"
SlashCmdList.FOREVERUILOOT = function()
    local function line(label, frame)
        if not frame then return end
        DEFAULT_CHAT_FRAME:AddMessage(("ForeverUI loot: %s strata=%s level=%d shown=%s parent=%s"):format(label,
            tostring(frame:GetFrameStrata()), frame:GetFrameLevel() or -1, tostring(frame:IsShown() and true or false),
            frame:GetParent() == LootFrame and "LootFrame" or tostring(frame:GetParent() and frame:GetParent():GetName())))
    end
    line("LootFrame", LootFrame)
    line("RetailArt", LootFrame.RetailArt)
    line("MetalBorder", LootFrame.RetailArt and LootFrame.RetailArt.MetalBorder)
    for index = 1, LOOTFRAME_NUMBUTTONS do line("LootButton" .. index, _G["LootButton" .. index]) end
end
