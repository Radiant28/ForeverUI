local _, ui = ...
local L = ui.L
local function relayout() if ui.Bags then ui.Bags.Relayout() end end
local function refresh() if ui.Bags then ui.Bags.Refresh() end end

ui.RegisterOptions("bags", {
    title = L("Единая сумка", "Combined bags"),
    description = L("Все сумки и банк в одном окне.", "Every bag and the bank in one window."),
    icon = "Interface\\Icons\\INV_Misc_Bag_08",
    group = "items", order = 10,
    enable = "bagsEnabled",
    unavailable = function()
        if IsAddOnLoaded("Bagnon") then
            return L("Модуль отключён: загружен Bagnon.", "The module is off because Bagnon is loaded.")
        end
    end,
    sections = {
        { title = L("Модуль", "Module"), options = {
            { "toggle", "bagsEnabled", L("Единая сумка WoW: Forever", "WoW: Forever combined bags"), default = true,
                reload = true },
            { "button", L("Подписи уровня и прочности…", "Item level and durability labels…"),
                func = function() ui.OpenOptions("labels") end },
        } },
        { title = L("Сетка", "Grid"), apply = relayout, options = {
            { "range", "bagsCellSize", L("Размер ячейки", "Slot size"), min = 26, max = 48, step = 1, default = 36, suffix = " px" },
            { "range", "bagsColumns", L("Предпочтительное число столбцов", "Preferred columns"), min = 1, max = 24, step = 1,
                default = 12 },
            { "range", "bagsRows", L("Предел рядов (0 — авто)", "Row limit (0 = auto)"), min = 0, max = 32, step = 1,
                default = 0 },
            { "toggle", "bagsGrouped", L("Отдельный блок для каждой сумки", "Separate bags into sections"), default = true },
        } },
        { title = L("Подписи", "Labels"), apply = refresh, options = {
            { "toggle", "bagsItemLevel", L("Уровень предмета", "Item level"), default = true },
            { "toggle", "bagsDurability", L("Прочность предметов", "Durability"), default = true },
            { "toggle", "bagsGearOnly", L("Только для экипировки", "Gear only"), default = false,
                depends = function(get) return get("bagsItemLevel") or get("bagsDurability") end,
                tooltip = L("Уровень и прочность показываются только на надеваемых предметах.",
                    "Item level and durability are shown on equippable items only.") },
        } },
        { title = L("Подсветка", "Highlights"), apply = refresh, options = {
            { "toggle", "bagsHighlightRare", L("Подсветка по качеству", "Highlight by quality"), default = true },
            { "range", "bagsHighlightBrightness", L("Яркость подсветки", "Highlight brightness"), min = 10, max = 100, step = 1,
                default = 50, suffix = "%", depends = "bagsHighlightRare" },
            { "toggle", "bagsHighlightQuest", L("Значок «!» на квестовых предметах", "Quest item mark"), default = true },
            { "range", "bagsQuestBadgeSize", L("Размер квестового значка", "Quest mark size"), min = 10, max = 24, step = 1,
                default = 16, depends = "bagsHighlightQuest" },
            { "toggle", "bagsJunkIcon", L("Монетка на сером мусоре", "Coin on grey junk"), default = true },
        } },
    },
})
