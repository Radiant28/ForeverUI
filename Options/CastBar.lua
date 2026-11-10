local _, ui = ...
local L = ui.L
local function apply() if ui.CastBar then ui.CastBar.Apply() end end
local function stock(field) return function() return ui.CastBar and ui.CastBar.stock[field] end end

ui.RegisterOptions("castbar", {
    title = L("Полоса заклинаний", "Cast bar"),
    description = L("Полосы игрока, питомца, цели, фокуса, боссов и арены.", "Player, pet, target, focus, boss and arena bars."),
    icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    group = "frames", order = 20,
    enable = "castMidStyle",
    apply = apply,
    sections = {
        { title = L("Модуль", "Module"), options = {
            { "toggle", "castMidStyle", L("Полоса WoW: Forever", "WoW: Forever cast bar"), default = true,
                tooltip = L("Выключение возвращает штатный вид всех полос без перезагрузки.",
                    "Turning it off restores the stock bars without a reload.") },
        } },
        { title = L("Какие полосы оформлять", "Bars to restyle"), columns = 3, options = {
            { "toggle", "castSkinPlayer", L("Игрок", "Player"), default = true },
            { "toggle", "castSkinPet", L("Питомец", "Pet"), default = true },
            { "toggle", "castSkinTarget", L("Цель", "Target"), default = true },
            { "toggle", "castSkinFocus", L("Фокус", "Focus"), default = true },
            { "toggle", "castSkinBoss", L("Боссы", "Bosses"), default = true },
            { "toggle", "castSkinArena", L("Арена", "Arena"), default = true },
        } },
        { title = L("Размер полосы игрока", "Player bar size"), options = {
            { "range", "castWidth", L("Ширина", "Width"), min = 120, max = 420, step = 1, default = stock("width"), suffix = " px" },
            { "range", "castHeight", L("Высота", "Height"), min = 8, max = 36, step = 1, default = stock("height"), suffix = " px" },
            { "range", "castScale", L("Масштаб", "Scale"), min = 50, max = 180, step = 5, default = stock("scale"), suffix = "%",
                tooltip = L("Тот же масштаб меняется в режиме редактирования.", "Edit Mode changes the same scale.") },
            { "range", "castIconSize", L("Размер значка (0 — авто)", "Icon size (0 = auto)"), min = 0, max = 48, step = 1,
                default = 0, depends = "castIcon" },
        } },
        { title = L("Текст", "Text"), options = {
            { "media", "castFont", L("Шрифт", "Font"), kind = "font", default = 1 },
            { "range", "castFontSize", L("Размер шрифта", "Font size"), min = 8, max = 22, step = 1, default = 12 },
            { "select", "castFontOutline", L("Обводка", "Outline"), values = ui.OutlineValues, default = "OUTLINE" },
            { "range", "castTimerDecimals", L("Знаков после запятой", "Timer decimals"), min = 0, max = 2, step = 1,
                default = 1, depends = "castTimer" },
            { "toggle", "castTimer", L("Оставшееся время", "Time remaining"), default = true },
            { "toggle", "castCenterText", L("Название по центру", "Centered spell name"), default = true },
            { "toggle", "castIcon", L("Значок заклинания", "Spell icon"), default = false },
        } },
        { title = L("Цвета и детали", "Colours and details"), options = {
            { "color", "castFillColor", L("Тонировка каста", "Cast tint"), default = { 1, 1, 1 } },
            { "color", "castChannelColor", L("Тонировка поддержания", "Channel tint"), default = { 1, 1, 1 } },
            { "color", "castShieldColor", L("Непрерываемое заклинание", "Uninterruptible cast"), default = { 0.64, 0.65, 0.71 } },
            { "range", "castSparkWidth", L("Ширина искры", "Spark width"), min = 4, max = 32, step = 1, default = 14 },
        } },
    },
})
