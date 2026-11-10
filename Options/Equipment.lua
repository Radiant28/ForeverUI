local _, ui = ...
local L = ui.L
local labels = ui.ItemLabels
local function apply() ui.ItemLabels.Apply() end

local function indexed(list)
    local values = {}
    for i, value in ipairs(list) do values[i] = { i, tostring(value) } end
    return values
end

local outlines = { { 1, L("Без обводки", "None") }, { 2, L("Тонкая", "Thin") }, { 3, L("Толстая", "Thick") } }

-- One section per label: the same eight settings for equipment and bag slots.
local function labelSection(key, title)
    local spec = labels.defaults[key]
    local options = {
        { "media", key .. "Font", L("Шрифт", "Font"), kind = "font", ignoreGlobal = true, default = 1 },
        { "select", key .. "Size", L("Размер", "Size"), values = indexed(spec.bag and labels.bagSizes or labels.sizes),
            default = spec.size },
        { "select", key .. "Point", L("Положение на ячейке", "Anchor on slot"), values = indexed(labels.pointNames),
            default = spec.point },
        { "select", key .. "Outline", L("Обводка", "Outline"), values = outlines, default = 2 },
        { "range", key .. "X", L("Смещение X", "Horizontal offset"), min = -40, max = 40, step = 1, default = spec.x },
        { "range", key .. "Y", L("Смещение Y", "Vertical offset"), min = -40, max = 40, step = 1, default = spec.y },
    }
    if spec.durability then
        options[#options + 1] = { "toggle", key .. "AutoColor", L("Цвет по прочности", "Colour by durability"), default = true }
        options[#options + 1] = { "color", key .. "Color", L("Свой цвет", "Custom colour"), default = spec.color,
            depends = "!" .. key .. "AutoColor" }
    else
        options[#options + 1] = { "color", key .. "Color", L("Цвет текста", "Text colour"), default = spec.color }
    end
    return { title = title, apply = apply, options = options }
end

ui.RegisterOptions("labels", {
    title = L("Подписи предметов", "Item labels"),
    description = L("Уровень предмета и прочность в окне персонажа и в сумках.",
        "Item level and durability on the character sheet and in bags."),
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    group = "items", order = 20,
    sections = {
        { title = L("Окно персонажа", "Character sheet"), options = {
            { "toggle", "equipLabels", L("Подписи на экипировке", "Labels on equipment"), default = true, apply = apply },
        } },
        labelSection("level", L("Персонаж · уровень предмета", "Character · item level")),
        labelSection("durability", L("Персонаж · прочность", "Character · durability")),
        labelSection("bagsLevel", L("Сумки · уровень предмета", "Bags · item level")),
        labelSection("bagsDurability", L("Сумки · прочность", "Bags · durability")),
    },
})
