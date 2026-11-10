local _, ui = ...
local midArt = "Interface\\AddOns\\ForeverUI\\Art\\MidCast\\"
local bars, settings = {}
-- Stock dimensions are captured before any skinning so option defaults stay stable.
local stock = {
    width = CastingBarFrame:GetWidth(), height = CastingBarFrame:GetHeight(),
    scale = CastingBarFrame:GetScale() * 100,
}
local kindKeys = { player = "castSkinPlayer", pet = "castSkinPet", target = "castSkinTarget", focus = "castSkinFocus",
    boss = "castSkinBoss", arena = "castSkinArena" }

local function enabledFor(state)
    local key = kindKeys[state.kind or "player"]
    return settings.castMidStyle and settings[key] ~= false
end

local function tint(key, fallback)
    local value = settings[key]
    if type(value) ~= "table" then value = fallback end
    return value[1], value[2], value[3], value[4] or 1
end

local function updateTimer(bar)
    local state = bars[bar]
    if not state.restore then return end
    if settings.castTimer and bar.maxValue and (bar.casting or bar.channeling) then
        local value = bar:GetValue()
        local remaining = bar.channeling and value or bar.maxValue - value
        state.timer:SetFormattedText("%." .. (settings.castTimerDecimals or 1) .. "f", math.max(0, remaining))
    else
        state.timer:SetText("")
    end
end

local function updateFillCoords(bar)
    local state = bars[bar]
    if not state.restore then return end
    local minimum, maximum = bar:GetMinMaxValues()
    local progress = maximum > minimum and (bar:GetValue() - minimum) / (maximum - minimum) or 0
    bar:GetStatusBarTexture():SetTexCoord(0, math.max(0, math.min(1, progress)), 0, 1)
end

local function rememberNativeColor(bar, state)
    local r, g, b, a = bar:GetStatusBarColor()
    local applied = state.appliedColor
    if not applied or r ~= applied[1] or g ~= applied[2] or b ~= applied[3] or a ~= applied[4] then
        state.nativeColor = { r, g, b, a }
    end
end

local function updateColor(bar)
    local state = bars[bar]
    if not state.restore then return end
    local fill = midArt .. (bar.channeling and "uicastingbar-chanel" or "uicastingbar-normal")
    rememberNativeColor(bar, state)
    if state.fillPath ~= fill then
        bar:SetStatusBarTexture(fill)
        state.fillPath = fill
    end
    updateFillCoords(bar)
    if bar.casting or bar.channeling then
        if state.shield and state.shield:IsShown() then
            bar:SetStatusBarColor(tint("castShieldColor", { 0.64, 0.65, 0.71 }))
        elseif bar.channeling then
            bar:SetStatusBarColor(tint("castChannelColor", { 1, 1, 1 }))
        else
            bar:SetStatusBarColor(tint("castFillColor", { 1, 1, 1 }))
        end
        state.appliedColor = { bar:GetStatusBarColor() }
    end
end

local function rememberBounds(region)
    local width, height = region:GetWidth(), region:GetHeight()
    local points = {}
    for i = 1, region:GetNumPoints() do points[i] = { region:GetPoint(i) } end
    return function()
        region:ClearAllPoints()
        region:SetSize(width, height)
        for _, point in ipairs(points) do region:SetPoint(unpack(point, 1, 5)) end
    end
end

local function rememberArt(texture)
    local file = texture:GetTexture()
    local coords = { texture:GetTexCoord() }
    local width, height = texture:GetWidth(), texture:GetHeight()
    return function()
        texture:SetTexture(file)
        texture:SetTexCoord(unpack(coords))
        texture:SetSize(width, height)
    end
end

