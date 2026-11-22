local _, ui = ...
local L = ui.L

ui.RegisterOptions("chat", {
    title = L("Окна чата", "Chat windows"),
    description = L("Автоматические вкладки «Группа/Рейд», «Добыча» и «Гильдия». /fuichat — что показывает каждая вкладка.",
        "Automatic Party/Raid, Loot and Guild tabs. /fuichat lists what every tab shows."),
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
            { "toggle", "chatGeneralClean", L("«Общий» без группы, рейда и добычи", "General without party, raid and loot"),
                default = true, tooltip = L("Эти сообщения остаются во вкладках «Группа/Рейд» и «Добыча».",
                    "These messages stay in the Party/Raid and Loot tabs.") },
            { "toggle", "chatKeepChannels", L("Не терять каналы в «Общем»", "Keep channels in General"),
                default = true, tooltip = L("Канал, в котором вы состоите, но который не показывает ни одна вкладка, "
                    .. "возвращается в «Общий» (после входа, /reload и загрузочного экрана). Канал, убранный вами "
                    .. "в настройках вкладки «Общий», не возвращается.",
                    "A channel you are in that no tab shows goes back to General (after login, /reload and loading "
                    .. "screens). A channel you untick in the General tab settings stays out.") },
            { "toggle", "chatGroupWindow", L("Группа/Рейд", "Party/Raid"), default = true },
            { "toggle", "chatGuildWindow", L("Гильдия", "Guild"), default = true },
            { "toggle", "chatLootWindow", L("Добыча", "Loot"), default = true },
            { "toggle", "chatLootRollsOnly", L("Во вкладке «Добыча» только броски", "Loot tab shows rolls only"),
                default = false, depends = "chatLootWindow" },
            { "toggle", "chatLootMoney", L("Золото с добычи, если сервер о нём не пишет", "Looted money when the server is silent"),
                default = true, depends = "chatLootWindow",
                tooltip = L("Аддон сам пишет во вкладку «Добыча», сколько денег пришло при открытом окне добычи.",
                    "The addon writes the money gained with the loot window open to the Loot tab.") },
        } },
    },
})

ui.RegisterOptions("loot", {
    title = L("Окно добычи", "Loot window"),
    description = L("Вид окна добычи и анимация появления и исчезновения.", "Loot window look and reveal and fade animation."),
    icon = "Interface\\Icons\\INV_Misc_Bag_10_Green",
    group = "items", order = 40,
    sections = {
        { title = L("Вид", "Look"), apply = function() if ui.Loot then ui.Loot.Apply() end end, options = {
            { "toggle", "lootForeverCards", L("Карточки предметов WoW Forever", "WoW Forever item cards"), default = true,
                tooltip = L("Фон, обводка и подсветка строк добычи из текстур WoW Forever. Выкл. — карточки клиента.",
                    "Background, outline and highlight of loot rows from WoW Forever textures. Off: the client's cards.") },
            { "toggle", "lootQualityBorder", L("Обводка цветом качества", "Outline in quality colour"), default = true,
                depends = "lootForeverCards" },
        } },
        { title = L("Анимация", "Animation"), options = {
            { "range", "lootFadeDuration", L("Длительность", "Duration"), min = 0.15, max = 1.5, step = 0.05, default = 0.3,
                suffix = L(" с", " s") },
            { "range", "lootFlyDistance", L("Дальность вылета предмета", "Item fly-out distance"), min = 0, max = 300,
                step = 5, default = 100, suffix = " px" },
        } },
    },
})

ui.RegisterOptions("chaticons", {
    title = L("Иконки в чате", "Chat icons"),
    description = L("Иконка предмета перед ссылкой в чате и в сообщениях о добыче.",
        "Item icon in front of item links in chat and loot messages."),
    icon = "Interface\\Icons\\INV_Misc_Gem_01",
    group = "social", order = 20,
    enable = "chatLootIcons",
    sections = {
        { options = {
            { "toggle", "chatLootIcons", L("Иконки предметов в чате", "Item icons in chat"), default = true,
                tooltip = L("Действует на новые сообщения.", "Applies to new messages.") },
            { "range", "chatLootIconSize", L("Размер иконки", "Icon size"), min = 10, max = 32, step = 1,
                default = 15, suffix = " px" },
        } },
    },
})
