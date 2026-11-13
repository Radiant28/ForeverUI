local addonName, ui = ...
local wfn, API = ui.wfn, WoWForeverNameplates
local ru = ui.russian
local function L(russian, english) return ru and russian or english end

local numbers = {
    {"widthEnemy", "Ширина врага", "Enemy width", 50, 250, 1, 120},
    {"widthFriend", "Ширина союзника", "Friendly width", 50, 250, 1, 120},
    {"heightEnemy", "Высота врага", "Enemy height", 8, 35, 1, 14},
    {"heightFriend", "Высота союзника", "Friendly height", 8, 35, 1, 14},
    {"outerLine", "Чёрный кант", "Black outer line", 0, 4, 0.25, 0.25},
    {"frameThickness", "Толщина рамки", "Frame thickness", 0, 5, 0.25, 1},
    {"targetGlowStrength", "Яркость ореола цели", "Target halo strength", 0, 1, 0.05, 0.85},
    {"sideGlowStrength", "Яркость ореола союзника", "Friendly halo strength", 0, 1, 0.05, 0.55},
    {"glowSize", "Размер ореола", "Halo size", 0.5, 3, 0.1, 1},
    {"castWidthEnemy", "Ширина каста врага (0 = авто)", "Enemy cast width (0 = auto)", 0, 250, 1, 120},
    {"castWidthFriend", "Ширина каста союзника (0 = авто)", "Friendly cast width (0 = auto)", 0, 250, 1, 120},
    {"castHeightEnemy", "Высота каста врага", "Enemy cast height", 7, 35, 1, 15},
    {"castHeightFriend", "Высота каста союзника", "Friendly cast height", 7, 35, 1, 15},
    {"castX", "Смещение каста X", "Cast offset X", -80, 80, 1, 15},
    {"castY", "Смещение каста Y", "Cast offset Y", 0, 80, 1, 4},
    {"castIconSize", "Размер иконки заклинания", "Cast icon size", 8, 36, 1, 15},
    {"castTextSize", "Размер текста заклинания", "Cast text size", 6, 24, 1, 8},
    {"nameSizeEnemy", "Размер имени врага", "Enemy name size", 8, 26, 1, 14},
    {"nameSizeFriend", "Размер имени союзника", "Friendly name size", 8, 26, 1, 14},
    {"nameLift", "Отступ имени", "Name spacing", 0, 24, 1, 6},
    {"nameX", "Смещение имени X", "Name offset X", -80, 80, 1, 0},
    {"nameMaxLetters", "Букв в имени (0 = все)", "Name letters (0 = all)", 0, 40, 1, 0},
}
local auraNumbers = {
    {"auraSize", "Размер значка ауры", "Aura icon size", 10, 32, 1, 16},
    {"auraGap", "Промежуток между значками", "Aura icon spacing", 0, 8, 1, 2},
    {"auraOffsetX", "Смещение ряда X (вправо)", "Aura row offset X (right)", -60, 60, 1, 0},
    {"auraOffsetY", "Смещение ряда Y (вверх)", "Aura row offset Y (up)", -60, 60, 1, 4},
}
local auraModes = {
    {"static", "Без анимации", "No animation"},
    {"forever", "Заливка с яркой линией (Forever)", "Radial fill with a bright edge (Forever)"},
    {"foreverPulse", "Заливка с линией и пульс", "Radial fill, edge and pulse"},
    {"sweep", "Круговая заливка (штатная)", "Cooldown sweep"},
    {"pulse", "Пульс перед спадом", "Expiry pulse"},
    {"both", "Заливка и пульс", "Sweep and pulse"},
}
local choices = {
    {"glowBlend", "Смешивание ореола", "Halo blending", {"light", "colour"}, {"свет", "цвет"}},
    {"castTextPlace", "Текст заклинания", "Cast text position", {"inside", "below"}, {"внутри", "снизу"}},
    {"castTextAlign", "Выравнивание заклинания", "Cast text alignment", {"left", "center", "right"}, {"слева", "центр", "справа"}},
    {"nameColour", "Цвет имени", "Name colour", {"white", "class"}, {"свой цвет", "класс"}},
    {"nameOutline", "Обводка имени", "Name outline", {"soft", "softer", "thin", "thick"}, {"тень", "мягкая тень", "тонкая", "толстая"}},
    {"namePlace", "Положение имени", "Name position", {"above", "undercast"}, {"над полосой", "под кастом"}},
    {"nameAlign", "Выравнивание имени", "Name alignment", {"center", "left", "right"}, {"центр", "слева", "справа"}},
}
local checks = {
    {"targetGlow", "Золотой ореол цели", "Gold target halo", true},
    {"sideGlow", "Ореол дружественных игроков", "Friendly player halo", false},
    {"level", "Бокс уровня", "Level box", true},
    {"cast", "Кастбар Forever", "Forever cast bar", true},
    {"castIcon", "Иконка заклинания", "Cast icon", true},
    {"castColour", "Цвет по доступности прерывания", "Colour casts by interrupt readiness", true},
    {"previewCast", "Пример каста в предпросмотре", "Example cast in preview", true},
}
local colours = {
    {"sideGlowFriend", "Ореол союзника", "Friendly halo colour"},
    {"castColourOpen", "Прерывание готово", "Interrupt ready"},
    {"castColourBusy", "Прерывание недоступно", "Interrupt unavailable"},
    {"castColourShut", "Каст непрерываемый", "Uninterruptible cast"},
    {"nameTextColour", "Цвет шрифта имени", "Name text colour"},
}

