-- ForeverUI click-casting (Clique / Cell style) on the client's compact party and raid buttons and,
-- optionally, on the stock unit frames. Mouse buttons 1-5 with Shift/Ctrl/Alt become secure
-- attributes of the button itself; the mouse wheel and keyboard keys become override bindings that
-- a secure wrapper sets on OnEnter and clears on OnLeave/OnHide (SetBindingClick with a virtual
-- button "fuiccN"), the pattern Cell uses on this client. Every child layer added by ForeverUI is
-- click-through, so the bar, the power bar and the shield line all reach the button.
-- Attributes of protected frames can only change out of combat: changes wait in ui.RunOutOfCombat.
-- Bindings per talent group (dual spec) or one common set, stored in the suite profile.
local _, ui = ...
local L, Suite = ui.L, ui.Suite

local CC = {}
ui.ClickCast = CC

CC.actions = {
    { "spell", L("Заклинание", "Spell") },
    { "macro", L("Макрос (по имени)", "Macro (by name)") },
    { "macrotext", L("Текст макроса", "Macro text") },
    { "item", L("Предмет", "Item") },
    { "target", L("Выбрать цель", "Target unit") },
    { "focus", L("Сделать фокусом", "Set focus") },
    { "assist", L("Помочь (цель цели)", "Assist") },
    { "menu", L("Меню юнита", "Unit menu") },
}
CC.actionNames = {}
for _, entry in ipairs(CC.actions) do CC.actionNames[entry[1]] = entry[2] end

Suite.RegisterProfilePart("clicks", function(db)
    if db.enabled == nil then db.enabled = true end
    if db.useCommon == nil then db.useCommon = false end
    if db.stockFrames == nil then db.stockFrames = false end
    if type(db.common) ~= "table" then db.common = {} end
    for group = 1, 2 do
        if type(db[group]) ~= "table" then db[group] = {} end
    end
    if type(db.hints) ~= "table" then db.hints = {} end
    Suite.Merge(db.hints, { enabled = true, show = "group", background = { 0.04, 0.04, 0.05, 0.55 },
        border = { 0.85, 0.72, 0.45, 0.5 }, scale = 1, fontSize = 11, iconSize = 16, keyColor = { 1, 0.82, 0.48 },
        columns = 1, title = true, alpha = 1 })
end)

local function data() return Suite.Part("clicks") end
CC.Data = data

function CC.ListKey()
    return data().useCommon and "common" or Suite.TalentGroup()
end

function CC.List(key)
    local db = data()
    key = key or CC.ListKey()
    if type(db[key]) ~= "table" then db[key] = {} end
    return db[key]
end

---------------------------------------------------------------------------------------------------
-- Keys: { key = "BUTTON1".."BUTTON5" | "MOUSEWHEELUP" | "MOUSEWHEELDOWN" | keyboard key, mods = "alt-ctrl-shift-" }
---------------------------------------------------------------------------------------------------
local mouseIndex = { BUTTON1 = 1, BUTTON2 = 2, BUTTON3 = 3, BUTTON4 = 4, BUTTON5 = 5,
    LeftButton = 1, RightButton = 2, MiddleButton = 3, Button4 = 4, Button5 = 5 }

function CC.NormalizeMods(alt, ctrl, shift)
    return (alt and "alt-" or "") .. (ctrl and "ctrl-" or "") .. (shift and "shift-" or "")
end

local keyNames = {
    BUTTON1 = L("ЛКМ", "Left click"), BUTTON2 = L("ПКМ", "Right click"), BUTTON3 = L("Средняя кнопка", "Middle click"),
    BUTTON4 = L("Кнопка 4", "Button 4"), BUTTON5 = L("Кнопка 5", "Button 5"),
    MOUSEWHEELUP = L("Колесо вверх", "Wheel up"), MOUSEWHEELDOWN = L("Колесо вниз", "Wheel down"),
}
function CC.FormatKey(binding)
    local mods = binding.mods or ""
    local text = mods:gsub("alt%-", "Alt+"):gsub("ctrl%-", "Ctrl+"):gsub("shift%-", "Shift+")
    local key = binding.key or "?"
    return text .. (keyNames[key] or (_G["KEY_" .. key]) or key)
end