local function enableAlternative(bar, state)
    local width, height, scale = bar:GetWidth(), bar:GetHeight(), bar:GetScale()
    local texture = bar:GetStatusBarTexture()
    local nativeFill = texture:GetTexture()
    local nativeFillLayer = { texture:GetDrawLayer() }
    local nativeFillCoords = { texture:GetTexCoord() }
    state.fillPath, state.appliedColor = nil, nil
    rememberNativeColor(bar, state)

    local spell = state.spell
    local spellBounds = rememberBounds(spell)
    local font = { spell:GetFont() }
    local spellLayer = { spell:GetDrawLayer() }
    local justify, wrap = spell:GetJustifyH(), spell:CanWordWrap()
    local borderAlpha = state.border and state.border:GetAlpha()
    local shieldAlpha = state.shield and state.shield:GetAlpha()
    local sparkArt = state.spark and rememberArt(state.spark)
    local flashArt = state.flash and rememberArt(state.flash)
    local flashBounds = state.flash and rememberBounds(state.flash)
    local icon = state.icon
    local iconWidth, iconHeight, iconShown
    if icon then iconWidth, iconHeight, iconShown = icon:GetWidth(), icon:GetHeight(), icon:IsShown() end

    state.restore = function()
        rememberNativeColor(bar, state)
        if bar == CastingBarFrame then
            bar:SetSize(width, height)
            bar:SetScale(scale)
        end
        bar:SetStatusBarTexture(nativeFill)
        local restoredFill = bar:GetStatusBarTexture()
        restoredFill:SetDrawLayer(unpack(nativeFillLayer))
        restoredFill:SetTexCoord(unpack(nativeFillCoords))
        bar:SetStatusBarColor(unpack(state.nativeColor))
        spell:SetFont(unpack(font))
        spell:SetDrawLayer(unpack(spellLayer))
        spell:SetJustifyH(justify)
        spell:SetWordWrap(wrap)
        spellBounds()
        if state.border then state.border:SetAlpha(borderAlpha) end
        if state.shield then state.shield:SetAlpha(shieldAlpha) end
        if sparkArt then sparkArt() end
        if flashArt then
            flashArt()
            flashBounds()
        end
        if icon then
            icon:SetSize(iconWidth, iconHeight)
            if iconShown then icon:Show() else icon:Hide() end
        end
        for _, region in ipairs(state.regions) do region:Hide() end
    end

    if state.border then state.border:SetAlpha(0) end
    if state.shield then state.shield:SetAlpha(0) end
    spell:SetDrawLayer("OVERLAY", 1)
    for _, region in ipairs(state.regions) do region:Show() end
end

local function layout(bar, state)
    if not enabledFor(state) then
        local restore = state.restore
        state.restore = nil
        if restore then restore() end
        if bar == CastingBarFrame then bar:SetScale(settings.castScale / 100) end
        return
    end
    if not state.restore then enableAlternative(bar, state) end

    local player = bar == CastingBarFrame
    if player then
        bar:SetSize(settings.castWidth, settings.castHeight)
        bar:SetScale(settings.castScale / 100)
    end

    local font = ui.MediaPath("font", settings.castFont)
    local size = player and settings.castFontSize or math.min(settings.castFontSize, 11)
    local headerHeight = size + 4
    local width = bar:GetWidth()
    local rightPadding = settings.castTimer and size * 3 + 7 or 5
    local timerAbove = settings.castCenterText and settings.castTimer and width - 2 * rightPadding < 2 * size
    state.header:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -headerHeight)
    local outline = settings.castFontOutline or "OUTLINE"
    state.spell:SetFont(font, size, outline)
    state.spell:ClearAllPoints()
    if settings.castCenterText then
        state.spell:SetPoint("CENTER", bar, "BOTTOM", 0, -headerHeight / 2)
        state.spell:SetWidth(math.max(1, width - 2 * (timerAbove and 5 or rightPadding)))
    else
        state.spell:SetPoint("LEFT", bar, "BOTTOMLEFT", 5, -headerHeight / 2)
        state.spell:SetWidth(math.max(1, width - 5 - rightPadding))
    end
    state.spell:SetHeight(size + 3)
    state.spell:SetJustifyH(settings.castCenterText and "CENTER" or "LEFT")
    state.spell:SetWordWrap(false)
    state.timer:SetFont(font, size, outline)
    state.timer:ClearAllPoints()
    if timerAbove then
        state.timer:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -4, 1)
    else
        state.timer:SetPoint("RIGHT", bar, "BOTTOMRIGHT", -4, -headerHeight / 2)
    end

    if state.icon then
        local iconSize = (settings.castIconSize or 0) > 0 and settings.castIconSize or math.max(16, bar:GetHeight())
        state.icon:SetSize(iconSize, iconSize)
        if settings.castIcon then state.icon:Show() else state.icon:Hide() end
    end
    if state.spark then
        state.spark:SetTexture(midArt .. "uicastingbar-Edge")
        state.spark:SetTexCoord(0, 1, 0, 1)
        state.spark:SetSize(settings.castSparkWidth or 14, bar:GetHeight() + 5)
    end
    if state.flash then
        state.flash:SetTexture(midArt .. "uicastingbarborder-atlas")
        state.flash:SetTexCoord(0, 428 / 512, 0.9375, 1)
        state.flash:ClearAllPoints()
        state.flash:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
        state.flash:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
    end
    updateColor(bar)
    updateTimer(bar)
