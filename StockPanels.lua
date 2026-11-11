local _, ui = ...
local art = "Interface\\AddOns\\ForeverUI\\Art\\"
local gryphons = art .. "ActionBar-EndCaps"

MainMenuBarLeftEndCap:SetTexture(gryphons)
MainMenuBarLeftEndCap:SetTexCoord(0, 482 / 1024, 0, 282 / 1024)
MainMenuBarLeftEndCap:SetSize(104, 61)
MainMenuBarLeftEndCap:SetVertexColor(1, 0.84, 0.65)
MainMenuBarRightEndCap:SetTexture(gryphons)
MainMenuBarRightEndCap:SetTexCoord(482 / 1024, 960 / 1024, 0, 282 / 1024)
MainMenuBarRightEndCap:SetSize(104, 61)
MainMenuBarRightEndCap:SetVertexColor(1, 0.84, 0.65)

local events = CreateFrame("Frame")
local tinted = { MainMenuBarLeftEndCap, MainMenuBarRightEndCap }
local slotEdges, slotBackgrounds, progressBorders = {}, {}, {}

local function artColor()
    local value = ui.Settings().barArtColor
    if type(value) ~= "table" then value = { 1, 0.84, 0.65 } end
    return value[1], value[2], value[3]
end

local function retailLayout()
    return ui.Settings().barLayout == "retail"
end

-- Retail look: Dragonflight gryphons (Alliance) or wyverns (Horde) hugging the main bar's button row instead
-- of the 1024 px stock art. The sheets and their cells come from DragonUI (MIT, see Art/CREDITS.md); the stock
-- look of each cap is remembered so the Classic layout can put it back.
local retailCaps = {
    Alliance = { art .. "ActionBar\\Retail-EndCaps-Alliance", { 1, 357, 209, 543 }, { 1, 357, 545, 879 } },
    Horde = { art .. "ActionBar\\Retail-EndCaps-Horde", { 1, 357, 1, 335 }, { 1, 357, 337, 671 } },
}
local stockCapPoints, stockCapLook
local function placeGryphons()
    local caps = { MainMenuBarLeftEndCap, MainMenuBarRightEndCap }
    if not stockCapPoints then
        stockCapPoints, stockCapLook = {}, {}
        for index, cap in ipairs(caps) do
            stockCapPoints[index] = {}
            for point = 1, cap:GetNumPoints() do stockCapPoints[index][point] = { cap:GetPoint(point) } end
            stockCapLook[index] = { cap:GetTexture(), { cap:GetTexCoord() }, cap:GetWidth(), cap:GetHeight() }
        end
    end
    if retailLayout() and ActionButton1 then
        local layout = ui.Settings().editLayout
        local config = type(layout) == "table" and layout.MainMenuBar
        local count = type(config) == "table" and tonumber(config.count) or 12
        local rows = type(config) == "table" and tonumber(config.rows) or 1
        count = math.max(1, math.min(12, math.floor(count)))
        rows = math.max(1, math.min(count, math.floor(rows)))
        local last = _G["ActionButton" .. math.ceil(count / rows)] or ActionButton12
        local retail = retailCaps[UnitFactionGroup("player")] or retailCaps.Horde
        for index, cap in ipairs(caps) do
            local cell = retail[index + 1]
            cap:SetTexture(retail[1])
            cap:SetTexCoord(cell[1] / 512, cell[2] / 512, cell[3] / 1024, cell[4] / 1024)
            cap:SetSize(104.5, 98)
            cap:SetVertexColor(1, 1, 1)
            cap:ClearAllPoints()
        end
        -- Retail puts the caps 9 px over the first slot and 6 px over the last, 24 px below the slot row.
        MainMenuBarLeftEndCap:SetPoint("BOTTOMRIGHT", ActionButton1, "BOTTOMLEFT", 9, -24)
        MainMenuBarRightEndCap:SetPoint("BOTTOMLEFT", last, "BOTTOMRIGHT", -6, -24)
    else
        for index, cap in ipairs(caps) do
            local look = stockCapLook[index]
            if look[1] then cap:SetTexture(look[1]) end
            cap:SetTexCoord(unpack(look[2], 1, 8))
            cap:SetSize(look[3], look[4])
            cap:ClearAllPoints()
            for _, point in ipairs(stockCapPoints[index]) do cap:SetPoint(unpack(point, 1, 5)) end
        end
    end