function CC.Describe(binding)
    local action = CC.actionNames[binding.action] or binding.action or "?"
    if binding.value and binding.value ~= "" and binding.action ~= "target" and binding.action ~= "menu"
        and binding.action ~= "focus" and binding.action ~= "assist" then
        return binding.value
    end
    return action
end

-- Same key and modifiers already bound in the list? Returns the index.
function CC.Find(list, key, mods)
    for index, binding in ipairs(list) do
        if binding.key == key and (binding.mods or "") == (mods or "") then return index end
    end
end

function CC.Add(listKey, key, mods, action, value)
    local list = CC.List(listKey)
    local index = CC.Find(list, key, mods)
    local binding = { key = key, mods = mods or "", action = action or "spell", value = value or "" }
    if index then list[index] = binding else list[#list + 1] = binding end
    CC.Apply()
    return index or #list
end

function CC.Remove(listKey, index)
    local list = CC.List(listKey)
    if list[index] then
        table.remove(list, index)
        CC.Apply()
    end
end

---------------------------------------------------------------------------------------------------
-- Attribute plan: binding list -> { attribute = value }, { binding key -> virtual button }
---------------------------------------------------------------------------------------------------
local function setAction(attrs, typeKey, suffixKey, binding)
    local action = binding.action
    if action == "spell" then
        attrs[typeKey] = "spell"
        attrs[suffixKey("spell")] = binding.value
    elseif action == "macro" then
        attrs[typeKey] = "macro"
        attrs[suffixKey("macro")] = binding.value
    elseif action == "macrotext" then
        attrs[typeKey] = "macro"
        attrs[suffixKey("macrotext")] = binding.value
    elseif action == "item" then
        attrs[typeKey] = "item"
        attrs[suffixKey("item")] = binding.value
    else
        attrs[typeKey] = action
    end
end

-- Pure: returns the attributes to set and the secure snippet that installs the override bindings.
function CC.Plan(list)
    local attrs, lines, virtual = {}, { "self:ClearBindings()" }, 0
    for _, binding in ipairs(list or {}) do
        local key, mods = binding.key, binding.mods or ""
        local valid = binding.action and (binding.value ~= "" or (binding.action ~= "spell" and binding.action ~= "macro"
            and binding.action ~= "macrotext" and binding.action ~= "item"))
        if key and valid then
            local index = mouseIndex[key]
            if index then
                setAction(attrs, mods .. "type" .. index, function(name) return mods .. name .. index end, binding)
            else
                virtual = virtual + 1
                local button = "fuicc" .. virtual
                setAction(attrs, "type-" .. button, function(name) return name .. "-" .. button end, binding)
                local bindKey = mods:upper() .. key
                bindKey = bindKey:gsub("\\", "\\\\"):gsub("\"", "\\\"")
                lines[#lines + 1] = ("self:SetBindingClick(true, \"%s\", self, \"%s\")"):format(bindKey, button)
            end
        end
    end
    return attrs, table.concat(lines, "\n")
end

---------------------------------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------------------------------
local header = CreateFrame("Frame", "ForeverStockUIClickWrap", UIParent, "SecureHandlerBaseTemplate")
local frames = {}           -- frame -> { original = { attr = value|false }, applied = { attr = true } }
local stockNames = { "PlayerFrame", "PetFrame", "TargetFrame", "FocusFrame", "TargetFrameToT",
    "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" }

local unitMenu = CreateFrame("Frame", "ForeverStockUIClickMenu", UIParent, "UIDropDownMenuTemplate")
local function showUnitMenu(self, unit)
    unit = unit or (self.GetAttribute and self:GetAttribute("unit"))
    if not unit or not UnitExists(unit) then return end
    local menu, name, id
    if UnitIsUnit(unit, "player") then
        menu = "SELF"
    elseif UnitIsUnit(unit, "pet") then
        menu = "PET"
    elseif UnitIsPlayer(unit) then
        id = UnitInRaid(unit)
        if id then
            menu, name = "RAID_PLAYER", GetRaidRosterInfo(id + 1)
        elseif UnitInParty(unit) then
            menu = "PARTY"
        else
            menu = "PLAYER"
        end
    else
        menu, name = "TARGET", RAID_TARGET_ICON
    end
    UIDropDownMenu_Initialize(unitMenu, function() UnitPopup_ShowMenu(unitMenu, menu, unit, name, id) end, "MENU")
    ToggleDropDownMenu(1, nil, unitMenu, "cursor", 0, 0)
end

local function wrap(frame)
    local state = frames[frame]
    if state.wrapped then return end
    state.wrapped = true
    header:WrapScript(frame, "OnEnter", [[
        local code = self:GetAttribute("fuicc-bind")
        if code then control:RunFor(self, code) end
    ]])
    header:WrapScript(frame, "OnLeave", [[ self:ClearBindings() ]])
    header:WrapScript(frame, "OnHide", [[ self:ClearBindings() ]])
    -- Plain (insecure) hooks only tell the hint panel that a unit frame is under the cursor.
    frame:HookScript("OnEnter", function() if CC.SetHovered then CC.SetHovered(true) end end)
    frame:HookScript("OnLeave", function() if CC.SetHovered then CC.SetHovered(false) end end)
end

local function applyTo(frame, attrs, snippet)
    local state = frames[frame]
    -- Restore what we changed before, then write the new plan.
    for attr in pairs(state.applied) do
        local original = state.original[attr]
        frame:SetAttribute(attr, original or nil)
        state.applied[attr] = nil
    end
    local enabled = data().enabled
    if enabled then
        for attr, value in pairs(attrs) do
            if state.original[attr] == nil then state.original[attr] = frame:GetAttribute(attr) or false end
            frame:SetAttribute(attr, value)
            state.applied[attr] = true
        end
        if not frame.menu then frame.menu = showUnitMenu end
        frame:RegisterForClicks("AnyUp")
    end
    frame:SetAttribute("fuicc-bind", enabled and snippet or "self:ClearBindings()")
    wrap(frame)
end

function CC.Attach(frame)
    if type(frame) ~= "table" or not frame.SetAttribute then return end
    if not frames[frame] then frames[frame] = { original = {}, applied = {} } end
    if InCombatLockdown() then
        ui.RunOutOfCombat("clickCastApply", CC.Apply)
        return
    end
    local attrs, snippet = CC.Plan(CC.List())
    applyTo(frame, attrs, snippet)
end

function CC.Apply()
    if InCombatLockdown() then
        ui.RunOutOfCombat("clickCastApply", CC.Apply)
        return
    end
    if ui.RaidFrames and ui.RaidFrames.EachFrame then
        ui.RaidFrames.EachFrame(function(frame)
            if not frames[frame] then frames[frame] = { original = {}, applied = {} } end
        end)
    end
    local stock = data().stockFrames
    for _, name in ipairs(stockNames) do
        local frame = _G[name]
        if frame and (stock or frames[frame]) then
            if not frames[frame] then frames[frame] = { original = {}, applied = {} } end
            frames[frame].stock = true
        end
    end
    local attrs, snippet = CC.Plan(CC.List())
    local empty = {}
    for frame, state in pairs(frames) do
        if state.stock and not stock then
            applyTo(frame, empty, "self:ClearBindings()")
        else
            applyTo(frame, attrs, snippet)
        end
    end
    ui.Fire("ClickCastChanged")
end

---------------------------------------------------------------------------------------------------
-- Hint panel: a translucent list "key combination — icon — name" of the active binding set.
-- Moves in Edit Mode (right click opens the click-casting page); shown always, in a group, only out
-- of combat or only while the cursor is over a unit frame.
---------------------------------------------------------------------------------------------------
local hints = CreateFrame("Frame", "ForeverStockUIClickHints", UIParent)
hints:SetWidth(200)
hints:SetHeight(40)
hints:SetPoint("LEFT", UIParent, "LEFT", 20, 120)
hints:SetClampedToScreen(true)
hints:EnableMouse(false)
hints:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 } })
hints.title = hints:CreateFontString(nil, "OVERLAY")
hints.title:SetPoint("TOPLEFT", 8, -6)
hints.rows = {}
hints:Hide()
CC.hints = hints

