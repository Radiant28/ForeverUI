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

function ui.ApplyGryphons()
    local alpha = ui.Settings().showGryphons == false and 0 or 1
    MainMenuBarLeftEndCap:SetAlpha(alpha)
    MainMenuBarRightEndCap:SetAlpha(alpha)
end

local function applyArt()
    local settings = ui.Settings()
    ui.ApplyGryphons()
    for _, texture in ipairs(tinted) do texture:SetVertexColor(artColor()) end
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
