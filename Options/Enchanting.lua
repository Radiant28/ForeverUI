local _, ui = ...
local L = ui.L
local function apply() if ui.Enchanting then ui.Enchanting.Apply() end end

ui.RegisterOptions("enchanting", {
    title = L("Наложение чар", "Enchanting"),
    description = L("Распыление выбранных предметов из сумки и переналожение чар на один предмет. Диагностика: /fuienchant.",
        "Disenchant hand-picked bag items and repeat an enchant on one item. Diagnostics: /fuienchant."),
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
            }, tooltip = L("Назначается только на время распыления или переналожения и после снимается. Каждое нажатие — следующий предмет, «Да» в окне замены чар или «Дальше»; пока идёт каст, нажатия ничего не делают (персонаж не прыгает и не сбивает каст).",
                "Bound only while disenchanting or re-enchanting, then released. Each press does the next item, \"Yes\" in the replace dialog or \"Next\"; presses during a cast do nothing (no jump, the cast is not interrupted).") },
        } },
        { title = L("Распыление", "Disenchanting"), options = {
            { "toggle", "enchantDisenchantButton", L("Кнопка распыления в сумке", "Disenchant button in bags"), default = true,
                tooltip = L("Клик — режим выбора: отметьте предметы и подтвердите. Дальше каждый клик по кнопке или нажатие клавиши сессии распыляет следующий предмет: клиент разрешает каст только по клику или клавише.",
                    "Click to pick items, then confirm. Each further click or session key press disenchants the next item: the client allows a cast only from a click or key press.") },
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
