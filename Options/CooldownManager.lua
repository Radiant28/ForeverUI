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
    { "CENTER", L("От центра", "From the centre") },
}
local wrapValues = {
    { "DOWN", L("Новый ряд ниже", "Next row below") }, { "UP", L("Новый ряд выше", "Next row above") },
    { "RIGHT", L("Новый столбец справа", "Next column right") }, { "LEFT", L("Новый столбец слева", "Next column left") },
}

local classOrder = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local classFallback = {
    WARRIOR = L("Воин", "Warrior"), PALADIN = L("Паладин", "Paladin"), HUNTER = L("Охотник", "Hunter"),
    ROGUE = L("Разбойник", "Rogue"), PRIEST = L("Жрец", "Priest"), DEATHKNIGHT = L("Рыцарь смерти", "Death Knight"),
    SHAMAN = L("Шаман", "Shaman"), MAGE = L("Маг", "Mage"), WARLOCK = L("Чернокнижник", "Warlock"), DRUID = L("Друид", "Druid"),
}
local function className(class)
    local names = LOCALIZED_CLASS_NAMES_MALE
    return names and names[class] or classFallback[class] or class
end
local function classValues()
    local values = { { "", L("Любой", "Any") } }
    for _, class in ipairs(classOrder) do values[#values + 1] = { class, className(class) } end
    return values
end
-- Tree choices for a class ("" = the player's class); "#1".."#3" when the names are unknown.
local function treeValues(class)
    local values = { { 0, L("Любая", "Any") } }
    local names = CDM().TreeNames(class)
    for i = 1, 3 do values[#values + 1] = { i, names[i] or ("#" .. i) } end
    return values
end

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

    -- Hints by setting key: what the option is for. hinted() makes a grid attach them as tooltips.
    local hints = {
        name = L("Имя группы в списке и в режиме редактирования.", "Name of the group in the list and in Edit Mode."),
        kind = L("Иконки — для перезарядок и баффов, полосы — для ДоТов и длительностей с названием.",
            "Icons suit cooldowns and buffs, bars suit DoTs and durations with a name."),
        enabled = L("Выключенная группа не показывается нигде, но её настройки сохраняются.",
            "A disabled group is shown nowhere, its settings are kept."),
        layout = L("«Сжатие» убирает скрытые элементы без дыр. «Фиксированные слоты» держат каждое место за своим "
            .. "элементом (сортировка по роли при этом не действует).",
            "“Dynamic” closes the gaps of hidden entries. “Fixed slots” keep every cell for its entry (the role "
            .. "sort does not apply then)."),
        sort = L("«По роли» ставит вперёд важное для вашей роли (см. «Роль» вверху), внутри категории — порядок "
            .. "списка. «Как в списке» — строго ваш порядок.",
            "“By role” puts first what matters for your role (see “Role” above), list order inside a category. "
            .. "“As listed” keeps exactly your order."),
        cdShow = L("Показывать перезарядки всегда, только готовые или только те, что откатываются. Активный бафф "
            .. "заклинания виден в любом случае.",
            "Show cooldowns always, only when ready or only while recharging. The spell's active buff shows anyway."),
        size = L("Сторона иконки в пикселях.", "Side of an icon in pixels."),
        spacing = L("Расстояние между элементами.", "Distance between elements."),
        perRow = L("Сколько элементов в ряду до переноса.", "How many elements fit a row before it wraps."),
        grow = L("Куда растёт ряд. «От центра» центрирует каждый ряд — удобно под персонажем.",
            "Where a row grows. “From the centre” centres every row — handy under the character."),
        wrap = L("Куда уходит следующий ряд (или столбец при росте вверх и вниз).",
            "Where the next row goes (or column when growing up or down)."),
        alpha = L("Прозрачность группы в бою.", "Opacity of the group in combat."),
        oocAlpha = L("Прозрачность группы вне боя: уменьшите, чтобы панели не отвлекали.",
            "Opacity of the group out of combat: lower it to keep the panels out of the way."),
        inactiveAlpha = L("Прозрачность неактивных элементов (фиксированные слоты, предпросмотр).",
            "Opacity of inactive elements (fixed slots, preview)."),
        fontSize = L("Размер цифр стаков и зарядов, у полос — названий.", "Size of stack and charge numbers, of names on bars."),
        timerSize = L("Размер цифр таймера.", "Size of the timer numbers."),
        showTimer = L("Цифры оставшегося времени на иконке.", "Remaining time as numbers on the icon."),
        timerColors = L("Белый > жёлтый (10 с) > красный (последние 3 с); у активного баффа — цвет «Активно».",
            "White > yellow (10 s) > red (last 3 s); the “Active” colour while the buff is up."),
        showSwipe = L("Затемнение-спираль поверх иконки на время перезарядки.", "The dark sweep over the icon while it recharges."),
        showCount = L("Число стаков баффа, зарядов или предметов.", "Number of buff stacks, charges or items."),
        desaturate = L("Иконка на перезарядке становится серой: готовые видны с первого взгляда.",
            "An icon on cooldown turns grey: the ready ones stand out at a glance."),
        showGCD = L("Показывать спираль общей перезарядки (1,5 с).", "Show the global cooldown sweep (1.5 s)."),
        showActive = L("Пока на вас висит бафф самого заклинания, иконка яркая, с рамкой «Активно» и считает время "
            .. "баффа; потом идёт перезарядка.",
            "While the spell's own buff is on you the icon is bright, has the “Active” border and counts the buff "
            .. "down; the cooldown follows."),
        activeColor = L("Цвет рамки и таймера активного эффекта.", "Colour of the border and timer of an active effect."),
        rangeTint = L("Лёгкий красный оттенок, когда цель вне радиуса заклинания. Синий оттенок — не хватает "
            .. "ресурса, серый — сейчас неприменимо.",
            "A light red tint when the target is out of the spell's range. Blue means not enough resource, grey "
            .. "means not usable now."),
        borderStyle = L("Рамка WoW Forever или плоская линия в 1 пиксель.", "The WoW Forever frame or a flat one-pixel line."),
        categoryBorder = L("Красит рамку по категории: бурст, защита, контроль, утилити, рейдовые.",
            "Colours the border by category: offensive, defensive, control, utility, raid."),
        borderColor = L("Обычный цвет рамки иконок.", "Normal colour of the icon border."),
        when = L("Дополнительное условие показа группы.", "An extra condition for showing the group."),
        group = L("Показывать группу только соло, в группе или в рейде.", "Show the group only solo, in a party or in a raid."),
        talentGroup = L("Только для основного или дополнительного набора талантов.", "Only for the primary or secondary talent spec."),
        class = L("Только для этого класса (для профилей, общих для нескольких персонажей).",
            "Only for this class (for profiles shared by several characters)."),
        tree = L("Только для этой ветки талантов.", "Only for this talent tree."),
        form = L("Только в этой стойке или форме.", "Only in this stance or form."),
        -- entries
        spell = L("ID или название; несколько вариантов через запятую; item:ID — предмет, slot:13 — аксессуар.",
            "An id or a name; several alternatives separated by commas; item:ID — an item, slot:13 — a trinket."),
        category = L("Для чего перезарядка: от этого зависят порядок по роли, цвет рамки и скрытие в режимах. "
            .. "«Авто» берёт категорию из встроенной базы.",
            "What the cooldown is for: it drives the role order, the border colour and hiding in modes. “Auto” "
            .. "takes the category from the built-in table."),
        activeAura = L("Бафф, который считается «активным эффектом» этого заклинания, если он называется иначе.",
            "The buff that counts as this spell's “active effect” when it has another name."),
        hideUnknown = L("Неизученное заклинание (не взятый талант) не занимает место в сетке.",
            "A spell you have not learned (a talent not taken) takes no cell in the grid."),
        requires = L("Показывать, только если изучено это заклинание или взят этот талант.",
            "Show only while this spell is learned or this talent is taken."),
        spec = L("Элемент виден только с этой веткой талантов. Добавленное вами получает текущую ветку; «Любая» — "
            .. "для всех.",
            "The entry shows only with this talent tree. What you add gets the current tree; “Any” — for all."),
        procAura = L("Подсветить иконку, пока на вас этот бафф-прок.", "Glow the icon while this proc buff is on you."),
        glowUsable = L("Подсветка, когда заклинание можно применить (например, по проку).",
            "Glow when the spell can be used (for instance on a proc)."),
        glowReady = L("Подсветка готового заклинания — для главных бурстов.", "Glow when ready — for the main bursts."),
        warn = L("За сколько секунд до спадания рамка становится красной.", "How many seconds before fading the border turns red."),
        mine = L("Учитывать только эффекты, наложенные вами.", "Count only effects you applied."),
        duration = L("Длительность внутренней перезарядки или жизни призванного существа.",
            "Length of the internal cooldown or of the summon's life."),
    }
    local function hinted(grid)
        local add = grid.Add
        function grid:Add(opt, access, full, enabled)
            if access and access.hint and not opt.tooltip then opt.tooltip = hints[access.hint] end
            return add(self, opt, access, full, enabled)
        end
        return grid
    end
    local function tagged(access, path)
        access.hint = type(path) == "table" and path[#path] or path
        return access
    end

    local defaults = cdm.groupDefaults
    local function g(key, default)
        return tagged(su.Access(selectedGroup, key, default == nil and defaults[key] or default, changed), key)
    end
    local function gl(path, default)
        return tagged(su.Access(selectedGroup, path, default, changed), path)
    end
    local itemDefaults = cdm.itemDefaults
    local function it(key, default)
        if default == nil then default = itemDefaults[key] end
        return tagged(su.Access(selectedItem, key, default, itemChanged), key)
    end
    -- Per-mode visibility of the selected group: its own choice, else the rule of the mode.
    local function modeAccess(mode)
        return {
            get = function()
                local group = selectedGroup()
                return group and cdm.ModeShows(group, mode) or false
            end,
            set = function(value)
                local group = selectedGroup()
                if not group then return end
                if type(group.modes) ~= "table" then group.modes = {} end
                group.modes[mode] = value and true or false
                changed()
            end,
        }
    end

    -------------------------------------------------------------------------------------------
    -- Quick start: what the module does by itself, test mode, role and display modes
    -------------------------------------------------------------------------------------------
    local y = 0
    local function db() return cdm.Data() end
    local function settingsChanged()
        cdm.SettingsChanged()
        if refresh then refresh() end
    end
    local function d(path, default) return su.Access(db, path, default, settingsChanged) end
    local modeValues = { { "auto", L("Авто (по типу зоны)", "Auto (by zone)") } }
    for _, entry in ipairs(cdm.modes) do modeValues[#modeValues + 1] = entry end

    local intro = su.Grid(parent, 0, y, width, 2)
    intro:Header(L("Быстрый старт", "Quick start"), true)
    intro:Text(L("Ничего настраивать не нужно: панели сами берут набор вашего класса и ветки талантов, прячут "
        .. "неизученное и смыкаются без дыр. При смене талантов набор, порядок и позиции меняются сами. "
        .. "Ниже — тест, роль и режимы; ещё ниже — тонкая настройка групп и заклинаний.",
        "Nothing has to be set up: the panels take the set of your class and talent tree, hide what is not "
        .. "learned and close the gaps. When talents change, the set, the order and the positions follow. "
        .. "Below: test, role and modes; further down: fine tuning of groups and spells."))
    local status = intro:Text(" ")
    local testRow = intro:Add({ "button", L("Тест / разблокировать панели", "Test / unlock panels"),
        func = function() cdm.SetTest(not cdm.IsTesting()) end,
        tooltip = L("Показывает заклинания текущей ветки с ненастоящими таймерами (готово > активно > перезарядка). "
            .. "Пока тест идёт, группы перетаскиваются мышью, место запоминается для этой ветки. Выход: эта кнопка, "
            .. "кнопка режима на экране, /fcdm test или начало боя.",
            "Shows the spells of the current tree with fake timers (ready > active > cooldown). While the test "
            .. "runs the groups are dragged with the mouse and the spot is remembered for this tree. Leave with "
            .. "this button, the mode button on screen, /fcdm test or by entering combat.") })
    local resetNote
    intro:Add({ "button", L("Сбросить раскладку этой ветки", "Reset the layout of this tree"),
        func = function()
            su.Confirm(L("Вернуть заводскую раскладку текущей ветки талантов? Её элементы (и добавленные вами) "
                .. "заменятся стандартными, позиции групп сбросятся. Другие ветки и свои группы не изменятся.",
                "Restore the factory layout of the current talent tree? Its entries (yours too) are replaced by the "
                .. "defaults and the group positions are reset. Other trees and your own groups stay."), function()
                local addedGroups, addedItems = cdm.ResetSpec()
                resetNote = (L("Ветка сброшена: групп %d, элементов %d.", "Tree reset: %d groups, %d entries."))
                    :format(addedGroups or 0, addedItems or 0)
                if refresh then refresh() end
            end)
        end,
        tooltip = L("Заводская раскладка только для текущей ветки талантов.",
            "Factory layout for the current talent tree only.") })
    intro:Add({ "toggle", L("Авто-адаптация под ветку и таланты", "Auto-adapt to tree and talents"),
        tooltip = L("Вкл.: видны только элементы текущей ветки, порядок в группах — по роли, добавленные вами "
            .. "заклинания и позиции групп запоминаются отдельно для каждой ветки. Выкл.: показываются элементы "
            .. "всех веток класса в порядке списка.",
            "On: only entries of the current tree are shown, groups are ordered by role, spells you add and group "
            .. "positions are kept per tree. Off: entries of every tree of the class are shown in list order.") },
        d("autoAdapt", true))
    intro:Add({ "select", L("Роль", "Role"), values = cdm.roles,
        tooltip = L("От роли зависит порядок в группах с сортировкой «По роли»: танк — защита и прерывания, "
            .. "лекарь — сейвы на группу и рейд, боец — бурсты и прерывания. «Авто» берёт роль ветки (друид-медведь "
            .. "и рыцарь смерти во власти льда — танк).",
            "The role sets the order in groups sorted “By role”: tank — defensives and interrupts, healer — "
            .. "externals and raid cooldowns, damage — bursts and interrupts. “Auto” uses the role of the tree "
            .. "(a bear druid and a death knight in Frost Presence count as tanks).") }, d("role", "auto"))

    intro:Header(L("Режимы панелей", "Panel modes"), true)
    intro:Text(L("Режим решает, какие группы видны: «Полный» — все; «Только бой» — без напоминаний и только в бою; "
        .. "«Рейд» — без мобильности и утилити; «Подземелье» — как полный (настройте под себя); «PvP» — без полос, "
        .. "напоминаний и рейдовых сейвов; «Минимум» — только главные перезарядки. Видимость каждой группы в режиме "
        .. "меняется в её настройках ниже.",
        "The mode decides which groups show: Full — all; Combat — no reminders, in combat only; Raid — no "
        .. "mobility and utility; Dungeon — like Full (tune it yourself); PvP — no bars, reminders or raid "
        .. "cooldowns; Minimal — the main cooldowns only. Each group's visibility per mode is set in its settings below."))
    intro:Add({ "select", L("Режим", "Mode"), values = modeValues,
        tooltip = L("«Авто» выбирает режим по типу зоны (ниже). Быстро: кнопка режима на экране или /fcdm mode.",
            "“Auto” picks the mode by the kind of zone (below). Quick switch: the mode button on screen or /fcdm mode.") },
        d("mode", "auto"))
    intro:Add({ "toggle", L("Кнопка режима на экране", "Mode button on screen"),
        tooltip = L("Маленькая кнопка над панелями: ЛКМ — следующий режим, ПКМ — авто. Двигается в режиме редактирования.",
            "A small button above the panels: left click — next mode, right click — auto. Moved in Edit Mode.") },
        d("modeButton", true))
    for _, zone in ipairs({ { "none", L("Авто: открытый мир", "Auto: open world") },
        { "party", L("Авто: подземелье", "Auto: dungeon") }, { "raid", L("Авто: рейд", "Auto: raid") },
        { "pvp", L("Авто: поле боя", "Auto: battleground") }, { "arena", L("Авто: арена", "Auto: arena") } }) do
        intro:Add({ "select", zone[2], values = cdm.modes,
            tooltip = L("Какой режим включать в этой зоне, когда выбран режим «Авто».",
                "Which mode to use in this kind of zone while the mode is “Auto”.") },
            d({ "autoModes", zone[1] }, cdm.autoModeDefaults[zone[1]]))
    end

    intro:Header(L("Звук при откате", "Sound when ready"), L("Звук для всех", "Sound for all"))
    intro:Text(L("Один звук для всех скиллов: играет, когда перезарядка любого заклинания или предмета в любой группе "
        .. "закончилась. Индивидуально — в настройках группы (для её скиллов) и у каждого элемента ниже; "
        .. "звук элемента важнее звука группы, звук группы важнее общего.",
        "One sound for every skill: plays when the cooldown of any spell or item in any group ends. Individually — "
        .. "in a group's settings (for its skills) and on each entry below; an entry's sound wins over its "
        .. "group's, a group's over the common one."))
    intro:Add({ "select", L("Звук для всех скиллов", "Sound for every skill"),
        values = function() return ui.Suite.SoundItems() end }, d("soundReady", ""))
    intro:Add({ "toggle", L("Звуки только в бою", "Sounds in combat only") }, d("soundCombatOnly", false))
    intro:Add({ "button", L("Прослушать общий звук", "Play the common sound"),
        func = function() ui.Suite.PlayAlert(db() and db().soundReady) end })
    intro:Add({ "button", L("Один звук для всех: убрать свои", "One sound for all: clear own ones"),
        func = function()
            su.Confirm(L("Убрать свои звуки отката у всех групп и элементов (и выключенные тоже)? Дальше у всех скиллов "
                .. "будет общий звук.", "Clear the own ready sounds of every group and entry (muted ones too)? "
                .. "Every skill then uses the common sound."), function()
                local count = cdm.ClearOwnSounds()
                ui.Print((L("убрано своих звуков: %d.", "own sounds cleared: %d.")):format(count or 0))
                settingsChanged()
            end)
        end,
        tooltip = L("Сбрасывает «Звук группы» и «Звук при откате» элементов на «Как для всех» / «Как у группы».",
            "Sets every “Group sound” and entry “Sound when ready” back to “As for all” / “As the group”.") })
    y = y - intro:Height() - 10

    -------------------------------------------------------------------------------------------
    -- Groups
    -------------------------------------------------------------------------------------------
    local header = W.Header(parent, L("Группы трекеров", "Tracker groups"), width)
    header:SetPoint("TOPLEFT", 0, y)
    su.Anchor(parent, L("Группы", "Groups"), -y)
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
    local restoreNote
    button(L("Вернуть удалённое", "Restore deleted"), function()
        local addedGroups, addedItems = cdm.RestoreDefaults("missing")
        state.item = nil
        restoreNote = (addedGroups + addedItems > 0)
            and (L("Восстановлено: групп %d, элементов %d.", "Restored: %d groups, %d entries.")):format(addedGroups, addedItems)
            or L("Всё стандартное на месте.", "All defaults are in place.")
        refresh()
    end, 1, 5)
    local reset = button(L("Сбросить к стандартным", "Reset to defaults"), function()
        su.Confirm(L("Заменить все группы трекеров стандартным набором вашего класса? Свои группы и изменения "
            .. "пропадут.", "Replace all tracker groups with the default set of your class? Your own groups and changes "
            .. "will be lost."), function()
            cdm.RestoreDefaults("all")
            state.group, state.item, restoreNote = nil, nil, nil
            refresh()
        end)
    end, 2, 5)
    reset.text:SetTextColor(W.rgba(S.danger))
    local hint = W.Description(parent, "", 356)
    hint:SetPoint("TOPLEFT", 236, y - 154)
    local function hintText()
        local class, tree = cdm.CurrentSpec()
        local treeName = tree and tree > 0 and cdm.TreeNames(class)[tree] or L("без талантов", "no talents")
        local text = (L("Сейчас: %s, %s. Стандартные элементы меняются вместе с классом и веткой талантов; "
            .. "серые в списке сейчас не показываются.", "Now: %s, %s. Default entries follow your class and talent "
            .. "tree; grey ones in the list are not shown now.")):format(
            className(class or ""), treeName)
        if restoreNote then text = text .. "\n|cffd9b873" .. restoreNote .. "|r" end
        return text
    end
    y = y - 8 * 24 - 16

    -------------------------------------------------------------------------------------------
    -- Group settings
    -------------------------------------------------------------------------------------------
    local grid = hinted(su.Grid(parent, 0, y, width, 2))
    grid:Header(L("Группа: вид и геометрия", "Group: look and geometry"), L("Вид группы", "Group look"))
    grid:Add({ "text", L("Название", "Name") }, g("name", ""), false, hasGroup)
    grid:Add({ "select", L("Тип отображения", "Display type"), values = {
        { "icons", L("Сетка / ряд иконок", "Icon grid / row") }, { "bars", L("Список полос", "Bar list") } } },
        g("kind"), false, hasGroup)
    grid:Add({ "toggle", L("Группа включена", "Group enabled") }, g("enabled"), false, hasGroup)
    grid:Add({ "select", L("Компоновка", "Layout"), values = {
        { "dynamic", L("Сжатие без пустых мест", "Dynamic, no gaps") }, { "fixed", L("Фиксированные слоты", "Fixed slots") } } },
        g("layout"), false, hasGroup)
    grid:Add({ "select", L("Порядок элементов", "Order of entries"), values = {
        { "manual", L("Как в списке", "As listed") }, { "role", L("По роли: важное вперёд", "By role: key ones first") } } },
        g("sort"), false, isIcons)
    grid:Add({ "select", L("Перезарядки показывать", "Show cooldowns"), values = {
        { "always", L("Всегда", "Always") }, { "ready", L("Только готовые", "Only when ready") },
        { "cooldown", L("Только на перезарядке", "Only on cooldown") } } }, g("cdShow"), false, hasGroup)
    grid:Add({ "range", L("Размер иконки", "Icon size"), min = 12, max = 96, step = 1 }, g("size"), false, isIcons)
    grid:Add({ "range", L("Отступ", "Spacing"), min = 0, max = 40, step = 1 }, g("spacing"), false, hasGroup)
    grid:Add({ "range", L("Элементов в ряду", "Per row"), min = 1, max = 40, step = 1 }, g("perRow"), false, hasGroup)
    grid:Add({ "select", L("Направление роста", "Growth"), values = growValues }, g("grow"), false, hasGroup)
    grid:Add({ "select", L("Перенос", "Wrap"), values = wrapValues }, g("wrap"), false, hasGroup)
    grid:Add({ "range", L("Прозрачность в бою", "Opacity in combat"), min = 0.1, max = 1, step = 0.05 }, g("alpha"), false, hasGroup)
    grid:Add({ "range", L("Прозрачность вне боя", "Opacity out of combat"), min = 0, max = 1, step = 0.05 },
        g("oocAlpha"), false, hasGroup)
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
    grid:Header(L("Состояния иконок", "Icon states"), true)
    grid:Text(L("Готово — яркая иконка. Активно — цветная рамка и отсчёт баффа. Перезарядка — серая иконка, спираль и "
        .. "таймер (жёлтый с 10 с, красный с 3 с). Синий оттенок — нет ресурса, красный — цель далеко.",
        "Ready — a bright icon. Active — a coloured border and the buff countdown. Cooldown — a grey icon, the sweep "
        .. "and a timer (yellow from 10 s, red from 3 s). Blue tint — no resource, red tint — target out of range."))
    grid:Add({ "toggle", L("Активный эффект на иконке", "Active effect on the icon") }, g("showActive"), false, isIcons)
    grid:Add({ "color", L("Цвет «Активно»", "“Active” colour"), alpha = true }, g("activeColor"), false, isIcons)
    grid:Add({ "toggle", L("Цвет таймера по времени", "Timer colour by time left") }, g("timerColors"), false, isIcons)
    grid:Add({ "toggle", L("Оттенок «вне радиуса»", "Out-of-range tint") }, g("rangeTint"), false, isIcons)
    grid:Add({ "select", L("Стиль рамки", "Border style"), values = {
        { "forever", L("Рамка WoW Forever", "WoW Forever frame") }, { "pixel", L("Линия 1 пиксель", "One-pixel line") } } },
        g("borderStyle"), false, isIcons)
    grid:Add({ "toggle", L("Рамка цветом категории", "Border coloured by category") }, g("categoryBorder"), false, isIcons)
    grid:Header(L("Звук при откате", "Sound when ready"), L("Звук группы", "Group sound"))
    grid:Text(L("Звук, когда перезарядка заклинания или предмета этой группы закончилась. «Как для всех» — общий звук "
        .. "(наверху страницы), «Без звука (выключить)» глушит группу. Свой звук элемента (ниже) важнее. Свои файлы — "
        .. "через LibSharedMedia.",
        "A sound when a spell or item of this group is ready again. “As for all” — the common sound (top of the "
        .. "page), “Off (mute)” silences the group. An entry's own sound (below) wins. Own files — through LibSharedMedia."))
    grid:Add({ "select", L("Звук группы", "Group sound"), values = function()
        local items = ui.Suite.SoundItems()
        items[1] = { "", L("Как для всех", "As for all") }
        table.insert(items, 2, { "none", L("Без звука (выключить)", "Off (mute)") })
        return items
    end }, g("soundReady"), false, hasGroup)
    grid:Add({ "toggle", L("Звуки только в бою", "Sounds in combat only") }, g("soundCombatOnly"), false, hasGroup)
    grid:Add({ "button", L("Прослушать звук группы", "Play the group sound"), func = function()
        local group = selectedGroup()
        if group then ui.Suite.PlayAlert(cdm.ReadySound(group, nil)) end
    end }, nil, false, hasGroup)
    grid:Header(L("В каких режимах видна группа", "Modes that show the group"))
    for _, mode in ipairs(cdm.modes) do
        grid:Add({ "toggle", mode[2], tooltip = L("Показывать эту группу в этом режиме панелей.",
            "Show this group in this panel mode.") }, modeAccess(mode[1]), false, hasGroup)
    end
    grid:Header(L("Полосы прогресса", "Progress bars"), true)
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

    grid:Header(L("Условия загрузки", "Load conditions"), true)
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
    grid:Add({ "select", L("Класс", "Class"), values = classValues }, gl({ "load", "class" }, ""), false, hasGroup)
    grid:Add({ "select", L("Ветка талантов", "Talent tree"), values = function()
        local group = selectedGroup()
        return treeValues(group and group.load and group.load.class or "")
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
    su.Anchor(parent, L("Заклинания группы", "Group spells"), -y)
    y = y - 30
    local itemList = su.List(parent, 260, 9, 24, function(index)
        state.item = index
        refresh()
    end)
    itemList:SetPoint("TOPLEFT", 0, y)

    local right, rightWidth = 276, width - 276
    local addSpell = W.Create(parent, { type = "text", label = L("ID, название, item:ID или slot:13", "ID, name, item:ID or slot:13"),
        spellDrop = { items = true } },
        su.Access(function() return state.add end, "spell", nil, nil), rightWidth)
    addSpell:SetPoint("TOPLEFT", right, y)
    local addKind
    addKind = W.Create(parent, { type = "select", label = L("Тип отслеживания", "Tracking type"), values = cdm.kinds },
        su.Access(function() return state.add end, "kind", nil, function() addKind:Refresh() end), rightWidth)
    addKind:SetPoint("TOPLEFT", right, y - 50)
    local function addBox()
        for _, child in ipairs({ addSpell:GetChildren() }) do
            if child.GetText and child.SetAutoFocus then return child end
        end
    end
    -- read the box directly: the text counts even without pressing Enter
    local function addText()
        local box = addBox()
        local text = box and box:GetText() or state.add.spell
        return (text or ""):match("^%s*(.-)%s*$")
    end
    -- Live preview of what is being added: icon, name, category and whether the spell is learned.
    local preview = CreateFrame("Frame", nil, parent)
    preview:SetWidth(rightWidth)
    preview:SetHeight(22)
    preview:SetPoint("TOPLEFT", right, y - 132)
    preview.icon = preview:CreateTexture(nil, "ARTWORK")
    preview.icon:SetWidth(20)
    preview.icon:SetHeight(20)
    preview.icon:SetPoint("LEFT", 0, 0)
    preview.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    preview.text = W.Text(preview, W.fonts.small)
    preview.text:SetPoint("LEFT", preview.icon, "RIGHT", 6, 0)
    preview.text:SetPoint("RIGHT", preview, "RIGHT", 0, 0)
    preview.text:SetJustifyH("LEFT")
    local function updatePreview()
        local text = addText()
        local first = ui.Suite.ParseSpellList(text)[1]
        local name, icon, note
        if type(first) == "string" and first:match("^item:%d+$") then
            local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(tonumber(first:match("%d+")))
            name, icon = itemName, itemIcon
        elseif type(first) == "string" and first:match("^slot:%d+$") then
            local slot = tonumber(first:match("%d+"))
            name, icon = L("Слот ", "Slot ") .. slot, GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
        elseif first then
            name, icon = ui.Suite.SpellInfo(first)
            if type(first) == "number" and not name then
                note = L("такого заклинания нет", "no such spell")
            elseif name then
                local category = cdm.CategoryOf({ spell = first })
                note = category and cdm.categoryNames[category] or nil
                if state.add.kind == "cooldown" and not ui.Suite.IsKnown(first) then
                    note = (note and note .. ", " or "") .. L("не изучено — будет скрыто", "not learned — will hide")
                end
            end
        end
        preview.icon:SetTexture(first and (icon or "Interface\\Icons\\INV_Misc_QuestionMark") or nil)
        if not first then
            preview.text:SetText(L("Введите ID или название — здесь появится иконка.", "Type an id or a name — the icon shows here."))
        else
            preview.text:SetText((name or tostring(first)) .. (note and " |cff8f8f96(" .. note .. ")|r" or ""))
        end
    end
    local box = addBox()
    if box and box.HookScript then box:HookScript("OnTextChanged", updatePreview) end
    local function addCurrent()
        local text = addText()
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
    up:SetPoint("TOPLEFT", right, y - 160)
    local down = W.Button(parent, L("Ниже", "Down"), 100, function()
        local group = selectedGroup()
        if group and state.item then state.item = cdm.MoveItem(group.id, state.item, 1) end
        refresh()
    end, 24)
    down:SetPoint("TOPLEFT", right + 108, y - 160)
    local remove = W.Button(parent, L("Удалить", "Remove"), 100, function()
        local group = selectedGroup()
        if group and state.item then
            cdm.RemoveItem(group.id, state.item)
            state.item = nil
            cdm.RefreshCombatLog()
        end
        refresh(true)
    end, 24)
    remove:SetPoint("TOPLEFT", right + 216, y - 160)
    remove.text:SetTextColor(W.rgba(S.danger))
    local itemHint = W.Description(parent, L("Несколько вариантов через запятую: «1459, 23028» — сработает любой. "
        .. "Неизученное скрывается само. Добавленное запоминается за текущей веткой талантов.",
        "Several alternatives separated by commas: “1459, 23028” — any of them counts. Unlearned spells hide "
        .. "themselves. What you add is kept for the current talent tree."), rightWidth)
    itemHint:SetPoint("TOPLEFT", right, y - 192)
    y = y - 9 * 24 - 36

    local categoryValues = { { "", L("Авто (из базы)", "Auto (built-in table)") }, { "none", L("Без категории", "None") } }
    for _, entry in ipairs(cdm.categories) do categoryValues[#categoryValues + 1] = { entry[1], entry[2] } end
    local itemGrid = hinted(su.Grid(parent, 0, y, width, 2))
    itemGrid:Header(L("Выбранный элемент", "Selected entry"), true)
    itemGrid:Add({ "select", L("Тип отслеживания", "Tracking type"), values = cdm.kinds }, it("kind"), false, hasItem)
    itemGrid:Add({ "text", L("Заклинание / предмет", "Spell / item"), spellDrop = { items = true } }, su.Access(selectedItem, "spell", "", function(key, value)
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
    itemGrid:Add({ "text", L("Подсветка при баффе-проке", "Glow while this proc buff is up"), spellDrop = true }, it("procAura", ""),
        false, itemKind("cooldown"))
    itemGrid:Add({ "select", L("Категория", "Category"), values = categoryValues }, it("category", ""), false, itemKind("cooldown"))
    itemGrid:Add({ "toggle", L("Показывать активный эффект", "Show the active effect"),
        tooltip = hints.showActive }, it("showActive"), false, itemKind("cooldown"))
    itemGrid:Add({ "text", L("Бафф активного эффекта", "Buff of the active effect"), spellDrop = true }, it("activeAura", ""), false,
        itemKind("cooldown"))
    itemGrid:Add({ "toggle", L("Подсветка, когда доступно", "Glow when usable") }, it("glowUsable"), false, itemKind("cooldown"))
    itemGrid:Add({ "toggle", L("Скрывать неизученное", "Hide unlearned") }, it("hideUnknown"), false, itemKind("cooldown"))
    itemGrid:Add({ "text", L("Требует заклинание / талант", "Requires spell / talent"), spellDrop = true }, it("requires", ""), false, hasItem)
    itemGrid:Add({ "select", L("Только для класса", "Class only"), values = classValues }, it("class", ""), false, hasItem)
    itemGrid:Add({ "select", L("Только для ветки талантов", "Talent tree only"), values = function()
        local entry = selectedItem()
        return treeValues(entry and entry.class or "")
    end }, it("spec", 0), false, hasItem)
    itemGrid:Add({ "toggle", L("Только в бою", "Only in combat") }, it("onlyCombat"), false, hasItem)
    itemGrid:Add({ "toggle", L("Только в группе / рейде", "Only in a party / raid") }, it("onlyGroup"), false, hasItem)
    itemGrid:Add({ "color", L("Свой цвет полосы", "Own bar colour"), alpha = true },
        su.Access(selectedItem, "color", nil, itemChanged), false, function() return hasItem() and isBars() end)
    itemGrid:Add({ "toggle", L("Подсвечивать отсутствие", "Glow when missing") }, it("glowMissing"), false, itemKind("missing"))
    itemGrid:Header(L("Подсветка и звуки", "Highlight and sounds"), true)
    local sounds = function() return ui.Suite.SoundItems() end
    -- Ready sound of an entry: "" follows the group, "none" mutes it, anything else is its own sound.
    local readySounds = function()
        local items = ui.Suite.SoundItems()
        items[1] = { "", L("Как у группы", "As the group") }
        table.insert(items, 2, { "none", L("Без звука (выключить)", "Off (mute)") })
        return items
    end
    itemGrid:Add({ "toggle", L("Подсветка при откате", "Glow when ready") }, it("glowReady"), false, itemKind("cooldown", "icd"))
    itemGrid:Add({ "select", L("Звук при откате", "Sound when ready"), values = readySounds }, it("soundReady"), false,
        itemKind("cooldown", "icd"))
    itemGrid:Add({ "button", L("Прослушать звук отката", "Play the ready sound"), func = function()
        local entry = selectedItem()
        if entry then ui.Suite.PlayAlert(cdm.ReadySound(selectedGroup(), entry)) end
    end }, nil, false, itemKind("cooldown", "icd"))
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
        row.sub:SetText((group.enabled and "" or L("выкл, ", "off, ")) .. count)
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
        local text = entry.label and entry.label ~= "" and entry.label or name or spec
        if (entry.spec or 0) > 0 then
            local tree = cdm.TreeNames(entry.class)[entry.spec] or ("#" .. entry.spec)
            text = text .. " |cff8f8f96(" .. tree .. ")|r"
        end
        row.text:SetText(text)
        -- entries of another class or tree are dimmed: they are not shown now
        local active = cdm.EntryActive(entry)
        row.text:SetTextColor(W.rgba(active and S.text or S.muted))
        row.icon:SetDesaturated(not active)
        row.icon:SetAlpha(active and 1 or 0.5)
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
        hint.label:SetText(hintText())
        do
            local class, tree = cdm.CurrentSpec()
            local treeName = tree and tree > 0 and cdm.TreeNames(class)[tree] or L("без талантов", "no talents")
            local mode = cdm.ActiveMode()
            local modeText = cdm.modeNames[mode] or mode
            if db().mode == "auto" then modeText = cdm.modeNames.auto .. " > " .. modeText end
            local text = (L("Сейчас: %s (%s), роль: %s, режим: %s", "Now: %s (%s), role: %s, mode: %s")):format(
                className(class or ""), treeName, cdm.roleNames[cdm.Role() or ""] or "?", modeText)
            if resetNote then text = text .. "  |cffd9b873" .. resetNote .. "|r" end
            status.label:SetText("|cffd9b873" .. text .. "|r")
        end
        if testRow and testRow.button then
            testRow.button:SetText(cdm.IsTesting() and L("Закончить тест", "Finish the test")
                or L("Тест / разблокировать панели", "Test / unlock panels"))
        end
        intro:Refresh()
        updatePreview()
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
    -- Test and mode are also switched from the screen (mode button, slash command, combat).
    ui.RegisterCallback("CooldownManagerTest", function() refresh() end, "CooldownManagerOptionsTest")
    ui.RegisterCallback("CooldownManagerMode", function() refresh() end, "CooldownManagerOptionsMode")
    refresh()
    return -y + 10
end

ui.RegisterOptions("cooldowns", {
    title = "Cooldown Manager",
    description = L("Перезарядки, баффы и полосы в стиле WoW Forever: сами подстраиваются под класс, ветку талантов "
        .. "и тип контента.", "Cooldowns, buffs and bars in the WoW Forever style that adapt to your class, talent "
        .. "tree and content by themselves."),
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