local media = LibStub and LibStub("LibSharedMedia-3.0", true)
function wfn.Font(key)
    local fonts = media and media:HashTable("font")
    return fonts and fonts[key] or [[Fonts\FRIZQT__.TTF]]
end

local function NormalizeNumbers(db, rows)
    for _, row in ipairs(rows) do
        local key, low, high, fallback = row[1], row[4], row[5], row[7]
        local v = db[key]
        db[key] = type(v) == "number" and v == v and math.max(low, math.min(high, v)) or fallback
    end
end

function wfn.NormalizeStyle()
    local db = wfn.db
    NormalizeNumbers(db, numbers)
    NormalizeNumbers(db, auraNumbers)
    local animation = "forever"
    for _, mode in ipairs(auraModes) do if db.auraTimerAnimation == mode[1] then animation = mode[1]; break end end
    db.auraTimerAnimation = animation
    for _, row in ipairs(choices) do
        local valid
        for _, item in ipairs(row[4]) do if db[row[1]] == item then valid = true; break end end
        if not valid then db[row[1]] = row[4][1] end
    end
end

-- The ForeverUI widget factory styles these controls in game; the test harness has no factory.
local function Button(parent, label, x, y, width, click)
    local button
    if ui.Widgets then
        button = ui.Widgets.Button(parent, label, width, nil, 22)
    else
        button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(width, 22)
        button:SetText(label)
    end
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetScript("OnClick", click)
    return button
end

local function Label(parent, label, x, y)
    local text
    if ui.Widgets then
        text = ui.Widgets.Text(parent, ui.Widgets.fonts.label)
    else
        text = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    end
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetText(label)
    return text
end

