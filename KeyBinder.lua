-- ForeverUI quick key binding for the action bars (LibKeyBound style): hover a slot and press a key,
-- a mouse button (middle, 4, 5) or turn the wheel, with Shift/Ctrl/Alt. Backspace or Delete clears
-- the slot, Esc leaves. Every change goes through SetBinding and is saved with SaveBindings to the
-- character or account set. Key bindings are protected: the mode is closed when combat starts.
-- Opened from the game menu (button under "ForeverUI"), /fuibind, or KeyBinder.Toggle().
local _, ui = ...
local L = ui.L

local KB = {}
ui.KeyBinder = KB

-- Bar prefix -> binding command prefix (3.3.5 Bindings.xml names).
local bars = {
    { "ActionButton", "ACTIONBUTTON", 12 },
    { "BonusActionButton", "ACTIONBUTTON", 12 },
    { "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON", 12 },
    { "MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON", 12 },
    { "MultiBarRightButton", "MULTIACTIONBAR3BUTTON", 12 },
    { "MultiBarLeftButton", "MULTIACTIONBAR4BUTTON", 12 },
    { "ShapeshiftButton", "SHAPESHIFTBUTTON", 10 },
    { "PetActionButton", "BONUSACTIONBUTTON", 10 },
}
local commands = {}       -- button -> binding command
local marks = {}          -- button -> highlight frame
local active, hovered = false, nil
local changed = false

local ignoredKeys = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    UNKNOWN = true, LeftButton = true, RightButton = true }
local mouseKeys = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function modifiers()
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
end

local function keysText(command)
    local keys = { GetBindingKey(command) }
    for i, key in ipairs(keys) do keys[i] = GetBindingText and GetBindingText(key, "KEY_") or key end
    return #keys > 0 and table.concat(keys, ", ") or L("не назначено", "not bound")
end

---------------------------------------------------------------------------------------------------
-- Binder: one invisible button that sits over the hovered slot and catches keys, wheel and clicks
---------------------------------------------------------------------------------------------------
local binder = CreateFrame("Button", "ForeverStockUIKeyBinderCatcher", UIParent)
binder:SetFrameStrata("DIALOG")
binder:EnableMouse(true)
binder:EnableMouseWheel(true)
binder:RegisterForClicks("AnyUp")
binder:Hide()
binder.glow = binder:CreateTexture(nil, "OVERLAY")
binder.glow:SetAllPoints(binder)
binder.glow:SetTexture(ui.Suite and ui.Suite.art.editHighlight or "Interface\\Buttons\\WHITE8X8")
binder.glow:SetBlendMode("ADD")
binder.glow:SetVertexColor(1, 0.82, 0.4, 0.55)

-- Top panel with the instructions and the character/account choice.
local panel = CreateFrame("Frame", "ForeverStockUIKeyBinder", UIParent)
panel:SetFrameStrata("DIALOG")
panel:SetWidth(470)
panel:SetHeight(92)
panel:SetPoint("TOP", UIParent, "TOP", 0, -90)
panel:EnableMouse(true)
panel:Hide()
if ui.Widgets then
    ui.Widgets.Skin(panel, ui.Style.window, ui.Style.borderHover)
else
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    panel:SetBackdropColor(0.05, 0.05, 0.06, 0.95)
end
panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
panel.title:SetPoint("TOP", 0, -10)
panel.title:SetText(L("Назначение клавиш панелей", "Action bar key bindings"))
panel.text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panel.text:SetPoint("TOP", panel.title, "BOTTOM", 0, -6)
panel.text:SetWidth(440)
panel.text:SetText(L("Наведите курсор на ячейку и нажмите клавишу, кнопку мыши или колесо (можно с Shift/Ctrl/Alt).\n"
    .. "Backspace или Delete — снять назначение · Esc — выход", "Hover a slot and press a key, a mouse button or the "
    .. "wheel (Shift/Ctrl/Alt allowed).\nBackspace or Delete clears the slot · Esc leaves"))
panel.character = CreateFrame("CheckButton", "ForeverStockUIKeyBinderCharacter", panel, "UICheckButtonTemplate")
panel.character:SetWidth(22)
panel.character:SetHeight(22)
panel.character:SetPoint("BOTTOMLEFT", 12, 6)
local characterLabel = panel.character:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
characterLabel:SetPoint("LEFT", panel.character, "RIGHT", 2, 0)
characterLabel:SetText(L("Только для этого персонажа", "This character only"))
panel.done = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
panel.done:SetWidth(110)
panel.done:SetHeight(22)
panel.done:SetPoint("BOTTOMRIGHT", -10, 7)
panel.done:SetText(L("Готово", "Done"))
tinsert(UISpecialFrames, panel:GetName())

local function bindingSet()
    return panel.character:GetChecked() and 2 or 1
end

local function save()
    if changed and not InCombatLockdown() then
        SaveBindings(bindingSet())
        changed = false
    end
end

