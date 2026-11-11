local _, ui = ...
local art = "Interface\\AddOns\\ForeverUI\\Art\\"
local atlas = art .. "Micro-Color"

-- Cells are column-major, with six rows of four-state icons in the source atlas.
local icons = {
    Character = { 8, 9, 8 },
    Spellbook = { 48, 46, 45 },
    Talent = { 44, 42, 41 },
    Achievement = { 3, 1, 0 },
    QuestLog = { 36, 34, 33 },
    Socials = { 29, 23, 22 },
    PVP = { 8, 9, 8 },
    LFD = { 21, 19, 18 },
    EncounterJournal = { 7, 5, 4 },
    Store = { 60, 61, 62 },
    MainMenu = { 40, 39, 37 },
    Help = { 17, 15, 14 },
}
local states = { "Normal", "Pushed", "Disabled" }
local hovers = {}

-- Retail look: DragonUI's flat micro menu icons (MIT, see Art/CREDITS.md), cells of a 256 x 512 sheet as
-- left, right, top, bottom pixels.
local retailSheet = art .. "ActionBar\\Retail-Micro"
local retailCells = {
    achievement = { up = {161, 199, 109, 161}, down = {161, 199, 55, 107}, mouseover = {201, 239, 55, 107}, disabled = {201, 239, 109, 161} },
    character = { up = {1, 39, 325, 377}, down = {121, 159, 163, 215}, mouseover = {81, 119, 217, 269}, disabled = {1, 39, 217, 269} },
    collections = { up = {41, 79, 163, 215}, down = {1, 39, 379, 431}, mouseover = {1, 39, 433, 485}, disabled = {121, 159, 1, 53} },
    help = { up = {201, 239, 217, 269}, down = {121, 159, 217, 269}, mouseover = {161, 199, 217, 269}, disabled = {41, 79, 217, 269} },
    lfd = { up = {1, 39, 163, 215}, down = {81, 119, 109, 161}, mouseover = {41, 79, 109, 161}, disabled = {41, 79, 271, 323} },
    mainmenu = { up = {1, 39, 109, 161}, down = {161, 199, 271, 323}, mouseover = {121, 159, 325, 377}, disabled = {41, 79, 325, 377} },
    pvp = { up = {1, 39, 271, 323}, down = {201, 239, 163, 215}, mouseover = {161, 199, 163, 215}, disabled = {81, 119, 163, 215} },
    questlog = { up = {201, 239, 271, 323}, down = {121, 159, 271, 323}, mouseover = {41, 79, 433, 485}, disabled = {41, 79, 379, 431} },
    socials = { up = {41, 79, 55, 107}, down = {1, 39, 1, 53}, mouseover = {41, 79, 1, 53}, disabled = {201, 239, 1, 53} },
    spellbook = { up = {121, 159, 55, 107}, down = {81, 119, 433, 485}, mouseover = {189, 227, 433, 485}, disabled = {1, 39, 55, 107} },
    talent = { up = {161, 199, 1, 53}, down = {81, 119, 271, 323}, mouseover = {81, 119, 1, 53}, disabled = {81, 119, 55, 107} },
}
local retailNames = { Character = "character", Spellbook = "spellbook", Talent = "talent", Achievement = "achievement",
    QuestLog = "questlog", Socials = "socials", PVP = "pvp", LFD = "lfd", MainMenu = "mainmenu", Help = "help" }
local skins, stockSizes, stockInsets, stockPoints = {}, {}, {}, {}

ui.MicroMenu = {
    ApplyLayout = function() if ui.MicroMenu.layout then ui.MicroMenu.layout() end end,
    ApplyColors = function()
        local value = ui.Settings().microHoverColor
        if type(value) ~= "table" then value = { 1, 0.84, 0.65 } end
        for _, hover in ipairs(hovers) do hover:SetVertexColor(value[1], value[2], value[3]) end
    end,
}

local function setRetailCell(texture, cell)
    texture:SetTexture(retailSheet)
    texture:SetTexCoord(cell[1] / 256, cell[2] / 256, cell[3] / 512, cell[4] / 512)
    texture:ClearAllPoints()
    texture:SetAllPoints(texture:GetParent())
