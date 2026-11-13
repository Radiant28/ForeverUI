local _, ui = ...
local L = ui.L

ui.RegisterOptions("characterskin", {
    title = L("Тёплые окна", "Warm windows"),
    description = L("Тёплый бронзовый оттенок текстур окон. Положение и функции элементов не меняются.",
        "Warm bronze tint on window textures. Positions and behaviour are unchanged."),
    icon = "Interface/Icons/INV_Misc_Book_09",
    group = "items", order = 35,
    apply = function() if ui.CharacterSkin then ui.CharacterSkin.Apply() end end,
    sections = {
        { title = L("Вид", "Look"), options = {
            { "toggle", "characterSkin", L("Тёплый оттенок окон", "Warm window tint"), default = true },
        } },
    },
})