end

function ui.ApplyGryphons()
    local alpha = ui.Settings().showGryphons == false and 0 or 1
    MainMenuBarLeftEndCap:SetAlpha(alpha)
    MainMenuBarRightEndCap:SetAlpha(alpha)
    placeGryphons()
end

-- Shared helpers: remember how a texture region looked so the Classic layout can restore it.
local function regionState(region)
    local state = { points = {}, texture = region:GetTexture(), coords = { region:GetTexCoord() },
        layer = { region:GetDrawLayer() }, alpha = region:GetAlpha() }
    for point = 1, region:GetNumPoints() do state.points[point] = { region:GetPoint(point) } end
    return state
end

local function restoreRegion(region, state)
    region:ClearAllPoints()
    for _, point in ipairs(state.points) do region:SetPoint(unpack(point, 1, 5)) end
    if state.texture then region:SetTexture(state.texture) end
    region:SetTexCoord(unpack(state.coords, 1, 8))
    region:SetDrawLayer(unpack(state.layer, 1, 2))
    region:SetAlpha(state.alpha)
end

-- Retail bag bar (cells from DragonUI's bag sheet): a big backpack picture, round rings on 28 px bag slots.
local bagSheet = art .. "ActionBar\\Retail-Bags"
local bagSlots = { "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot" }
local bagSkins, stockBags = {}, nil

local function glow(button, setter, getter, stockPath, cell, size, retail)
    if retail then
        button[setter](button, bagSheet, "ADD")
        local texture = button[getter](button)
        if texture then
            texture:SetTexCoord(cell[1] / 512, cell[2] / 512, cell[3] / 128, cell[4] / 128)
            texture:ClearAllPoints()
            texture:SetPoint("CENTER", button, "CENTER")
            texture:SetSize(size, size)
        end
    else
        button[setter](button, stockPath, "ADD")
        local texture = button[getter](button)
        if texture then
            texture:SetTexCoord(0, 1, 0, 1)
            texture:ClearAllPoints()
            texture:SetAllPoints(button)
        end
    end
end

-- Any other region or child frame on a bag slot (square quality borders and the like) is hidden in Retail.
local extras = {}
local function hideExtras(slot, keep, hide)
    local function visit(object)
        if keep[object] then return end
        if hide then
            if extras[object] == nil then extras[object] = object:GetAlpha() end
            object:SetAlpha(0)
        elseif extras[object] ~= nil then
            object:SetAlpha(extras[object])
            extras[object] = nil
        end
    end
    for _, region in ipairs({ slot:GetRegions() }) do visit(region) end
    for _, child in ipairs({ slot:GetChildren() }) do visit(child) end
end

SLASH_FOREVERUIBAG1 = "/fuibag"
SlashCmdList.FOREVERUIBAG = function(name)
    local slot = _G[name ~= "" and name or "CharacterBag3Slot"]
    if not slot then return end
    local function describe(kind, object)
        local texture = object.GetTexture and object:GetTexture() or ""
        print(kind, object:GetName() or "<anon>", object:GetObjectType(), tostring(texture),
            object.GetWidth and string.format("%.0fx%.0f", object:GetWidth(), object:GetHeight()) or "",
            "alpha", object:GetAlpha(), object:IsShown() and "shown" or "hidden")
    end
    for _, region in ipairs({ slot:GetRegions() }) do describe("region", region) end
    for _, child in ipairs({ slot:GetChildren() }) do describe("child", child) end
end

local function applyBags()
    local retail = retailLayout()
    local backpack, icon = MainMenuBarBackpackButton, MainMenuBarBackpackButtonIconTexture
    if not backpack or not icon or not CharacterBag0Slot or InCombatLockdown() then return end
    if not stockBags then
        stockBags = { size = backpack:GetWidth(), icon = regionState(icon), points = {}, slots = {} }
        for point = 1, CharacterBag0Slot:GetNumPoints() do stockBags.points[point] = { CharacterBag0Slot:GetPoint(point) } end
        for _, name in ipairs(bagSlots) do
            local slot = _G[name]
            local slotIcon = slot and _G[name .. "IconTexture"]
            if slotIcon then stockBags.slots[name] = { size = slot:GetWidth(), icon = regionState(slotIcon) } end
        end
    end
    local highlightPath = "Interface\\Buttons\\ButtonHilight-Square"
    local checkedPath = "Interface\\Buttons\\CheckButtonHilight"
    if retail then
        backpack:SetSize(50, 50)
        icon:SetTexture(bagSheet)
        icon:SetTexCoord(1 / 512, 97 / 512, 1 / 128, 97 / 128)
        CharacterBag0Slot:ClearAllPoints()
        CharacterBag0Slot:SetPoint("RIGHT", backpack, "LEFT", -14, -2)
    else
        backpack:SetSize(stockBags.size, stockBags.size)
        restoreRegion(icon, stockBags.icon)
        CharacterBag0Slot:ClearAllPoints()
        for _, point in ipairs(stockBags.points) do CharacterBag0Slot:SetPoint(unpack(point, 1, 5)) end
    end
    -- The stock square frame around the backpack picture, and anything else another addon added.
    local backpackCount = _G["MainMenuBarBackpackButtonCount"]
    local backpackNormal = backpack:GetNormalTexture()
    if backpackNormal then backpackNormal:SetAlpha(retail and 0 or 1) end
    hideExtras(backpack, { [icon] = true, [backpackCount or icon] = true, [backpack:GetCheckedTexture() or icon] = true,
        [backpack:GetHighlightTexture() or icon] = true, [backpack:GetPushedTexture() or icon] = true,
        [backpackNormal or icon] = true }, retail)
    glow(backpack, "SetHighlightTexture", "GetHighlightTexture", highlightPath, { 99, 195, 1, 97 }, 50, retail)
    glow(backpack, "SetCheckedTexture", "GetCheckedTexture", checkedPath, { 99, 195, 1, 97 }, 50, retail)

    for _, name in ipairs(bagSlots) do
        local slot, slotIcon = _G[name], _G[name .. "IconTexture"]
        if slot and slotIcon then
            local skin = bagSkins[slot]
            if not skin and retail then
                skin = {}
                skin.back = slot:CreateTexture(nil, "BACKGROUND", nil, -2)
                skin.back:SetTexture(bagSheet)
                skin.back:SetTexCoord(295 / 512, 356 / 512, 64 / 128, 125 / 128)
                skin.back:SetSize(34, 34)
                skin.back:SetPoint("CENTER", slot, "CENTER")
                skin.ring = slot:CreateTexture(nil, "OVERLAY", nil, 6)
                skin.ring:SetTexture(bagSheet)
                skin.ring:SetTexCoord(295 / 512, 356 / 512, 1 / 128, 62 / 128)
                skin.ring:SetSize(34, 34)
                skin.ring:SetPoint("CENTER", slot, "CENTER")
                bagSkins[slot] = skin
            end
            if skin then
                skin.back:SetAlpha(retail and 1 or 0)
                skin.ring:SetAlpha(retail and 1 or 0)
            end
            local stock = stockBags.slots[name]
            if retail then
                slot:SetSize(28, 28)
                slotIcon:ClearAllPoints()
                slotIcon:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -5, -2.9)
                slotIcon:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 2.9, 5)
                slotIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            elseif stock then
                slot:SetSize(stock.size, stock.size)
                restoreRegion(slotIcon, stock.icon)
            end
            local keep = { [slotIcon] = true, [_G[name .. "Count"] or slotIcon] = true,
                [slot:GetCheckedTexture() or slotIcon] = true, [slot:GetHighlightTexture() or slotIcon] = true,
                [slot:GetPushedTexture() or slotIcon] = true, [_G[name .. "Cooldown"] or slotIcon] = true }
            if skin then keep[skin.back], keep[skin.ring] = true, true end
            hideExtras(slot, keep, retail)
            -- The stock round frame clashes with the Retail ring.
            local normal = slot:GetNormalTexture()
            if normal then normal:SetAlpha(retail and 0 or 1) end
            glow(slot, "SetHighlightTexture", "GetHighlightTexture", highlightPath, { 358, 419, 1, 62 }, 40, retail)
            glow(slot, "SetCheckedTexture", "GetCheckedTexture", checkedPath, { 358, 419, 1, 62 }, 40, retail)
        end
    end
