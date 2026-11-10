local _, ui = ...
local L = ui.L

ui.RegisterOptions("chat", {
    title = L("Окна чата", "Chat windows"),
    description = L("Автоматические вкладки «Группа/Рейд», «Добыча» и «Гильдия».",
        "Automatic Party/Raid, Loot and Guild tabs."),
    icon = "Interface\\Icons\\INV_Letter_15",
    group = "social", order = 10,
    enable = "chatManage",
    apply = function() if ui.Chat then ui.Chat.Apply() end end,
    sections = {
        { options = {
            { "toggle", "chatManage", L("Управлять вкладками чата", "Manage chat tabs"), default = true,
                tooltip = L("Уже созданные вкладки не удаляются при выключении.", "Existing tabs stay when turned off.") },
        } },
        { title = L("Вкладки", "Tabs"), options = {
            { "toggle", "chatGroupWindow", L("Группа/Рейд", "Party/Raid"), default = true },
            { "toggle", "chatGuildWindow", L("Гильдия", "Guild"), default = true },
            { "toggle", "chatLootWindow", L("Добыча", "Loot"), default = true },
            { "toggle", "chatLootRollsOnly", L("Во вкладке «Добыча» только броски", "Loot tab shows rolls only"),
                default = true, depends = "chatLootWindow" },
        } },
    },
})

ui.RegisterOptions("loot", {
    title = L("Окно добычи", "Loot window"),
    description = L("Анимация появления и исчезновения добычи.", "Loot reveal and fade animation."),
    icon = "Interface\\Icons\\INV_Misc_Bag_10_Green",
    group = "items", order = 40,
    sections = {
        { title = L("Анимация", "Animation"), options = {
            { "range", "lootFadeDuration", L("Длительность", "Duration"), min = 0.15, max = 1.5, step = 0.05, default = 0.3,
                suffix = L(" с", " s") },
            { "range", "lootFlyDistance", L("Дальность вылета предмета", "Item fly-out distance"), min = 0, max = 300,
                step = 5, default = 100, suffix = " px" },
        } },
    },
})