local function tooltip(button)
    local command = commands[button]
    if not command then return end
    GameTooltip:SetOwner(binder, "ANCHOR_TOP")
    GameTooltip:SetText(_G["BINDING_NAME_" .. command] or command, 1, 0.82, 0)
    GameTooltip:AddLine(keysText(command), 1, 1, 1)
    GameTooltip:Show()
end

-- Binds key (with the held modifiers) to the hovered slot; nil key clears every key of the slot.
function KB.Bind(button, key)
    local command = commands[button]
    if not command or InCombatLockdown() then return false end
    if key == nil then
        for _, old in ipairs({ GetBindingKey(command) }) do SetBinding(old) end
        ui.Print((L("Снято: %s", "Cleared: %s")):format(_G["BINDING_NAME_" .. command] or command))
    else
        local full = modifiers() .. key
        -- The key leaves whatever it did before.
        SetBinding(full)
        SetBinding(full, command)
        ui.Print((L("%s → %s", "%s → %s")):format(GetBindingText and GetBindingText(full, "KEY_") or full,
            _G["BINDING_NAME_" .. command] or command))
    end
    changed = true
    save()
    tooltip(button)
    return true
end

binder:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        KB.Stop()
        return
    end
    if ignoredKeys[key] or not hovered then return end
    if key == "BACKSPACE" or key == "DELETE" then
        KB.Bind(hovered, nil)
    else
        KB.Bind(hovered, key)
    end
end)
binder:SetScript("OnMouseWheel", function(_, delta)
    if hovered then KB.Bind(hovered, delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end
end)
binder:SetScript("OnClick", function(_, button)
    local key = mouseKeys[button]
    if key and hovered then KB.Bind(hovered, key) end
end)
binder:SetScript("OnLeave", function(self)
    hovered = nil
    GameTooltip:Hide()
    self:EnableKeyboard(false)
    self:ClearAllPoints()
    self:Hide()
end)

local function onEnter(button)
    if not active or not commands[button] then return end
    hovered = button
    binder:ClearAllPoints()
    binder:SetAllPoints(button)
    binder:Show()
    binder:EnableKeyboard(true)
    tooltip(button)
end

---------------------------------------------------------------------------------------------------
-- Slots: collected once (and again for late bars), each gets a hover hook and a highlight
---------------------------------------------------------------------------------------------------
local function collect()
    for _, bar in ipairs(bars) do
        for i = 1, bar[3] do
            local button = _G[bar[1] .. i]
            if button and not commands[button] then
                commands[button] = bar[2] .. i
                button:HookScript("OnEnter", onEnter)
                local mark = CreateFrame("Frame", nil, button)
                mark:SetAllPoints(button)
                mark:SetFrameLevel(button:GetFrameLevel() + 3)
                mark:EnableMouse(false)
                local texture = mark:CreateTexture(nil, "OVERLAY")
                texture:SetAllPoints(mark)
                texture:SetTexture(ui.Suite and ui.Suite.art.editSelected or "Interface\\Buttons\\WHITE8X8")
                texture:SetVertexColor(0.35, 0.6, 1, 0.35)
                mark:Hide()
                marks[button] = mark
            end
        end
    end
end
KB.Commands = function() collect() return commands end

function KB.Start()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(L("Назначение клавиш доступно вне боя.", "Key binding is available out of combat."), 1, 0.2, 0.2)
        return
    end
    collect()
    active, changed = true, false
    panel.character:SetChecked(GetCurrentBindingSet() == 2)
    for button, mark in pairs(marks) do
        if button:IsVisible() then mark:Show() end
    end
    panel:Show()
end

function KB.Stop()
    if not active then return end
    active, hovered = false, nil
    save()
    binder:EnableKeyboard(false)
    binder:Hide()
    GameTooltip:Hide()
    for _, mark in pairs(marks) do mark:Hide() end
    if panel:IsShown() then panel:Hide() end
end

function KB.Toggle()
    if active then KB.Stop() else KB.Start() end
end

function KB.IsActive() return active end

panel:SetScript("OnHide", function() KB.Stop() end)
panel.done:SetScript("OnClick", function() KB.Stop() end)
panel.character:SetScript("OnClick", function(self)
    -- Switching the set copies the current bindings into it, like the stock key binding window.
    if InCombatLockdown() then return end
    changed = true
    save()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function() KB.Stop() end)

SLASH_FOREVERUIBIND1 = "/fuibind"
SlashCmdList.FOREVERUIBIND = function() KB.Toggle() end

-- Game menu: right under the "ForeverUI" button added by EditMode.lua.
if GameMenuFrame and GameMenuFrame_AddButton then
    local menu = CreateFrame("Button", "ForeverStockUIKeyBindButton", GameMenuFrame, "GameMenuButtonTemplate")
    menu:SetText(L("Назначение клавиш", "Key bindings"))
    menu:SetScript("OnClick", function()
        PlaySound("igMainMenuOption")
        HideUIPanel(GameMenuFrame)
        KB.Start()
    end)
    local after = _G.ForeverStockUISettingsButton and "ForeverStockUISettingsButton" or "GameMenuButtonOptions"
    GameMenuFrame_AddButton(menu:GetName(), after)
end