end

-- Retail XP bar (DragonUI's retail UI look): the dark background, the round border and the width of the bar
-- row; the bar is resized instead of scaled, so its text keeps the normal size.
local xpSheet = art .. "ActionBar\\Retail-XP"
local XP_HEIGHT = 10
local stockXp

local function applyXpBar()
    local bar = MainMenuExpBar
    if not bar or InCombatLockdown() then return end
    local retail = retailLayout()
    if not stockXp then
        stockXp = { width = bar:GetWidth(), height = bar:GetHeight(), backgrounds = {}, borders = {},
            fill = ExhaustionLevelFillBar and ExhaustionLevelFillBar:GetHeight() }
        for _, region in ipairs({ bar:GetRegions() }) do
            if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" then
                stockXp.backgrounds[#stockXp.backgrounds + 1] = { region, regionState(region) }
            end
        end
        for index = 0, 3 do
            local border = _G["MainMenuXPBarTexture" .. index]
            if border then stockXp.borders[index] = { border, regionState(border) } end
        end
    end
    if retail then
        bar:SetSize(math.max(100, tonumber(ui.Settings().barXpWidth) or stockXp.width), XP_HEIGHT)
        for index, entry in ipairs(stockXp.backgrounds) do
            local region = entry[1]
            if index == 1 then
                region:ClearAllPoints()
                region:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 0)
                region:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, 0)
                region:SetTexture(xpSheet)
                region:SetTexCoord(0, 570 / 1024, 20 / 256, 29 / 256)
                region:SetAlpha(1)
            else
                region:SetAlpha(0)
            end
        end
        for index, entry in pairs(stockXp.borders) do
            local border = entry[1]
            if index == 0 then
                border:ClearAllPoints()
                border:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 3)
                border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -6)
                border:SetDrawLayer("OVERLAY", 1)
                border:SetTexture(xpSheet)
                border:SetTexCoord(1 / 1024, 572 / 1024, 1 / 256, 18 / 256)
                border:SetVertexColor(1, 1, 1)
                border:SetAlpha(1)
            else
                border:SetAlpha(0)
            end
        end
        if ExhaustionLevelFillBar then ExhaustionLevelFillBar:SetHeight(XP_HEIGHT) end
    else
        bar:SetSize(stockXp.width, stockXp.height)
        for _, entry in ipairs(stockXp.backgrounds) do restoreRegion(entry[1], entry[2]) end
        for _, entry in pairs(stockXp.borders) do restoreRegion(entry[1], entry[2]) end
        if ExhaustionLevelFillBar and stockXp.fill then ExhaustionLevelFillBar:SetHeight(stockXp.fill) end
    end
