local _, ui = ...
local L = ui.L
local function apply() if ui.Performance then ui.Performance.Apply() end end

ui.RegisterOptions("performance", {
    title = L("Производительность", "Performance"),
    description = L("Индикаторы FPS и пинга под миникартой.", "FPS and latency readouts below the minimap."),
    icon = "Interface\\Icons\\INV_Gizmo_02",
    group = "general", order = 30,
    enable = "perfEnabled",
    apply = apply,
    sections = {
        { title = L("Модуль", "Module"), options = {
            { "toggle", "perfEnabled", L("Показывать индикаторы", "Show readouts"), default = true },
            { "range", "perfInterval", L("Частота обновления", "Update interval"), min = 0.1, max = 2, step = 0.1,
                default = 0.5, suffix = L(" с", " s") },
            { "toggle", "perfShowFPS", L("FPS", "FPS"), default = true },
            { "toggle", "perfShowPing", L("Пинг", "Latency"), default = true },
            { "range", "fpsScale", L("Масштаб FPS", "FPS scale"), min = 50, max = 200, step = 5, default = 100, suffix = "%",
                depends = "perfShowFPS" },
            { "range", "pingScale", L("Масштаб пинга", "Latency scale"), min = 50, max = 200, step = 5, default = 100,
                suffix = "%", depends = "perfShowPing" },
        } },
        { title = L("Текст", "Text"), options = {
            { "media", "perfFont", L("Шрифт", "Font"), kind = "font", ignoreGlobal = true, default = 1 },
            { "range", "perfFontSize", L("Размер шрифта", "Font size"), min = 8, max = 24, step = 1, default = 12 },
            { "select", "perfFontOutline", L("Обводка", "Outline"), values = ui.OutlineValues, default = "OUTLINE" },
        } },
        { title = L("Пороги и цвета", "Thresholds and colours"), options = {
            { "range", "perfGoodFPS", L("Хороший FPS от", "Good FPS from"), min = 10, max = 240, step = 5, default = 60 },
            { "range", "perfFairFPS", L("Средний FPS от", "Fair FPS from"), min = 5, max = 200, step = 5, default = 30 },
            { "range", "perfGoodPing", L("Хороший пинг до", "Good latency up to"), min = 10, max = 500, step = 5, default = 80,
                suffix = L(" мс", " ms") },
            { "range", "perfFairPing", L("Средний пинг до", "Fair latency up to"), min = 20, max = 1000, step = 10,
                default = 150, suffix = L(" мс", " ms") },
            { "color", "perfGoodColor", L("Хорошо", "Good"), default = { 0.39, 0.9, 0.43 } },
            { "color", "perfFairColor", L("Средне", "Fair"), default = { 1, 0.78, 0.29 } },
            { "color", "perfPoorColor", L("Плохо", "Poor"), default = { 1, 0.36, 0.32 } },
        } },
    },
})
