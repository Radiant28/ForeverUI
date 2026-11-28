local _, ui = ...
local L = ui.L

ui.RegisterOptions("quests", {
    title = L("Квесты", "Quests"),
    description = L("Автопринятие и автосдача заданий — только при Shift + клике по квестодателю (Shift можно отпустить за 1,5 с до появления окна). Дальше весь разговор идёт сам, включая цепочки. Обычный клик — всё вручную. Пункты меню разговора не нажимаются никогда. Диагностика: /fuiquest.",
        "Quests are accepted and turned in only on Shift + click on the quest giver (Shift may be released up to 1.5 s before the window opens). The whole talk then runs by itself, chains included. A plain click leaves everything to you. Gossip options are never clicked. Diagnostics: /fuiquest."),
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    group = "general", order = 40,
    apply = function() if ui.AutoQuest then ui.AutoQuest.Apply() end end,
    sections = {
        { title = L("Автоматика", "Automation"), options = {
            { "toggle", "questAutoAccept", L("Принимать задания", "Accept quests"), default = true,
                tooltip = L("Открывает новые задания у NPC по очереди и принимает их. Цепочки берутся подряд. При полном журнале (25) останавливается и пишет в чат.",
                    "Opens new quests at the NPC one by one and accepts them. Chains are taken in a row. Stops with a chat note when the log is full (25).") },
            { "toggle", "questAutoTurnIn", L("Сдавать выполненные задания", "Turn in completed quests"), default = true,
                tooltip = L("Награду без выбора забирает сам. Если награду нужно выбрать, останавливается и подсвечивает самую дорогую у торговца — выбираете вы. Задание, которое требует золото, не сдаёт.",
                    "Takes a reward when there is nothing to choose. With a choice it stops and highlights the most valuable one at a vendor; you pick. Quests that ask for money are left to you.") },
        } },
        { title = L("Какие задания", "Which quests"), options = {
            { "toggle", "questDaily", L("Ежедневные", "Daily quests"), default = true },
            { "toggle", "questTrivial", L("Серые (низкого уровня)", "Grey (low level)"), default = false,
                tooltip = L("Выключено — серые задания не засоряют журнал. Открытое вручную серое задание принимается.",
                    "Off keeps grey quests out of the log. A grey quest you open yourself is still accepted.") },
            { "toggle", "questRepeatable", L("Повторяемые сдачи предметов", "Repeatable item hand-ins"), default = false,
                tooltip = L("Сдачи на репутацию, ткань и т.п., которых нет в журнале. Включено — аддон может отдать NPC всю стопку по одной сдаче за разговор.",
                    "Reputation, cloth and similar hand-ins that never enter the log. When on, the addon may hand in a stack, one per talk.") },
            { "toggle", "questShared", L("Задания от членов группы", "Quests shared by group members"), default = true,
                tooltip = L("Окно подтверждения эскорта аддон не нажимает: клиент разрешает это только интерфейсу Blizzard.",
                    "The escort confirmation popup is not clicked: the client allows that only to the Blizzard UI.") },
            { "toggle", "questFromItems", L("Задания, начатые с предмета", "Quests started by an item"), default = true },
        } },
        { title = L("Чат", "Chat"), options = {
            { "toggle", "questChat", L("Строки «Принято / Сдано» в чате", "\"Accepted / Turned in\" chat lines"), default = true,
                tooltip = L("Полный журнал заданий сообщается всегда.", "A full quest log is always reported.") },
        } },
    },
})