end

-- Buttons without a flat DragonUI icon (Store, Adventure Guide) keep their colour icon in Retail, but
-- desaturated and without the plate, so they sit with the flat ones.
local function flatCell(texture, button, cell)
    local x = 1 + math.floor(cell / 6) * 66
    local y = 1 + (cell % 6) * 84
    texture:SetTexture(atlas)
    texture:SetTexCoord(x / 1024, (x + 64) / 1024, y / 512, (y + 82) / 512)
    -- Slightly larger than the flat icons and lifted, so the row lines up with them.
    texture:ClearAllPoints()
    texture:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    texture:SetSize(29, 35)
    texture:SetDesaturated(1)
    texture:SetVertexColor(0.92, 0.92, 0.92)
end

local function setCell(texture, button, cell)
    local x = 1 + math.floor(cell / 6) * 66
    local y = 1 + (cell % 6) * 84
    texture:SetTexture(atlas)
    texture:SetTexCoord(x / 1024, (x + 64) / 1024, y / 512, (y + 82) / 512)
    texture:ClearAllPoints()
    texture:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    texture:SetSize(27, 35)
    texture:SetDesaturated(nil)
    texture:SetVertexColor(1, 1, 1)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local settings = ui.Settings()
    if settings.microEnabled == false then return end
    local hoverColor = type(settings.microHoverColor) == "table" and settings.microHoverColor or { 1, 0.84, 0.65 }
    for name, cells in pairs(icons) do
        local button = _G[name .. "MicroButton"]
        if button then
            local plate = button:CreateTexture(nil, "BACKGROUND")
            setCell(plate, button, 8)
            local edge = button:CreateTexture(nil, "OVERLAY")
            ui.ApplySlotEdge(edge)
            edge:SetAllPoints(plate)
            local hover = button:CreateTexture(nil, "HIGHLIGHT")
            ui.ApplySlotEdge(hover)
            hover:SetAllPoints(plate)
            hover:SetVertexColor(hoverColor[1], hoverColor[2], hoverColor[3])
            hovers[#hovers + 1] = hover
            skins[name] = { plate = plate, edge = edge, hover = hover, button = button, cells = cells }
            button:SetHighlightTexture(hover)
            hover:SetBlendMode("ADD")
            for i, state in ipairs(states) do
                local setter, getter = "Set" .. state .. "Texture", "Get" .. state .. "Texture"
                local cell = cells[i]
                button[setter](button, atlas)
                local texture = button[getter](button)
                setCell(texture, button, cell)
                if name == "Store" then
                    -- Nozdor assigns the stock store textures on a delayed client update.
                    hooksecurefunc(button, setter, function(self)
                        local current = self[getter](self)
                        if not current then return end
                        if skins[name] and skins[name].flat then
                            flatCell(current, self, cell)
                        else
                            setCell(current, self, cell)
                        end
                    end)
                end
            end
        end
    end
    ui.MicroMenu.layout = function()
        if InCombatLockdown() then return end
        local retail = ui.Settings().barLayout == "retail"
        for name, skin in pairs(skins) do
            local button = skin.button
            local cells = retailNames[name] and retailCells[retailNames[name]]
            local flat = retail and cells
            local desaturated = retail and not cells
            skin.flat = desaturated
            -- Flat icons carry their own plate; the colour-only buttons get the bronze plate, desaturated.
            skin.plate:SetAlpha(flat and 0 or 1)
            skin.edge:SetAlpha((flat or desaturated) and 0 or 1)
            if not stockSizes[button] then stockSizes[button] = { button:GetSize() } end
            -- The stock buttons are 58 px tall with the top 18 px outside the hit area; a resized button
            -- must be clickable over its whole face.
            if not stockInsets[button] then stockInsets[button] = { button:GetHitRectInsets() } end
            -- Retail spacing: every button chained to another micro button sits exactly `spacing` px away from it
            -- (the stock chain overlaps the buttons, so the stock offset is replaced, not added to).
            if not stockPoints[button] then
                stockPoints[button] = {}
                for point = 1, button:GetNumPoints() do stockPoints[button][point] = { button:GetPoint(point) } end
            end
            local spacing = retail and (tonumber(ui.Settings().microSpacing) or 4) or 0
            button:ClearAllPoints()
            for _, saved in ipairs(stockPoints[button]) do
                local point, relative, relativePoint, x, y = unpack(saved, 1, 5)
                local name = relative and relative.GetName and relative:GetName()
                if spacing ~= 0 and name and name:find("MicroButton$") and point and relativePoint then
                    if point:find("LEFT") and relativePoint:find("RIGHT") then
                        x = spacing
                    elseif point:find("RIGHT") and relativePoint:find("LEFT") then
                        x = -spacing
                    end
                end
                button:SetPoint(point, relative, relativePoint, x, y)
            end
            if retail then
                button:SetHitRectInsets(0, 0, 0, 0)
            else
                button:SetHitRectInsets(unpack(stockInsets[button], 1, 4))
            end
            button:EnableMouse(true)
            if flat then
                button:SetSize(24, 32)
                local faces = { { "GetNormalTexture", cells.up }, { "GetPushedTexture", cells.down },
                    { "GetDisabledTexture", cells.disabled } }
                for _, face in ipairs(faces) do
                    local texture = button[face[1]](button)
                    if texture then setRetailCell(texture, face[2]) end
                end
                setRetailCell(skin.hover, cells.mouseover)
                skin.hover:SetBlendMode("ADD")
                skin.hover:SetVertexColor(1, 1, 1)
            elseif desaturated then
                button:SetSize(24, 32)
                flatCell(skin.plate, button, 8)
                for i, state in ipairs(states) do
                    local texture = button["Get" .. state .. "Texture"](button)
                    if texture and skin.cells[i] then flatCell(texture, button, skin.cells[i]) end
                end
                -- The mouse-over glow reuses the normal icon.
                local x = 1 + math.floor(skin.cells[1] / 6) * 66
                local y = 1 + (skin.cells[1] % 6) * 84
                skin.hover:SetTexture(atlas)
                skin.hover:SetTexCoord(x / 1024, (x + 64) / 1024, y / 512, (y + 82) / 512)
                skin.hover:ClearAllPoints()
                skin.hover:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
                skin.hover:SetSize(29, 35)
                skin.hover:SetBlendMode("ADD")
                skin.hover:SetVertexColor(1, 1, 1)
            else
                button:SetSize(unpack(stockSizes[button], 1, 2))
                setCell(skin.plate, button, 8)
                for i, state in ipairs(states) do
                    local texture = button["Get" .. state .. "Texture"](button)
                    if texture and skin.cells[i] then setCell(texture, button, skin.cells[i]) end
                end
                ui.ApplySlotEdge(skin.hover)
                skin.hover:ClearAllPoints()
                skin.hover:SetAllPoints(skin.plate)
                ui.MicroMenu.ApplyColors()
            end
        end
        if MicroButtonPortrait then MicroButtonPortrait:SetAlpha(retail and 0 or 1) end
        if ui.MicroMenu.emblem then ui.MicroMenu.emblem:SetAlpha(retail and 0 or 1) end
    end
    if MicroButtonPortrait then
        MicroButtonPortrait:ClearAllPoints()
        MicroButtonPortrait:SetPoint("BOTTOM", CharacterMicroButton, "BOTTOM", 0, 7)
        MicroButtonPortrait:SetSize(18, 25)
    end
    if PVPMicroButtonTexture then
        PVPMicroButtonTexture:SetAlpha(0)
        local emblem = PVPMicroButton:CreateTexture(nil, "ARTWORK")
        local left = UnitFactionGroup("player") == "Horde" and 118 or 0
        emblem:SetTexture(art .. "Micro-PvP")
        emblem:SetTexCoord(left / 256, (left + 118) / 256, 0, 151 / 256)
        emblem:SetPoint("BOTTOM", PVPMicroButton, "BOTTOM", 0, 2)
        emblem:SetSize(27, 35)
        ui.MicroMenu.emblem = emblem
    end
    ui.MicroMenu.layout()
end)
