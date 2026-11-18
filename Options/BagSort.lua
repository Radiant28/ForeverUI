local _, ui = ...
local L = ui.L
local function start(mode) return function() if ui.BagSort then ui.BagSort.Start(mode) end end end

ui.RegisterOptions("bagsort", {
    title = L("Сортировка сумок", "Bag sorting"),
    description = L("Сортировка сумок и банка по кнопке: стопки объединяются, реагенты, руда, травы, самоцветы, "
        .. "боеприпасы и осколки душ сначала ложатся в подходящие профессиональные сумки, серые предметы — в конец.",
        "Sorts the bags and the bank on a button: stacks merge, reagents, ore, herbs, gems, ammo and soul shards go "
        .. "into matching profession bags first, grey items go last."),
    icon = "Interface\\Icons\\INV_Misc_Bag_10",
    group = "items", order = 11,
    enable = "bagSortEnabled",
    sections = {
        { title = L("Модуль", "Module"), options = {
            { "toggle", "bagSortEnabled", L("Сортировка сумок и банка", "Bag and bank sorting"), default = true,
                reload = true, tooltip = L("Кнопки в окне сумок и банка, команда /fuisort и клавиша в меню назначения клавиш.",
                    "Buttons in the bag and bank windows, /fuisort and a key binding.") },
        } },
        { title = L("Порядок", "Order"), options = {
            { "toggle", "bagSortReverse", L("Заполнять с конца (свободные ячейки в начале)",
                "Fill from the end (free slots first)"), default = false },
            { "toggle", "bagSortJunkLast", L("Серые предметы в конец", "Grey items last"), default = true },
        } },
        { title = L("Скорость", "Speed"), options = {
            { "range", "bagSortBatch", L("Перемещений за раз", "Moves at once"), min = 1, max = 5, step = 1, default = 2,
                tooltip = L("Сколько перемещений отправлять серверу, не дожидаясь ответа. Если сервер теряет "
                    .. "перемещения или пишет об ошибках, поставьте 1.",
                    "How many moves are sent before the server answers. If the server drops moves or reports "
                    .. "errors, set 1.") },
            { "toggle", "bagSortMessages", L("Сообщение в чат по завершении", "Chat message when done"), default = true },
        } },
        { title = L("Действия", "Actions"), options = {
            { "button", L("Отсортировать сумки", "Sort bags"), func = start("bags") },
            { "button", L("Отсортировать банк", "Sort bank"), func = start("bank") },
            { "button", L("Сложить в банк", "Stack into the bank"), func = start("deposit") },
            { "button", L("Взять из банка", "Take from the bank"), func = start("withdraw") },
        } },
    },
})
