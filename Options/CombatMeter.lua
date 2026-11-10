local _, ui = ...
local L = ui.L
local limits = ui.CombatMeterLimits
local function call(name)
    return function() if ui.CombatMeter then ui.CombatMeter[name]() end end
end

ui.RegisterOptions("meter", {
    title = L("Урон и лечение", "Damage and healing"),
    description = L("Встроенные измерители урона и лечения.", "Built-in damage and healing meters."),
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
            { "range", "meterWidth", L("Ширина обоих окон", "Width of both windows"), min = limits.minWidth,
                max = limits.maxWidth, step = 5, default = 385, suffix = " px", apply = call("ResetWidth") },
            { "range", "meterRowHeight", L("Высота полосы", "Bar height"), min = 12, max = 40, step = 1, default = 20,
                suffix = " px" },
            { "range", "meterDamageRows", L("Строки урона", "Damage rows"), min = limits.minRows, max = limits.maxRows,
                step = 1, default = 5, apply = call("ResetDamageRows") },
            { "range", "meterHealingRows", L("Строки лечения", "Healing rows"), min = limits.minRows, max = limits.maxRows,
                step = 1, default = 7, apply = call("ResetHealingRows") },
        } },
        { title = L("Оформление", "Appearance"), options = {
            { "range", "meterTextSize", L("Размер шрифта", "Font size"), min = 10, max = 20, step = 1, default = 15 },
            { "range", "meterBackground", L("Непрозрачность фона", "Background opacity"), min = 0, max = 100, step = 5,
                default = 80, suffix = "%" },
            { "media", "meterBackgroundTexture", L("Текстура фона", "Background texture"), kind = "meterbackground",
                ignoreGlobal = true, default = 1 },
            { "media", "meterBarTexture", L("Текстура полосы", "Bar texture"), kind = "meterbar", ignoreGlobal = true,
                default = 1 },
        } },
    },
})
