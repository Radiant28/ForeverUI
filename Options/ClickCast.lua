-- Options page of click-casting: capture a mouse button, wheel turn or key with modifiers, pick a
-- spell from the spellbook, a macro or an action, and keep one binding set per talent group
-- (switched automatically with the spec) or one common set.
local _, ui = ...
local L, W, S = ui.L, ui.Widgets, ui.Style

local function build(parent, width)
    local cc, su = ui.ClickCast, ui.SuiteUI
    if not cc or not su or not ui.Suite then return su and su.Unavailable(parent, width) or 20 end
    local state = { listKey = nil, index = nil, draft = { key = nil, mods = "", action = "spell", value = "" } }
    local refresh
    local function data() return cc.Data() end
    local function listKey() return state.listKey or cc.ListKey() end
    local function changed()
        cc.Apply()
        if refresh then refresh() end
    end

    local y = 0
    local grid = su.Grid(parent, 0, y, width, 2)
    grid:Add({ "toggle", L("Включить назначение клавиш", "Enable click-casting") }, su.Access(data, "enabled", true, changed))
    grid:Add({ "toggle", L("Также на стандартных рамках", "Also on the stock unit frames") },
        su.Access(data, "stockFrames", false, changed))
    grid:Add({ "toggle", L("Один набор для обоих наборов талантов", "One set for both talent specs") },
        su.Access(data, "useCommon", false, function() state.listKey = nil changed() end))
    grid:Add({ "select", L("Редактировать набор", "Edit the set"), values = function()
        local current = ui.Suite.TalentGroup()
        return {
            { "common", L("Общий", "Common") },
            { 1, L("Основные таланты", "Primary talents") .. (current == 1 and L(" (активны)", " (active)") or "") },
            { 2, L("Дополнительные таланты", "Secondary talents") .. (current == 2 and L(" (активны)", " (active)") or "") },
        }
    end }, {
        get = function() return listKey() end,
        set = function(value)
            state.listKey, state.index = value, nil
            refresh()
        end,
    })
    y = y - grid:Height() - 6

    local header = W.Header(parent, L("Новая привязка", "New binding"), width)
    header:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local keyLabel = W.Text(parent, W.fonts.heading)
    keyLabel:SetPoint("TOPLEFT", 0, y - 4)
    keyLabel:SetWidth(200)
    local capture = su.CaptureButton(parent, width - 210, function(key, mods)
        state.draft.key, state.draft.mods = key, mods
        refresh()
    end)
    capture:SetPoint("TOPLEFT", 210, y)
    y = y - 36
    local draft = function() return state.draft end
    local actionRow = W.Create(parent, { type = "select", label = L("Действие", "Action"), values = cc.actions },
        su.Access(draft, "action", "spell", function() refresh() end), 220)
    actionRow:SetPoint("TOPLEFT", 0, y)
    local valueRow = W.Create(parent, { type = "text", label = L("Заклинание, макрос или предмет", "Spell, macro or item") },
        su.Access(draft, "value", "", function() refresh() end), width - 240)
    valueRow:SetPoint("TOPLEFT", 240, y)
    y = y - 52
    local function readValue()
        for _, child in ipairs({ valueRow:GetChildren() }) do
            if child.GetText and child.SetAutoFocus and child:GetText() then state.draft.value = child:GetText() end
        end
    end
    local book = W.Button(parent, L("Из книги заклинаний", "From spellbook"), 170, function(self)
        W.OpenList(self, su.SpellbookItems(), state.draft.value, function(value)
            state.draft.action, state.draft.value = "spell", value
            refresh()
        end, 280)
    end, 24)
    book:SetPoint("TOPLEFT", 0, y)
    local macros = W.Button(parent, L("Макросы", "Macros"), 120, function(self)
        W.OpenList(self, su.MacroItems(), state.draft.value, function(value)
            state.draft.action, state.draft.value = "macro", value
            refresh()
        end, 280)
    end, 24)
    macros:SetPoint("TOPLEFT", 178, y)
    local add = W.Button(parent, L("Сохранить привязку", "Save binding"), 180, function()
        readValue()
        local d = state.draft
        if not d.key then
            ui.Print(L("Сначала задайте клавишу.", "Set a key first."))
            return
        end
        if (d.action == "spell" or d.action == "macro" or d.action == "macrotext" or d.action == "item")
            and (d.value or "") == "" then
            ui.Print(L("Укажите заклинание, макрос или предмет.", "Enter a spell, macro or item."))
            return
        end
        state.index = cc.Add(listKey(), d.key, d.mods, d.action, d.value)
        if InCombatLockdown() then
            ui.Print(L("Привязки применятся после выхода из боя.", "Bindings apply after combat."))
        end
        refresh()
    end, 24)
    add:SetPoint("TOPLEFT", width - 180, y)
    y = y - 36

    local listHeader = W.Header(parent, L("Привязки набора", "Bindings of the set"), width)
    listHeader:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local bindingList = su.List(parent, width - 130, 10, 24, function(index, binding)
        state.index = index
        state.draft = { key = binding.key, mods = binding.mods or "", action = binding.action, value = binding.value or "" }
        refresh()
    end)
    bindingList:SetPoint("TOPLEFT", 0, y)
    local remove = W.Button(parent, L("Удалить", "Remove"), 120, function()
        if state.index then
            cc.Remove(listKey(), state.index)
            state.index = nil
        end
        refresh()
    end, 24)
    remove:SetPoint("TOPLEFT", width - 120, y)
    remove.text:SetTextColor(W.rgba(S.danger))
    local clear = W.Button(parent, L("Очистить набор", "Clear the set"), 120, function()
        su.Confirm(L("Удалить все привязки этого набора?", "Remove every binding of this set?"), function()
            local list = cc.List(listKey())
            for i = #list, 1, -1 do list[i] = nil end
            state.index = nil
            changed()
        end)
    end, 24)
    clear:SetPoint("TOPLEFT", width - 120, y - 30)
    local copy = W.Button(parent, L("Копировать из…", "Copy from…"), 120, function(self)
        local items = {}
        for _, key in ipairs({ "common", 1, 2 }) do
            if key ~= listKey() then
                items[#items + 1] = { key, key == "common" and L("Общий", "Common") or (L("Таланты ", "Talents ") .. key) }
            end
        end
        W.OpenList(self, items, nil, function(source)
            local target = cc.List(listKey())
            for i = #target, 1, -1 do target[i] = nil end
            for _, binding in ipairs(cc.List(source)) do target[#target + 1] = ui.CopyTable(binding) end
            state.index = nil
            changed()
        end, 200)
    end, 24)
    copy:SetPoint("TOPLEFT", width - 120, y - 60)
    local note = W.Description(parent, L("Колесо и клавиши работают, пока курсор над фреймом. Без модификаторов колесо "
        .. "над фреймом не двигает камеру. Изменения в бою применятся после боя.", "The wheel and keys work while the "
        .. "cursor is over a frame. An unmodified wheel over a frame does not zoom the camera. Changes in combat apply "
        .. "after combat."), 120)
    note:SetPoint("TOPLEFT", width - 120, y - 96)
    y = y - 10 * 24 - 10

    -- Hint panel: translucent list of the active bindings (key — icon — name), moved in Edit Mode.
    local function hintsTable() return data().hints end
    local function hintsChanged() if cc.RefreshHints then cc.RefreshHints() end end
    local function h(key, default) return su.Access(hintsTable, key, default, hintsChanged) end
    local hintsGrid = su.Grid(parent, 0, y, width, 2)
    hintsGrid:Header(L("Панель подсказок клавиш", "Key binding hint panel"))
    hintsGrid:Add({ "toggle", L("Подсказки назначения клавиш", "Key binding hints"),
        tooltip = L("Также: /fuikeys или клавиша в «Назначении клавиш» → Forever UI.",
            "Also: /fuikeys or a key in Key Bindings → Forever UI.") }, h("enabled", true))
    hintsGrid:Add({ "range", L("Прозрачность панели", "Panel opacity"), min = 0.1, max = 1, step = 0.05 }, h("alpha", 1))
    hintsGrid:Add({ "select", L("Когда показывать", "When to show"), values = {
        { "always", L("Всегда", "Always") }, { "group", L("В группе или рейде", "In a party or raid") },
        { "ooc", L("Только вне боя", "Out of combat only") },
        { "hover", L("При наведении на фрейм", "While hovering a unit frame") } } }, h("show", "group"))
    hintsGrid:Add({ "color", L("Фон (с прозрачностью)", "Background (with opacity)"), alpha = true },
        h("background", { 0.04, 0.04, 0.05, 0.55 }))
    hintsGrid:Add({ "color", L("Рамка", "Border"), alpha = true }, h("border", { 0.85, 0.72, 0.45, 0.5 }))
    hintsGrid:Add({ "color", L("Цвет сочетаний", "Key colour") }, h("keyColor", { 1, 0.82, 0.48 }))
    hintsGrid:Add({ "toggle", L("Заголовок", "Title") }, h("title", true))
    hintsGrid:Add({ "range", L("Масштаб", "Scale"), min = 0.5, max = 2, step = 0.05 }, h("scale", 1))
    hintsGrid:Add({ "range", L("Размер шрифта", "Font size"), min = 8, max = 20, step = 1 }, h("fontSize", 11))
    hintsGrid:Add({ "range", L("Размер иконок", "Icon size"), min = 10, max = 36, step = 1 }, h("iconSize", 16))
    hintsGrid:Add({ "range", L("Столбцов", "Columns"), min = 1, max = 3, step = 1 }, h("columns", 1))
    hintsGrid:Text(L("Панель перемещается в режиме редактирования; ПКМ по ней открывает эту страницу.",
        "Move the panel in Edit Mode; right click it there to open this page."))
    y = y - hintsGrid:Height()

    local function render(row, binding)
        row.icon:SetTexture(nil)
        local icon = cc.BindingVisual and cc.BindingVisual(binding)
        row.icon:SetTexture(icon)
        row.text:SetText("|cffffd27a" .. cc.FormatKey(binding) .. "|r  " .. cc.Describe(binding))
        row.sub:SetText(cc.actionNames[binding.action] or "")
    end
    refresh = function()
        local list = cc.List(listKey())
        if state.index and not list[state.index] then state.index = nil end
        bindingList:SetItems(list, render)
        bindingList:Select(state.index)
        grid:Refresh()
        hintsGrid:Refresh()
        actionRow:Refresh()
        valueRow:Refresh()
        local d = state.draft
        keyLabel:SetText(d.key and cc.FormatKey(d) or L("Клавиша не задана", "No key yet"))
        local needsValue = d.action == "spell" or d.action == "macro" or d.action == "macrotext" or d.action == "item"
        valueRow:SetEnabled(needsValue)
        if state.index then remove:Enable() else remove:Disable() end
    end
    parent.refreshClicks = refresh
    parent:SetScript("OnShow", refresh)
    ui.RegisterCallback("SuiteProfileChanged", function()
        state.index = nil
        refresh()
    end, "ClickCastOptionsProfile")
    ui.RegisterCallback("SuiteTalentsChanged", function() refresh() end, "ClickCastOptionsTalents")
    ui.RegisterCallback("ClickCastHintsToggled", function() refresh() end, "ClickCastOptionsHints")
    refresh()
    return -y
end

ui.RegisterOptions("clickcast", {
    title = L("Назначение клавиш (Click-Casting)", "Click-casting"),
    description = L("Заклинания по наведению на фреймы группы и рейда: мышь, колесо, клавиши, модификаторы.",
        "Spells on hovered party and raid frames: mouse, wheel, keys, modifiers."),
    icon = "Interface\\Icons\\Spell_Holy_FlashHeal",
    group = "combat",
    order = 6,
    sections = {
        { options = {
            { "custom", build = build, refresh = function(holder)
                if holder.refreshClicks then holder.refreshClicks() end
            end },
        } },
    },
})
