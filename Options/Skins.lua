local _, ui = ...
local L = ui.L
local function applyWindows() if ui.WindowSkin then ui.WindowSkin.Apply() end end

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
