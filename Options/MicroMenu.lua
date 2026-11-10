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
        } },
    },
})