end

-- The page arrows and number next to the main bar are not part of the Retail look.
local function applyPager()
    local hidden = retailLayout()
    for _, name in ipairs({ "ActionBarUpButton", "ActionBarDownButton", "MainMenuBarPageNumber" }) do
        local frame = _G[name]
        if frame then
            frame:SetAlpha(hidden and 0 or 1)
            if frame.EnableMouse then frame:EnableMouse(not hidden) end
        end
    end
end

-- The XP bar is scaled down in the Retail layout; keep its text at a readable on-screen size.
local function fitBarText(bar, text)
    if not bar or not text then return end
    local file, size, flags = text:GetFont()
    if not file then return end
    text.foreverBase = text.foreverBase or size
    local scale = bar:GetScale()
    if not scale or scale <= 0 then scale = 1 end
    local target = scale < 1 and math.min(36, math.max(text.foreverBase, 12) / scale) or text.foreverBase
    if math.abs(target - size) > 0.1 then text:SetFont(file, target, flags) end
end

local function fitTexts()
    fitBarText(MainMenuExpBar, MainMenuBarExpText)
    fitBarText(ReputationWatchBar, ReputationWatchStatusBarText)
end
if MainMenuExpBar then hooksecurefunc(MainMenuExpBar, "SetScale", fitTexts) end
if ReputationWatchBar then hooksecurefunc(ReputationWatchBar, "SetScale", fitTexts) end

