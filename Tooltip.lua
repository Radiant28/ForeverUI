local _, ui = ...
local ru = ui.russian

-- Tooltip placement: a movable anchor (Edit Mode) or the cursor, plus combat visibility rules.
-- Settings (ui.Settings()): tooltipPosition "anchor"|"cursor", tooltipScale, tooltipCursorX/Y (cursor offsets), tooltipFade "default"|"instant"|"custom", tooltipFadeTime, tooltipCombat "show"|"units"|"all",
-- tooltipCombatModifier "none"|"shift"|"ctrl"|"alt".

local anchor = CreateFrame("Frame", "ForeverStockUITooltipAnchor", UIParent)
anchor:SetSize(190, 80)
anchor:SetFrameStrata("TOOLTIP")
anchor:EnableMouse(false)

local function placeDefault()
    anchor:ClearAllPoints()
    anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -((CONTAINER_OFFSET_X or 0) + 13), CONTAINER_OFFSET_Y or 70)
end
placeDefault()

local modifiers = { shift = IsShiftKeyDown, ctrl = IsControlKeyDown, alt = IsAltKeyDown }

local function setting(key, fallback)
    local value = ui.Settings()[key]
    if value == nil then return fallback end
    return value
end

local function applyScale()
    local scale = (tonumber(setting("tooltipScale", 100)) or 100) / 100
    if GameTooltip:GetScale() ~= scale then GameTooltip:SetScale(scale) end
    anchor:SetScale(scale)
end

local function isUnitTooltip(tooltip)
    local _, unit = tooltip:GetUnit()
    return unit ~= nil
end

-- True when the combat rules say this tooltip must stay hidden right now.
local function suppressed(tooltip)
    local mode = setting("tooltipCombat", "show")
    if mode == "show" or not InCombatLockdown() then return false end
    local modifier = modifiers[setting("tooltipCombatModifier", "none")]
    if modifier and modifier() then return false end
    return mode == "all" or isUnitTooltip(tooltip)
end

-- Cursor mode is positioned here (ANCHOR_CURSOR has no offsets in 3.3.5), only while following is set.
local following, placing = false, false

-- Fade-out: the client fades the tooltip by itself after GameTooltip:FadeOut(). "instant" hides it at once;
-- "custom" runs our own alpha ramp (the client still hides the tooltip at the end of its own fade).
local fade, faded

local function cancelFade()
    fade = nil
    if faded then
        faded = false
        GameTooltip:SetAlpha(1)
    end
end

local function stepFade(tooltip)
    if not fade then return end
    local progress = (GetTime() - fade[1]) / fade[2]
    if progress >= 1 then
        cancelFade()
        tooltip:Hide()
    else
        faded = true
        tooltip:SetAlpha(1 - progress)
    end
end

local function startFade(tooltip)
    local mode = setting("tooltipFade", "default")
    if mode == "instant" then
        cancelFade()
        tooltip:Hide()
    elseif mode == "custom" and not fade then
        fade = { GetTime(), math.max(0.05, tonumber(setting("tooltipFadeTime", 0.3)) or 0.3) }
    end
end

-- Some callers use GameTooltip:FadeOut().
hooksecurefunc(GameTooltip, "FadeOut", startFade)

-- The 3.3.5 client fades world-unit tooltips internally without calling FadeOut, so a tooltip shown for
-- "mouseover" is watched: once that unit is gone, the tooltip is leaving.
local watching = false

hooksecurefunc(GameTooltip, "SetOwner", function()
    cancelFade()
    watching = false
    if not placing then following = false end
end)

local function followCursor(tooltip)
    if not following then return end
    local x, y = GetCursorPosition()
    local ratio = tooltip:GetEffectiveScale()
    if not x or not ratio or ratio == 0 then return end
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / ratio + (tonumber(setting("tooltipCursorX", 16)) or 0),
        y / ratio + (tonumber(setting("tooltipCursorY", -16)) or 0))
end
GameTooltip:HookScript("OnUpdate", function(tooltip)
    if watching and not UnitExists("mouseover") then
        watching = false
        startFade(tooltip)
    end
    followCursor(tooltip)
    stepFade(tooltip)
end)
GameTooltip:HookScript("OnHide", function()
    following, watching = false, false
    cancelFade()
end)

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
    if tooltip ~= GameTooltip then return end
    applyScale()
    if setting("tooltipPosition", "anchor") == "cursor" then
        placing = true
        tooltip:SetOwner(parent or UIParent, "ANCHOR_NONE")
        placing = false
        following = true
        followCursor(tooltip)
    else
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    end
end)

local function hideInCombat(tooltip)
    if suppressed(tooltip) then tooltip:Hide() end
end
GameTooltip:HookScript("OnShow", hideInCombat)
GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
    cancelFade()
    local _, unit = tooltip:GetUnit()
    watching = unit == "mouseover" and tooltip:GetOwner() == UIParent
    hideInCombat(tooltip)
end)

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        applyScale()
    elseif GameTooltip:IsShown() and suppressed(GameTooltip) then
        GameTooltip:Hide()
    end
end)

if ui.RegisterEditFrame then
    ui.RegisterEditFrame(anchor, ru and "Подсказка" or "Tooltip", "tooltip", ui.OptionBinding("tooltip", "tooltipScale"))
end

ui.Tooltip = { Apply = applyScale, anchor = anchor }
