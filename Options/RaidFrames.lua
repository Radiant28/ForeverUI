-- Options page of the party/raid frame extension. Values live in the "raid" part of the active
-- suite profile (spec.db), so switching profiles switches the whole page. A decorated mock frame on
-- top previews every change; the client frames update live too.
local _, ui = ...
local L, W, S = ui.L, ui.Widgets, ui.Style

local function RF() return ui.RaidFrames end
local function apply() if RF() then RF().Apply() end end

local anchors = {
    { "TOPLEFT", L("Сверху слева", "Top left") }, { "TOP", L("Сверху", "Top") }, { "TOPRIGHT", L("Сверху справа", "Top right") },
    { "LEFT", L("Слева", "Left") }, { "CENTER", L("Центр", "Centre") }, { "RIGHT", L("Справа", "Right") },
    { "BOTTOMLEFT", L("Снизу слева", "Bottom left") }, { "BOTTOM", L("Снизу", "Bottom") },
    { "BOTTOMRIGHT", L("Снизу справа", "Bottom right") },
}
local grows = {
    { "RIGHT", L("Вправо", "Right") }, { "LEFT", L("Влево", "Left") }, { "UP", L("Вверх", "Up") }, { "DOWN", L("Вниз", "Down") },
}

local function buildPreview(parent, width)
    local rf = RF()
    if not rf or not ui.Suite then return ui.SuiteUI and ui.SuiteUI.Unavailable(parent, width) or 20 end
    -- The preview lives in a panel beside the options window (not in the scrolled page), so it stays
    -- in view while the settings below are scrolled. It shows only while this page is open.
    local host = ForeverUIOptions or parent
    local SCALE, FRAME_W, FRAME_H = 1.7, 120, 48
    local side = CreateFrame("Frame", nil, host)
    side:SetWidth(FRAME_W * SCALE + 36)
    side:SetPoint("TOPLEFT", host, "TOPRIGHT", 6, 0)
    side:SetFrameStrata(host:GetFrameStrata() or "DIALOG")
    side:SetClampedToScreen(true)
    side:EnableMouse(true)
    W.Skin(side, S.window, S.border)
    local title = W.Text(side, W.fonts.heading)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(L("Предпросмотр", "Preview"))
    -- Auras are the same on all three frames (your indicators, tracked buffs, a curse you dispel);
    -- the captions describe what differs: the bars.
    local captions = {
        tank = L("Щит без свечения, рамка угрозы", "Glow-free shield, threat border"),
        healer = L("Входящее лечение", "Incoming heals"),
        dps = L("Мало здоровья, щит и лечение", "Low health, shield and heals"),
    }
    local y, previews = -40, {}
    for _, variant in ipairs(rf.previewOrder) do
        local preview = rf.BuildPreview(side, FRAME_W, FRAME_H, variant)
        preview:SetScale(SCALE)
        preview:SetPoint("TOPLEFT", side, "TOPLEFT", 18 / SCALE, y / SCALE)
        local caption = W.Text(side, W.fonts.small)
        caption:SetPoint("TOPLEFT", side, "TOPLEFT", 18, y - FRAME_H * SCALE - 4)
        caption:SetWidth(FRAME_W * SCALE)
        caption:SetText(captions[variant] or "")
        previews[#previews + 1] = preview
        y = y - FRAME_H * SCALE - 30
    end
    local hint = W.Description(side, L("Индикаторы, баффы и дебаффы одинаковы на всех трёх: ваши индикаторы, "
        .. "отслеживаемые баффы и проклятие, которое «вы» рассеиваете. Настройки сразу применяются и к настоящим "
        .. "фреймам. /fuiraid — диагностика.", "Indicators, buffs and debuffs are the same on all three: your "
        .. "indicators, tracked buffs and a curse “you” dispel. Settings apply to the real frames at once. /fuiraid "
        .. "prints diagnostics."), FRAME_W * SCALE)
    hint:SetPoint("TOPLEFT", side, "TOPLEFT", 18, y + 4)
    side:SetHeight(-y + 40)
    side:Hide()
    parent:SetScript("OnShow", function() side:Show() end)
    parent:SetScript("OnHide", function() side:Hide() end)
    if parent:IsVisible() then side:Show() end
    parent.previews = previews

    local note = W.Description(parent, L("Предпросмотр — справа от окна, он виден при прокрутке. ПКМ по якорю рейда в "
        .. "режиме редактирования открывает эту страницу.", "The preview is to the right of the window and stays visible "
        .. "while you scroll. Right click the raid anchor in Edit Mode to open this page."), width)
    note:SetPoint("TOPLEFT", 0, 0)
    return note:GetHeight() + 4
end

local function buildIndicators(parent, width)
    local rf, su = RF(), ui.SuiteUI
    if not rf or not su or not ui.Suite then return su and su.Unavailable(parent, width) or 20 end
    local state = { index = nil }
    local refresh
    local function list() return rf.Settings().indicators end
    local function selected() return state.index and list()[state.index] end
    local function has() return selected() ~= nil end
    local function changed()
        apply()
        if refresh then refresh() end
    end
    local function a(key, default) return su.Access(selected, key, default, changed) end

    local indicatorList = su.List(parent, 240, 8, 22, function(index)
        state.index = index
        refresh()
    end)
    indicatorList:SetPoint("TOPLEFT", 0, 0)
    local x = 256
    local function button(text, fn, row, column)
        local b = W.Button(parent, text, 160, fn, 24)
        b:SetPoint("TOPLEFT", x + (column - 1) * 170, -(row - 1) * 30)
        return b
    end
    button(L("+ Индикатор баффа", "+ Buff indicator"), function()
        local entries = list()
        entries[#entries + 1] = { enabled = true, name = L("Новый", "New"), spell = "", kind = "aura", mine = true,
            harmful = false, point = "TOPLEFT", style = "square", size = 8, color = { 0.3, 1, 0.3 }, timer = true,
            stacks = false, x = 0, y = 0 }
        state.index = #entries
        changed()
    end, 1, 1)
    button(L("+ Нет баффа класса", "+ Missing class buff"), function()
        local entries = list()
        entries[#entries + 1] = { enabled = true, name = L("Нет баффа", "Missing buff"), spell = "", kind = "missing",
            mine = false, harmful = false, point = "BOTTOM", style = "square", size = 6, color = { 1, 1, 1 },
            timer = false, stacks = false, x = 0, y = 0 }
        state.index = #entries
        changed()
    end, 1, 2)
    local up = button(L("Выше", "Up"), function()
        local entries, i = list(), state.index
        if i and entries[i - 1] then
            entries[i], entries[i - 1] = entries[i - 1], entries[i]
            state.index = i - 1
        end
        changed()
    end, 2, 1)
    local down = button(L("Ниже", "Down"), function()
        local entries, i = list(), state.index
        if i and entries[i + 1] then
            entries[i], entries[i + 1] = entries[i + 1], entries[i]
            state.index = i + 1
        end
        changed()
    end, 2, 2)
    local remove = button(L("Удалить", "Remove"), function()
        if state.index then
            table.remove(list(), state.index)
            state.index = nil
        end
        changed()
    end, 3, 1)
    remove.text:SetTextColor(W.rgba(S.danger))
    local presetHint
    local function addPresets(presets)
        local added = rf.AddPresets(list(), presets)
        presetHint:SetText(added > 0 and string.format(L("Добавлено: %d", "Added: %d"), added)
            or L("Всё уже в списке", "Everything is in the list already"))
        changed()
    end
    button(L("+ Базовые для хила", "+ Healer basics"), function() addPresets(rf.healerIndicators) end, 3, 2)
    button(L("+ Набор класса", "+ Class set"), function()
        local _, class = UnitClass("player")
        addPresets(rf.classIndicators[class])
    end, 4, 1)
    presetHint = W.Text(parent, W.fonts.small)
    presetHint:SetPoint("LEFT", parent, "TOPLEFT", x + 176, -90 - 12)
    local hint = W.Description(parent, L("Индикаторы в углах (как в Cell): свои HoT и щиты, чужие баффы или отсутствующий "
        .. "бафф класса. Заклинания — ID или названия через запятую. Порядок списка — это слои: индикатор выше в списке рисуется поверх тех, что ниже («Выше»/«Ниже»). «Базовые для хила» — то, что нужно видеть любому "
        .. "лекарю: большой защитный кулдаун или внешнее спасение (иконка справа) и снижение исцеления — Смертельный "
        .. "удар, Нейтрализующий яд, Прицельный выстрел (красная метка слева).", "Corner indicators (Cell style): own "
        .. "HoTs and shields, any buff, or a missing class buff. Spells are ids or names separated by commas. The list "
        .. "order is the layer order: an indicator higher in the list is drawn over the ones below (Up/Down). “Healer "
        .. "basics” is what every healer needs: a big defensive or an external save (icon on the right) and healing "
        .. "reduction — Mortal Strike, Wound Poison, Aimed Shot (red mark on the left)."), width - x)
    hint:SetPoint("TOPLEFT", x, -128)

    local top = math.max(8 * 22 + 16, 128 + math.ceil(hint:GetHeight() or 0) + 12)
    local grid = su.Grid(parent, 0, -top, width, 2)
    grid:Add({ "toggle", L("Включён", "Enabled") }, a("enabled", true), false, has)
    grid:Add({ "text", L("Подпись", "Label") }, a("name", ""), false, has)
    grid:Add({ "text", L("Заклинания (ID или названия)", "Spells (ids or names)") }, a("spell", ""), false, has)
    grid:Add({ "select", L("Показывать", "Show"), values = {
        { "aura", L("Когда бафф есть", "When the aura is up") }, { "missing", L("Когда баффа нет", "When the aura is missing") } } },
        a("kind", "aura"), false, has)
    grid:Add({ "toggle", L("Только мои", "Mine only") }, a("mine", true), false, has)
    grid:Add({ "toggle", L("Это дебафф", "It is a debuff") }, a("harmful", false), false, has)
    grid:Add({ "select", L("Позиция", "Position"), values = anchors }, a("point", "TOPLEFT"), false, has)
    grid:Add({ "select", L("Вид", "Style"), values = {
        { "square", L("Цветной квадрат", "Coloured square") }, { "icon", L("Иконка заклинания", "Spell icon") },
        { "text", L("Таймер текстом", "Timer text") } } }, a("style", "square"), false, has)
    grid:Add({ "range", L("Размер", "Size"), min = 4, max = 30, step = 1 }, a("size", 8), false, has)
    grid:Add({ "color", L("Цвет", "Colour"), alpha = true }, a("color", { 1, 1, 1, 1 }), false, has)
    grid:Add({ "toggle", L("Спираль длительности", "Duration spiral") }, a("timer", true), false, has)
    grid:Add({ "toggle", L("Число стаков", "Stack count") }, a("stacks", false), false, has)
    grid:Add({ "range", L("Смещение X", "Offset X"), min = -30, max = 30, step = 1 }, a("x", 0), false, has)
    grid:Add({ "range", L("Смещение Y", "Offset Y"), min = -30, max = 30, step = 1 }, a("y", 0), false, has)

    local function render(row, entry)
        local name, icon = ui.Suite.SpellInfo(ui.Suite.ParseSpellList(entry.spell)[1])
        row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.text:SetText((entry.enabled and "" or "|cff888888") .. (entry.name ~= "" and entry.name or name or "?"))
        row.sub:SetText(entry.kind == "missing" and L("нет", "missing") or (entry.point or ""):lower())
    end
    refresh = function()
        local entries = list()
        if state.index and not entries[state.index] then state.index = nil end
        indicatorList:SetItems(entries, render)
        indicatorList:Select(state.index)
        grid:Refresh()
        for _, b in ipairs({ up, down, remove }) do
            if state.index then b:Enable() else b:Disable() end
        end
    end
    parent.refreshIndicators = refresh
    ui.RegisterCallback("SuiteProfileChanged", function()
        state.index = nil
        refresh()
    end, "RaidIndicatorOptions")
    refresh()
    return top + grid:Height()
end

-- Spell list editor: tracked buffs (rfBuffTrack, the only buffs drawn as icons) or hidden debuffs
-- (rfDebuffHide). The list stays a comma separated string in the profile, so import and export keep working.
local function exclusionEditor(key, hintText)
    return function(parent, width)
        local rf, su = RF(), ui.SuiteUI
        if not rf or not su or not ui.Suite then return su and su.Unavailable(parent, width) or 20 end
        local Suite = ui.Suite
        local state = { index = nil }
        local refresh
        local function settings() return rf.Settings() end
        local function entries() return Suite.ParseSpellList(settings()[key] or "") end
        local function store(list)
            local parts = {}
            for i, spell in ipairs(list) do parts[i] = tostring(spell) end
            settings()[key] = table.concat(parts, ", ")
            apply()
            refresh()
        end
        local function contains(list, spell)
            local name = Suite.SpellInfo(spell)
            for i, existing in ipairs(list) do
                if existing == spell or (name and Suite.SpellInfo(existing) == name) then return i end
            end
        end

        local listWidth = math.min(300, math.floor(width * 0.5))
        local list = su.List(parent, listWidth, 7, 22, function(index)
            state.index = index
            refresh()
        end)
        list:SetPoint("TOPLEFT", 0, 0)
        local x = listWidth + 16
        local buttonWidth = math.max(120, math.min(200, width - x))

        local input = CreateFrame("EditBox", nil, parent)
        input:SetHeight(22)
        input:SetWidth(buttonWidth)
        input:SetPoint("TOPLEFT", x, 0)
        W.Skin(input, { 0, 0, 0, 0.35 }, S.border)
        input:SetFontObject(W.fonts.label)
        input:SetAutoFocus(false)
        input:SetTextInsets(8, 8, 0, 0)
        local function add()
            local current = entries()
            local added
            for _, spell in ipairs(Suite.ParseSpellList(input:GetText() or "")) do
                local index = contains(current, spell)
                if not index then
                    current[#current + 1] = spell
                    index = #current
                end
                added = index
            end
            input:SetText("")
            input:ClearFocus()
            state.index = added or state.index
            store(current)
        end
        input:SetScript("OnEnterPressed", add)
        input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        parent["input" .. key] = input

        local function button(text, fn, row)
            local b = W.Button(parent, text, buttonWidth, fn, 22)
            b:SetPoint("TOPLEFT", x, -row * 28)
            return b
        end
        button(L("Добавить (ID или название)", "Add (id or name)"), add, 1)
        local remove = button(L("Удалить выбранное", "Remove selected"), function()
            local current = entries()
            if state.index and current[state.index] then
                table.remove(current, state.index)
                if not current[state.index] then state.index = nil end
                store(current)
            end
        end, 2)
        remove.text:SetTextColor(W.rgba(S.danger))
        button(L("Добавить рекомендуемые", "Add recommended"), function()
            local current = entries()
            for _, spell in ipairs(Suite.ParseSpellList(rf.defaultExclusionText[key] or "")) do
                if not contains(current, spell) then current[#current + 1] = spell end
            end
            store(current)
        end, 3)
        button(L("Очистить список", "Clear the list"), function()
            su.Confirm(L("Очистить список?", "Clear the list?"), function()
                state.index = nil
                store({})
            end)
        end, 4)
        local hint = W.Description(parent, hintText, buttonWidth)
        hint:SetPoint("TOPLEFT", x, -5 * 28)

        local function render(row, spell)
            local name, icon = Suite.SpellInfo(spell)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.text:SetText(name or tostring(spell))
            row.sub:SetText(type(spell) == "number" and tostring(spell) or "")
        end
        refresh = function()
            local current = entries()
            if state.index and not current[state.index] then state.index = nil end
            list:SetItems(current, render)
            list:Select(state.index)
            if state.index then remove:Enable() else remove:Disable() end
        end
        parent["refresh" .. key] = refresh
        ui.RegisterCallback("SuiteProfileChanged", function()
            state.index = nil
            refresh()
        end, "RaidExclusions" .. key)
        refresh()
        return 7 * 22 + 8
    end
end

ui.RegisterOptions("raidframes", {
    title = L("Фреймы группы и рейда", "Party and raid frames"),
    description = L("Доработка встроенных фреймов клиента в стиле Cell.", "Cell-style extension of the client frames."),
    icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
    group = "frames",
    order = 3,
    enable = "rfEnabled",
    db = function()
        local suite = ui.Suite
        if suite and suite.ready then return suite.Part("raid") end
    end,
    apply = apply,
    sections = {
        { options = {
            { "toggle", "rfEnabled", L("Включить доработку фреймов", "Enable the frame extension"), default = true },
            { "custom", build = buildPreview, refresh = function(holder)
                for _, preview in ipairs(holder.previews or {}) do preview:Refresh() end
            end },
        } },
        { title = L("Видимость", "Visibility"),
            description = L("«Всегда» показывает фреймы и вне группы или рейда, «Отключить» скрывает их совсем. "
                .. "Работает и при выключенной доработке; в бою применяется после боя.", "“Always” shows the frames "
                .. "outside a party or raid too, “Off” hides them entirely. Works with the extension disabled as well; "
                .. "in combat it applies after combat."), options = {
            { "select", "rfPartyShow", L("Фреймы группы", "Party frames"), default = "client", ignoreEnable = true,
                protected = true, apply = function() if RF() then RF().ApplyVisibility() end end, values = {
                { "client", L("Как в клиенте", "Client") }, { "always", L("Показывать всегда", "Always show") },
                { "hidden", L("Отключить", "Off") } } },
            { "select", "rfRaidShow", L("Фреймы рейда", "Raid frames"), default = "client", ignoreEnable = true,
                protected = true, apply = function() if RF() then RF().ApplyVisibility() end end, values = {
                { "client", L("Как в клиенте", "Client") }, { "always", L("Показывать всегда", "Always show") },
                { "hidden", L("Отключить", "Off") } } },
        } },
        { title = L("Полосы", "Bars"), options = {
            { "media", "rfHealthTexture", L("Текстура здоровья", "Health texture"), kind = "statusbar", ignoreGlobal = true,
                default = "WoW Forever Raid" },
            { "media", "rfPowerTexture", L("Текстура ресурса", "Power texture"), kind = "statusbar", ignoreGlobal = true,
                default = "WoW Forever Raid" },
            { "select", "rfHealthColorMode", L("Цвет здоровья", "Health colour"), default = "client", values = {
                { "client", L("Как в клиенте", "Client") }, { "class", L("Цвет класса", "Class colour") },
                { "custom", L("Свой цвет", "Custom") }, { "gradient", L("Градиент по здоровью", "Health gradient") } } },
            { "color", "rfHealthColor", L("Свой цвет здоровья", "Custom health colour"), default = { 0.22, 0.78, 0.32 },
                depends = function(get) return get("rfHealthColorMode") == "custom" end },
            { "color", "rfBackgroundColor", L("Фон фрейма", "Frame background"), alpha = true, default = { 0.07, 0.07, 0.08, 0.9 } },
            { "toggle", "rfBackgroundForever", L("Фон WoW Forever", "WoW Forever background"), default = true },
            { "select", "rfDeficitText", L("Текст здоровья", "Health text"), default = "none", values = {
                { "none", L("Нет", "None") }, { "deficit", L("Дефицит (-12.3k)", "Deficit (-12.3k)") },
                { "percent", L("Проценты", "Percent") }, { "current", L("Текущее", "Current") } } },
            { "range", "rfTextSize", L("Размер текста", "Text size"), min = 7, max = 18, step = 1, default = 10 },
            { "toggle", "rfHealPrediction", L("Входящее исцеление", "Incoming heals"), default = true,
                tooltip = L("Источник: API клиента или LibHealComm-4.0 (если её загрузил другой аддон).",
                    "Source: the client API or LibHealComm-4.0 when another addon loads it.") },
            { "color", "rfHealColor", L("Цвет входящего исцеления", "Incoming heal colour"), alpha = true,
                default = { 0.25, 0.95, 0.45, 0.55 }, depends = "rfHealPrediction" },
            { "toggle", "rfThreat", L("Рамка угрозы", "Threat border"), default = true },
            { "range", "rfBorderSize", L("Толщина рамки угрозы", "Threat border size"), min = 1, max = 4, step = 1, default = 2,
                depends = "rfThreat" },
            { "select", "rfRangeMode", L("Вне радиуса", "Out of range"), default = "custom", values = {
                { "client", L("Как в клиенте", "Client") }, { "custom", L("Своя прозрачность", "Own opacity") } } },
            { "range", "rfRangeAlpha", L("Прозрачность вне радиуса", "Out of range opacity"), min = 0.1, max = 1, step = 0.05,
                default = 0.4, depends = function(get) return get("rfRangeMode") == "custom" end },
            { "toggle", "rfRangeFade", L("Плавное затухание", "Smooth fade"), default = true,
                depends = function(get) return get("rfRangeMode") == "custom" end },
        } },
        { title = L("Баффы", "Buffs"), options = {
            { "toggle", "rfBuffs", L("Показывать баффы", "Show buffs"), default = true },
            { "select", "rfBuffFilter", L("Чьи баффы", "Whose buffs"), default = "all", depends = "rfBuffs",
                tooltip = L("Из списка «Отслеживаемые баффы». Индикаторы видят все баффы независимо от этого.",
                    "Among the tracked buffs. Indicators see every buff regardless."), values = {
                { "all", L("Любого игрока", "Anyone's") }, { "mine", L("Только мои", "Mine only") },
                { "raid", L("Которые я могу наложить", "Castable by me") } } },
            { "range", "rfBuffSize", L("Размер", "Size"), min = 6, max = 32, step = 1, default = 13, depends = "rfBuffs" },
            { "range", "rfBuffMax", L("Максимум", "Maximum"), min = 0, max = 10, step = 1, default = 3, depends = "rfBuffs" },
            { "select", "rfBuffAnchor", L("Позиция", "Position"), values = anchors, default = "BOTTOMRIGHT", depends = "rfBuffs" },
            { "select", "rfBuffGrow", L("Рост", "Growth"), values = grows, default = "LEFT", depends = "rfBuffs" },
            { "range", "rfBuffSpacing", L("Отступ", "Spacing"), min = 0, max = 10, step = 1, default = 1, depends = "rfBuffs" },
            { "range", "rfBuffX", L("Смещение X", "Offset X"), min = -40, max = 40, step = 1, default = -2, depends = "rfBuffs" },
            { "range", "rfBuffY", L("Смещение Y", "Offset Y"), min = -40, max = 40, step = 1, default = 2, depends = "rfBuffs" },
            { "toggle", "rfAuraTimer", L("Цифры таймера на иконках", "Timer numbers on icons"), default = false },
            { "toggle", "rfHideClientAuras", L("Скрыть ауры клиента", "Hide the client auras"), default = true,
                tooltip = L("Штатные иконки клиента перехватывают клики; их заменяют свои.",
                    "The client icons catch clicks; ForeverUI draws its own instead.") },
        } },
        { title = L("Дебаффы и рассеивание", "Debuffs and dispel"), options = {
            { "toggle", "rfDebuffs", L("Показывать дебаффы", "Show debuffs"), default = true },
            { "select", "rfDebuffFilter", L("Какие дебаффы", "Which debuffs"), default = "all", depends = "rfDebuffs", values = {
                { "all", L("Все", "All") }, { "typed", L("С типом (магия, яд…)", "Typed (magic, poison…)") },
                { "dispellable", L("Только те, что я рассеиваю", "Only what I can dispel") } } },
            { "range", "rfDebuffSize", L("Размер", "Size"), min = 6, max = 36, step = 1, default = 15, depends = "rfDebuffs" },
            { "range", "rfDebuffMax", L("Максимум", "Maximum"), min = 0, max = 10, step = 1, default = 3, depends = "rfDebuffs" },
            { "select", "rfDebuffAnchor", L("Позиция", "Position"), values = anchors, default = "BOTTOMLEFT", depends = "rfDebuffs" },
            { "select", "rfDebuffGrow", L("Рост", "Growth"), values = grows, default = "RIGHT", depends = "rfDebuffs" },
            { "range", "rfDebuffSpacing", L("Отступ", "Spacing"), min = 0, max = 10, step = 1, default = 1, depends = "rfDebuffs" },
            { "range", "rfDebuffX", L("Смещение X", "Offset X"), min = -40, max = 40, step = 1, default = 2, depends = "rfDebuffs" },
            { "range", "rfDebuffY", L("Смещение Y", "Offset Y"), min = -40, max = 40, step = 1, default = 2, depends = "rfDebuffs" },
            { "range", "rfDispelScale", L("Увеличение рассеиваемых", "Dispellable scale"), min = 1, max = 2, step = 0.05,
                default = 1.25, depends = "rfDebuffs" },
            { "toggle", "rfDispelHighlight", L("Подсветка по типу дебаффа", "Highlight by debuff type"), default = true },
            { "toggle", "rfDispelOnlyMine", L("Только то, что я могу рассеять", "Only what I can dispel"), default = true,
                depends = "rfDispelHighlight", tooltip = L("Учитываются класс, изученные заклинания, таланты и охотник Скверны.",
                    "Class, learned spells, talents and the felhunter are taken into account.") },
            { "select", "rfDispelStyle", L("Вид подсветки", "Highlight style"), default = "both", depends = "rfDispelHighlight",
                values = { { "border", L("Рамка WoW Forever", "WoW Forever outline") }, { "overlay", L("Градиент", "Gradient") },
                    { "both", L("Рамка и градиент", "Outline and gradient") } } },
            { "range", "rfDispelAlpha", L("Яркость градиента", "Gradient strength"), min = 0.1, max = 1, step = 0.05,
                default = 0.45, depends = "rfDispelHighlight" },
            { "toggle", "rfDispelIcon", L("Значок типа (магия, яд…)", "Type icon (magic, poison…)"), default = true,
                depends = "rfDispelHighlight" },
            { "range", "rfDispelIconSize", L("Размер значка", "Icon size"), min = 8, max = 28, step = 1, default = 13,
                depends = "rfDispelIcon" },
            { "select", "rfDispelIconAnchor", L("Позиция значка", "Icon position"), values = anchors, default = "TOPRIGHT",
                depends = "rfDispelIcon" },
        } },
        { title = L("Отслеживаемые баффы", "Tracked buffs"),
            description = L("Иконками баффов показываются только баффы из этого списка; пустой список — иконок баффов нет. "
                .. "Рекомендуемые: большие защитные кулдауны и внешние спасения (Подавление боли, Оберегающий дух, "
                .. "Длани, Стена щитов, Незыблемость льда…), Придание сил, Озарение, Гимн надежды, Мастер аур, Защита от страха.",
                "Only buffs from this list are drawn as buff icons; an empty list draws none. Recommended: big defensive "
                .. "cooldowns and external saves (Pain Suppression, Guardian Spirit, Hands, Shield Wall, Icebound "
                .. "Fortitude…), Power Infusion, Innervate, Hymn of Hope, Aura Mastery, Fear Ward."), options = {
            { "custom", build = exclusionEditor("rfBuffTrack", L("Остальные баффы иконкой не рисуются. Индикаторы видят все баффы.",
                "Other buffs get no icon. Indicators still see every buff.")), refresh = function(holder)
                if holder.refreshrfBuffTrack then holder.refreshrfBuffTrack() end
            end },
        } },
        { title = L("Исключения дебаффов", "Debuff exclusions"),
            description = L("Эти дебаффы не показываются на фреймах. Рекомендуемые (список Cell, дополненный): "
                .. "Призрак, Истощение, Пресыщение, Слабость после воскрешения, Дезертир, Недавняя перевязка, "
                .. "Гипотермия, Ревностный защитник, Холод Трона и другие.",
                "These debuffs are never shown on the frames. Recommended (Cell's list, extended): Ghost, Exhaustion, "
                .. "Sated, Resurrection Sickness, Deserter, Recently Bandaged, Hypothermia, Ardent Defender, Chill of "
                .. "the Throne and more."), options = {
            { "custom", build = exclusionEditor("rfDebuffHide", L("Скрытые дебаффы не рисуются иконкой и не дают подсветку "
                .. "рассеивания. Индикаторы их видят.", "Hidden debuffs get no icon and no dispel highlight. Indicators still see them.")),
                refresh = function(holder)
                if holder.refreshrfDebuffHide then holder.refreshrfDebuffHide() end
            end },
        } },
        { title = L("Линия щита (поглощение)", "Shield line (absorb)"),
            description = L("Свечение (glow) у щита клиента убрано полностью. Своя линия рисуется по данным API клиента "
                .. "или по ширине его штатной полосы.", "The client shield glow is removed entirely. The line is drawn "
                .. "from the client API or from the width of its own bar."), options = {
            { "toggle", "rfShield", L("Показывать линию щита", "Show the shield line"), default = true },
            { "toggle", "rfHideAbsorbGlow", L("Убрать свечение щита", "Remove the shield glow"), default = true },
            { "media", "rfShieldTexture", L("Текстура", "Texture"), kind = "statusbar", ignoreGlobal = true,
                default = "WoW Forever Raid", depends = "rfShield" },
            { "color", "rfShieldColor", L("Цвет", "Colour"), alpha = true, default = { 0.85, 0.95, 1, 1 }, depends = "rfShield" },
            { "range", "rfShieldAlpha", L("Прозрачность", "Opacity"), min = 0.05, max = 1, step = 0.05, default = 0.7,
                depends = "rfShield" },
            { "range", "rfShieldHeight", L("Толщина, px (0 — во всю высоту)", "Thickness, px (0 = full height)"),
                min = 0, max = 40, step = 1, default = 0, depends = "rfShield" },
            { "select", "rfShieldMode", L("Привязка к здоровью", "Attach to health"), default = "attached", depends = "rfShield",
                values = { { "attached", L("После здоровья (обрезать)", "After health (clipped)") },
                    { "overlay", L("После здоровья, сверх — поверх", "After health, overflow on top") },
                    { "reverse", L("От правого края", "From the right edge") },
                    { "line", L("От левого края", "From the left edge") } } },
            { "select", "rfShieldAlign", L("Вертикально", "Vertical position"), default = "BOTTOM", depends = "rfShield",
                values = { { "BOTTOM", L("Снизу", "Bottom") }, { "CENTER", L("По центру", "Centre") }, { "TOP", L("Сверху", "Top") } } },
        } },
        { title = L("Иконки ролей и сортировка", "Role icons and sorting"), options = {
            { "toggle", "rfRoleIcon", L("Показывать иконку роли", "Show the role icon"), default = true },
            { "select", "rfRoleSet", L("Набор иконок", "Icon set"), default = "blizzard2", depends = "rfRoleIcon",
                values = function()
                    local values = {}
                    for _, set in ipairs(RF() and RF().roleSets or {}) do values[#values + 1] = { set[1], set[2] } end
                    if #values == 0 then values[1] = { "blizzard2", "Blizzard" } end
                    return values
                end },
            { "range", "rfRoleSize", L("Размер", "Size"), min = 6, max = 32, step = 1, default = 12, depends = "rfRoleIcon" },
            { "select", "rfRoleAnchor", L("Позиция", "Position"), values = anchors, default = "TOPLEFT", depends = "rfRoleIcon" },
            { "range", "rfRoleX", L("Смещение X", "Offset X"), min = -40, max = 40, step = 1, default = 2, depends = "rfRoleIcon" },
            { "range", "rfRoleY", L("Смещение Y", "Offset Y"), min = -40, max = 40, step = 1, default = -2, depends = "rfRoleIcon" },
            { "toggle", "rfRoleHideDamager", L("Не показывать иконку ДД", "Hide the damage dealer icon"), default = false,
                depends = "rfRoleIcon" },
            { "toggle", "rfRoleHideClient", L("Скрыть иконку роли клиента", "Hide the client's role icon"), default = true,
                depends = "rfRoleIcon" },
            { "toggle", "rfRoleSort", L("Сортировать ряд по ролям", "Sort the row by role"), default = false, protected = true,
                tooltip = L("Работает, когда фреймы идут одним списком (без «держать группы вместе»). Применяется вне боя.",
                    "Works when the frames form one list (not “keep groups together”). Applies out of combat.") },
            { "select", "rfRoleOrder", L("Порядок ролей", "Role order"), default = "THD", depends = "rfRoleSort", protected = true,
                values = { { "THD", L("Танки, хилы, ДД", "Tanks, healers, damage") },
                    { "HTD", L("Хилы, танки, ДД", "Healers, tanks, damage") },
                    { "TDH", L("Танки, ДД, хилы", "Tanks, damage, healers") } } },
        } },
        { title = L("Положение", "Position"), options = {
            { "toggle", "rfMoveContainer", L("Двигать контейнер якорем Edit Mode", "Move the container with the Edit Mode anchor"),
                default = true, width = "full", protected = true, apply = function() if RF() then RF().ApplyLayout() end end,
                tooltip = L("Сброс позиции якоря в режиме редактирования возвращает управление клиенту.",
                    "Resetting the anchor in Edit Mode hands the position back to the client.") },
        } },
        { title = L("Индикаторы (HoT, щиты, баффы класса)", "Indicators (HoTs, shields, class buffs)"), options = {
            { "toggle", "rfIndicators", L("Показывать индикаторы", "Show indicators"), default = true },
            { "toggle", "rfIndicatorTimer", L("Спираль длительности", "Duration spiral"), default = true, depends = "rfIndicators" },
            { "custom", build = buildIndicators, refresh = function(holder)
                if holder.refreshIndicators then holder.refreshIndicators() end
            end },
        } },
    },
})

ui.RegisterCallback("SuiteReady", function() ui.NormalizeModule("raidframes") end, "RaidFramesOptionsReady")