local function applyArt()
    local settings = ui.Settings()
    ui.ApplyGryphons()
    for _, texture in ipairs(tinted) do texture:SetVertexColor(artColor()) end
    -- The Retail caps keep their own colours; reapply their state after the tint.
    ui.ApplyGryphons()
    applyBags()
    applyXpBar()
    applyPager()
    if ui.MicroMenu and ui.MicroMenu.ApplyLayout then ui.MicroMenu.ApplyLayout() end
    fitTexts()
    local stockArt = settings.barStockArt ~= false and 1 or 0
    for i = 0, 3 do
        local texture = _G["MainMenuBarTexture" .. i]
        if texture then texture:SetAlpha(stockArt) end
    end
    local edges = settings.barSlotEdges ~= false and 1 or 0
    for edge in pairs(slotEdges) do edge:SetAlpha(edges) end
    local backgrounds = settings.barSlotBackgrounds ~= false and 1 or 0
    for background in pairs(slotBackgrounds) do background:SetAlpha(backgrounds) end
    local borders = settings.barProgressBorder ~= false and 1 or 0
    for border in pairs(progressBorders) do border:SetAlpha(borders) end
end
ui.ActionBars = { Apply = applyArt }

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    applyArt()
    if ui.RegisterEditFrame then
        for _, name in ipairs({ "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight" }) do
            ui.RegisterEditFrame(_G[name], nil, "actionbars")
        end
    end
end)

for i = 0, 3 do
    tinted[#tinted + 1] = _G["MainMenuBarTexture" .. i]
    tinted[#tinted + 1] = _G["MainMenuXPBarTexture" .. i]
    tinted[#tinted + 1] = _G["MainMenuMaxLevelBar" .. i]
end
for _, texture in ipairs(tinted) do texture:SetVertexColor(1, 0.84, 0.65) end

-- The stock XP border ends above the bottom of the status bar.
ExhaustionLevelFillBar:SetHeight(MainMenuXPBarTexture0:GetHeight())

local slotArt = art .. "ActionBar\\Slots"
function ui.ApplySlotEdge(texture)
    texture:SetTexture(slotArt)
    texture:SetTexCoord(132 / 256, 224 / 256, 0, 90 / 128)
end

local slots = {}
local function updateSlot(button)
    if not slots[button] then return end
    local normal = button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
end

for _, prefix in ipairs({
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarLeftButton", "MultiBarRightButton", "BonusActionButton",
    "PetActionButton", "ShapeshiftButton", "PossessButton", "MultiCastActionButton",
}) do
    for index = 1, 12 do
        local name = prefix .. index
        local button, icon = _G[name], _G[name .. "Icon"]
        if button and icon then
            local edge = button:CreateTexture(nil, "ARTWORK", nil, -1)
            ui.ApplySlotEdge(edge)
            edge:SetAllPoints(button)
            slotEdges[edge] = true

            slots[button] = true
            if prefix == "ActionButton" or prefix == "BonusActionButton" then
                -- The artwork stays visible when the stock grid hides an empty button.
                local background = button:GetParent():CreateTexture(nil, "OVERLAY")
                background:SetTexture(slotArt)
                background:SetTexCoord(0, 128 / 256, 0, 124 / 128)
                background:SetAllPoints(icon)
                slotBackgrounds[background] = true
            end
            updateSlot(button)
        end
    end
end
hooksecurefunc("ActionButton_Update", updateSlot)
if PetActionBar_Update then
    hooksecurefunc("PetActionBar_Update", function()
        for index = 1, NUM_PET_ACTION_SLOTS do
            updateSlot(_G["PetActionButton" .. index])
        end
    end)
end

local function skinProgress(bar)
    if not bar then return end
    local border = bar:CreateTexture(nil, "ARTWORK")
    border:SetTexture(art .. "ActionBar\\StatusBarTexture")
    border:SetTexCoord(0, 1, 0, 27 / 128)
    border:SetAllPoints(bar)
    progressBorders[border] = true
end
skinProgress(ReputationWatchStatusBar)
