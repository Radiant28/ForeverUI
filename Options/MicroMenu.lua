local _, ui = ...
local L = ui.L

ui.RegisterOptions("micromenu", {
    title = L("Микроменю", "Micro menu"),
    description = L("Цветные значки кнопок меню.", "Coloured micro menu icons."),
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    group = "frames", order = 40,
    enable = "microEnabled",
    sections = {
        { options = {
            { "toggle", "microEnabled", L("Значки WoW: Forever", "WoW: Forever icons"), default = true, reload = true },
            { "color", "microHoverColor", L("Подсветка при наведении", "Hover glow"), default = { 1, 0.84, 0.65 },
                apply = function() if ui.MicroMenu then ui.MicroMenu.ApplyColors() end end },
            { "range", "microSpacing", L("Отступ между кнопками (Retail)", "Button spacing (Retail)"), min = 0, max = 20,
                step = 1, default = 4, suffix = " px",
                apply = function() if ui.MicroMenu then ui.MicroMenu.ApplyLayout() end end,
                tooltip = L("Щель между кнопками; действует в раскладке Retail.", "Gap between buttons; applies in the Retail layout.") },
        } },
    },
})
