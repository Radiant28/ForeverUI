local _, ui = ...
local L = ui.L
local ct = ui.CombatText
local defaults = ct.defaults
local function apply() ui.CombatText.Apply() end
-- Everything else is read while the text animates; only these touch the stock font and CVars.
local live = { enabled = true, replace3DFont = true, hideBlizzDamage = true, hideBlizzHealing = true,
    showOutgoingDamage = true, showOutgoingHeal = true }

-- Rows reuse the module's switch/slider tables: { key, russian, english [, min, max, step] }.
local function rows(list, keys, kind)
    local options = {}
    for _, key in ipairs(keys) do
        for _, row in ipairs(list) do
            if row[1] == key then
                local opt = { kind, key, L(row[2], row[3]), default = defaults[key], apply = live[key] and apply or nil }
                if kind == "range" then opt.min, opt.max, opt.step = row[4], row[5], row[6] end
                options[#options + 1] = opt
            end
        end
    end
    return options
end

local function section(title, list, keys, kind, extra)
    local options = rows(list, keys, kind)
    for _, opt in ipairs(extra or {}) do options[#options + 1] = opt end
    return { title = title, options = options }
end

local schools = {
    { 1, L("Физический", "Physical") }, { 2, L("Свет", "Holy") }, { 4, L("Огонь", "Fire") },
    { 8, L("Природа", "Nature") }, { 16, L("Лёд", "Frost") }, { 32, L("Тьма", "Shadow") }, { 64, L("Тайная магия", "Arcane") },
}
local schoolOptions = {}
for _, school in ipairs(schools) do
    schoolOptions[#schoolOptions + 1] = { "color", "colorSchool" .. school[1], school[2], default = ct.schools[school[1]],
        depends = "colorBySchool" }
end

ui.RegisterOptions("combattext", {
    title = L("Текст боя", "Combat text"),
    description = L("Всплывающие цифры урона и лечения (на основе NiceDamage). Тест: /nd test.",
        "Floating damage and healing numbers (based on NiceDamage). Test: /nd test."),
    icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
    group = "combat", order = 20,
    db = function() return ui.Settings().combatText end,
    enable = "enabled",
    unavailable = function()
        if IsAddOnLoaded("NiceDamage") then
            return L("Модуль отключён: загружен аддон NiceDamage.", "The module is off because NiceDamage is loaded.")
        end
        if not ui.CombatText.active then return L("Модуль ещё не загружен.", "The module is not loaded yet.") end
    end,
    sections = {
        section(L("Модуль", "Module"), ct.switches, { "enabled" }, "toggle", {
            { "button", L("Показать пример", "Preview combat text"), func = function() ui.CombatText.Test() end },
        }),
        section(L("Что показывать", "What to show"), ct.switches,
            { "showOutgoingDamage", "showOutgoingHeal", "showPetDamage", "showIncomingDamage", "showIncomingHeal", "showMana", "showMisses" },
            "toggle"),
        section(L("Шрифт", "Font"), ct.sliders, { "fontSize", "critScale" }, "range", {
            { "media", "fontName", L("Шрифт текста боя", "Combat text font"), kind = "font", ignoreGlobal = true,
                default = defaults.fontName, apply = apply },
            { "select", "fontOutline", L("Обводка", "Outline"), values = ui.OutlineValues, default = defaults.fontOutline,
                apply = apply },
            { "toggle", "fontShadow", L("Тень текста", "Text shadow"), default = defaults.fontShadow },
            { "toggle", "shortNumbers", L("Сокращать числа", "Abbreviate amounts"), default = defaults.shortNumbers },
        }),
        section(L("Иконки", "Icons"), ct.sliders, { "iconSize" }, "range", {
            { "toggle", "showIcons", L("Иконки заклинаний", "Spell icons"), default = defaults.showIcons },
            { "toggle", "showSwingIcon", L("Иконки автоатак", "Auto-attack icons"), default = defaults.showSwingIcon,
                depends = "showIcons" },
            { "select", "iconPosition", L("Положение иконки", "Icon side"), default = defaults.iconPosition,
                values = { { "LEFT", L("Слева", "Left") }, { "RIGHT", L("Справа", "Right") } }, depends = "showIcons" },
        }),
        section(L("Анимация и положение", "Animation and position"), ct.sliders,
            { "duration", "floatHeight", "nameplateOffsetY", "fallbackOffsetX", "fallbackOffsetY" }, "range", {
            { "select", "animStyle", L("Анимация", "Animation"), default = defaults.animStyle, values = {
                { "FOUNTAIN", L("Фонтан", "Fountain") }, { "VERTICAL", L("Вверх", "Vertical") },
                { "DIAGONAL", L("По диагонали", "Diagonal") } } },
            { "toggle", "anchorToNameplates", L("Текст над неймплейтами", "Anchor text to nameplates"),
                default = defaults.anchorToNameplates },
            { "toggle", "onlyOnUnits", L("Только на юнитах", "On units only"), default = defaults.onlyOnUnits,
                tooltip = L("Текст без юнита (в верхней части экрана) не показывается. Входящие цифры не затрагиваются.",
                    "Text without a unit (the upper screen area) is not shown. Incoming numbers are unaffected.") },
            { "button", L("Переместить зоны текста", "Move text zones"), func = function()
                if ui.EditMode then ui.EditMode.Open() end
            end },
        }),
        { title = L("Цвета", "Colours"), options = {
            { "color", "colorNormal", L("Обычный урон", "Normal damage"), default = defaults.colorNormal },
            { "color", "colorCrit", L("Критический урон", "Critical damage"), default = defaults.colorCrit },
            { "color", "colorHeal", L("Лечение", "Healing"), default = defaults.colorHeal },
            { "color", "colorHealCrit", L("Критическое лечение", "Critical healing"), default = defaults.colorHealCrit },
            { "color", "colorMana", L("Мана", "Mana"), default = defaults.colorMana },
            { "color", "colorPet", L("Урон питомца", "Pet damage"), default = defaults.colorPet, depends = "!colorBySchool" },
            { "toggle", "colorBySchool", L("Цвет по школе магии", "Colour by spell school"), default = defaults.colorBySchool },
        } },
        { title = L("Школы магии", "Spell schools"), columns = 3, options = schoolOptions },
        section(L("Штатный текст боя", "Stock combat text"), ct.switches,
            { "replace3DFont", "hideBlizzDamage", "hideBlizzHealing" }, "toggle"),
    },
})
