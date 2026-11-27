local _, ui = ...
local L = ui.L
local function apply() if ui.ActionBars then ui.ActionBars.Apply() end end

ui.RegisterOptions("actionbars", {
    title = L("Панели действий", "Action bars"),
    description = L("Грифоны, оправа ячеек и оттенок штатной панели. Расположение — в режиме редактирования.",
        "Gryphons, slot frames and the main bar tint. Positions live in Edit Mode."),
    icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
    group = "frames", order = 30,
    apply = apply,
    sections = {
        { title = L("Оформление", "Styling"), options = {
            { "toggle", "showGryphons", L("Грифоны по краям", "Gryphons at the ends"), default = true },
            { "toggle", "barArtHidden", L("Без фона панелей и грифонов", "No bar background or gryphons"), default = false,
                tooltip = L("Остаются только кнопки: без фона основной панели, панелей стоек, питомца и подчинения и без грифонов. То же — в режиме редактирования.",
                    "Only the buttons stay: no background of the main, stance, pet and possess bars, no gryphons. Also in Edit Mode.") },
            { "color", "barArtColor", L("Оттенок панели и грифонов", "Bar and gryphon tint"), default = { 1, 0.84, 0.65 } },
            { "toggle", "barStockTint", L("Оттенок на фоне штатной панели", "Tint the stock bar background"), default = false,
                tooltip = L("Прежний вид: фон панели перекрашивается оттенком панели. Выключено — штатные цвета Blizzard.",
                    "The former look: the bar background takes the bar tint. Off — the plain Blizzard colours.") },
            { "toggle", "barSlotEdges", L("Оправа ячеек", "Slot frames"), default = true },
            { "toggle", "barSlotBackgrounds", L("Фон ячеек с крыльями (основная панель)", "Winged slot backgrounds (main bar)"),
                default = true },
            { "toggle", "barProgressBorder", L("Рамка полосы репутации", "Reputation bar border"), default = true },
        } },
        { title = L("Расположение", "Layout"), options = {
            { "button", L("Раскладка Retail", "Retail layout"), func = function()
                if ui.EditMode then ui.EditMode.ApplyLayout("retail") end
            end, tooltip = L("Панели по центру внизу в стопку, полоса опыта под ними, стойки, питомец и тотемы сверху.",
                "Bars stacked bottom-centre, the XP bar below, stance, pet and totem bars on top.") },
            { "button", L("Классическая раскладка", "Classic layout"), func = function()
                if ui.EditMode then ui.EditMode.ApplyLayout("classic") end
            end },
            { "button", L("Открыть режим редактирования", "Open Edit Mode"), func = function()
                if ui.EditMode then ui.EditMode.Open() end
            end },
            { "button", L("Назначить клавиши ячейкам", "Bind keys to slots"), func = function()
                if not ui.KeyBinder then
                    ui.Print(L("Модуль назначения клавиш не загружен: полностью перезапустите игру.",
                        "The key binding module is not loaded: restart the game completely."))
                    return
                end
                if ForeverUIOptions then ForeverUIOptions:Hide() end
                ui.KeyBinder.Start()
            end, tooltip = L("Наведите курсор на ячейку и нажмите клавишу. То же: кнопка «Remap» в игровом меню или /fuibind.",
                "Hover a slot and press a key. Same as the “Remap” game menu button or /fuibind.") },
            { "button", L("Штатные настройки панелей", "Stock action bar settings"), func = function()
                if ForeverUIOptions then ForeverUIOptions:Hide() end
                ui.OpenOptions(InterfaceOptionsActionBarsPanel)
            end },
        } },
    },
})
