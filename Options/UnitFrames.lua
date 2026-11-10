local _, ui = ...
local L = ui.L
local function call(name)
    return function() if ui.UnitFrames then ui.UnitFrames[name]() end end
end

ui.RegisterOptions("unitframes", {
    title = L("Рамки персонажей", "Unit frames"),
    description = L("Игрок, цель, фокус, питомец, группа, боссы и арена.", "Player, target, focus, pet, party, bosses and arena."),
    icon = "Interface\\Icons\\Achievement_Character_Human_Male",
    group = "frames", order = 10,
    enable = "unitFramesEnabled",
    sections = {
        { title = L("Модуль", "Module"), options = {
            { "toggle", "unitFramesEnabled", L("Оформление WoW: Forever", "WoW: Forever styling"), default = true, reload = true,
                tooltip = L("Отключает переоформление штатных рамок.", "Turns off the restyling of the stock frames.") },
            { "toggle", "healthClassColor", L("Цвет класса на полосе здоровья", "Class-colored health bars"), default = false,
                apply = call("ApplyHealthColor") },
        } },
        { title = L("Текстуры", "Textures"), columns = 3, options = {
            { "media", "unitBarFill", L("Полосы здоровья и ресурса", "Health and power bars"), kind = "unitbar",
                default = 3, apply = call("ApplyBarFill") },
            { "media", "unitBarBackground", L("Фон рамок", "Frame background"), kind = "background",
                default = 1, apply = call("ApplyPanelMedia") },
            { "media", "unitBarBorder", L("Окантовка рамок", "Frame border"), kind = "border",
                default = 1, apply = call("ApplyPanelMedia") },
        } },
        { title = L("Цвета", "Colours"), apply = call("ApplyColors"), options = {
            { "color", "ufChromeColor", L("Оправа игрока и цели", "Player and target chrome"), default = { 0.93, 0.89, 0.82 },
                apply = call("ApplyColors") },
            { "color", "ufRingColor", L("Кольцо портрета", "Portrait ring"), default = { 0.92, 0.73, 0.45 },
                apply = call("ApplyColors") },
            { "color", "ufAggroColor", L("Оправа при агро", "Chrome while holding aggro"), default = { 1, 0.18, 0.08 },
                apply = call("ApplyColors") },
            { "color", "ufPanelColor", L("Подложка полос", "Bar backdrop"), alpha = true,
                default = { 0.13, 0.085, 0.048, 0.30 }, apply = call("ApplyColors") },
            { "color", "ufDividerColor", L("Разделитель полос", "Bar divider"), alpha = true,
                default = { 157 / 255, 125 / 255, 84 / 255, 0.9 }, apply = call("ApplyColors") },
            { "color", "ufTargetNameColor", L("Имя цели", "Target name"), default = { 1, 0.82, 0.44 },
                apply = call("ApplyVisibility") },
            { "toggle", "ufManaRecolor", L("Свой цвет маны", "Custom mana colour"), default = true, apply = call("ApplyColors") },
            { "color", "ufManaColor", L("Цвет маны", "Mana colour"), default = { 0.25, 0.57, 1 }, depends = "ufManaRecolor",
                apply = call("ApplyColors") },
        } },
        { title = L("Элементы", "Elements"), options = {
            { "toggle", "ufTargetAccent", L("Подсветка имени цели по реакции", "Reaction tint behind the target name"),
                default = true, apply = call("ApplyVisibility") },
            { "toggle", "ufEliteDragon", L("Дракон элиты / редкого / босса", "Elite, rare and boss dragon"),
                default = true, apply = call("ApplyVisibility") },
            { "toggle", "ufDeathIcon", L("Череп на мёртвой цели", "Skull on a dead target"), default = true,
                apply = call("ApplyVisibility") },
            { "toggle", "ufRestIcon", L("Значок отдыха игрока", "Player resting icon"), default = true,
                apply = call("ApplyVisibility") },
            { "toggle", "ufShowPvP", L("Значок PvP", "PvP icon"), default = false, apply = call("ApplyVisibility") },
            { "range", "ufTargetAuraOffset", L("Отступ аур под целью", "Target aura offset"), min = 0, max = 40, step = 1,
                default = 10, suffix = " px", apply = call("ApplyVisibility") },
        } },
    },
})
