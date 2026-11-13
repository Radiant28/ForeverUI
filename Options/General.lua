local _, ui = ...
local L = ui.L

ui.RegisterOptions("general", {
    title = L("Общие", "General"),
    description = L("Окно настроек и обслуживание аддона. Команда: /fui [раздел].",
        "The settings window and maintenance. Command: /fui [section]."),
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    group = "general", order = 1,
    sections = {
        { title = L("Окно настроек", "Settings window"), options = {
            { "range", "optionsScale", L("Масштаб окна", "Window scale"), min = 50, max = 160, step = 5, default = 100,
                suffix = "%", apply = function() ui.ApplyOptionsWindowScale() end,
                tooltip = L("Размер окна (ширина и высота) меняется ПКМ: зажмите на заголовке окна и тяните.",
                    "The window size (width and height) changes with a right drag on the window header.") },
        } },
        { title = L("Обслуживание", "Maintenance"), options = {
            { "button", L("Перезагрузить интерфейс", "Reload UI"), func = ReloadUI },
            { "button", L("Сбросить все настройки…", "Reset all settings…"), func = function()
                StaticPopup_Show("FOREVERUI_RESET_ALL")
            end, tooltip = L("Возвращает все разделы к значениям по умолчанию и перезагружает интерфейс.",
                "Restores every section to defaults and reloads the interface.") },
            { "description", L("Позиции, перемещённые в режиме редактирования, сбрасываются кнопкой «Сбросить все позиции» в самом режиме.",
                "Positions moved in Edit Mode are reset with “Reset all positions” inside Edit Mode.") },
        } },
    },
})
