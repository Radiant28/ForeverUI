local _, ui = ...
local L = ui.L
local function apply() if ui.Tooltip then ui.Tooltip.Apply() end end

ui.RegisterOptions("tooltip", {
    title = L("Подсказки", "Tooltips"),
    description = L("Положение подсказок и их показ в бою. Якорь переносится в режиме редактирования.",
        "Tooltip position and combat visibility. The anchor is moved in Edit Mode."),
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    group = "general", order = 35,
    apply = apply,
    sections = {
        { title = L("Положение", "Position"), options = {
            { "select", "tooltipPosition", L("Привязка", "Anchor"), default = "anchor",
                values = {
                    { "anchor", L("К якорю (режим редактирования)", "To anchor (Edit Mode)") },
                    { "cursor", L("К курсору", "To cursor") },
                },
                tooltip = L("Подсказка появляется у курсора или в месте якоря, который переносится в режиме редактирования.",
                    "The tooltip follows the cursor or sits at the anchor moved in Edit Mode.") },
            { "range", "tooltipCursorX", L("Смещение по горизонтали", "Horizontal offset"), min = -200, max = 200,
                step = 1, default = 16, suffix = " px", depends = function() return ui.GetOption("tooltip", "tooltipPosition") == "cursor" end,
                tooltip = L("От курсора вправо; отрицательное значение — влево.", "Right of the cursor; negative goes left.") },
            { "range", "tooltipCursorY", L("Смещение по вертикали", "Vertical offset"), min = -200, max = 200,
                step = 1, default = -16, suffix = " px", depends = function() return ui.GetOption("tooltip", "tooltipPosition") == "cursor" end,
                tooltip = L("Подсказка растёт вниз от этой точки; отрицательное значение — ниже курсора.",
                    "The tooltip hangs down from this point; negative is below the cursor.") },
            { "range", "tooltipScale", L("Масштаб", "Scale"), min = 50, max = 200, step = 5, default = 100, suffix = "%" },
        } },
        { title = L("Исчезновение", "Fade out"), options = {
            { "select", "tooltipFade", L("Скрытие подсказки", "Hiding"), default = "default",
                values = {
                    { "default", L("Штатное", "Default") },
                    { "instant", L("Мгновенно", "Instant") },
                    { "custom", L("Своя скорость", "Custom speed") },
                } },
            { "range", "tooltipFadeTime", L("Время затухания", "Fade time"), min = 0.05, max = 1.5, step = 0.05,
                default = 0.3, suffix = L(" с", " s"),
                depends = function() return ui.GetOption("tooltip", "tooltipFade") == "custom" end,
                tooltip = L("Клиент сам скрывает подсказку по окончании штатного затухания, поэтому слишком большое время может обрезаться.",
                    "The client hides the tooltip when its own fade ends, so very long times may be cut short.") },
        } },
        { title = L("В бою", "In combat"), options = {
            { "select", "tooltipCombat", L("Подсказки в бою", "Tooltips in combat"), default = "show",
                values = {
                    { "show", L("Показывать все", "Show all") },
                    { "units", L("Скрывать подсказки существ и игроков", "Hide unit tooltips") },
                    { "all", L("Скрывать все подсказки", "Hide all tooltips") },
                } },
            { "select", "tooltipCombatModifier", L("Показывать при зажатой клавише", "Show while holding"),
                default = "none", depends = function() return ui.GetOption("tooltip", "tooltipCombat") ~= "show" end,
                values = {
                    { "none", L("Нет", "None") },
                    { "shift", "Shift" },
                    { "ctrl", "Ctrl" },
                    { "alt", "Alt" },
                } },
        } },
    },
})
