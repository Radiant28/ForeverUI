local _, ui = ...
local L = ui.L

ui.RegisterOptions("merchant", {
    title = L("Продажа мусора", "Sell junk"),
    description = L("Кнопка у торговца и автопродажа серых предметов. Правила: /fujunk.",
        "Merchant button and automatic sale of grey items. Rules: /fujunk."),
    icon = "Interface\\Icons\\INV_Misc_Coin_02",
    group = "items", order = 30,
    apply = function() if ui.Merchant then ui.Merchant.Apply() end end,
    sections = {
        { title = L("Продажа", "Selling"), options = {
            { "toggle", "junkButton", L("Кнопка у торговца", "Merchant button"), default = true },
            { "toggle", "junkAuto", L("Автопродажа при открытии торговца", "Sell automatically at merchants"), default = false,
                tooltip = L("Не срабатывает, если загружен аддон SellJunk.", "Skipped while the SellJunk addon is loaded.") },
            { "toggle", "junkMax12", L("Ограничить число стаков за раз", "Limit stacks per sale"), default = false,
                tooltip = L("Защищает от отката продаж сервером при большом количестве предметов.",
                    "Prevents the server from dropping sales when there are many items.") },
            { "range", "junkLimit", L("Стаков за одну продажу", "Stacks per sale"), min = 1, max = 60, step = 1, default = 12,
                depends = "junkMax12" },
        } },
        { title = L("Чат", "Chat"), options = {
            { "toggle", "junkVerbose", L("Список проданных предметов", "List sold items"), default = true },
            { "toggle", "junkSummary", L("Итоговая сумма", "Total amount"), default = true },
        } },
    },
})