end

local function barKind(bar, name)
    if bar == CastingBarFrame then return "player" end
    if bar == PetCastingBarFrame then return "pet" end
    if name:match("^Boss%d") then return "boss" end
    if name:match("^ArenaEnemyFrame") then return "arena" end
    if name:match("^Focus") then return "focus" end
    return "target"
end

local function skin(bar)
    if not bar or not settings or bars[bar] then return end
    local name = bar:GetName()
    local spell = name and _G[name .. "Text"]
    if not spell then return end
    local state = {
        kind = barKind(bar, name),
        spell = spell,
        border = _G[name .. "Border"],
        icon = _G[name .. "Icon"],
        shield = _G[name .. "BorderShield"],
        spark = _G[name .. "Spark"],
        flash = _G[name .. "Flash"],
    }
    bars[bar] = state

    state.header = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    state.header:SetTexture(midArt .. "uicastingbar-backgrounds")
    state.header:SetTexCoord(0, 421 / 512, 0, 59 / 128)
    state.header:SetPoint("TOPLEFT", bar, "TOPLEFT")
    state.midTrack = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
    state.midTrack:SetTexture(midArt .. "uicastingbar-backgrounds")
    state.midTrack:SetTexCoord(0, 420 / 512, 59 / 128, 83 / 128)
    state.midTrack:SetAllPoints(bar)
    state.progressBorder = bar:CreateTexture(nil, "ARTWORK")
    state.progressBorder:SetTexture(midArt .. "uicastingbarborder-atlas")
    state.progressBorder:SetTexCoord(0, 428 / 512, 0, 0.0625)
    state.progressBorder:SetAllPoints(bar)
    state.timer = bar:CreateFontString(nil, "OVERLAY", nil, 2)
    state.regions = { state.header, state.midTrack, state.progressBorder, state.timer }
    for _, region in ipairs(state.regions) do region:Hide() end

    bar:HookScript("OnValueChanged", updateFillCoords)
    bar:HookScript("OnUpdate", updateTimer)
    bar:HookScript("OnShow", function(self)
        updateColor(self)
        updateTimer(self)
    end)
    bar:HookScript("OnEvent", function(self, event, unit)
        if unit == self.unit or event == self.updateEvent or event == "PLAYER_ENTERING_WORLD" then
            updateColor(self)
            updateTimer(self)
        end
    end)
    layout(bar, state)
end

local function apply()
    for bar, state in pairs(bars) do layout(bar, state) end
end

local function skinArena()
    for index = 1, 5 do skin(_G["ArenaEnemyFrame" .. index .. "CastingBar"]) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" then
        if addon == "Blizzard_ArenaUI" then skinArena() end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    settings = ui.Settings()
    if ui.RegisterEditFrame then
        ui.RegisterEditFrame(CastingBarFrame, nil, "castbar", ui.OptionBinding("castbar", "castScale"))
    end

    skin(CastingBarFrame)
    skin(PetCastingBarFrame)
    skin(TargetFrameSpellBar)
    skin(FocusFrameSpellBar)
    for index = 1, 4 do skin(_G["Boss" .. index .. "TargetFrameSpellBar"]) end
    skinArena()
    if TargetFrame_CreateSpellbar then
        hooksecurefunc("TargetFrame_CreateSpellbar", function(frame) skin(frame.spellbar) end)
    end
    if CastingBarFrame_SetLook then
        hooksecurefunc("CastingBarFrame_SetLook", function(bar)
            local state = bars[bar]
            if state then layout(bar, state) end
        end)
    end
end)

ui.CastBar = { stock = stock, Apply = function() if settings then apply() end end }