local function Cycle(items, current)
    for i, item in ipairs(items) do if item == current then return items[i % #items + 1] end end
    return items[1]
end

local function Fold(value)
    -- Lower only ASCII bytes before folding Cyrillic, regardless of the client's C locale.
    local ascii = value:gsub("[A-Z]", string.lower)
    return ascii:gsub("\208([\129\144-\175])", function(byte)
        local n = byte:byte()
        if n == 129 then return "\209\145" end
        if n >= 160 then return "\209" .. string.char(n - 32) end
        return "\208" .. string.char(n + 32)
    end)
end

local function BuildMedia(parent, y, defaults)
    local db = wfn.db
    local browser = CreateFrame("Frame", nil, parent)
    browser:SetSize(386, 300)
    browser:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    Label(browser, L("Шрифты и текстуры", "Fonts and textures"), 16, -4)
    local tabs = {
        {"nameFont", "font", L("Шрифт имени", "Name font")},
        {"castFont", "font", L("Шрифт каста", "Cast font")},
        {"barTexture", "statusbar", L("Текстура здоровья", "Health texture")},
        {"castTexture", "statusbar", L("Текстура каста", "Cast texture")},
    }
    local selected, page, switching = 1, 1, false
    local entries, matches, rows, buttons = {}, {}, {}, {}
    local pageSize = 6
    Label(browser, L("Поиск", "Search"), 16, -82)
    local search = CreateFrame("EditBox", "WoWForeverNameplatesMediaSearch", browser, "InputBoxTemplate")
    search:SetSize(288, 22)
    search:SetPoint("TOPLEFT", browser, "TOPLEFT", 79, -78)
    search:SetAutoFocus(false)
    search:SetMaxLetters(80)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnEnterPressed", search.ClearFocus)

    local function Draw()
        local tab = tabs[selected]
        for i, row in ipairs(rows) do
            local entry = matches[(page - 1) * pageSize + i]
            row.entry = entry
            if entry then
                local active = db[tab[1]] == entry.value
                row.background:SetTexture(active and 0.17 or 0.07, active and 0.29 or 0.09, active and 0.40 or 0.12, 1)
                row.label:SetText(entry.label)
                row.label:SetTextColor(active and 1 or 0.85, active and 0.87 or 0.85, active and 0.53 or 0.85)
                if tab[2] == "font" then
                    row.sample:SetFont(wfn.Font(""), 13)
                    row.sample:SetFont(entry.path, 13)
                else
                    row.swatch:SetTexture(entry.path)
                end
                wfn.Visible(row.sample, tab[2] == "font")
                wfn.Visible(row.swatch, tab[2] == "statusbar")
            end
            wfn.Visible(row, entry ~= nil)
        end
    end

    for i = 1, pageSize do
        local row = CreateFrame("Button", nil, browser)
        row:SetSize(357, 24)
        row:SetPoint("TOPLEFT", browser, "TOPLEFT", 16, -108 - (i - 1) * 26)
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints(row)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetTexture(0.42, 0.64, 0.9, 0.22)
        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.label:SetWidth(208)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.sample = row:CreateFontString(nil, "ARTWORK")
        row.sample:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.sample:SetFont(wfn.Font(""), 13)
        row.sample:SetText(L("Аа Бб 123", "Aa Bb 123"))
        row.swatch = row:CreateTexture(nil, "ARTWORK")
        row.swatch:SetSize(124, 13)
        row.swatch:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row:SetScript("OnClick", function(self)
            if not self.entry then return end
            db[tabs[selected][1]] = self.entry.value
            Draw()
            wfn.Changed()
        end)
        rows[i] = row
    end

    local indicator = Label(browser, "", 66, -271)
    local empty = Label(browser, L("Ничего не найдено", "No matches"), 22, -115)
    local previous, nextPage
    local function Refresh()
        local pages = math.max(1, math.ceil(#matches / pageSize))
        page = math.max(1, math.min(page, pages))
        indicator:SetText(page .. " / " .. pages)
        if page == 1 then previous:Disable() else previous:Enable() end
        if page == pages then nextPage:Disable() else nextPage:Enable() end
        wfn.Visible(empty, #matches == 0)
        Draw()
    end
    previous = Button(browser, "<", 16, -267, 38, function() page = page - 1; Refresh() end)
    nextPage = Button(browser, ">", 119, -267, 38, function() page = page + 1; Refresh() end)

    local function Filter(revealSelection)
        local needle = Fold(search:GetText() or "")
        for i = #matches, 1, -1 do matches[i] = nil end
        for _, entry in ipairs(entries) do
            if entry.search:find(needle, 1, true) then matches[#matches + 1] = entry end
        end
        page = 1
        if revealSelection then
            for i, entry in ipairs(matches) do
                if entry.value == db[tabs[selected][1]] then page = math.ceil(i / pageSize); break end
            end
        end
        Refresh()
    end

    local function List()
        local key, kind = tabs[selected][1], tabs[selected][2]
        entries = {}
        local seen = {}
        local function Add(label, value, path)
            if not path or path == "" or seen[value] then return end
            seen[value] = true
            entries[#entries + 1] = { label = label, value = value, path = path, search = Fold(label) }
        end
        if kind == "font" then
            Add("Friz Quadrata", "", wfn.Font(""))
        else
            Add("WoW: Forever", defaults[key], defaults[key])
            local classic = [[Interface\TargetingFrame\UI-StatusBar]]
            local flat = [[Interface\Buttons\WHITE8X8]]
            Add(L("Классическая", "Classic"), classic, classic)
            Add(L("Сплошная", "Flat"), flat, flat)
        end
        local paths = media and media:HashTable(kind)
        for _, name in ipairs(paths and media:List(kind) or {}) do
            local path = paths[name]
            Add(name, kind == "font" and name or path, path)
        end
        local value = db[key]
        if kind == "statusbar" then
            Add(value:match("[^\\/]+$") or value, value, value)
        elseif value ~= "" and not seen[value] then
            Add(value, value, wfn.Font(value))
        end
        for i, button in ipairs(buttons) do
            button:SetText((selected == i and "[x] " or "") .. tabs[i][3])
        end
        Filter(true)
    end
    for i, tab in ipairs(tabs) do
        local index = i
        buttons[i] = Button(browser, tab[3], 16 + (i - 1) % 2 * 182, -23 - math.floor((i - 1) / 2) * 25, 175, function()
            selected = index
            switching = true
            search:SetText("")
            switching = false
            List()
        end)
    end
    search:SetScript("OnTextChanged", function() if not switching then Filter() end end)
    if media and media.RegisterCallback then
        media.RegisterCallback(browser, "LibSharedMedia_Registered", function(_, kind)
            if kind == tabs[selected][2] then List() end
        end)
    end
    List()
    return y - 300
end

local general = {
    {"hideTotems", "Скрывать тотемы", "Hide totems"},
    {"hideMinions", "Скрывать питомцев и прислужников", "Hide pets and minions"},
    {"hideFriendlyInDungeons", "Скрывать дружественных NPC в подземельях и рейдах", "Hide friendly NPCs in dungeons and raids"},
    {"hideFullHealthOutOfCombat", "Скрывать мобов с полным здоровьем вне боя", "Hide full-health mobs out of combat"},
    {"headlineOutOfCombat", "Только имя для обычных мобов вне боя", "Name only for normal mobs out of combat"},
    {"combatOnlyEngaged", "В бою только противники, с которыми идёт бой", "In combat only the enemies you fight"},
    {"combatKeepFriends", "В бою оставлять союзников", "Keep allies in combat"},
    {"crowdSaver", "Экономный режим при скоплении", "Saver mode when crowded"},
    {"fadeDistance", "Затухание по дистанции", "Fade by distance"},
    {"showEliteDragon", "Показывать элитного дракона", "Show elite dragon"},
}

local function Build(panel, applyCVars, defaults)
    local scroll = CreateFrame("ScrollFrame", "WoWForeverNameplatesOptionsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -40)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 8)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(386)
    local db = wfn.db
    local y = BuildMedia(content, -4, defaults)
    Label(content, L("Видимость и расположение", "Visibility and positioning"), 16, y)
    ui.Slider(content, "plateOffsetX", L("Смещение неймплейта X (вправо)", "Nameplate offset X (right)"), y - 36,
        {-60, 60, 1, defaults.plateOffsetX}, wfn.Changed, nil, db)
    ui.Slider(content, "plateOffsetY", L("Смещение неймплейта Y (вверх)", "Nameplate offset Y (up)"), y - 81,
        {-60, 60, 1, defaults.plateOffsetY}, wfn.Changed, nil, db)
    y = y - 119
    for _, row in ipairs(general) do
        ui.Checkbox(content, row[1], L(row[2], row[3]), y, defaults[row[1]], wfn.Changed, db)
        y = y - 24
    end
    ui.Checkbox(content, "stacking", L("Нативное размещение в стек", "Native stacking"), y, defaults.stacking, applyCVars, db)
    local unavailable = L(" (недоступно в клиенте)", " (unavailable on this client)")
    local canSpace = GetCVar("nameplateOverlapV") ~= nil
    local spacing = ui.Slider(content, "verticalSpacing", L("Вертикальный интервал", "Vertical spacing") .. (canSpace and "" or unavailable), y - 42, {0.5, 2, 0.05, 0.9}, applyCVars, nil, db)
    if not canSpace then spacing:Disable() end
    local canRange = GetCVar("nameplateMaxDistance") ~= nil or GetCVar("nameplateDistance") ~= nil
    local range = ui.Slider(content, "maxDistance", L("Радиус неймплейтов", "Nameplate range") .. (canRange and "" or unavailable), y - 87, {30, 41, 1, 41}, applyCVars, L(" ярд.", " yd"), db)
    if not canRange then range:Disable() end
    y = y - 138
    Label(content, L("Ауры на неймплейте", "Nameplate auras"), 16, y)
    y = y - 36
    for _, row in ipairs(auraNumbers) do
        ui.Slider(content, row[1], L(row[2], row[3]), y, {row[4], row[5], row[6], row[7]}, wfn.Changed, nil, db)
        y = y - 44
    end
    Label(content, L("Анимация таймера", "Timer animation"), 16, y + 8)
    local auraButtons = {}
    for i, mode in ipairs(auraModes) do
        local key = mode[1]
        auraButtons[i] = Button(content, "", 16 + (i - 1) % 2 * 182, y - 12 - math.floor((i - 1) / 2) * 26, 175, function()
            db.auraTimerAnimation = key
            wfn.Changed()
        end)
    end
    y = y - 68
    Label(content, L("Боксы", "Boxes"), 16, y)
    y = y - 21
    Button(content, L("Предпросмотр", "Toggle preview"), 16, y, 170, function() wfn.Preview("all") end)
    Button(content, L("Сбросить позиции боксов", "Reset box offsets"), 198, y, 175, function() API:ResetBoxOffsets() end)
    y = y - 32

    local selected
    local boxLabel = Label(content, "", 16, y - 30)
    local boxButton = Button(content, "", 16, y, 226, function()
        selected = Cycle(wfn.order, selected)
        wfn.refreshOptions()
    end)
    local enabledButton = Button(content, "", 249, y, 124, function()
        if selected then API:SetBoxEnabled(selected, not API:IsBoxEnabled(selected)) end
    end)
    y = y - 53
    local placeButtons = {}
    for i, place in ipairs(wfn.places) do
        local key = place.key
        placeButtons[i] = Button(content, "", 16 + ((i - 1) % 2) * 182, y - math.floor((i - 1) / 2) * 26, 175, function()
            if selected then
                local _, on = API:BoxPlaces(selected)
                if on and on[key] ~= nil then API:SetBoxPlace(selected, key, not on[key]) end
            end
        end)
    end
    y = y - 62
    Label(content, L("Оформление", "Appearance"), 16, y)
    y = y - 22
    local choiceButtons = {}
    for i, row in ipairs(choices) do
        local option = row
        choiceButtons[i] = Button(content, "", 16, y, 357, function()
            db[option[1]] = Cycle(option[4], db[option[1]]); wfn.Changed()
        end)
        y = y - 26
    end
    for _, row in ipairs(colours) do
        local key = row[1]
        Button(content, L(row[2], row[3]), 16, y, 357, function()
            local color = db[key]
            local r, g, b = unpack(color)
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.func = function() color[1], color[2], color[3] = ColorPickerFrame:GetColorRGB(); wfn.Changed() end
            ColorPickerFrame.cancelFunc = function() color[1], color[2], color[3] = r, g, b; wfn.Changed() end
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Show()
        end)
        y = y - 26
    end
    for _, row in ipairs(checks) do
        ui.Checkbox(content, row[1], L(row[2], row[3]), y, row[4], wfn.Changed, db)
        y = y - 25
    end
    y = y - 16
    for _, row in ipairs(numbers) do
        ui.Slider(content, row[1], L(row[2], row[3]), y, {row[4], row[5], row[6], row[7]}, wfn.Changed, nil, db)
        y = y - 45
    end
    content:SetHeight(-y + 10)
    scroll:SetScrollChild(content)

    function wfn.refreshOptions()
        for i, mode in ipairs(auraModes) do
            auraButtons[i]:SetText((db.auraTimerAnimation == mode[1] and "[x] " or "") .. L(mode[2], mode[3]))
        end
        if not wfn.specs[selected] then selected = wfn.order[1] end
        local spec = selected and wfn.specs[selected]
        boxButton:SetText(spec and spec.label or L("Нет боксов", "No boxes"))
        local x, y = API:BoxOffset(selected)
        boxLabel:SetText(spec and (spec.owner .. " · " .. spec.side .. " · " .. x .. ", " .. y) or "")
        enabledButton:SetText(API:IsBoxEnabled(selected) and L("Включён", "Enabled") or L("Выключен", "Disabled"))
        local _, on = API:BoxPlaces(selected)
        for i, place in ipairs(wfn.places) do
            local active = on and on[place.key]
            wfn.Visible(placeButtons[i], active ~= nil)
            placeButtons[i]:SetText((active and "[x] " or "[ ] ") .. place.label)
        end
        for i, row in ipairs(choices) do
            local value = db[row[1]]
            if ru then for j, option in ipairs(row[4]) do if option == value then value = row[5][j]; break end end end
            choiceButtons[i]:SetText(L(row[2], row[3]) .. " · " .. value)
        end
    end
    wfn.refreshOptions()
end

-- Box editor for the ForeverUI options window.
local function BuildBoxes(content)
    local y = 0
    Button(content, L("Предпросмотр", "Toggle preview"), 0, y, 170, function() wfn.Preview("all") end)
    Button(content, L("Сбросить позиции боксов", "Reset box offsets"), 182, y, 190, function() API:ResetBoxOffsets() end)
    y = y - 32
    local selected
    local boxButton = Button(content, "", 0, y, 226, function()
        selected = Cycle(wfn.order, selected)
        wfn.refreshOptions()
    end)
    local enabledButton = Button(content, "", 234, y, 138, function()
        if selected then API:SetBoxEnabled(selected, not API:IsBoxEnabled(selected)) end
    end)
    local boxLabel = Label(content, "", 0, y - 30)
    y = y - 53
    local placeButtons = {}
    for i, place in ipairs(wfn.places) do
        local key = place.key
        placeButtons[i] = Button(content, "", ((i - 1) % 2) * 182, y - math.floor((i - 1) / 2) * 26, 175, function()
            if selected then
                local _, on = API:BoxPlaces(selected)
                if on and on[key] ~= nil then API:SetBoxPlace(selected, key, not on[key]) end
            end
        end)
    end
    y = y - math.ceil(#wfn.places / 2) * 26
    function wfn.refreshOptions()
        if not wfn.specs[selected] then selected = wfn.order[1] end
        local spec = selected and wfn.specs[selected]
        boxButton:SetText(spec and spec.label or L("Нет боксов", "No boxes"))
        local x, offsetY = API:BoxOffset(selected)
        boxLabel:SetText(spec and (spec.owner .. " · " .. spec.side .. " · " .. x .. ", " .. offsetY) or "")
        enabledButton:SetText(API:IsBoxEnabled(selected) and L("Включён", "Enabled") or L("Выключен", "Disabled"))
        local _, on = API:BoxPlaces(selected)
        for i, place in ipairs(wfn.places) do
            local active = on and on[place.key]
            wfn.Visible(placeButtons[i], active ~= nil)
            placeButtons[i]:SetText((active and "[x] " or "[ ] ") .. place.label)
        end
    end
    wfn.refreshOptions()
    return -y
end

local function Ranges(list, defaults)
    local options = {}
    for _, row in ipairs(list) do
        options[#options + 1] = { "range", row[1], L(row[2], row[3]), min = row[4], max = row[5], step = row[6],
            default = defaults and defaults[row[1]] or row[7] }
    end
    return options
end

-- Declarative schema for the ForeverUI options window, built from the same tables as the legacy page.
local function RegisterSchema(applyCVars, defaults)
    local canSpace = GetCVar("nameplateOverlapV") ~= nil
    local canRange = GetCVar("nameplateMaxDistance") ~= nil or GetCVar("nameplateDistance") ~= nil
    local unavailable = L(" (недоступно в клиенте)", " (unavailable on this client)")
    local visibility = {
        { "range", "plateOffsetX", L("Смещение X (вправо)", "Offset X (right)"), min = -60, max = 60, step = 1,
            default = defaults.plateOffsetX },
        { "range", "plateOffsetY", L("Смещение Y (вверх)", "Offset Y (up)"), min = -60, max = 60, step = 1,
            default = defaults.plateOffsetY },
    }
    for _, row in ipairs(general) do
        visibility[#visibility + 1] = { "toggle", row[1], L(row[2], row[3]), default = defaults[row[1]] }
    end
    visibility[#visibility + 1] = { "range", "crowdThreshold", L("Скопление: больше плашек, чем", "Crowded above plates"),
        min = 5, max = 60, step = 1, default = defaults.crowdThreshold, depends = "crowdSaver",
        tooltip = L("Если на экране больше плашек, спокойные (без каста, угрозы и не цель) обновляются 5 раз в секунду вместо 20. Цель, наведение, касты и угроза — всегда без задержки.",
            "With more plates on screen, quiet ones (no cast, no threat, not the target) refresh 5 times a second instead of 20. Target, hover, casts and threat always refresh at full rate.") }
    local function stackApply() applyCVars(); wfn.Changed() end
    visibility[#visibility + 1] = { "toggle", "stackForever", L("Вертикальный ряд при скоплении", "Vertical column when crowded"),
        default = defaults.stackForever, apply = stackApply,
        tooltip = L("Плашки в одной точке выстраиваются столбиком снизу вверх и не перекрывают друг друга. Штатное раздвигание клиента при этом выключается, чтобы плашки не двигались дважды.",
            "Plates gathered at one spot line up in a column from the bottom and never cover each other. The client's own spreading is turned off so plates do not move twice.") }
    visibility[#visibility + 1] = { "toggle", "stackNearestFirst", L("Ближайший остаётся на месте", "Nearest stays in place"),
        default = defaults.stackNearestFirst, apply = stackApply, depends = "stackForever",
        tooltip = L("В ряду не поднимается плашка ближайшего юнита: поднимаются те, кто стоит позади него.",
            "In the column the nearest unit's plate does not move; the plates of units behind it are lifted instead.") }
    visibility[#visibility + 1] = { "range", "stackBehindAlpha", L("Непрозрачность плашек позади", "Opacity of plates behind"),
        min = 0.1, max = 1, step = 0.05, default = defaults.stackBehindAlpha, apply = stackApply, depends = "stackForever",
        tooltip = L("Плашки, поднятые над более близкой в ряду, рисуются прозрачнее. Цель не затрагивается. 1 — без изменений.",
            "Plates lifted over a nearer one in the column are drawn fainter. The target is never affected. 1 keeps them as they are.") }
    visibility[#visibility + 1] = { "toggle", "stacking", L("Нативное размещение в стек", "Native stacking"),
        default = defaults.stacking, apply = applyCVars, protected = true,
        depends = function(get) return not get("stackForever") end }
    visibility[#visibility + 1] = { "range", "verticalSpacing", L("Вертикальный интервал", "Vertical spacing"),
        min = 0.5, max = 2, step = 0.05, default = defaults.verticalSpacing, apply = stackApply,
        depends = function(get) return get("stackForever") or (canSpace and get("stacking")) end }
    visibility[#visibility + 1] = { "range", "maxDistance", L("Радиус неймплейтов", "Nameplate range") ..
        (canRange and "" or unavailable), min = 30, max = 41, step = 1, default = defaults.maxDistance,
        suffix = L(" ярд.", " yd"), apply = applyCVars, protected = true, depends = function() return canRange end }
    visibility[#visibility + 1] = { "toggle", "edgeFade", L("Затухание к краям экрана", "Fade towards the screen edges"),
        default = defaults.edgeFade,
        tooltip = L("Как в WoW: Forever: плашки в центре экрана видны полностью и плавно гаснут к периферии, не засоряя края интерфейса. Цель не гаснет.",
            "As in WoW: Forever: plates near the screen centre stay solid and fade towards the periphery, keeping the edges clean. The target never fades.") }
    visibility[#visibility + 1] = { "range", "edgeFadeInner", L("Радиус полной видимости", "Fully visible radius"),
        min = 10, max = 190, step = 5, default = defaults.edgeFadeInner, suffix = "%", depends = "edgeFade",
        tooltip = L("В процентах от половины высоты экрана, от центра.", "Percent of half the screen height, from the centre.") }
    visibility[#visibility + 1] = { "range", "edgeFadeOuter", L("Радиус исчезновения", "Vanishing radius"),
        min = 20, max = 200, step = 5, default = defaults.edgeFadeOuter, suffix = "%", depends = "edgeFade",
        tooltip = L("Дальше этого радиуса плашки не видны; между радиусами — плавный градиент.",
            "Beyond this radius plates are hidden; between the radii they fade smoothly.") }

    local auras = Ranges(auraNumbers)
    local modes = {}
    for i, mode in ipairs(auraModes) do modes[i] = { mode[1], L(mode[2], mode[3]) } end
    auras[#auras + 1] = { "select", "auraTimerAnimation", L("Анимация таймера", "Timer animation"), values = modes,
        default = "forever", tooltip = L("Заливка с яркой линией затемняет прошедшую часть по часовой стрелке.",
            "The radial fill darkens the elapsed part clockwise, led by a bright edge.") }

    local filters = {
        { "toggle", "auraDebuffs", L("Показывать дебаффы", "Show debuffs"), default = defaults.auraDebuffs },
        { "toggle", "auraBuffs", L("Показывать баффы", "Show buffs"), default = defaults.auraBuffs },
        { "toggle", "auraMine", L("Мои дебаффы", "My debuffs"), default = defaults.auraMine, depends = "auraDebuffs",
            tooltip = L("Наложенные вами, вашим питомцем или транспортом.", "Cast by you, your pet or your vehicle.") },
        { "toggle", "auraOthers", L("Чужие дебаффы", "Other debuffs"), default = defaults.auraOthers,
            depends = "auraDebuffs", tooltip = L("Выключите вместе с включёнными «Моими», чтобы видеть только свои.",
                "Turn off with “My debuffs” on to see only your own.") },
        { "toggle", "auraOthersClass", L("Чужие — только моего класса", "Others — my class only"),
            default = defaults.auraOthersClass, depends = function(get) return get("auraDebuffs") and get("auraOthers") end,
            tooltip = L("Дебаффы других игроков вашего класса. Если заклинателя не видно, считается дебафф, который вы умеете накладывать сами.",
                "Debuffs from other players of your class. When the caster is unknown, a debuff you can cast yourself counts.") },
    }
    local timerFonts = function()
        local values = { { "", "Friz Quadrata" } }
        local seen = { [""] = true }
        for _, name in ipairs(media and media:List("font") or {}) do
            if not seen[name] then seen[name] = true; values[#values + 1] = { name, name } end
        end
        local current = wfn.db and wfn.db.auraTimerFont
        if type(current) == "string" and not seen[current] then values[#values + 1] = { current, current } end
        return values
    end
    local timer = {
        { "toggle", "auraTimerText", L("Показывать таймер", "Show the timer"), default = defaults.auraTimerText,
            tooltip = L("Цифры оставшегося времени на значках аур. Анимации работают и без них.",
                "Remaining-time numbers on aura icons. The animations work without them.") },
        { "select", "auraTimerFont", L("Шрифт таймера", "Timer font"), values = timerFonts, default = defaults.auraTimerFont,
            depends = "auraTimerText" },
        { "range", "auraTimerSize", L("Размер таймера (0 = авто)", "Timer size (0 = auto)"), min = 0, max = 24, step = 1,
            default = defaults.auraTimerSize, depends = "auraTimerText" },
        { "select", "auraTimerOutline", L("Обводка таймера", "Timer outline"), default = defaults.auraTimerOutline,
            depends = "auraTimerText",
            values = { { "none", L("нет", "none") }, { "thin", L("тонкая", "thin") }, { "thick", L("толстая", "thick") } } },
        { "color", "auraTimerColour", L("Цвет таймера", "Timer colour"), default = defaults.auraTimerColour,
            depends = "auraTimerText" },
    }
    local function classApply() applyCVars(); wfn.Changed() end
    local players = {
        { "toggle", "classColourEnemy", L("Цвет класса у врагов", "Class colours on enemies"),
            default = defaults.classColourEnemy, apply = classApply,
            tooltip = L("Полоса здоровья вражеских игроков в цвет класса.", "Enemy player health bars in class colours.") },
        { "toggle", "classColourFriend", L("Цвет класса у союзников", "Class colours on allies"),
            default = defaults.classColourFriend, apply = classApply },
        { "toggle", "npcTitles", L("Титул NPC под именем", "NPC title under the name"), default = defaults.npcTitles,
            tooltip = L("Что продаёт торговец, чему учит учитель, «Распорядитель полётов» и т. п. — как на плашках оригинальной игры.",
                "What a merchant sells, what a trainer teaches, flight masters and so on, as on the original game plates.") },
        { "toggle", "playerGuilds", L("Гильдия игрока под именем", "Player guild under the name"), default = defaults.playerGuilds },
        { "range", "subtitleSize", L("Размер подписи", "Subtitle size"), min = 6, max = 18, step = 1,
            default = defaults.subtitleSize, depends = function(get) return get("npcTitles") or get("playerGuilds") end },
        { "toggle", "friendlyNPCNameOnly", L("Дружественные NPC: только имя", "Friendly NPCs: name only"),
            default = defaults.friendlyNPCNameOnly,
            tooltip = L("Скрывает полосу здоровья дружественных NPC (торговцы, стража, учителя) и оставляет имя с титулом.",
                "Hides friendly NPC health bars (merchants, guards, trainers) and keeps the name and title.") },
        { "toggle", "friendlyNameOnly", L("Союзные игроки: только имя", "Allied players: name only"), default = defaults.friendlyNameOnly,
            tooltip = L("Скрывает полосу здоровья дружественных игроков и оставляет имя (в цвет класса, если он включён).",
                "Hides friendly player health bars and keeps the name (class coloured when class colours are on).") },
    }

    local appearance = {}
    for _, row in ipairs(choices) do
        local values = {}
        for i, value in ipairs(row[4]) do values[i] = { value, ru and row[5][i] or value } end
        appearance[#appearance + 1] = { "select", row[1], L(row[2], row[3]), values = values, default = row[4][1] }
    end
    for _, row in ipairs(colours) do
        appearance[#appearance + 1] = { "color", row[1], L(row[2], row[3]), default = defaults[row[1]] }
    end
    for _, row in ipairs(checks) do
        appearance[#appearance + 1] = { "toggle", row[1], L(row[2], row[3]), default = row[4] }
    end

    ui.RegisterOptions("nameplates", {
        title = L("Неймплейты", "Nameplates"),
        description = L("Полосы над головами в стиле WoW: Forever. Команда: /wfn.", "WoW: Forever nameplates. Command: /wfn."),
        icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
        group = "combat", order = 10,
        db = function() return wfn.db end,
        apply = function() wfn.Changed() end,
        sections = {
            { options = {
                { "custom", build = function(parent)
                    -- The media browser draws its own heading.
                    BuildMedia(parent, 0, defaults)
                    return 300
                end },
            } },
            { title = L("Видимость и расположение", "Visibility and positioning"), options = visibility },
            { title = L("Игроки", "Players"), options = players },
            { title = L("Ауры", "Auras"), options = auras },
            { title = L("Фильтр аур", "Aura filter"), options = filters },
            { title = L("Таймер аур", "Aura timer"), options = timer },
            { title = L("Боксы", "Boxes"), options = { { "custom", build = BuildBoxes } } },
            { title = L("Оформление", "Appearance"), options = appearance },
            { title = L("Размеры", "Dimensions"), options = Ranges(numbers) },
        },
    })
end

local panel
function wfn.CreateOptions(applyCVars, defaults)
    if ui.RegisterOptions then
        RegisterSchema(applyCVars, defaults)
        return
    end
    panel = ui.Options(L("Неймплейты", "Nameplates"))
    panel:SetScript("OnShow", function(self)
        self:SetScript("OnShow", nil)
        Build(self, applyCVars, defaults)
    end)
end

function wfn.OpenOptions()
    if not panel and ui.OpenOptions then
        ui.OpenOptions("nameplates")
        return
    end
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end

function wfn.Preview(side)
    side = (side == "friend" or side == "enemy") and side or "all"
    if wfn.previewing == side then wfn.previewing = nil else wfn.previewing = side end
    if wfn.releasePreviewMouse then wfn.releasePreviewMouse() end
    wfn.Changed()
    wfn.Print(wfn.previewing and L("Предпросмотр включён", "Preview on") or L("Предпросмотр выключен", "Preview off"))
end

local perf, scans, total, worst, frames, since = nil, 0, 0, 0, 0, 0
wfn.Clock = debugprofilestop or function() return GetTime() * 1000 end
local report = L("Нет замеров. Включите /wfn perf.", "No samples yet. Start /wfn perf.")

function wfn.RecordPerf(start, count)
    local cost = wfn.Clock() - start
    scans, total, worst, frames = scans + 1, total + cost, math.max(worst, cost), count
    local now = GetTime()
    if now - since < 1 then return end
    report = (L("Плашки %d · циклы %d · среднее %.3f мс · пик %.3f мс", "Plates %d · scans %d · mean %.3f ms · peak %.3f ms"))
        :format(frames, scans, total / scans, worst)
    perf.text:SetText(report)
    scans, total, worst, since = 0, 0, 0, now
end

local function TogglePerf()
    if not perf then
        perf = CreateFrame("Frame", nil, UIParent)
        perf:SetSize(420, 26)
        perf:SetPoint("TOP", UIParent, "TOP", 0, -100)
        perf:SetFrameStrata("DIALOG")
        perf.text = Label(perf, "WoW Forever Nameplates", 4, -4)
        perf:Hide()
    end
    wfn.profile = not perf:IsShown()
    wfn.Visible(perf, wfn.profile)
    scans, total, worst, since = 0, 0, 0, GetTime()
end

function wfn.RegisterSlash()
    SLASH_WOWFOREVERNAMEPLATES1 = "/wfn"
    SlashCmdList.WOWFOREVERNAMEPLATES = function(input)
        local cmd, arg = (input or ""):lower():match("^%s*(%S*)%s*(%S*)")
        if cmd == "preview" then wfn.Preview(arg)
        elseif cmd == "boxes" then
            for _, id in ipairs(wfn.order) do
                local spec = wfn.specs[id]
                wfn.Print(id .. " · " .. spec.owner .. " · " .. spec.side .. (API:IsBoxEnabled(id) and " [+]" or " [-]"))
            end
        elseif (cmd == "perf" or cmd == "cost") and arg == "dump" then wfn.Print(report)
        elseif cmd == "perf" or cmd == "cost" then TogglePerf()
        elseif cmd == "class" and wfn.DebugClasses then wfn.DebugClasses()
        elseif cmd == "check" then
            local hostVersion = GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")
            wfn.Print(L("Сканер WorldFrame активен", "WorldFrame scanner active") .. " · " .. API.Version
                .. (hostVersion and " · Forever UI " .. hostVersion or ""))
            local unavailable = L("недоступно", "unavailable")
            wfn.Print("nameplateAllowOverlap=" .. (GetCVar("nameplateAllowOverlap") or unavailable)
                .. " · nameplateOverlapV=" .. (GetCVar("nameplateOverlapV") or unavailable)
                .. " · nameplateMaxDistance=" .. (GetCVar("nameplateMaxDistance") or GetCVar("nameplateDistance") or unavailable))
        elseif cmd == "" then wfn.OpenOptions()
        else wfn.Print("/wfn · preview [friend|enemy] · boxes · check · class · perf [dump]") end
    end
end
