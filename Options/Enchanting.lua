local _, ui = ...
local L = ui.L
local function apply() if ui.Enchanting then ui.Enchanting.Apply() end end

ui.RegisterOptions("enchanting", {
    title = L("Наложение чар", "Enchanting"),
    description = L("Кнопки распыления и просеивания в сумке и переналожение чар на один предмет. Диагностика: /fuienchant.",
        "Disenchant and prospecting buttons in the bags and repeating an enchant on one item. Diagnostics: /fuienchant."),
    icon = "Interface\\Icons\\Trade_Engraving",
    group = "items", order = 35,
    enable = "enchantEnabled",
    apply = apply,
    sections = {
        { title = L("Модуль", "Module"), options = {
            { "toggle", "enchantEnabled", L("Помощник наложения чар", "Enchanting helper"), default = true },
            { "toggle", "enchantChat", L("Сообщения о ходе работы в чате", "Progress messages in chat"), default = true,
                tooltip = L("Остановки и итоги пишутся всегда.", "Stops and totals are always reported.") },
        } },
        { title = L("Клавиша сессии", "Session key"), options = {
            { "select", "enchantKey", L("Клавиша", "Key"), default = "SPACE", values = {
                { "SPACE", L("Пробел", "Space") },
                { "MOUSEWHEELDOWN", L("Колесо мыши вниз", "Mouse wheel down") },
                { "MOUSEWHEELUP", L("Колесо мыши вверх", "Mouse wheel up") },
                { "ENTER", L("Enter", "Enter") },
                { "NONE", L("Не назначать", "None") },
            }, tooltip = L("Назначается только на время переналожения и после снимается. Каждое нажатие — «Да» в окне замены чар или «Дальше»; пока идёт каст, нажатия ничего не делают (персонаж не прыгает и не сбивает каст).",
                "Bound only while re-enchanting, then released. Each press is \"Yes\" in the replace dialog or \"Next\"; presses during a cast do nothing (no jump, the cast is not interrupted).") },
        } },
        { title = L("Распыление", "Disenchanting"), options = {
            { "toggle", "enchantDisenchantButton", L("Кнопка распыления в сумке", "Disenchant button in bags"), default = true,
                tooltip = L("Слева от крестика сумки; без профессии «Наложение чар» кнопки нет. Клик — курсор распыления, затем кликните по предмету. Пока курсор активен, предметы, которые нельзя распылить, затемнены (и при распылении из книги заклинаний).",
                    "Left of the bag close cross; without Enchanting there is no button. Click for the disenchant cursor, then click an item. While the cursor is up, items that cannot be disenchanted are dimmed (also with Disenchant from the spellbook).") },
            { "toggle", "enchantProspectButton", L("Кнопка просеивания в сумке", "Prospecting button in bags"), default = true,
                tooltip = L("Слева от кнопки распыления (или от крестика, если её нет); без профессии «Ювелирное дело» кнопки нет. Клик — курсор просеивания, затем кликните по руде. Пока курсор активен, всё, что нельзя просеять (не руда или меньше 5 штук), затемнено.",
                    "Left of the disenchant button (or of the cross without it); without Jewelcrafting there is no button. Click for the prospecting cursor, then click an ore. While the cursor is up, everything that cannot be prospected (not an ore, or fewer than 5) is dimmed.") },
        } },
        { title = L("Переналожение", "Re-enchanting"), options = {
            { "toggle", "enchantReenchant", L("Кнопка «Повторить» в окне профессии", "\"Repeat\" button in the profession window"),
                default = true },
            { "toggle", "enchantAutoChain", L("Следующий повтор без клика", "Next repeat without a click"), default = true,
                depends = "enchantReenchant",
                tooltip = L("Если клиент этого не позволяет, сессия сама перейдёт на «Дальше» по клику.",
                    "If the client refuses, the session switches to a \"Next\" click per repeat.") },
            { "toggle", "enchantKeyConfirm", L("Клавиша сессии подтверждает замену чар", "Session key confirms enchant replacement"),
                default = true, depends = "enchantReenchant",
                tooltip = L("Только пока идёт переналожение: клавиша нажимает «Да» в окне замены чар. Сам аддон окно не трогает — клиент разрешает это только интерфейсу Blizzard. Окно привязки предмета всегда подтверждаете вы.",
                    "Only while a repeat session runs: the key presses \"Yes\" in the replace dialog. The addon never touches the dialog itself; the client allows that only to the Blizzard UI. The bind-on-enchant dialog is always left to you.") },
        } },
    },
})
