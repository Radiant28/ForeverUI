-- Options page of the low healer mana alert (HealerMana.lua). Values live flat in ui.Settings().
local _, ui = ...
local L = ui.L

local function HM() return ui.HealerMana end
local function apply() if HM() then HM().Apply() end end

local function sounds()
    if ui.Suite and ui.Suite.SoundItems then return ui.Suite.SoundItems() end
    return { { "", L("Без звука", "None") }, { "RaidWarning", L("Рейдовое предупреждение", "Raid warning") } }
end

ui.RegisterOptions("healermana", {
    title = L("Мана хила", "Healer mana"),
    description = L("Баннер, когда у хила группы мало маны. Хил с ForeverUI сообщает о себе сам (сообщение аддона), "
        .. "хилы без аддона проверяются по мане вашей подгруппы. Самому хилу оповещение не показывается.",
        "A banner when a healer of the group runs low on mana. A healer with ForeverUI reports itself (addon "
        .. "message), healers without it are checked by the mana of your subgroup. The healer never sees its own alert."),
    icon = "Interface\\Icons\\INV_Drink_18",
    group = "combat", order = 25,
    enable = "hmEnabled",
    apply = apply,
    sections = {
        { options = {
            { "toggle", "hmEnabled", L("Оповещать о низкой мане хила", "Alert on low healer mana"), default = true,
                width = "full", tooltip = L("Выключено — аддон не шлёт и не показывает оповещения.",
                    "Off: the addon neither sends nor shows alerts.") },
            { "range", "hmThreshold", L("Порог маны", "Mana threshold"), min = 10, max = 50, step = 1, default = 25,
                suffix = "%", tooltip = L("Хил сообщает, когда его мана ниже его порога; баннер показывается, если "
                    .. "мана ниже и вашего порога. Повтор — только после восстановления выше 40% и не чаще раза в 18 с.",
                    "A healer reports when its mana drops below its own threshold; the banner shows when the mana is "
                    .. "below yours too. It repeats only after the mana climbs above 40%, at most once per 18 s.") },
            { "select", "hmScope", L("Область в рейде", "Raid area"), default = "group", values = {
                { "group", L("Только моя группа", "My group only") }, { "raid", L("Весь рейд", "Whole raid") } },
                tooltip = L("Хилы без ForeverUI всегда проверяются только в вашей подгруппе.",
                    "Healers without ForeverUI are always checked in your subgroup only.") },
            { "select", "hmSound", L("Звук", "Sound"), default = "RaidWarning", values = sounds },
            { "range", "hmFontSize", L("Размер шрифта", "Font size"), min = 10, max = 28, step = 1, default = 15 },
            { "range", "hmDuration", L("Длительность показа", "Display time"), min = 1, max = 10, step = 0.5, default = 4,
                suffix = L(" с", " s") },
            { "button", L("Тест оповещения", "Test the alert"), func = function() if HM() then HM().Test() end end },
            { "button", L("Переместить (режим редактирования)", "Move (Edit Mode)"), func = function()
                if ui.EditMode and ui.EditMode.Open then ui.EditMode.Open() end
            end },
        } },
    },
})
