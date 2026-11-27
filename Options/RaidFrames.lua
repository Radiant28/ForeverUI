-- Options page of the party/raid frame extension, Cell style: a list of the frame's parts on the left
-- (spec.layout = "list"), the settings of the chosen part on the right and, beside the window, a
-- preview that draws only what that part changes (everything on "Overview"). Values live in the "raid"
-- part of the active suite profile (spec.db), so switching profiles switches the whole page; the client
-- frames update live too.
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

-- What the page shares between its blocks: the indicator chosen in the list (the preview flashes it and
-- lets it be dragged) and the preview panel.
local shared = { indicator = nil }

---------------------------------------------------------------------------------------------------
-- Focused preview: which sample members each list item shows and which parts of them it draws.
-- mask = nil draws everything. Each frame: { variant, override, caption }.
---------------------------------------------------------------------------------------------------
local everything = {
    frames = { { "tank", nil, L("Почти полное здоровье", "Nearly full health") },
        { "healer", nil, L("Пьёт", "Drinking") },
        { "dps", nil, L("Мало здоровья, под курсором", "Low health, hovered") } },
    hint = L("Показано всё сразу: ваши индикаторы, отслеживаемые баффы и дебаффы. Выберите пункт слева, и здесь "
        .. "останется только то, что он меняет.", "Everything at once: your indicators, tracked buffs and debuffs. "
        .. "Pick an item on the left and only what it changes stays here."),
}

local focus = {
    bars = { mask = {}, frames = {
        { "tank", { health = 0.92 }, L("Почти полное здоровье", "Nearly full health") },
        { "healer", { health = 0.55 }, L("Половина здоровья", "Half health") },
        { "dps", { health = 0.16 }, L("Мало здоровья", "Low health") } } },
    power = { mask = {}, frames = {
        { "healer", nil, L("Мана", "Mana") }, { "tank", nil, L("Ярость", "Rage") },
        { "dps", { power = "ENERGY", class = "ROGUE", name = L("Разбойник", "Rogue") }, L("Энергия", "Energy") } } },
    hover = { mask = { hover = true }, frames = {
        { "dps", { hover = true }, L("Под курсором", "Under the cursor") } } },
    drink = { mask = { drink = true }, frames = {
        { "healer", { drink = true }, L("Пьёт (42% маны)", "Drinking (42% mana)") } } },
    buffs = { mask = { buffs = true }, frames = { { "healer", nil, L("Отслеживаемые баффы", "Tracked buffs") } } },
    tracked = { mask = { buffs = true }, frames = { { "healer", nil, L("Первые баффы из списка", "The first listed buffs") } } },
    debuffs = { mask = { debuffs = true }, frames = { { "healer", nil, L("Проклятие (вы его рассеиваете), яд и "
        .. "кровотечение", "A curse (you dispel it), a poison and a bleed") } } },
    indicators = { mask = { indicators = true }, drag = true, frames = {
        { "healer", nil, L("Наложены вами", "Cast by you") },
        { "tank", { others = true }, L("Наложены другими", "Cast by others") } },
        hint = L("Перетащите выбранный индикатор мышью по верхнему фрейму: угол и смещение подберутся сами. "
            .. "Нижний фрейм — те же ауры от других игроков.", "Drag the chosen indicator on the top frame: the "
            .. "corner and offset follow. The bottom frame shows the same auras cast by other players.") },
}

