local _, ui = ...
local L = ui.L
local limits = ui.CombatMeterLimits
local function call(name)
    return function() if ui.CombatMeter then ui.CombatMeter[name]() end end
end

ui.RegisterOptions("meter", {
    title = L("Урон и лечение", "Damage and healing"),
    description = L("Встроенные измерители урона, лечения и угрозы.", "Built-in damage, healing and threat meters."),
    icon = "Interface\\Icons\\Ability_DualWield",
    group = "combat", order = 30,
    enable = "meterEnabled",
    apply = call("Apply"),
    sections = {
        { title = L("Модуль", "Module"), options = {
            { "toggle", "meterEnabled", L("Показывать измерители", "Show meters"), default = true },
            { "range", "meterInterval", L("Частота обновления", "Update interval"), min = 0.1, max = 2, step = 0.05,
                default = 0.25, suffix = L(" с", " s"), apply = false },
        } },
        { title = L("Предпросмотр", "Preview"), options = {
            { "custom", build = function(parent)
                if not ui.CombatMeter then return 0 end
                return ui.CombatMeter.BuildPreview(parent)
            end },
        } },
        { title = L("Размеры", "Dimensions"), options = {
            { "range", "meterWidth", L("Ширина окон", "Window width"), min = limits.minWidth,
                max = limits.maxWidth, step = 5, default = 385, suffix = " px", apply = call("ResetWidth") },
            { "range", "meterRowHeight", L("Высота полосы", "Bar height"), min = 12, max = 40, step = 1, default = 20,
                suffix = " px" },
            { "range", "meterDamageRows", L("Строки окон урона и угрозы", "Damage and threat window rows"),
                min = limits.minRows, max = limits.maxRows, step = 1, default = 5, apply = call("ResetDamageRows") },
            { "range", "meterHealingRows", L("Строки окон лечения", "Healing window rows"), min = limits.minRows,
                max = limits.maxRows, step = 1, default = 7, apply = call("ResetHealingRows") },
        } },
        { title = L("Оформление", "Appearance"), options = {
            { "range", "meterTextSize", L("Размер шрифта", "Font size"), min = 10, max = 20, step = 1, default = 15 },
            { "range", "meterBackground", L("Непрозрачность фона", "Background opacity"), min = 0, max = 100, step = 5,
                default = 80, suffix = "%" },
            { "media", "meterBackgroundTexture", L("Текстура фона", "Background texture"), kind = "meterbackground",
                ignoreGlobal = true, default = 1 },
            { "media", "meterBarTexture", L("Текстура полосы", "Bar texture"), kind = "meterbar", ignoreGlobal = true,
                default = 1 },
            { "color", "meterRowColor", L("Фон полос (сплошной)", "Bar background (solid)"), alpha = true,
                default = { 0.06, 0.06, 0.07, 1 } },
            { "range", "meterRowGap", L("Промежуток между полосами", "Gap between bars"), min = 0, max = 8, step = 1,
                default = 1, suffix = " px" },
        } },
        { title = L("Числа", "Numbers"), description = L("Пример: 1 234 567 урона и 4 321,5 в секунду.",
            "Example: 1,234,567 damage and 4,321.5 per second."), options = {
            { "select", "meterNumberFormat", L("Вид чисел", "Number style"), default = "full", values = {
                { "full", L("Полностью (1234567)", "Full (1234567)") },
                { "tens", L("Без единиц (1234570)", "No ones (1234570)") },
                { "hundreds", L("Без десятков (1234600)", "No tens (1234600)") },
                { "short", L("Сокращённо (1,2м · 4,3к)", "Short (1.2m · 4.3k)") } } },
            { "range", "meterDecimals", L("Цифр после запятой", "Decimal places"), min = 0, max = 2, step = 1, default = 1,
                tooltip = L("Для «в секунду» и сокращённых чисел.", "For per-second and short values.") },
            { "toggle", "meterTrimZeros", L("Убирать нули после запятой", "Drop trailing zeros"), default = true },
            { "toggle", "meterSeparator", L("Разделять разряды (1 234 567)", "Group digits (1 234 567)"), default = false },
            { "select", "meterSecondary", L("Второе число в скобках", "Second value in brackets"), default = "show",
                values = { { "show", L("Показывать", "Show") }, { "none", L("Скрыть", "Hide") } } },
        } },
        -- Kept last: the list grows with every added window and pushes nothing else down.
        { title = L("Окна", "Windows"), description = L("Добавляйте сколько угодно окон (до 10) или удалите все. "
            .. "Показатель окна (урон, лечение, угроза) выбирается стрелкой в его заголовке. Угроза считается по "
            .. "враждебной цели, а без неё — по фокусу.",
            "Add as many windows as you like (up to 10) or delete them all. Pick each window's metric (damage, "
            .. "healing, threat) with the arrow in its header. Threat follows your hostile target, or your focus "
            .. "without one."), options = {
            { "custom", build = function(parent, width)
                if not ui.CombatMeter or not ui.CombatMeter.BuildWindowList then return 0 end
                return ui.CombatMeter.BuildWindowList(parent, width)
            end },
        } },
    },
})
