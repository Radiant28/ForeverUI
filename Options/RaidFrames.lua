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
    local captions = {
        tank = L("Щит без свечения, рамка угрозы", "Glow-free shield, threat border"),
        healer = L("Входящее лечение, HoT в углах, яд", "Incoming heals, corner HoTs, a poison"),
        dps = L("Проклятие, которое вы рассеиваете", "A curse you can dispel"),
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
    local hint = W.Description(side, L("Настройки сразу применяются и к настоящим фреймам. /fuiraid — диагностика.",
        "Settings apply to the real frames at once. /fuiraid prints diagnostics."), FRAME_W * SCALE)
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
    local hint = W.Description(parent, L("Индикаторы в углах (как в Cell): свои HoT и щиты, чужие баффы или отсутствующий "
        .. "бафф класса. Заклинания — ID или названия через запятую.", "Corner indicators (Cell style): own HoTs and "
        .. "shields, any buff, or a missing class buff. Spells are ids or names separated by commas."), width - x)
    hint:SetPoint("TOPLEFT", x, -100)

    local grid = su.Grid(parent, 0, -(8 * 22 + 16), width, 2)
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
    return 8 * 22 + 16 + grid:Height()
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
            { "select", "rfBuffFilter", L("Какие баффы", "Which buffs"), default = "mine", depends = "rfBuffs", values = {
                { "mine", L("Только мои", "Mine only") }, { "raid", L("Рейдовые (которые я могу наложить)", "Raid (castable by me)") },
                { "all", L("Все", "All") } } },
            { "range", "rfBuffSize", L("Размер", "Size"), min = 6, max = 32, step = 1, default = 13, depends = "rfBuffs" },
            { "range", "rfBuffMax", L("Максимум", "Maximum"), min = 0, max = 10, step = 1, default = 3, depends = "rfBuffs" },
            { "select", "rfBuffAnchor", L("Позиция", "Position"), values = anchors, default = "BOTTOMRIGHT", depends = "rfBuffs" },
            { "select", "rfBuffGrow", L("Рост", "Growth"), values = grows, default = "LEFT", depends = "rfBuffs" },
            { "range", "rfBuffSpacing", L("Отступ", "Spacing"), min = 0, max = 10, step = 1, default = 1, depends = "rfBuffs" },
            { "range", "rfBuffX", L("Смещение X", "Offset X"), min = -40, max = 40, step = 1, default = -2, depends = "rfBuffs" },
            { "range", "rfBuffY", L("Смещение Y", "Offset Y"), min = -40, max = 40, step = 1, default = 2, depends = "rfBuffs" },
            { "text", "rfBuffHide", L("Не показывать баффы (ID или названия через запятую)", "Hide buffs (ids or names, comma separated)"),
                default = "63944", width = "full", depends = "rfBuffs",
                tooltip = L("По умолчанию скрыта «Возрождённая надежда» (63944): «Слово силы: Щит» с этим талантом вешает её на всю группу, и она выглядит как щит на всех фреймах. Сам щит показывается индикатором.",
                    "Renewed Hope (63944) is hidden by default: Power Word: Shield with that talent puts it on the whole party, where it looks like the shield on every frame. The shield itself has its own indicator.") },
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
