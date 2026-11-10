local _, ui = ...
local L = ui.L
local function apply() if ui.EditMode then ui.EditMode.Apply() end end

ui.RegisterOptions("editmode", {
    title = L("Режим редактирования", "Edit Mode"),
    description = L("Перемещение и масштаб элементов интерфейса. Меню игры → «Редактирование».",
        "Move and scale interface elements. Game menu → Edit Mode."),
    icon = "Interface\\Icons\\INV_Misc_Wrench_01",
    group = "general", order = 20,
    apply = apply,
    unavailable = function()
        if not ui.EditMode then
            return L("Клиент не поддерживает кнопки в меню игры — режим редактирования недоступен.",
                "This client cannot add game menu buttons, so Edit Mode is unavailable.")
        end
    end,
    sections = {
        { options = {
            { "button", L("Открыть режим редактирования", "Open Edit Mode"), func = function()
                if ForeverUIOptions then ForeverUIOptions:Hide() end
                ui.EditMode.Open()
            end },
        } },
        { title = L("Сетка", "Grid"), options = {
            { "toggle", "editGrid", L("Показывать сетку", "Show grid"), default = false },
            { "toggle", "editSnap", L("Прилипание к сетке", "Snap to grid"), default = false },
            { "range", "editGridSpacing", L("Шаг сетки", "Grid spacing"), min = 8, max = 64, step = 4, default = 24,
                suffix = " px" },
            { "color", "editGridColor", L("Цвет линий", "Line colour"), alpha = true, default = { 0.92, 0.75, 0.48, 0.23 } },
        } },
        { title = L("Рамки элементов", "Element overlays"), options = {
            { "color", "editOverlayColor", L("Цвет подсветки", "Overlay colour"), alpha = true,
                default = { 0.26, 0.64, 0.95, 0.36 } },
        } },
    },
})
