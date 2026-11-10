local _, ui = ...
local L = ui.L
local Cursor = ui.cursor
local defaults, ranges = Cursor.defaults, Cursor.ranges

local function range(key, label, extra)
    local limits = ranges[key]
    local opt = { "range", key, label, min = limits[1], max = limits[2], step = limits[3], default = defaults[key] }
    for field, value in pairs(extra or {}) do opt[field] = value end
    return opt
end

local function colour(prefix, label, depends)
    return { "color", prefix, label, split = true, depends = depends,
        default = { defaults[prefix .. "R"], defaults[prefix .. "G"], defaults[prefix .. "B"] } }
end

ui.RegisterOptions("cursor", {
    title = L("Курсор", "Cursor"),
    description = L("Обводка и след курсора (CursorUZ). Команда: /cursoruz.", "Cursor outline and trail (CursorUZ). Command: /cursoruz."),
    icon = "Interface\\Icons\\Spell_Arcane_Blink",
    group = "combat", order = 40,
    db = function() return Cursor.settings end,
    enable = "cursorEnabled",
    apply = function() Cursor.Apply() end,
    onReset = function() Cursor.Apply() end,
    sections = {
        { title = L("Модуль", "Module"), options = {
            { "toggle", "cursorEnabled", L("Эффекты курсора", "Cursor effects"), default = true, db = ui.Settings },
            { "select", "mode", L("Когда показывать", "When to show"), default = defaults.mode, values = {
                { "always", L("Всегда", "Always") }, { "combat", L("Только в бою", "In combat only") },
                { "peace", L("Только вне боя", "Out of combat only") } } },
        } },
        { title = L("Обводка", "Outline"), depends = "outlineEnabled", options = {
            { "toggle", "outlineEnabled", L("Показывать обводку", "Show outline"), default = defaults.outlineEnabled,
                depends = false },
            { "select", "outlineStyle", L("Вид обводки", "Outline style"), default = defaults.outlineStyle, values = {
                { "ring", L("Кольцо", "Ring") }, { "halo", L("Мягкий ореол", "Soft halo") },
                { "arrow", L("Контур стрелки", "Arrow outline") } } },
            range("size", L("Размер", "Size")),
            range("thickness", L("Толщина", "Thickness"), {
                depends = function(get) return get("outlineEnabled") and get("outlineStyle") ~= "halo" end }),
            range("outlineAlpha", L("Непрозрачность", "Opacity")),
            range("glow", L("Сила свечения", "Glow strength")),
            range("softness", L("Мягкость свечения", "Glow softness")),
            range("offsetX", L("Смещение по X", "Offset X")),
            range("offsetY", L("Смещение по Y", "Offset Y")),
            colour("outline", L("Цвет обводки", "Outline colour")),
        } },
        { title = L("След", "Trail"), depends = "trailEnabled", options = {
            { "toggle", "trailEnabled", L("Показывать след", "Show trail"), default = defaults.trailEnabled, depends = false },
            { "select", "trailStyle", L("Вид следа", "Trail style"), default = defaults.trailStyle, values = {
                { "smooth", L("Гладкая лента", "Smooth ribbon") }, { "smoke", L("Дымчатая полоса", "Smoky streak") } } },
            range("width", L("Ширина", "Width")),
            range("trailAlpha", L("Непрозрачность", "Opacity")),
            range("length", L("Максимальная длина", "Maximum length")),
            range("lifetime", L("Время до исчезновения", "Lifetime"), { suffix = L(" с", " s") }),
            range("fade", L("Кривая затухания", "Fade curve"), {
                tooltip = L("Больше значение — быстрее снижается яркость.", "Higher values fade faster.") }),
            range("taper", L("Сужение хвоста", "Tail taper")),
            range("edge", L("Мягкость краёв", "Edge softness"), {
                tooltip = L("Чёткие / средние / мягкие края.", "Hard / medium / soft edges.") }),
            range("density", L("Плотность дыма", "Smoke density"), {
                depends = function(get) return get("trailEnabled") and get("trailStyle") == "smoke" end }),
            range("smoke", L("Выраженность фактуры", "Smoke texture"), {
                depends = function(get) return get("trailEnabled") and get("trailStyle") == "smoke" end }),
            colour("trail", L("Цвет следа", "Trail colour")),
        } },
    },
})
