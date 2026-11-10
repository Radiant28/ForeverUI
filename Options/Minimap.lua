local _, ui = ...
local L = ui.L
local function layout() if ui.Minimap then ui.Minimap.Layout() end end

ui.RegisterOptions("minimap", {
    title = L("Миникарта", "Minimap"),
    description = L("Размер карты и положение бафов рядом с ней.", "Map size and the buffs next to it."),
    icon = "Interface\\Icons\\INV_Misc_Map02",
    group = "frames", order = 50,
    apply = layout,
    protected = true,
    sections = {
        { title = L("Карта", "Map"), options = {
            { "range", "mapScale", L("Размер миникарты", "Minimap scale"), min = 60, max = 150, step = 5, default = 100,
                suffix = "%", tooltip = L("Тот же масштаб меняется в режиме редактирования.", "Edit Mode changes the same scale.") },
        } },
        { title = L("Бафы", "Buffs"), options = {
            { "range", "mapBuffGap", L("Отступ слева от карты", "Gap to the left of the map"), min = 0, max = 250, step = 2,
                default = 10, suffix = " px" },
            { "range", "mapBuffY", L("Смещение по высоте", "Vertical offset"), min = -200, max = 200, step = 2,
                default = 0, suffix = " px" },
        } },
    },
})

ui.RegisterOptions("addonbar", {
    title = L("Панель аддонов", "Addon bar"),
    description = L("Кнопки аддонов с миникарты собраны в одну панель или кольцо.",
        "Addon minimap buttons gathered in a bar or around the map."),
    icon = "Interface\\Icons\\INV_Misc_EngGizmos_20",
    group = "frames", order = 55,
    enable = "mapButtonsEnabled",
    apply = layout,
    protected = true,
    sections = {
        { title = L("Модуль", "Module"), options = {
            { "toggle", "mapButtonsEnabled", L("Собирать кнопки аддонов", "Gather addon buttons"), default = true,
                reload = true, tooltip = L("Кнопки, уже перенесённые панелью, вернутся на место после /reload.",
                    "Buttons already moved return to place after /reload.") },
            { "toggle", "mapButtonsCircle", L("Кнопки по кругу миникарты", "Buttons around the minimap"), default = true },
        } },
        { title = L("Кольцо", "Ring"), depends = "mapButtonsCircle", options = {
            { "range", "mapRingOffset", L("Отступ от края карты", "Distance from the map edge"), min = -20, max = 40, step = 1,
                default = 2, suffix = " px" },
        } },
        { title = L("Панель", "Bar"), depends = "!mapButtonsCircle", options = {
            { "range", "mapButtonsScale", L("Размер панели", "Bar scale"), min = 50, max = 180, step = 5, default = 100,
                suffix = "%" },
            { "range", "mapButtonsSpacing", L("Промежуток между кнопками", "Button spacing"), min = 0, max = 16, step = 1,
                default = 2, suffix = " px" },
            { "range", "mapButtonsX", L("Смещение по X", "X offset"), min = -1000, max = 1000, step = 2, default = -14 },
            { "range", "mapButtonsY", L("Смещение по Y", "Y offset"), min = -700, max = 700, step = 2, default = -34 },
            { "toggle", "mapButtonsVertical", L("Вертикальная панель", "Vertical bar"), default = false },
            { "toggle", "mapButtonsBackground", L("Фон и рамка", "Background and border"), default = true },
            { "color", "mapButtonsBgColor", L("Цвет фона", "Background colour"), alpha = true,
                default = { 0.08, 0.065, 0.05, 0.88 },
                depends = function(get) return not get("mapButtonsCircle") and get("mapButtonsBackground") end },
            { "color", "mapButtonsBorderColor", L("Цвет рамки", "Border colour"), alpha = true,
                default = { 0.48, 0.34, 0.17, 0.95 },
                depends = function(get) return not get("mapButtonsCircle") and get("mapButtonsBackground") end },
        } },
    },
})
