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

ui.MicroMenu = {
    ApplyColors = function()
        local value = ui.Settings().microHoverColor
        if type(value) ~= "table" then value = { 1, 0.84, 0.65 } end
        for _, hover in ipairs(hovers) do hover:SetVertexColor(value[1], value[2], value[3]) end
    end,
}

local function setCell(texture, button, cell)
    local x = 1 + math.floor(cell / 6) * 66
    local y = 1 + (cell % 6) * 84
    texture:SetTexture(atlas)
    texture:SetTexCoord(x / 1024, (x + 64) / 1024, y / 512, (y + 82) / 512)
    texture:ClearAllPoints()
    texture:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    texture:SetSize(27, 35)
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
                        if current then setCell(current, self, cell) end
                    end)
                end
            end
        end
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
    end
end)
