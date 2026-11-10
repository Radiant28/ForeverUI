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
            { "color", "barArtColor", L("Оттенок панели и грифонов", "Bar and gryphon tint"), default = { 1, 0.84, 0.65 } },
            { "toggle", "barSlotEdges", L("Оправа ячеек", "Slot frames"), default = true },
            { "toggle", "barSlotBackgrounds", L("Фон пустых ячеек", "Empty slot backgrounds"), default = true },
            { "toggle", "barProgressBorder", L("Рамка полосы репутации", "Reputation bar border"), default = true },
        } },
        { title = L("Расположение", "Layout"), options = {
            { "button", L("Открыть режим редактирования", "Open Edit Mode"), func = function()
                if ui.EditMode then ui.EditMode.Open() end
            end },
            { "button", L("Штатные настройки панелей", "Stock action bar settings"), func = function()
                if ForeverUIOptions then ForeverUIOptions:Hide() end
                ui.OpenOptions(InterfaceOptionsActionBarsPanel)
            end },
        } },
    },
})
