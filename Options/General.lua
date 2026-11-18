local _, ui = ...
local L = ui.L

local function setup(mode)
    return function()
        if ui.Setup and ui.Setup.Open then ui.Setup.Open(mode) end
    end
end

ui.RegisterOptions("general", {
    title = L("Общие", "General"),
    description = L("Окно настроек и обслуживание аддона. Команда: /fui [раздел].",
        "The settings window and maintenance. Command: /fui [section]."),
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    group = "general", order = 1,
    sections = {
        { title = L("Установка", "Setup"), options = {
            { "button", L("Пройти установку заново", "Run the setup again"), func = setup("full"),
                tooltip = L("Роль, стиль, масштаб, раскладка, модули и чат этого персонажа. Команда: /fui install.",
                    "Role, style, scale, layout, modules and chat of this character. Command: /fui install.") },
            { "button", L("Скопировать с другого персонажа…", "Copy from another character…"), func = setup("copy"),
                tooltip = L("Наборы талантов другого персонажа: роль, стиль, масштаб, позиции фреймов и модули.",
                    "Another character's talent sets: role, style, scale, frame positions and modules.") },
            { "description", L("Роль, стиль, масштаб, позиции фреймов и главные модули хранятся отдельно для каждого "
                .. "персонажа и набора талантов; остальные настройки общие.",
                "Role, style, scale, frame positions and the main modules are kept per character and talent set; "
                .. "every other setting is shared.") },
        } },
        { title = L("Окно настроек", "Settings window"), options = {
            { "range", "optionsScale", L("Масштаб окна", "Window scale"), min = 50, max = 160, step = 5, default = 100,
                suffix = "%", apply = function() ui.ApplyOptionsWindowScale() end,
                tooltip = L("Размер окна (ширина и высота) меняется ПКМ: зажмите на заголовке окна и тяните.",
                    "The window size (width and height) changes with a right drag on the window header.") },
        } },
        { title = L("Неймплейты", "Nameplates"), options = {
            { "toggle", "nameplatesEnabled", L("Неймплейты WoW Forever", "WoW Forever nameplates"), default = true,
                reload = true, apply = false,
                tooltip = L("Общая настройка для всех персонажей. Выкл. — полосы клиента.",
                    "Shared by every character. Off: the client's nameplates.") },
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
