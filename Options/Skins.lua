local _, ui = ...
local L = ui.L
local function applyWindows()
    if ui.WindowSkin then ui.WindowSkin.Apply() end
    if ui.BagAero then ui.BagAero.Apply() end
end

-- The Skins page holds only checkboxes, one per window or element, like ElvUI's list of Blizzard skins.
-- Windows come from WindowSkin.lua (RECIPES with a key and a label): a window added there gets its checkbox here
-- without touching this file. The fine-tuning values of a window (outsets, thickness, title offset, parts) are
-- fixed in WindowSkin.lua and not shown here.
local options = {
    { "toggle", "foreverWindows", L("Скины WoW Forever", "WoW Forever skins"), default = true, width = "full" },
}
local WS = ui.WindowSkin
for _, name in ipairs(WS and WS.Order or {}) do
    local recipe = WS.Recipes[name]
    if recipe.key and recipe.label then
        options[#options + 1] = { "toggle", recipe.key, L(recipe.label[1], recipe.label[2]), default = true,
            depends = "foreverWindows" }
    end
end
-- Elements reskinned in every window (SkinExtras.lua); turning them off takes effect after /reload.
options[#options + 1] = { "toggle", "skinPanelButtons", L("Кнопки окон", "Window buttons"), default = true,
    reload = true, apply = false, depends = "foreverWindows" }
options[#options + 1] = { "toggle", "skinTalents", L("Фоны талантов", "Talent backgrounds"), default = true,
    reload = true, apply = false, depends = "foreverWindows" }
-- Own chat bubbles above the ForeverUI nameplates (ChatBubbles.lua): bronze WoW look, no other settings.
options[#options + 1] = { "toggle", "bubblesEnabled", L("Облачка сообщений над неймплейтами", "Chat bubbles above nameplates"),
    default = true, apply = function() if ui.ChatBubbles then ui.ChatBubbles.Apply() end end,
    tooltip = L("Бронзовое облачко над плашкой говорящего: «сказать», крик, группа, рейд и речь NPC. Камень сверху — "
        .. "цвет канала, золотое свечение — сообщение с вашим именем. Облачка клиента (над своим персонажем и игроками "
        .. "без плашки) оформляются так же. Нужны неймплейты ForeverUI.",
        "A bronze bubble above the speaker's plate: say, yell, party, raid and NPC speech. The gem on top is the "
        .. "channel colour, a gold glow marks a message with your name. The client's bubbles (above your character "
        .. "and players without a plate) get the same look. Needs the ForeverUI nameplates.") }
-- Animated emote medallions above the ForeverUI nameplates (ChatEmotes.lua), no other settings.
options[#options + 1] = { "toggle", "emotesEnabled", L("Эмоции над неймплейтами", "Emotes above nameplates"),
    default = true, apply = function() if ui.ChatEmotes then ui.ChatEmotes.Apply() end end,
    tooltip = L("Бронзовый медальон с анимацией над плашкой персонажа при встроенной эмоции (/смех, /танец, /плакать "
        .. "и ещё 13). Рядом с облачком сообщения, если оно есть. /fuiemote test — пример над целью. "
        .. "Нужны неймплейты ForeverUI.",
        "An animated bronze medallion above a character's plate on a built-in emote (/laugh, /dance, /cry and 13 "
        .. "more), on the chat bubble when there is one. /fuiemote test shows an example above the target. "
        .. "Needs the ForeverUI nameplates.") }
ui.RegisterOptions("skins", {
    title = L("Скины", "Skins"),
    description = L("Окна клиента в стиле WoW Forever: отметьте окна, к которым применяется скин.",
        "The client's windows in WoW Forever style: tick the windows the skin applies to."),
    icon = "Interface/Icons/INV_Misc_Book_09",
    group = "items", order = 35,
    apply = applyWindows,
    sections = {
        { options = options },
    },
})