-- Which part a setting belongs to, by key prefix.
local keyParts = {
    { "rfHealth", "health" }, { "rfPower", "power" }, { "rfBackground", "frame" },
    { "rfHover", "hover" }, { "rfDrink", "drink" },
    { "rfBuff", "buffs" }, { "rfAuraTimer", "buffs" }, { "rfDispelScale", "debuffs" }, { "rfDebuff", "debuffs" },
    { "rfIndicator", "indicators" },
}
local function partOf(opt, section)
    local key = opt and opt.key
    if key then
        for _, pair in ipairs(keyParts) do
            if key:sub(1, #pair[1]) == pair[1] then return pair[2] end
        end
        return nil
    end
    -- Rows of the indicator editor have no key: they edit the chosen indicator.
    if opt and section and section.id == "indicators" then return "indicators", shared.indicator end
end

---------------------------------------------------------------------------------------------------
-- Preview panel beside the options window
---------------------------------------------------------------------------------------------------
local SCALE, FRAME_W, FRAME_H, MAX_FRAMES = 1.7, 120, 48, 4
local states = {
    { "normal", L("Обычное", "Normal") }, { "dead", L("Мёртв", "Dead") }, { "combat", L("В бою (не пьёт)", "In combat (no drinking)") },
}

local function buildPreviewPanel(page, spec)
    local rf = RF()
    if not rf or not ui.Suite then return nil end
    local host = ForeverUIOptions or page
    local panelWidth = FRAME_W * SCALE + 36
    local side = CreateFrame("Frame", nil, host)
    side:SetWidth(panelWidth)
    side:SetPoint("TOPLEFT", host, "TOPRIGHT", 6, 0)
    side:SetFrameStrata(host:GetFrameStrata() or "DIALOG")
    side:SetClampedToScreen(true)
    side:EnableMouse(true)
    W.Skin(side, S.window, S.border)
    local obj = { side = side, frames = {}, captions = {}, state = "normal" }

    local title = W.Text(side, W.fonts.heading)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(L("Предпросмотр", "Preview"))
    local shown = W.Text(side, W.fonts.small)
    shown:SetPoint("TOPLEFT", 16, -34)
    shown:SetWidth(panelWidth - 32)
    shown:SetJustifyH("LEFT")
    obj.shownText = shown

    local stateRow = W.Select(side, { type = "select", label = L("Состояние участника", "Member state"), values = states },
        { get = function() return obj.state end, set = function(value)
            obj.state = value
            obj.Refresh()
        end }, panelWidth - 32)
    stateRow:SetPoint("TOPLEFT", 16, -68)
    obj.stateRow = stateRow

    -- Hold to see the defaults of the chosen item (the whole page on Overview); release to come back.
    local compare = W.Button(side, L("Удерживайте: по умолчанию", "Hold: defaults"), panelWidth - 32, nil, 22)
    compare:SetPoint("TOPLEFT", 16, -122)
    compare:HookScript("OnMouseDown", function() obj.ShowDefaults(true) end)
    compare:HookScript("OnMouseUp", function() obj.ShowDefaults(false) end)
    compare:HookScript("OnHide", function() if obj.defaults then obj.ShowDefaults(false) end end)
    compare:HookScript("OnEnter", function(self)
        W.ShowTooltip(self, L("До / после", "Before / after"), L("Пока кнопка зажата, предпросмотр рисует значения по "
            .. "умолчанию выбранного пункта. Настройки не меняются.", "While the button is held, the preview draws the "
            .. "defaults of the chosen item. Nothing is changed."))
    end)
    compare:HookScript("OnLeave", GameTooltip_Hide)
    obj.compare = compare
    local TOP = -154

    for i = 1, MAX_FRAMES do
        local frame = rf.BuildPreview(side, FRAME_W, FRAME_H, "healer")
        frame:SetScale(SCALE)
        frame:Hide()
        local caption = W.Text(side, W.fonts.small)
        caption:SetWidth(FRAME_W * SCALE)
        caption:SetJustifyH("LEFT")
        caption:Hide()
        obj.frames[i], obj.captions[i] = frame, caption
    end
    local hint = W.Description(side, "", FRAME_W * SCALE)
    obj.hint = hint

    -- The options this item edits (all of the page on Overview).
    local function optionsOf(section)
        if section and not section.overview then return section.options or {} end
        return spec.options
    end

    function obj.Layout()
        local plan = obj.plan or everything
        local y = TOP
        for i, frame in ipairs(obj.frames) do
            local entry = plan.frames[i]
            local caption = obj.captions[i]
            if entry then
                frame:SetData(entry[1], entry[2])
                frame:SetMask(plan.mask)
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", side, "TOPLEFT", 18 / SCALE, y / SCALE)
                frame:Show()
                caption:ClearAllPoints()
                caption:SetPoint("TOPLEFT", side, "TOPLEFT", 18, y - FRAME_H * SCALE - 4)
                caption:SetText(entry[3] or "")
                caption:Show()
                y = y - FRAME_H * SCALE - 30
            else
                frame:Hide()
                caption:Hide()
            end
        end
        hint.label:SetText(plan.hint or (plan == everything and everything.hint) or L("Показано только то, что меняет "
            .. "этот пункт. «Общий вид» показывает всё сразу.", "Only what this item changes is shown. “Overview” "
            .. "shows everything at once."))
        hint:SetHeight(math.max(14, hint.label:GetStringHeight() + 2))
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", side, "TOPLEFT", 18, y + 4)
        side:SetHeight(-y + hint:GetHeight() + 20)
    end

    function obj.Refresh()
        local rfNow = RF()
        if not rfNow then return end
        local section = obj.section
        shown:SetText((obj.defaults and L("По умолчанию: ", "Defaults: ") or L("Показано: ", "Shown: "))
            .. (section and not section.overview and section.title or L("всё", "everything")))
        for _, frame in ipairs(obj.frames) do
            if frame:IsShown() then
                frame:SetState(obj.state ~= "normal" and obj.state or nil)
                frame:Refresh()
            end
        end
        stateRow:Refresh()
    end

    -- Draws the preview with the defaults of the chosen item, then puts the values back at once: nothing
    -- is saved and the real frames keep the user's settings.
    function obj.ShowDefaults(on)
        obj.defaults = on or nil
        if not on then
            obj.Refresh()
            return
        end
        local settings = RF().Settings()
        local saved = {}
        for _, opt in ipairs(optionsOf(obj.section)) do
            if opt.key and opt.default ~= nil and not opt.noReset then
                saved[#saved + 1] = { opt.key, settings[opt.key] }
                settings[opt.key] = ui.ResolveDefault(opt)
            end
        end
        local ok, err = pcall(obj.Refresh)
        for i = #saved, 1, -1 do settings[saved[i][1]] = saved[i][2] end
        if not ok then error(err) end
    end

    function obj.Select(section)
        obj.section = section
        obj.plan = section and focus[section.id] or everything
        obj.Layout()
        obj.Refresh()
        obj.Flash(nil)
        if section and section.id == "indicators" and shared.indicator then obj.Flash("indicators", shared.indicator) end
    end

    function obj.Flash(part, index)
        for _, frame in ipairs(obj.frames) do
            rf.FlashPreview(frame, frame:IsShown() and part or nil, index)
        end
    end

    -- Dragging the chosen indicator on the first frame (Indicators item only).
    local function dropSpot(frame)
        local bar = frame.healthBar
        local cx, cy = GetCursorPosition()
        local s = bar:GetEffectiveScale()
        local left, bottom = bar:GetLeft(), bar:GetBottom()
        if not (left and bottom) then return end
        return cx / s - left, cy / s - bottom, bar:GetWidth(), bar:GetHeight()
    end
    local first = obj.frames[1]
    first:EnableMouse(true)
    first:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not (obj.plan and obj.plan.drag) then return end
        local entry = shared.indicator and rf.Settings().indicators[shared.indicator]
        local widget = entry and self.deco.indicators[shared.indicator]
        if not (entry and widget and widget:IsShown()) then return end
        obj.dragging = { entry = entry, widget = widget }
        self:SetScript("OnUpdate", function(frame)
            local x, y = dropSpot(frame)
            if not x then return end
            widget:ClearAllPoints()
            widget:SetPoint("CENTER", frame.healthBar, "BOTTOMLEFT", x, y)
        end)
    end)
    first:SetScript("OnMouseUp", function(self)
        local drag = obj.dragging
        if not drag then return end
        obj.dragging = nil
        self:SetScript("OnUpdate", nil)
        local x, y, w, h = dropSpot(self)
        if x then
            local point, ox, oy = rf.IndicatorDrop(w, h, x, y, drag.entry.size)
            drag.entry.point, drag.entry.x, drag.entry.y = point, ox, oy
        end
        drag.widget.stamp = nil
        apply()
        if shared.refreshIndicators then shared.refreshIndicators() end
    end)
    first:SetScript("OnEnter", function(self)
        if obj.plan and obj.plan.drag and shared.indicator then
            W.ShowTooltip(self, L("Перетаскивание", "Dragging"), L("Зажмите ЛКМ на выбранном индикаторе и отпустите "
                .. "там, где он должен быть.", "Hold the left button on the chosen indicator and release it where it "
                .. "should be."))
        end
    end)
    first:SetScript("OnLeave", GameTooltip_Hide)

    side:Hide()
    page:HookScript("OnShow", function() side:Show() end)
    page:HookScript("OnHide", function()
        side:Hide()
        if obj.defaults then obj.ShowDefaults(false) end
    end)
    if page:IsVisible() then side:Show() end
    shared.preview = obj
    obj.Select(nil)
    return obj
end

---------------------------------------------------------------------------------------------------
-- Indicators editor
---------------------------------------------------------------------------------------------------
-- Whose auras an indicator shows: only mine, everyone's, or everyone's with the others' faded.
local whoseValues = {
    { "dim", L("Все, чужие приглушены", "Everyone's, others faded") },
    { "all", L("Все одинаково", "Everyone's alike") },
    { "mine", L("Только мои", "Mine only") },
}
local function whoseOf(entry)
    if not entry then return "dim" end
    if entry.mine then return "mine" end
    return entry.dimOthers and "dim" or "all"
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
    local function select(index)
        state.index = index
        shared.indicator = index
        local preview = shared.preview
        if preview and preview.section and preview.section.id == "indicators" then
            preview.Flash(index and "indicators" or nil, index)
        end
    end

    -- Buttons two per row above the list, so the block fits a narrow page.
    local gap = 8
    local buttonWidth = math.floor((math.min(width, 420) - gap) / 2)
    local count = 0
    local function button(text, fn)
        local b = W.Button(parent, text, buttonWidth, fn, 24)
        b:SetPoint("TOPLEFT", (count % 2) * (buttonWidth + gap), -math.floor(count / 2) * 30)
        count = count + 1
        return b
    end
    button(L("+ Индикатор баффа", "+ Buff indicator"), function()
        local entries = list()
        entries[#entries + 1] = { enabled = true, name = L("Новый", "New"), spell = "", kind = "aura", mine = false,
            dimOthers = true, harmful = false, point = "TOPLEFT", style = "square", size = 8, color = { 0.3, 1, 0.3 },
            timer = true, stacks = false, x = 0, y = 0 }
        select(#entries)
        changed()
    end)
    button(L("+ Нет баффа класса", "+ Missing class buff"), function()
        local entries = list()
        entries[#entries + 1] = { enabled = true, name = L("Нет баффа", "Missing buff"), spell = "", kind = "missing",
            mine = false, harmful = false, point = "BOTTOM", style = "square", size = 6, color = { 1, 1, 1 },
            timer = false, stacks = false, x = 0, y = 0 }
        select(#entries)
        changed()
    end)
    local up = button(L("Выше", "Up"), function()
        local entries, i = list(), state.index
        if i and entries[i - 1] then
            entries[i], entries[i - 1] = entries[i - 1], entries[i]
            select(i - 1)
        end
        changed()
    end)
    local down = button(L("Ниже", "Down"), function()
        local entries, i = list(), state.index
        if i and entries[i + 1] then
            entries[i], entries[i + 1] = entries[i + 1], entries[i]
            select(i + 1)
        end
        changed()
    end)
    local presetHint
    local function addPresets(presets)
        local added = rf.AddPresets(list(), presets)
        presetHint:SetText(added > 0 and string.format(L("Добавлено: %d", "Added: %d"), added)
            or L("Всё уже в списке", "Everything is in the list already"))
        changed()
    end
    button(L("+ Базовые для хила", "+ Healer basics"), function() addPresets(rf.healerIndicators) end)
    button(L("+ Набор класса", "+ Class set"), function()
        local _, class = UnitClass("player")
        addPresets(rf.classIndicators[class])
    end)
    -- Old lists were made with "mine only" everywhere: one click shows the others' shields and HoTs too.
    local everyone = button(L("Чужие — всем (приглушённо)", "Others' for all (faded)"), function()
        su.Confirm(L("Показывать во всех индикаторах баффов и чужие ауры (приглушённо)?",
            "Show the others' auras (faded) in every buff indicator?"), function()
            local n = 0
            for _, entry in ipairs(list()) do
                if entry.kind ~= "missing" and (entry.mine or not entry.dimOthers) then
                    entry.mine, entry.dimOthers = false, true
                    n = n + 1
                end
            end
            presetHint:SetText(string.format(L("Изменено: %d", "Changed: %d"), n))
            changed()
        end)
    end)
    everyone:HookScript("OnEnter", function(self)
        W.ShowTooltip(self, L("Чужие ауры", "Others' auras"), L("Например, Слово силы: Щит другого жреца. Свои ауры "
            .. "остаются яркими, чужие рисуются полупрозрачными.", "For example, another priest's Power Word: Shield. "
            .. "Your own auras stay bright, the others' are drawn half transparent."))
    end)
    everyone:HookScript("OnLeave", GameTooltip_Hide)
    local remove = button(L("Удалить", "Remove"), function()
        if state.index then
            table.remove(list(), state.index)
            select(nil)
        end
        changed()
    end)
    remove.text:SetTextColor(W.rgba(S.danger))
    local y = -math.ceil(count / 2) * 30
    presetHint = W.Text(parent, W.fonts.small)
    presetHint:SetPoint("TOPLEFT", 0, y - 2)
    y = y - 20

    local indicatorList = su.List(parent, math.min(width, 420), 8, 22, function(index)
        select(index)
        refresh()
    end)
    indicatorList:SetPoint("TOPLEFT", 0, y)
    y = y - (8 * 22 + 4) - 8
    local hint = W.Description(parent, L("Индикаторы в углах (как в Cell): HoT, щиты, чужие баффы или отсутствующий "
        .. "бафф класса. Заклинания — ID или названия через запятую (можно перетащить из книги заклинаний). Порядок "
        .. "списка — это слои: индикатор выше в списке рисуется поверх («Выше»/«Ниже»). «Базовые для хила» — большой "
        .. "защитный кулдаун или внешнее спасение (иконка справа) и снижение исцеления (красная метка слева).",
        "Corner indicators (Cell style): HoTs, shields, any buff, or a missing class buff. Spells are ids or names "
        .. "separated by commas (drag them from the spellbook). The list order is the layer order: an indicator higher "
        .. "in the list is drawn over the ones below (Up/Down). “Healer basics”: a big defensive or an external save "
        .. "(icon on the right) and healing reduction (red mark on the left)."), width)
    hint:SetPoint("TOPLEFT", 0, y)
    y = y - math.ceil(hint:GetHeight() or 0) - 10

    local grid = su.Grid(parent, 0, y, width, width >= 470 and 2 or 1)
    grid:Add({ "toggle", L("Включён", "Enabled") }, a("enabled", true), false, has)
    grid:Add({ "text", L("Подпись", "Label") }, a("name", ""), false, has)
    grid:Add({ "text", L("Заклинания (ID или названия)", "Spells (ids or names)"), spellDrop = { list = true } }, a("spell", ""), false, has)
    grid:Add({ "select", L("Показывать", "Show"), values = {
        { "aura", L("Когда бафф есть", "When the aura is up") }, { "missing", L("Когда баффа нет", "When the aura is missing") } } },
        a("kind", "aura"), false, has)
    grid:Add({ "select", L("Чьи ауры", "Whose auras"), values = whoseValues, tooltip = L("Свои ауры всегда важнее: если "
        .. "на игроке и ваш, и чужой экземпляр, показывается ваш.", "Your own aura wins: with both yours and somebody "
        .. "else's on a player, yours is shown.") }, {
        get = function() return whoseOf(selected()) end,
        set = function(value)
            local entry = selected()
            if not entry then return end
            entry.mine, entry.dimOthers = value == "mine", value == "dim"
            changed()
        end,
    }, false, function() local entry = selected() return entry ~= nil and entry.kind ~= "missing" end)
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

    local whoseShort = { mine = L("мои", "mine"), all = L("все", "all"), dim = L("все", "all") }
    local function render(row, entry)
        local name, icon = ui.Suite.SpellInfo(ui.Suite.ParseSpellList(entry.spell)[1])
        row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.text:SetText((entry.enabled and "" or "|cff888888") .. (entry.name ~= "" and entry.name or name or "?"))
        row.sub:SetText(entry.kind == "missing" and L("нет", "missing")
            or ((entry.point or ""):lower() .. ", " .. whoseShort[whoseOf(entry)]))
    end
    refresh = function()
        local entries = list()
        if state.index and not entries[state.index] then select(nil) end
        indicatorList:SetItems(entries, render)
        indicatorList:Select(state.index)
        grid:Refresh()
        for _, b in ipairs({ up, down, remove }) do
            if state.index then b:Enable() else b:Disable() end
        end
    end
    parent.refreshIndicators = refresh
    parent.selectIndicator = function(index)
        select(index)
        refresh()
    end
    shared.refreshIndicators = refresh
    ui.RegisterCallback("SuiteProfileChanged", function()
        select(nil)
        refresh()
    end, "RaidIndicatorOptions")
    refresh()
    return -y + grid:Height()
end

-- Spell list editor of the tracked buffs (rfBuffTrack, the only buffs drawn as icons). The list stays a comma
-- separated string in the profile, so import and export keep working.
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
        if ui.SpellID then ui.SpellID.Attach(input, { list = true }) end
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

local function buildOverviewNote(parent, width)
    local note = W.Description(parent, L("Слева — части фрейма. Выберите часть, и предпросмотр справа от окна "
        .. "покажет только то, что она меняет; здесь, на «Общем виде», он показывает всё сразу. Точка у пункта — "
        .. "в нём что-то отличается от значений по умолчанию. Наведите на настройку — её элемент замигает в "
        .. "предпросмотре. ПКМ по якорю рейда в режиме редактирования открывает «Положение». /fuiraid — диагностика.",
        "On the left are the parts of the frame. Pick one and the preview beside the window shows only what it "
        .. "changes; here, on “Overview”, it shows everything. A dot marks an item with something changed from the "
        .. "defaults. Hover a setting and its element flashes in the preview. Right click the raid anchor in Edit "
        .. "Mode to open “Position”. /fuiraid prints diagnostics."), width)
    note:SetPoint("TOPLEFT", 0, 0)
    return note:GetHeight() + 4
end

local G_MAIN, G_BAR, G_TEXT, G_AURA = L("Основное", "General"), L("Полоса", "Bar"), L("Текст и состояния", "Text and states"),
    L("Ауры", "Auras")

ui.RegisterOptions("raidframes", {
    title = L("Фреймы группы и рейда", "Party and raid frames"),
    description = L("Доработка встроенных фреймов клиента в стиле Cell.", "Cell-style extension of the client frames."),
    icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
    group = "frames",
    order = 3,
    enable = "rfEnabled",
    layout = "list",
    preview = {
        build = buildPreviewPanel,
        select = function(obj, section) obj.Select(section) end,
        refresh = function(obj) obj.Refresh() end,
        hover = function(obj, opt, section)
            local part, index = partOf(opt, section)
            -- Leaving a row of the Indicators item goes back to flashing the chosen indicator.
            if not part and section and section.id == "indicators" and shared.indicator then
                part, index = "indicators", shared.indicator
            end
            obj.Flash(part, index)
        end,
    },
    db = function()
        local suite = ui.Suite
        if suite and suite.ready and RF() then return RF().Settings() end
    end,
    apply = apply,
    sections = {
        { id = "overview", overview = true, title = L("Общий вид", "Overview"), group = G_MAIN, options = {
            { "toggle", "rfEnabled", L("Включить доработку фреймов", "Enable the frame extension"), default = true,
                width = "full" },
            { "custom", build = buildOverviewNote },
        } },
        { id = "visibility", title = L("Видимость", "Visibility"), group = G_MAIN,
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
        { id = "position", title = L("Положение и рост", "Position and growth"), group = G_MAIN, options = {
            { "toggle", "rfMoveContainer", L("Двигать контейнер якорем Edit Mode", "Move the container with the Edit Mode anchor"),
                default = true, width = "full", protected = true, apply = function() if RF() then RF().ApplyLayout() end end,
                tooltip = L("Сброс позиции якоря в режиме редактирования возвращает управление клиенту.",
                    "Resetting the anchor in Edit Mode hands the position back to the client.") },
            { "select", "rfGrowth", L("Рост группы", "Group growth"), default = "center", width = "full",
                depends = "rfMoveContainer", values = {
                    { "center", L("От центра в обе стороны", "From the centre to both sides") },
                    { "corner", L("От левого верхнего угла", "From the top-left corner") },
                },
                tooltip = L("Когда игроки приходят и уходят, группа держит середину по ширине: в горизонтальном режиме "
                    .. "влево и вправо расходятся игроки, в вертикальном — группы (колонки), а игроки внутри группы "
                    .. "растут вниз. Верх группы стоит на месте. Работает, когда позиция группы сохранена в режиме "
                    .. "редактирования; в бою — после боя.",
                    "When players join and leave, the group keeps its horizontal middle: horizontally the players "
                    .. "spread left and right, vertically the groups (columns) do, and players inside a group grow "
                    .. "downwards. The top stays. Works once the group position is saved in Edit Mode; in combat, "
                    .. "after combat.") },
            { "select", "rfGroupsPerLine", L("Групп в строке", "Groups per line"), default = 5, width = "full",
                protected = true, apply = function() if RF() then RF().ApplyLines() end end, values = {
                    { 0, L("Как в клиенте", "Client") }, { 1, "1" }, { 2, "2" }, { 3, "3" }, { 4, "4" },
                    { 5, "5" }, { 6, "6" }, { 7, "7" }, { 8, "8" } },
                tooltip = L("Сколько групп рейда стоит рядом, следующие переносятся на новую строку. При колонках "
                    .. "групп строки идут сверху вниз; при рядах групп (горизонтальные группы в профиле рейда "
                    .. "клиента) группы заполняют колонки сверху вниз. Работает, когда в профиле рейда клиента "
                    .. "включено «Держать группы вместе»; на группу из пяти игроков не влияет. Меняется размер "
                    .. "контейнера клиента, раскладку делает сам клиент. В бою — после боя.",
                    "How many raid groups stand side by side; the next ones wrap to a new line. With columns of "
                    .. "groups the lines go top to bottom; with rows of groups (horizontal groups in the client's raid "
                    .. "profile) the groups fill columns top to bottom. Works when “Keep groups together” is on in the "
                    .. "client's raid profile; a party of five is not affected. Only the size of the client's "
                    .. "container changes, the client lays the frames out itself. In combat, after combat.") },
            { "button", L("Показать / скрыть шаблоны на экране", "Show / hide sample frames on screen"), func = function()
                if RF() then RF().ToggleTemplate() end
            end, tooltip = L("Шаблоны встают на место группы с размером и раскладкой из профиля рейда клиента "
                .. "(Интерфейс > Профили рейда). Побывав в группе такого размера, они повторяют её точно.",
                "The samples stand in place of the group with the size and layout of the client's raid profile "
                .. "(Interface > Raid profiles). Once you have been in a group of that size they repeat it exactly.") },
            { "select", "rfTemplateSize", L("Игроков в шаблоне", "Players in the samples"), default = 0,
                tooltip = L("«По типу группы»: 5, 10 или 25. Профиль «Рейд 25» действует и в рейде на 40, выберите 40, "
                    .. "чтобы увидеть, где фреймы перенесутся.", "“By group type”: 5, 10 or 25. The raid 25 profile also "
                    .. "applies in a raid of 40; pick 40 to see where the frames wrap."), values = {
                    { 0, L("По типу группы", "By group type") }, { 5, "5" }, { 10, "10" }, { 15, "15" }, { 20, "20" },
                    { 25, "25" }, { 40, "40" } } },
            { "toggle", "rfHandle", L("Ручка перетаскивания над группой", "Drag handle above the group"),
                default = true, width = "full", depends = "rfMoveContainer",
                tooltip = L("Метка «Группа» появляется при наведении на фреймы; перетащите её, чтобы сдвинуть группу без Edit Mode. В бою отключено.",
                    "The \"Group\" label appears when you hover the frames; drag it to move the group without Edit Mode. Disabled in combat.") },
        } },
        { id = "roleicon", title = L("Значок роли", "Role icon"), group = G_MAIN,
            description = L("Значок роли рисует клиент; аддон роли не определяет и смотрит только на картинку значка "
                .. "клиента. В предпросмотре значка нет: смотрите на настоящие фреймы.", "The client draws the role "
                .. "icon; the addon works out no roles and only looks at the client's icon picture. The preview has no "
                .. "role icon: look at the real frames."), options = {
            { "toggle", "rfHideDamagerIcon", L("Скрывать значок бойца (ДД)", "Hide the damage dealer icon"), default = true,
                width = "full", tooltip = L("Значки танка и лекаря остаются. Если значок бойца не скрывается, пришлите "
                    .. "строку «Role icon» из /fuiraid.", "Tank and healer icons stay. If the damage dealer icon still "
                    .. "shows, send the “Role icon” line of /fuiraid.") },
        } },
        { id = "bars", title = L("Здоровье и ресурс", "Health and power"), group = G_BAR, options = {
            { "media", "rfHealthTexture", L("Текстура здоровья", "Health texture"), kind = "statusbar", ignoreGlobal = true,
                default = "WoW Forever Raid" },
            { "color", "rfBackgroundColor", L("Фон фрейма", "Frame background"), alpha = true, default = { 0.07, 0.07, 0.08, 0.9 } },
            { "toggle", "rfBackgroundForever", L("Фон WoW Forever", "WoW Forever background"), default = true },
        } },
        { id = "power", title = L("Полоса ресурса", "Power bar"), group = G_BAR,
            description = L("Работает, когда полосы ресурсов включены в профиле рейда клиента. Высота и зазор "
                .. "меняются только вне боя.", "Works when power bars are on in the client's raid profile. Height "
                .. "and gap change out of combat only."), options = {
            { "media", "rfPowerTexture", L("Текстура ресурса", "Power texture"), kind = "statusbar", ignoreGlobal = true,
                default = "WoW Forever Raid" },
            { "select", "rfPowerColorMode", L("Цвет ресурса", "Power colour"), default = "light", values = {
                { "light", L("Светлее, чем в клиенте", "Lighter than the client") },
                { "client", L("Как в клиенте", "Client") }, { "custom", L("Свой по типу", "Custom per type") } } },
            { "range", "rfPowerLighten", L("Осветление", "Lighten"), min = 0, max = 60, step = 5, default = 25,
                suffix = "%", depends = function(get) return get("rfPowerColorMode") == "light" end,
                tooltip = L("Насколько цвет клиента смешивается с белым.", "How much of white goes into the client's colour.") },
            { "color", "rfPowerColorMana", L("Мана", "Mana"), default = { 0.25, 0.5, 1 },
                depends = function(get) return get("rfPowerColorMode") == "custom" end },
            { "color", "rfPowerColorRage", L("Ярость", "Rage"), default = { 0.9, 0.22, 0.22 },
                depends = function(get) return get("rfPowerColorMode") == "custom" end },
            { "color", "rfPowerColorEnergy", L("Энергия", "Energy"), default = { 1, 0.88, 0.3 },
                depends = function(get) return get("rfPowerColorMode") == "custom" end },
            { "color", "rfPowerColorRunic", L("Сила рун", "Runic power"), default = { 0.25, 0.8, 1 },
                depends = function(get) return get("rfPowerColorMode") == "custom" end },
            { "range", "rfPowerHeight", L("Высота полосы", "Bar height"), min = 0, max = 16, step = 1, default = 0,
                protected = true, tooltip = L("0 — как в клиенте. Полоса здоровья занимает остальное место.",
                    "0 is the client's height. The health bar takes the rest.") },
            { "range", "rfPowerGap", L("Зазор над полосой", "Gap above the bar"), min = 0, max = 3, step = 1, default = 0,
                protected = true },
            { "toggle", "rfPowerDivider", L("Разделитель над полосой", "Divider above the bar"), default = false,
                tooltip = L("Тонкая линия между здоровьем и ресурсом; при зазоре заполняет его.",
                    "A thin line between health and power; with a gap it fills the gap.") },
            { "color", "rfPowerDividerColor", L("Цвет разделителя", "Divider colour"), alpha = true,
                default = { 0, 0, 0, 0.9 }, depends = "rfPowerDivider" },
            { "toggle", "rfPowerBack", L("Свой фон под ресурсом", "Own background under the power"), default = false },
            { "color", "rfPowerBackColor", L("Цвет фона", "Background colour"), alpha = true,
                default = { 0.03, 0.06, 0.14, 0.85 }, depends = "rfPowerBack" },
        } },
        { id = "hover", title = L("Наведение", "Hover"), group = G_TEXT,
            description = L("Подсветка фрейма под курсором. Текущую цель выделяет клиент.", "Highlight of the "
                .. "frame under the cursor. The client marks your current target."), options = {
            { "toggle", "rfHover", L("Подсветка наведения", "Hover highlight"), default = true },
            { "select", "rfHoverStyle", L("Вид подсветки", "Highlight style"), default = "both", depends = "rfHover",
                values = { { "both", L("Рамка и осветление", "Border and wash") }, { "border", L("Только рамка", "Border only") },
                    { "fill", L("Только осветление", "Wash only") } } },
            { "color", "rfHoverColor", L("Цвет и прозрачность наведения", "Hover colour and opacity"), alpha = true,
                default = { 1, 1, 1, 0.85 }, depends = "rfHover" },
        } },
        { id = "drink", title = L("Питьё", "Drinking"), group = G_TEXT,
            description = L("Надпись «Пьёт - - -» внизу слева, пока игрок пьёт (бафф «Питье» или «Потребление пищи "
                .. "и напитков», включая воду мага). Пропадает сразу, когда бафф спадает или игрок входит в бой.",
                "The label “Drinking - - -” at the bottom left while the player drinks (the “Drink” or “Food & Drink” "
                .. "buff, mage water included). It goes away at once when the buff ends or the player enters combat."),
            options = {
            { "toggle", "rfDrink", L("Индикатор питья", "Drinking indicator"), default = true },
            { "select", "rfDrinkStyle", L("Вид", "Style"), default = "text", depends = "rfDrink", values = {
                { "text", L("«Пьёт - - -»", "“Drinking - - -”") },
                { "mana", L("«Пьёт» и % маны", "“Drinking” and mana %") } } },
            { "toggle", "rfDrinkManaOnly", L("Только у классов с маной", "Mana users only"), default = true,
                depends = "rfDrink", tooltip = L("Воины, разбойники и рыцари смерти (и друиды в облике кошки или "
                    .. "медведя) не получают индикатор.", "Warriors, rogues and death knights (and druids in cat or "
                    .. "bear form) get no indicator.") },
            { "select", "rfDrinkAnchor", L("Позиция", "Position"), values = anchors, default = "BOTTOMLEFT",
                depends = "rfDrink" },
            { "range", "rfDrinkX", L("Смещение X", "Offset X"), min = -40, max = 40, step = 1, default = 2, depends = "rfDrink" },
            { "range", "rfDrinkY", L("Смещение Y", "Offset Y"), min = -40, max = 40, step = 1, default = 2, depends = "rfDrink" },
            { "range", "rfDrinkScale", L("Масштаб", "Scale"), min = 0.5, max = 2.5, step = 0.05, default = 1,
                depends = "rfDrink" },
        } },
        { id = "buffs", title = L("Баффы", "Buffs"), group = G_AURA, options = {
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
        { id = "tracked", title = L("Отслеживаемые баффы", "Tracked buffs"), group = G_AURA,
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
        { id = "debuffs", title = L("Дебаффы", "Debuffs"), group = G_AURA, options = {
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
        } },
        { id = "indicators", title = L("Индикаторы", "Indicators"), group = G_AURA,
            hint = L("HoT, щиты и баффы класса в углах фрейма.", "HoTs, shields and class buffs in the frame corners."),
            options = {
            { "toggle", "rfIndicators", L("Показывать индикаторы", "Show indicators"), default = true },
            { "toggle", "rfIndicatorTimer", L("Спираль длительности", "Duration spiral"), default = true, depends = "rfIndicators" },
            { "custom", build = buildIndicators, refresh = function(holder)
                if holder.refreshIndicators then holder.refreshIndicators() end
            end },
        } },
    },
})

ui.RegisterCallback("SuiteReady", function() ui.NormalizeModule("raidframes") end, "RaidFramesOptionsReady")
