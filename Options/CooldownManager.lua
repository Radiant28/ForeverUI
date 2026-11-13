-- Options page of the Cooldown Manager: list of tracker groups (create, duplicate, rename, delete,
-- reorder), group geometry and load conditions, and the spell constructor (add by id, name,
-- spellbook, item:ID or slot:13; tracking type, order, highlight and sounds). Every control applies
-- at once and the edited group is shown on screen as a live preview while the page is open.
local _, ui = ...
local L, W, S = ui.L, ui.Widgets, ui.Style

local function CDM() return ui.CooldownManager end
local function SU() return ui.SuiteUI end

local growValues = {
    { "RIGHT", L("Вправо", "Right") }, { "LEFT", L("Влево", "Left") },
    { "DOWN", L("Вниз", "Down") }, { "UP", L("Вверх", "Up") },
}
local wrapValues = {
    { "DOWN", L("Новый ряд ниже", "Next row below") }, { "UP", L("Новый ряд выше", "Next row above") },
    { "RIGHT", L("Новый столбец справа", "Next column right") }, { "LEFT", L("Новый столбец слева", "Next column left") },
}

local function buildManager(parent, width)
    local cdm, su = CDM(), SU()
    if not cdm or not su or not ui.Suite then return SU() and SU().Unavailable(parent, width) or 20 end
    local state = { group = cdm.selectedGroup, item = nil, add = { spell = "", kind = "cooldown" } }
    local refresh

    local function groups() return cdm.Groups() end
    local function selectedGroup()
        if state.group and cdm.Group(state.group) then return cdm.Group(state.group) end
        local first = groups()[1]
        state.group = first and first.id
        return first
    end
    local function selectedItem()
        local group = selectedGroup()
        return group and state.item and group.items[state.item]
    end
    local function changed()
        cdm.Rebuild()
        if refresh then refresh() end
    end
    local function itemChanged(key)
        cdm.RefreshCombatLog()
        cdm.Rebuild()
        if refresh then refresh(key == "kind") end
    end
    local function isBars() local g = selectedGroup() return g and g.kind == "bars" end
    local function isIcons() local g = selectedGroup() return g and g.kind ~= "bars" end
    local function hasGroup() return selectedGroup() ~= nil end
    local function itemKind(...)
        local kinds = { ... }
        return function()
            local entry = selectedItem()
            if not entry then return false end
            for _, kind in ipairs(kinds) do if entry.kind == kind then return true end end
            return false
        end
    end
    local function hasItem() return selectedItem() ~= nil end

    local defaults = cdm.groupDefaults
    local function g(key, default)
        return su.Access(selectedGroup, key, default == nil and defaults[key] or default, changed)
    end
    local function gl(path, default)
        return su.Access(selectedGroup, path, default, changed)
    end
    local itemDefaults = cdm.itemDefaults
    local function it(key, default)
        if default == nil then default = itemDefaults[key] end
        return su.Access(selectedItem, key, default, itemChanged)
    end

    -------------------------------------------------------------------------------------------
    -- Groups
    -------------------------------------------------------------------------------------------
    local y = 0
    local header = W.Header(parent, L("Группы трекеров", "Tracker groups"), width)
    header:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    local groupList = su.List(parent, 220, 8, 24, function(index, group)
        state.group, state.item = group.id, nil
        cdm.SetPreview(true, group.id)
        refresh()
    end)
    groupList:SetPoint("TOPLEFT", 0, y)

    local buttons = {}
    local function button(text, fn, column, row, w)
        local b = W.Button(parent, text, w or 172, fn, 24)
        b:SetPoint("TOPLEFT", 236 + (column - 1) * 184, y - (row - 1) * 30)
        buttons[#buttons + 1] = b
        return b
    end
    button(L("+ Сетка иконок", "+ Icon grid"), function()
        state.group, state.item = cdm.CreateGroup(nil, "icons"), nil
        refresh()
    end, 1, 1)
    button(L("+ Список полос", "+ Bar list"), function()
        state.group, state.item = cdm.CreateGroup(nil, "bars"), nil
        refresh()
    end, 2, 1)
    button(L("Переименовать", "Rename"), function()
        local group = selectedGroup()
        if not group then return end
        su.Prompt(L("Новое имя группы:", "New group name:"), group.name, function(name)
            group.name = name
            changed()
        end)
    end, 1, 2)
    button(L("Дублировать", "Duplicate"), function()
        local group = selectedGroup()
        if group then state.group, state.item = cdm.DuplicateGroup(group.id), nil end
        refresh()
    end, 2, 2)
    button(L("Выше", "Move up"), function()
        local group = selectedGroup()
        if group then cdm.MoveGroup(group.id, -1) end
        changed()
    end, 1, 3)
    button(L("Ниже", "Move down"), function()
        local group = selectedGroup()
        if group then cdm.MoveGroup(group.id, 1) end
        changed()
    end, 2, 3)
    local delete = button(L("Удалить группу", "Delete group"), function()
        local group = selectedGroup()
        if not group then return end
        su.Confirm((L("Удалить группу «%s»?", "Delete the group “%s”?")):format(group.name or "?"), function()
            cdm.DeleteGroup(group.id)
            state.group, state.item = nil, nil
            refresh()
        end)
    end, 1, 4)
    delete.text:SetTextColor(W.rgba(S.danger))
    button(L("Режим редактирования", "Edit Mode"), function()
        if ui.EditMode and ui.EditMode.Open then
            if ForeverUIOptions then ForeverUIOptions:Hide() end
            ui.EditMode.Open()
        end
    end, 2, 4)
    local hint = W.Description(parent, L("Группа видна на экране, пока открыта эта страница. В режиме редактирования группы "
        .. "перетаскиваются ЛКМ, а ПКМ открывает их настройки.", "The selected group stays on screen while this page is open. "
        .. "In Edit Mode drag groups with the left button; right click opens their settings."), 356)
    hint:SetPoint("TOPLEFT", 236, y - 124)
    y = y - 8 * 24 - 16

    -------------------------------------------------------------------------------------------
    -- Group settings
    -------------------------------------------------------------------------------------------
    local grid = su.Grid(parent, 0, y, width, 2)
    grid:Header(L("Группа: вид и геометрия", "Group: look and geometry"))
    grid:Add({ "text", L("Название", "Name") }, g("name", ""), false, hasGroup)
    grid:Add({ "select", L("Тип отображения", "Display type"), values = {
        { "icons", L("Сетка / ряд иконок", "Icon grid / row") }, { "bars", L("Список полос", "Bar list") } } },
        g("kind"), false, hasGroup)
    grid:Add({ "toggle", L("Группа включена", "Group enabled") }, g("enabled"), false, hasGroup)
    grid:Add({ "select", L("Компоновка", "Layout"), values = {
        { "dynamic", L("Сжатие без пустых мест", "Dynamic, no gaps") }, { "fixed", L("Фиксированные слоты", "Fixed slots") } } },
        g("layout"), false, hasGroup)
    grid:Add({ "select", L("Перезарядки показывать", "Show cooldowns"), values = {
        { "always", L("Всегда", "Always") }, { "ready", L("Только готовые", "Only when ready") },
        { "cooldown", L("Только на перезарядке", "Only on cooldown") } } }, g("cdShow"), false, hasGroup)
    grid:Add({ "range", L("Размер иконки", "Icon size"), min = 12, max = 96, step = 1 }, g("size"), false, isIcons)
    grid:Add({ "range", L("Отступ", "Spacing"), min = 0, max = 40, step = 1 }, g("spacing"), false, hasGroup)
    grid:Add({ "range", L("Элементов в ряду", "Per row"), min = 1, max = 40, step = 1 }, g("perRow"), false, hasGroup)
    grid:Add({ "select", L("Направление роста", "Growth"), values = growValues }, g("grow"), false, hasGroup)
    grid:Add({ "select", L("Перенос", "Wrap"), values = wrapValues }, g("wrap"), false, hasGroup)
    grid:Add({ "range", L("Прозрачность", "Opacity"), min = 0.1, max = 1, step = 0.05 }, g("alpha"), false, hasGroup)
    grid:Add({ "range", L("Прозрачность неактивных", "Inactive opacity"), min = 0, max = 1, step = 0.05 },
        g("inactiveAlpha"), false, hasGroup)
    grid:Add({ "range", L("Шрифт: стаки и названия", "Font: stacks and names"), min = 7, max = 24, step = 1 },
        g("fontSize"), false, hasGroup)
    grid:Add({ "range", L("Шрифт таймера", "Timer font"), min = 7, max = 30, step = 1 }, g("timerSize"), false, hasGroup)
    grid:Add({ "toggle", L("Цифры таймера", "Timer numbers") }, g("showTimer"), false, hasGroup)
    grid:Add({ "toggle", L("Спираль перезарядки", "Cooldown spiral") }, g("showSwipe"), false, isIcons)
    grid:Add({ "toggle", L("Счётчик стаков и зарядов", "Stack and charge count") }, g("showCount"), false, hasGroup)
    grid:Add({ "toggle", L("Серые на перезарядке", "Desaturate on cooldown") }, g("desaturate"), false, hasGroup)
    grid:Add({ "toggle", L("Показывать ГКД", "Show the GCD") }, g("showGCD"), false, hasGroup)
    grid:Add({ "color", L("Цвет рамки иконок", "Icon border colour"), alpha = true }, g("borderColor"), false, hasGroup)
    grid:Header(L("Полосы прогресса", "Progress bars"))
    grid:Add({ "range", L("Ширина полосы", "Bar width"), min = 60, max = 500, step = 1 }, g("barWidth"), false, isBars)
    grid:Add({ "range", L("Высота полосы", "Bar height"), min = 8, max = 60, step = 1 }, g("barHeight"), false, isBars)
    grid:Add({ "select", L("Формат полосы", "Bar format"), values = {
        { "full", L("Иконка + название + таймер", "Icon + name + timer") },
        { "icon", L("Иконка + таймер", "Icon + timer") },
        { "bar", L("Только полоса с названием", "Bar with name only") } } }, g("barFormat"), false, isBars)
    grid:Add({ "media", L("Текстура полосы", "Bar texture"), kind = "statusbar", ignoreGlobal = true },
        g("barTexture"), false, isBars)
    grid:Add({ "color", L("Цвет заполнения", "Fill colour"), alpha = true }, g("barColor"), false, isBars)
    grid:Add({ "color", L("Фон полосы", "Bar background"), alpha = true }, g("barBackground"), false, isBars)

    grid:Header(L("Условия загрузки", "Load conditions"))
    grid:Add({ "select", L("Показывать", "Show"), values = {
        { "always", L("Всегда", "Always") }, { "combat", L("Только в бою", "In combat") },
        { "ooc", L("Только вне боя", "Out of combat") }, { "target", L("Есть цель", "With a target") },
        { "hostile", L("Цель — противник", "Hostile target") } } }, gl({ "load", "when" }, "always"), false, hasGroup)
    grid:Add({ "select", L("Группа игрока", "Player group"), values = {
        { "any", L("Неважно", "Any") }, { "solo", L("Соло", "Solo") }, { "group", L("В группе или рейде", "Party or raid") },
        { "party", L("Только группа", "Party only") }, { "raid", L("Только рейд", "Raid only") } } },
        gl({ "load", "group" }, "any"), false, hasGroup)
    grid:Add({ "select", L("Набор талантов", "Talent spec"), values = {
        { 0, L("Любой", "Any") }, { 1, L("Основной", "Primary") }, { 2, L("Дополнительный", "Secondary") } } },
        gl({ "load", "talentGroup" }, 0), false, hasGroup)
    grid:Add({ "select", L("Ветка талантов", "Talent tree"), values = function()
        local values = { { 0, L("Любая", "Any") } }
        for index, name in ipairs(ui.Suite.TreeNames()) do values[#values + 1] = { index, name } end
        if #values == 1 then for i = 1, 3 do values[#values + 1] = { i, "#" .. i } end end
        return values
    end }, gl({ "load", "tree" }, 0), false, hasGroup)
    grid:Add({ "select", L("Стойка / форма", "Stance / form"), values = function()
        local values = { { 0, L("Любая", "Any") }, { 1, L("Без формы", "No form") } }
        for i = 1, (GetNumShapeshiftForms and GetNumShapeshiftForms()) or 0 do
            local _, name = GetShapeshiftFormInfo(i)
            values[#values + 1] = { i + 1, name or ("#" .. i) }
        end
        return values
    end }, gl({ "load", "form" }, 0), false, hasGroup)
    grid:Add({ "toggle", L("В открытом мире", "Open world") }, gl({ "load", "zone", "none" }, true), false, hasGroup)
    grid:Add({ "toggle", L("В подземельях", "Dungeons") }, gl({ "load", "zone", "party" }, true), false, hasGroup)
    grid:Add({ "toggle", L("В рейдах", "Raids") }, gl({ "load", "zone", "raid" }, true), false, hasGroup)
    grid:Add({ "toggle", L("На полях боя", "Battlegrounds") }, gl({ "load", "zone", "pvp" }, true), false, hasGroup)
    grid:Add({ "toggle", L("На арене", "Arena") }, gl({ "load", "zone", "arena" }, true), false, hasGroup)
    y = y - grid:Height() - 10

    -------------------------------------------------------------------------------------------
    -- Spell constructor
    -------------------------------------------------------------------------------------------
    local itemsHeader = W.Header(parent, L("Заклинания и предметы группы", "Spells and items of the group"), width)
    itemsHeader:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local itemList = su.List(parent, 260, 9, 24, function(index)
        state.item = index
        refresh()
    end)
    itemList:SetPoint("TOPLEFT", 0, y)

    local right, rightWidth = 276, width - 276
    local addSpell = W.Create(parent, { type = "text", label = L("ID, название, item:ID или slot:13", "ID, name, item:ID or slot:13") },
        su.Access(function() return state.add end, "spell", nil, nil), rightWidth)
    addSpell:SetPoint("TOPLEFT", right, y)
    local addKind
    addKind = W.Create(parent, { type = "select", label = L("Тип отслеживания", "Tracking type"), values = cdm.kinds },
        su.Access(function() return state.add end, "kind", nil, function() addKind:Refresh() end), rightWidth)
    addKind:SetPoint("TOPLEFT", right, y - 50)
    local function addCurrent()
        -- read the box directly: the text counts even without pressing Enter
        local text = state.add.spell
        for _, child in ipairs({ addSpell:GetChildren() }) do
            if child.GetText and child.SetAutoFocus and child:GetText() then text = child:GetText() end
        end
        text = (text or ""):match("^%s*(.-)%s*$")
        local group = selectedGroup()
        if not group then return end
        if state.add.kind ~= "missing" and state.add.kind ~= "totem" and (text == nil or text == "") then return end
        local spell = tonumber(text) or text
        state.item = cdm.AddItem(group.id, state.add.kind, spell)
        state.add.spell = ""
        cdm.RefreshCombatLog()
        cdm.Rebuild()
        refresh(true)
    end
    local addButton = W.Button(parent, L("Добавить", "Add"), 100, addCurrent, 24)
    addButton:SetPoint("TOPLEFT", right, y - 102)
    local book = W.Button(parent, L("Из книги заклинаний", "From spellbook"), 170, function(self)
        W.OpenList(self, su.SpellbookItems(), nil, function(value)
            state.add.spell = value
            addSpell:Refresh()
        end, 260)
    end, 24)
    book:SetPoint("TOPLEFT", right + 108, y - 102)
    local up = W.Button(parent, L("Выше", "Up"), 100, function()
        local group = selectedGroup()
        if group and state.item then state.item = cdm.MoveItem(group.id, state.item, -1) end
        refresh()
    end, 24)
    up:SetPoint("TOPLEFT", right, y - 134)
    local down = W.Button(parent, L("Ниже", "Down"), 100, function()
        local group = selectedGroup()
        if group and state.item then state.item = cdm.MoveItem(group.id, state.item, 1) end
        refresh()
    end, 24)
    down:SetPoint("TOPLEFT", right + 108, y - 134)
    local remove = W.Button(parent, L("Удалить", "Remove"), 100, function()
        local group = selectedGroup()
        if group and state.item then
            cdm.RemoveItem(group.id, state.item)
            state.item = nil
            cdm.RefreshCombatLog()
        end
        refresh(true)
    end, 24)
    remove:SetPoint("TOPLEFT", right + 216, y - 134)
    remove.text:SetTextColor(W.rgba(S.danger))
    local itemHint = W.Description(parent, L("Несколько вариантов через запятую: «1459, 23028» — сработает любой. "
        .. "Неизученные заклинания скрываются сами.", "Several alternatives separated by commas: “1459, 23028” — any of them "
        .. "counts. Unlearned spells hide themselves."), rightWidth)
    itemHint:SetPoint("TOPLEFT", right, y - 166)
    y = y - 9 * 24 - 16

    local itemGrid = su.Grid(parent, 0, y, width, 2)
    itemGrid:Header(L("Выбранный элемент", "Selected entry"))
    itemGrid:Add({ "select", L("Тип отслеживания", "Tracking type"), values = cdm.kinds }, it("kind"), false, hasItem)
    itemGrid:Add({ "text", L("Заклинание / предмет", "Spell / item") }, su.Access(selectedItem, "spell", "", function(key, value)
        local entry = selectedItem()
        if entry then entry.spell = tonumber(value) or value end
        itemChanged(key)
    end), false, hasItem)
    itemGrid:Add({ "text", L("Своя подпись (полосы)", "Custom label (bars)") }, it("label", ""), false, hasItem)
    itemGrid:Add({ "select", L("Юнит", "Unit"), values = {
        { "player", L("Игрок", "Player") }, { "target", L("Цель", "Target") }, { "focus", L("Фокус", "Focus") },
        { "pet", L("Питомец", "Pet") } } }, it("unit"), false, itemKind("buff", "debuff"))
    itemGrid:Add({ "toggle", L("Только мои", "Mine only") }, it("mine"), false, itemKind("buff", "debuff"))
    itemGrid:Add({ "select", L("Чего не хватает", "What is missing"), values = cdm.missingTypes }, it("missingType"),
        false, itemKind("missing"))
    itemGrid:Add({ "range", L("Длительность, с (ICD, призыв)", "Duration, s (ICD, summon)"), min = 1, max = 600, step = 1 },
        it("duration"), false, itemKind("icd", "summon"))
    itemGrid:Add({ "range", L("Предупреждение до спадания, с", "Warn before it fades, s"), min = 0, max = 15, step = 0.5 },
        it("warn"), false, itemKind("debuff"))
    itemGrid:Add({ "text", L("Подсветка при баффе-проке", "Glow while this proc buff is up") }, it("procAura", ""),
        false, itemKind("cooldown"))
    itemGrid:Add({ "toggle", L("Подсветка, когда доступно", "Glow when usable") }, it("glowUsable"), false, itemKind("cooldown"))
    itemGrid:Add({ "toggle", L("Скрывать неизученное", "Hide unlearned") }, it("hideUnknown"), false, itemKind("cooldown"))
    itemGrid:Add({ "text", L("Требует заклинание / талант", "Requires spell / talent") }, it("requires", ""), false, hasItem)
    itemGrid:Add({ "toggle", L("Только в бою", "Only in combat") }, it("onlyCombat"), false, hasItem)
    itemGrid:Add({ "toggle", L("Только в группе / рейде", "Only in a party / raid") }, it("onlyGroup"), false, hasItem)
    itemGrid:Add({ "color", L("Свой цвет полосы", "Own bar colour"), alpha = true },
        su.Access(selectedItem, "color", nil, itemChanged), false, function() return hasItem() and isBars() end)
    itemGrid:Add({ "toggle", L("Подсвечивать отсутствие", "Glow when missing") }, it("glowMissing"), false, itemKind("missing"))
    itemGrid:Header(L("Подсветка и звуки", "Highlight and sounds"))
    local sounds = function() return ui.Suite.SoundItems() end
    itemGrid:Add({ "toggle", L("Подсветка при откате", "Glow when ready") }, it("glowReady"), false, itemKind("cooldown", "icd"))
    itemGrid:Add({ "select", L("Звук при откате", "Sound when ready"), values = sounds }, it("soundReady"), false,
        itemKind("cooldown", "icd"))
    itemGrid:Add({ "range", L("Порог стаков", "Stack threshold"), min = 0, max = 50, step = 1 }, it("stacks"), false, hasItem)
    itemGrid:Add({ "toggle", L("Подсветка на пороге стаков", "Glow at the stack threshold") }, it("glowStacks"), false, hasItem)
    itemGrid:Add({ "select", L("Звук на пороге стаков", "Sound at the stack threshold"), values = sounds },
        it("soundStacks"), false, hasItem)
    itemGrid:Add({ "range", L("Скоро закончится, с", "Ending soon, s"), min = 0, max = 30, step = 0.5 }, it("expire"),
        false, hasItem)
    itemGrid:Add({ "toggle", L("Подсветка перед окончанием", "Glow before it ends") }, it("glowExpire"), false, hasItem)
    itemGrid:Add({ "select", L("Звук перед окончанием", "Sound before it ends"), values = sounds }, it("soundExpire"),
        false, hasItem)
    y = y - itemGrid:Height()

    -------------------------------------------------------------------------------------------
    -- Refresh
    -------------------------------------------------------------------------------------------
    local function renderGroup(row, group)
        row.text:SetText(group.name or "?")
        row.icon:SetTexture(group.kind == "bars" and "Interface\\Icons\\INV_Misc_PocketWatch_01"
            or "Interface\\Icons\\Spell_Nature_TimeStop")
        local count = #(group.items or {})
        row.sub:SetText((group.enabled and "" or L("выкл · ", "off · ")) .. count)
    end
    local function renderItem(row, entry)
        local name, icon = ui.Suite.SpellInfo(ui.Suite.ParseSpellList(entry.spell)[1])
        local spec = tostring(entry.spell or "")
        if spec:match("^item:%d+$") then
            local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(tonumber(spec:match("%d+")))
            name, icon = itemName or spec, itemIcon
        elseif spec:match("^slot:%d+$") then
            local slot = tonumber(spec:match("%d+"))
            name, icon = L("Слот ", "Slot ") .. slot, GetInventoryItemTexture("player", slot)
        elseif entry.kind == "missing" and entry.missingType ~= "aura" then
            for _, value in ipairs(cdm.missingTypes) do if value[1] == entry.missingType then name = value[2] end end
        elseif entry.kind == "totem" and tonumber(entry.spell) and tonumber(entry.spell) <= 4 then
            name = L("Тотем, слот ", "Totem slot ") .. entry.spell
        end
        row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.text:SetText(entry.label and entry.label ~= "" and entry.label or name or spec)
        row.sub:SetText(cdm.kindNames[entry.kind] and cdm.kindNames[entry.kind]:match("^[^%s]+") or entry.kind)
    end

    refresh = function()
        local list = groups()
        local group = selectedGroup()
        local selectedIndex
        for index, entry in ipairs(list) do if group and entry.id == group.id then selectedIndex = index end end
        groupList:SetItems(list, renderGroup)
        groupList:Select(selectedIndex)
        local items = group and group.items or {}
        if state.item and not items[state.item] then state.item = nil end
        itemList:SetItems(items, renderItem)
        itemList:Select(state.item)
        grid:Refresh()
        itemGrid:Refresh()
        addSpell:Refresh()
        addKind:Refresh()
        for _, b in ipairs({ up, down, remove }) do
            if state.item then b:Enable() else b:Disable() end
        end
        if parent:IsVisible() then cdm.SetPreview(true, group and group.id) end
    end
    parent.refreshManager = refresh

    parent:SetScript("OnShow", function()
        if cdm.selectedGroup then state.group, state.item = cdm.selectedGroup, nil end
        refresh()
        cdm.SetPreview(true, state.group)
    end)
    parent:SetScript("OnHide", function() cdm.SetPreview(false) end)
    ui.RegisterCallback("CooldownManagerSelect", function(id)
        state.group, state.item = id, nil
        refresh()
    end, "CooldownManagerOptions")
    ui.RegisterCallback("SuiteProfileChanged", function()
        state.group, state.item = nil, nil
        refresh()
    end, "CooldownManagerOptionsProfile")
    refresh()
    return -y + 10
end

ui.RegisterOptions("cooldowns", {
    title = "Cooldown Manager",
    description = L("Группы трекеров кулдаунов, баффов и полос в стиле WoW Forever.",
        "Cooldown, buff and bar tracker groups in the WoW Forever style."),
    icon = "Interface\\Icons\\Spell_Nature_TimeStop",
    group = "combat",
    order = 5,
    enable = "cdmEnabled",
    apply = function() if CDM() then CDM().Rebuild() end end,
    sections = {
        { options = {
            { "toggle", "cdmEnabled", L("Включить Cooldown Manager", "Enable Cooldown Manager"), default = true },
            { "custom", build = buildManager, refresh = function(holder)
                if holder.refreshManager then holder.refreshManager() end
            end },
        } },
    },
})