local hovered, editing, inCombat = false, false, false
local keyOrder = { BUTTON1 = 1, BUTTON2 = 2, BUTTON3 = 3, BUTTON4 = 4, BUTTON5 = 5, MOUSEWHEELUP = 6, MOUSEWHEELDOWN = 7 }

local function hintRow(index)
    local row = hints.rows[index]
    if not row then
        row = CreateFrame("Frame", nil, hints)
        row.key = row:CreateFontString(nil, "OVERLAY")
        row.key:SetPoint("LEFT", 0, 0)
        row.key:SetJustifyH("RIGHT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetJustifyH("LEFT")
        hints.rows[index] = row
    end
    return row
end

-- Icon and readable name of a binding: spell, macro, item or a unit action.
function CC.BindingVisual(binding)
    local action, value = binding.action, binding.value or ""
    if action == "spell" then
        local name, icon = Suite.SpellInfo(value)
        return icon or (GetSpellTexture and GetSpellTexture(value)), name or value
    elseif action == "macro" then
        local index = GetMacroIndexByName and GetMacroIndexByName(value)
        if index and index > 0 then
            local _, icon = GetMacroInfo(index)
            return icon, value
        end
        return nil, value
    elseif action == "item" then
        local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(value)
        return icon, name or value
    elseif action == "macrotext" then
        local spell = value:match("/cast%s+%b[]%s*([^\n;]+)") or value:match("/cast%s+([^\n;]+)")
        if spell then
            local name, icon = Suite.SpellInfo(spell:match("^%s*(.-)%s*$"))
            return icon or "Interface\\Icons\\INV_Misc_Note_01", name or spell
        end
        return "Interface\\Icons\\INV_Misc_Note_01", L("Макрос", "Macro")
    end
    local icons = { target = "Interface\\Icons\\Ability_Hunter_SniperShot", focus = "Interface\\Icons\\Ability_Hunter_MarkedForDeath",
        assist = "Interface\\Icons\\Ability_Warrior_Rampage", menu = "Interface\\Icons\\INV_Misc_Book_09" }
    return icons[action], CC.actionNames[action] or action
end

local function sortedBindings()
    local list = {}
    for _, binding in ipairs(CC.List()) do list[#list + 1] = binding end
    table.sort(list, function(a, b)
        local ka, kb = keyOrder[a.key] or 50, keyOrder[b.key] or 50
        if ka ~= kb then return ka < kb end
        if (a.mods or "") ~= (b.mods or "") then return #(a.mods or "") < #(b.mods or "") end
        return tostring(a.key) < tostring(b.key)
    end)
    return list
end

local function hintsWanted()
    local cfg = data().hints
    if editing then return true end
    if not cfg.enabled or not data().enabled then return false end
    local show = cfg.show
    if show == "hover" then return hovered end
    if show == "ooc" then return not inCombat end
    if show == "group" then return Suite.GroupType() ~= "solo" end
    return true
end

function CC.RefreshHints()
    local cfg = data().hints
    local list = sortedBindings()
    if not hintsWanted() or (#list == 0 and not editing) then
        hints:Hide()
        return
    end
    local font, size, icon = STANDARD_TEXT_FONT, cfg.fontSize, cfg.iconSize
    local bg, edge, keyColor = cfg.background, cfg.border, cfg.keyColor
    hints:SetScale(cfg.scale)
    hints:SetAlpha(editing and math.max(0.5, cfg.alpha or 1) or (cfg.alpha or 1))
    hints:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 0.55)
    hints:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 0.5)
    local top = 6
    if cfg.title then
        hints.title:SetFont(font, size, "OUTLINE")
        hints.title:SetTextColor(keyColor[1], keyColor[2], keyColor[3])
        hints.title:SetText(L("Назначенные клавиши", "Key bindings") .. (data().useCommon and ""
            or (" · " .. L("таланты ", "spec ") .. Suite.TalentGroup())))
        hints.title:Show()
        top = top + size + 6
    else
        hints.title:Hide()
    end
    if #list == 0 then
        list = { { key = "BUTTON1", mods = "shift-", action = "spell", value = L("Пример", "Example"), sample = true } }
    end
    -- Measure the key column so names line up.
    local keyWidth, nameWidth = 0, 0
    local rowHeight = math.max(icon, size + 2)
    for index, binding in ipairs(list) do
        local row = hintRow(index)
        row.key:SetFont(font, size, "OUTLINE")
        row.name:SetFont(font, size, "OUTLINE")
        row.key:SetText(CC.FormatKey(binding))
        local texture, name = CC.BindingVisual(binding)
        row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:SetText(name or "")
        keyWidth = math.max(keyWidth, row.key:GetStringWidth())
        nameWidth = math.max(nameWidth, row.name:GetStringWidth())
    end
    local columns = math.max(1, math.min(3, cfg.columns or 1))
    local perColumn = math.ceil(#list / columns)
    local columnWidth = keyWidth + 6 + icon + 6 + nameWidth + 12
    for index, row in ipairs(hints.rows) do
        if list[index] then
            local column, line = math.floor((index - 1) / perColumn), (index - 1) % perColumn
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", hints, "TOPLEFT", 8 + column * columnWidth, -top - line * (rowHeight + 2))
            row:SetWidth(columnWidth)
            row:SetHeight(rowHeight)
            row.key:SetWidth(keyWidth)
            row.key:SetTextColor(keyColor[1], keyColor[2], keyColor[3])
            row.icon:SetWidth(icon)
            row.icon:SetHeight(icon)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", row, "LEFT", keyWidth + 6, 0)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.name:SetTextColor(1, 1, 1)
            row:Show()
        else
            row:Hide()
        end
    end
    hints:SetWidth(math.max(120, 16 + columns * columnWidth - 12))
    local titleWidth = cfg.title and hints.title:GetStringWidth() + 16 or 0
    if titleWidth > hints:GetWidth() then hints:SetWidth(titleWidth) end
    hints:SetHeight(top + perColumn * (rowHeight + 2) + 6)
    hints:Show()
end

-- Quick on/off of the panel: /fuikeys, the key binding in Key Bindings → Forever UI, or the options.
function CC.ToggleHints(state)
    local cfg = data().hints
    if state == nil then state = not cfg.enabled end
    cfg.enabled = state and true or false
    CC.RefreshHints()
    ui.Fire("ClickCastHintsToggled", cfg.enabled)
    ui.Print(cfg.enabled and L("Подсказки клавиш включены.", "Key binding hints on.")
        or L("Подсказки клавиш выключены.", "Key binding hints off."))
end

-- Key binding hook (Bindings.xml) and slash command.
BINDING_HEADER_FOREVERUI = "Forever UI"
BINDING_NAME_FOREVERUI_TOGGLE_KEYHINTS = L("Подсказки назначения клавиш: вкл/выкл", "Key binding hints: on/off")
function ForeverStockUI_ToggleKeyHints() CC.ToggleHints() end
SLASH_FOREVERUIKEYS1 = "/fuikeys"
SlashCmdList.FOREVERUIKEYS = function(input)
    local arg = (input or ""):lower():match("^%s*(%S*)")
    if arg == "on" or arg == "вкл" then
        CC.ToggleHints(true)
    elseif arg == "off" or arg == "выкл" then
        CC.ToggleHints(false)
    else
        CC.ToggleHints()
    end
end

function CC.SetHovered(state)
    if hovered == state then return end
    hovered = state
    if data().hints.show == "hover" then CC.RefreshHints() end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PARTY_MEMBERS_CHANGED",
    "RAID_ROSTER_UPDATE" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        CC.Apply()
        if ui.RegisterEditFrame then
            local entry = ui.RegisterEditFrame(hints, L("Подсказки клавиш", "Key binding hints"), "clickcast")
            if entry then entry.onRightClick = function() ui.OpenOptions("clickcast") end end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    end
    CC.RefreshHints()
end)
if ForeverStockUIEditMode then
    ForeverStockUIEditMode:HookScript("OnShow", function()
        editing = true
        CC.RefreshHints()
        if ui.RefreshEditLayout then ui.RefreshEditLayout() end
    end)
    ForeverStockUIEditMode:HookScript("OnHide", function()
        editing = false
        CC.RefreshHints()
    end)
end
ui.RegisterCallback("ClickCastChanged", function() CC.RefreshHints() end, "ClickCastHints")
ui.RegisterCallback("SuiteSpellsChanged", function() CC.RefreshHints() end, "ClickCastHintsSpells")
ui.RegisterCallback("SuiteProfileChanged", function() CC.Apply() end, "ClickCastProfile")
ui.RegisterCallback("SuiteTalentsChanged", function()
    if not data().useCommon then CC.Apply() else CC.RefreshHints() end
end, "ClickCastTalents")
