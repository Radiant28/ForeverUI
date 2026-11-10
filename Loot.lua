local _, ui = ...
local art = LootFrame.RetailArt
if art then
    art.Bg:SetTexture(0.12, 0.078, 0.045, 0.97)
    for _, region in ipairs({ art.MetalBorder:GetRegions() }) do
        if region:IsObjectType("Texture") then
            region:SetVertexColor(1, 0.84, 0.65)
        end
    end
    art.MetalBorder.TitleText:SetTextColor(1, 0.82, 0.46)
end

for index = 1, LOOTFRAME_NUMBUTTONS do
    local button = _G["LootButton" .. index]
    local card = button.RetailCard
    if card then
        card.Border:SetVertexColor(0.82, 0.64, 0.43)
        card.Highlight:SetVertexColor(1, 0.83, 0.58)
        button.RetailIconHover:SetVertexColor(1, 0.76, 0.40)
    end
end

if art then
    hooksecurefunc("LootFrame_UpdateButton", function(index)
        local button = _G["LootButton" .. index]
        local card = button and button.RetailCard
        if not (card and button:IsShown() and button.slot) then return end
        local r, g, b, a = card.Bg:GetVertexColor()
        card.Bg:SetVertexColor(r, g * 0.83, b * 0.65, a)
    end)
end

local rows = {}
local flyouts = {}
local closedAt, lastFlyout, backgroundAlpha
local openAlpha, revealElapsed
local function duration()
    local value = ui.Settings().lootFadeDuration
    return type(value) == "number" and value > 0.1 and value or 0.3
end
local fadingArt, fadingArtLevel
local fadingRegions = {}
local background = CreateFrame("Frame", nil, UIParent)
background:SetAllPoints(LootFrame)
background:SetFrameStrata("HIGH")
background:Hide()

local function finishBackground()
    background:Hide()
    background:SetScript("OnUpdate", nil)
    if fadingArt then
        fadingArt:SetParent(LootFrame)
        fadingArt:SetFrameLevel(fadingArtLevel)
        fadingArt = nil
    end
    for index, region in ipairs(fadingRegions) do
        region:SetParent(LootFrame)
        fadingRegions[index] = nil
    end
end

local function moveBackground()
    background:SetScale(LootFrame:GetEffectiveScale() / UIParent:GetEffectiveScale())
    local art = LootFrame.RetailArt
    if art and art:IsShown() then
        -- The client fits this frame to the visible loot rows and anchors it to LootFrame.
        fadingArt, fadingArtLevel = art, art:GetFrameLevel()
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
LootFrame:HookScript("OnShow", finishBackground)
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
