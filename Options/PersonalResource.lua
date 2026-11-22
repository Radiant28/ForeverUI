-- Options page of the Personal Resource Display (PersonalResource.lua). Most values live in the per-spec
-- table PRD.DB() (ui.Settings().prdProfiles[talent group] or .shared); the master switch, the per-spec
-- switch and the position stay flat in ui.Settings() (opt.db = main).
local _, ui = ...
local L = ui.L

local function PRD() return ui.PersonalResource end
local function apply() if PRD() then PRD().Apply() end end
local function main() return ui.Settings() end
local function specDB() return PRD() and PRD().DB() or main() end

local textModes = {
    { "none", L("Без текста", "None") },
    { "percent", L("Проценты", "Percent") },
    { "current", L("Текущее значение", "Current value") },
    { "both", L("Текущее | процент", "Current | percent") },
    { "full", L("Текущее / максимум", "Current / maximum") },
}

ui.RegisterOptions("prd", {
    title = L("Панель ресурсов", "Personal resources"),
    description = L("Здоровье, ресурс, классовый ресурс (серия приёмов, руны, тотемы, стаки) и важные проки игрока "
        .. "под персонажем. Вне боя и в покое панель затухает.",
        "Health, power, the class resource (combo points, runes, totems, stacks) and the player's important procs "
        .. "under the character. Out of combat and at rest the panel fades out."),
    icon = "Interface\\Icons\\Spell_Holy_SealOfMight",
    group = "combat", order = 12,
    enable = "prdEnabled",
    db = specDB,
    apply = apply,
    sections = {
        { options = {
            { "toggle", "prdEnabled", L("Включить панель ресурсов", "Enable the resource panel"), default = true,
                db = main, width = "full" },
            { "toggle", "prdPerSpec", L("Отдельные настройки для каждой специализации", "Separate settings per specialization"),
                default = false, db = main, width = "full", apply = function() apply() ui.Fire("OptionsRefresh", "prd") end,
                tooltip = L("Включено — у основного и дополнительного набора талантов свои настройки (позиция общая). "
                    .. "Первый раз набор получает копию общих настроек.",
                    "On: the primary and the secondary talent set have their own settings (the position is shared). "
                    .. "A set starts as a copy of the shared settings.") },
            { "button", L("Тестовый режим (вкл / выкл)", "Test mode (on / off)"), func = function()
                if PRD() then PRD().SetTest(not PRD().test) end
            end, tooltip = L("Показывает все слои сразу: здоровье с входящим лечением и щитом, ресурс, классовые ячейки "
                .. "и пробные проки. Выключается сам при входе в бой.", "Shows every layer at once: health with incoming "
                .. "heals and a shield, power, class cells and sample procs. Turns off when combat starts.") },
            { "button", L("Переместить (режим редактирования)", "Move (Edit Mode)"), func = function()
                if ui.EditMode and ui.EditMode.Open then ui.EditMode.Open() end
            end, tooltip = L("В режиме редактирования панель видна целиком: перетащите её и задайте масштаб. "
                .. "Ползунки ниже показывают ту же позицию.", "In Edit Mode the whole panel is shown: drag it and set "
                .. "its scale. The sliders below show the same position.") },
            { "button", L("Скопировать настройки другой специализации", "Copy the other specialization's settings"),
                func = function()
                    local p = PRD()
                    if not p or not main().prdPerSpec then return end
                    p.CopyFrom(p.TalentGroup() == 1 and 2 or 1)
                end, depends = function() return main().prdPerSpec and true or false end },
            { "range", "prdX", L("Смещение по горизонтали", "Horizontal offset"), min = -800, max = 800, step = 1,
                default = 0, db = main, suffix = " px" },
            { "range", "prdY", L("Смещение по вертикали", "Vertical offset"), min = -600, max = 600, step = 1,
                default = -170, db = main, suffix = " px" },
            { "range", "prdScale", L("Масштаб", "Scale"), min = 50, max = 200, step = 5, default = 100, db = main,
                suffix = "%" },
        } },
        { title = L("Слои", "Layers"), options = {
            { "toggle", "prdShowAuras", L("Проки и баффы (над здоровьем)", "Procs and buffs (above health)"), default = true },
            { "toggle", "prdShowHealth", L("Полоса здоровья", "Health bar"), default = true },
            { "toggle", "prdShowPower", L("Полоса ресурса", "Power bar"), default = true },
            { "toggle", "prdShowClass", L("Классовый ресурс", "Class resource"), default = true },
        } },
        { title = L("Размеры и текстура", "Size and texture"), columns = 2, options = {
            { "range", "prdWidth", L("Ширина", "Width"), min = 80, max = 500, step = 1, default = 220, suffix = " px" },
            { "range", "prdHealthHeight", L("Высота здоровья", "Health height"), min = 4, max = 40, step = 1, default = 14,
                suffix = " px" },
            { "range", "prdPowerHeight", L("Высота ресурса", "Power height"), min = 2, max = 30, step = 1, default = 8,
                suffix = " px" },
            { "range", "prdPowerGap", L("Отступ ресурса от здоровья", "Power gap below health"), min = -1, max = 12, step = 1,
                default = -1, suffix = " px", tooltip = L("-1 — полосы делят общую рамку в 1 px.",
                    "-1: the bars share one 1 px border.") },
            { "range", "prdGap", L("Отступ проков от здоровья", "Gap below the procs"), min = 0, max = 20, step = 1,
                default = 3, suffix = " px" },
            { "range", "prdDruidHeight", L("Высота маны друида", "Druid mana height"), min = 2, max = 12, step = 1,
                default = 4, suffix = " px" },
            { "range", "prdClassHeight", L("Высота классовых ячеек", "Class cell height"), min = 4, max = 30, step = 1,
                default = 9, suffix = " px" },
            { "range", "prdClassGap", L("Отступ классовых ячеек", "Class cell gap"), min = -1, max = 20, step = 1,
                default = 3, suffix = " px" },
            { "range", "prdCellGap", L("Промежуток между ячейками", "Space between cells"), min = 0, max = 10, step = 1,
                default = 2, suffix = " px" },
            { "media", "prdTexture", L("Текстура полос", "Bar texture"), kind = "statusbar", ignoreGlobal = true, default = 1 },
            { "toggle", "prdSmooth", L("Плавное изменение полос", "Smooth bars"), default = true },
        } },
        { title = L("Текст", "Text"), columns = 2, options = {
            { "media", "prdFont", L("Шрифт", "Font"), kind = "font", ignoreGlobal = true, default = 1 },
            { "range", "prdFontSize", L("Размер шрифта", "Font size"), min = 7, max = 20, step = 1, default = 11 },
            { "select", "prdFontOutline", L("Обводка", "Outline"), values = ui.OutlineValues, default = "OUTLINE" },
            { "select", "prdHealthText", L("Текст здоровья", "Health text"), values = textModes, default = "both" },
            { "select", "prdPowerText", L("Текст ресурса", "Power text"), values = textModes, default = "current" },
        } },
        { title = L("Здоровье", "Health"), columns = 2, depends = "prdShowHealth", options = {
            { "select", "prdHealthColorMode", L("Цвет полосы", "Bar colour"), default = "class", values = {
                { "class", L("Цвет класса", "Class colour") }, { "gradient", L("Градиент по здоровью", "Health gradient") },
                { "custom", L("Свой цвет", "Custom colour") } } },
            { "color", "prdHealthColor", L("Свой цвет", "Custom colour"), default = { 0.2, 0.8, 0.2 },
                depends = function() return ui.GetOption("prd", "prdHealthColorMode") == "custom" end },
            { "toggle", "prdHealPrediction", L("Входящее лечение", "Incoming heals"), default = true,
                tooltip = L("Нужен API клиента (UnitGetIncomingHeals) или библиотека LibHealComm-4.0 в другом аддоне. "
                    .. "Источник показывает /fuiprd.", "Needs the client API (UnitGetIncomingHeals) or LibHealComm-4.0 "
                    .. "shipped by another addon. /fuiprd tells the source.") },
            { "color", "prdHealColor", L("Цвет лечения", "Heal colour"), alpha = true, default = { 0.4, 1, 0.5, 0.45 },
                depends = "prdHealPrediction" },
            { "toggle", "prdShield", L("Индикатор щитов", "Shield indicator"), default = true,
                tooltip = L("Рамка при «Слове силы: Щит», «Священном щите», «Ледяной преграде» и других поглощениях; "
                    .. "полоса поглощения — если клиент сообщает его размер.", "A border while Power Word: Shield, Sacred "
                    .. "Shield, Ice Barrier and other absorbs are up; an absorb bar when the client tells its size.") },
            { "color", "prdShieldColor", L("Цвет щита", "Shield colour"), alpha = true, default = { 0.85, 0.95, 1, 0.6 },
                depends = "prdShield" },
            { "toggle", "prdCriticalGlow", L("Подсветка при низком здоровье", "Low health glow"), default = true },
            { "range", "prdCritical", L("Критический порог", "Critical threshold"), min = 5, max = 60, step = 1, default = 30,
                suffix = "%", depends = "prdCriticalGlow" },
            { "color", "prdCriticalColor", L("Цвет подсветки", "Glow colour"), default = { 1, 0.1, 0.1 },
                depends = "prdCriticalGlow" },
        } },
        { title = L("Ресурс", "Power"), columns = 2, depends = "prdShowPower", options = {
            { "select", "prdPowerColorMode", L("Цвет полосы", "Bar colour"), default = "power", values = {
                { "power", L("По типу ресурса", "By power type") }, { "custom", L("Свой цвет", "Custom colour") } },
                tooltip = L("Мана — синий, ярость — красный, энергия — жёлтый, сила рун — голубой. Тип меняется сам при "
                    .. "смене облика друида.", "Mana blue, rage red, energy yellow, runic power cyan. The type follows "
                    .. "druid forms.") },
            { "color", "prdPowerColor", L("Свой цвет", "Custom colour"), default = { 0.2, 0.45, 1 },
                depends = function() return ui.GetOption("prd", "prdPowerColorMode") == "custom" end },
            { "toggle", "prdDruidMana", L("Мана друида в облике", "Druid mana in forms"), default = true,
                hidden = function() return PRD() ~= nil and PRD().class ~= "DRUID" end },
            { "toggle", "prdEnergyTick", L("Метка тика энергии", "Energy tick spark"), default = false,
                tooltip = L("Искра бежит по полосе до следующего тика энергии (2 с; реальный интервал виден в /fuiprd).",
                    "A spark runs to the next energy tick (2 s; /fuiprd shows the measured gap).") },
            { "toggle", "prdFiveSecond", L("Правило пяти секунд (мана)", "Five second rule (mana)"), default = false,
                tooltip = L("После траты маны искра идёт 5 секунд — до возобновления восполнения от духа.",
                    "After spending mana a spark runs for 5 seconds, until spirit regeneration resumes.") },
        } },
        { title = L("Классовые ресурсы", "Class resources"), columns = 2, depends = "prdShowClass", options = {
            { "color", "prdComboColor", L("Цвет серии приёмов", "Combo point colour"), default = { 1, 0.85, 0.25 } },
            { "color", "prdComboMaxColor", L("Цвет максимума (5 / все стаки)", "Maximum colour (5 / all stacks)"),
                default = { 1, 0.35, 0.15 } },
            { "toggle", "prdRunes", L("Руны (рыцарь смерти)", "Runes (death knight)"), default = true },
            { "select", "prdRuneOrder", L("Порядок рун", "Rune order"), default = "buf", depends = "prdRunes", values = {
                { "buf", L("Кровь, Нечестивость, Лёд", "Blood, Unholy, Frost") },
                { "bfu", L("Кровь, Лёд, Нечестивость", "Blood, Frost, Unholy") },
                { "fub", L("Лёд, Нечестивость, Кровь", "Frost, Unholy, Blood") },
                { "ufb", L("Нечестивость, Лёд, Кровь", "Unholy, Frost, Blood") } } },
            { "toggle", "prdRuneTimer", L("Таймер перезарядки рун", "Rune recharge timer"), default = true,
                depends = "prdRunes" },
            { "toggle", "prdTotems", L("Тотемы (шаман)", "Totems (shaman)"), default = true,
                tooltip = L("Огонь, Земля, Вода, Воздух: значок и оставшееся время. Если выключено, у шамана "
                    .. "показываются стаки («Оружие Водоворота», щиты).", "Fire, Earth, Water, Air: icon and time left. "
                    .. "When off, a shaman sees stacks (Maelstrom Weapon, shields) instead.") },
            { "toggle", "prdTotemTimer", L("Таймер тотемов", "Totem timer"), default = true, depends = "prdTotems" },
            { "toggle", "prdStacks", L("Стаки для классов без второго ресурса", "Stacks for classes without a second resource"),
                default = true, tooltip = L("Шаман — «Оружие Водоворота», «Щит молний», «Водный щит», «Щит земли»; "
                    .. "рыцарь смерти без рун — «Костяной щит»; жрец — «Прозорливость», «Тёмное плетение»; маг — "
                    .. "«Чародейская вспышка»; чернокнижник — число осколков души в сумках. Своё заклинание — ниже.",
                    "Shaman: Maelstrom Weapon, Lightning / Water / Earth Shield; death knight without runes: Bone Shield; "
                    .. "priest: Serendipity, Shadow Weaving; mage: Arcane Blast; warlock: soul shards in the bags. "
                    .. "Your own spell below.") },
            { "color", "prdStackColor", L("Цвет стаков", "Stack colour"), default = { 0.3, 0.75, 1 }, depends = "prdStacks" },
            { "toggle", "prdStackHideEmpty", L("Скрывать пустые стаки", "Hide empty stacks"), default = true,
                depends = "prdStacks", tooltip = L("Без стаков ряд прозрачен; место остаётся, чтобы панель не прыгала.",
                    "Without stacks the row is transparent; its space stays so the panel does not jump.") },
            { "text", "prdStackCustom", L("Своя аура для стаков (имя или ID)", "Own stack aura (name or ID)"), default = "", spellDrop = true,
                depends = "prdStacks", tooltip = L("Заменяет набор класса. Например, ID или точное имя баффа.",
                    "Replaces the class set. A spell ID or the exact buff name.") },
            { "range", "prdStackCustomMax", L("Стаков максимум", "Maximum stacks"), min = 1, max = 10, step = 1, default = 5,
                depends = "prdStacks" },
        } },
        { title = L("Проки и баффы", "Procs and buffs"), columns = 2, depends = "prdShowAuras", options = {
            { "select", "prdAuraFilter", L("Фильтр", "Filter"), default = "smart", values = {
                { "smart", L("Умный: проки, защита и свои короткие", "Smart: procs, defensives, own short buffs") },
                { "procs", L("Только проки и защита из списка", "Listed procs and defensives only") },
                { "all", L("Все короткие баффы", "All short buffs") } },
                tooltip = L("Проки талантов, тринкеты, инженерные чары и защитные кулдауны видны всегда. Длинные "
                    .. "рейдовые баффы («Лапка», «Кулак», «Каска», ауры) скрыты.", "Talent procs, trinkets, engineering "
                    .. "tinkers and defensive cooldowns always show. Long raid buffs (Mark, Kings, Fortitude, auras) are hidden.") },
            { "range", "prdAuraMaxDuration", L("Максимальная длительность", "Maximum duration"), min = 5, max = 600, step = 5,
                default = 60, suffix = L(" с", " s") },
            { "range", "prdAuraCount", L("Иконок не больше", "Icons at most"), min = 1, max = 12, step = 1, default = 6 },
            { "range", "prdAuraSize", L("Размер иконок", "Icon size"), min = 14, max = 48, step = 1, default = 24, suffix = " px" },
            { "toggle", "prdAuraHideRaid", L("Скрывать рейдовые баффы", "Hide raid buffs"), default = true },
            { "toggle", "prdAuraKeepVisible", L("Не скрывать баффы в покое", "Keep buffs visible at rest"), default = true,
                tooltip = L("Иконки баффов остаются видны, когда панель затухает при полном здоровье и ресурсе вне боя "
                    .. "(с прозрачностью «Активна»). Полосы затухают как обычно.", "Buff icons stay visible while the panel "
                    .. "fades at full health and power out of combat (at the \"Active\" opacity). The bars fade as usual.") },
            { "toggle", "prdAuraProcGlow", L("Подсветка проков к нажатию", "Glow on procs to press"), default = true },
            { "color", "prdAuraGlowColor", L("Цвет подсветки", "Glow colour"), default = { 1, 0.85, 0.2 },
                depends = "prdAuraProcGlow" },
            { "toggle", "prdAuraSwipe", L("Затемнение по кругу", "Cooldown swipe"), default = true },
            { "toggle", "prdAuraTimer", L("Таймер в цифрах", "Numeric timer"), default = true },
            { "text", "prdAuraWhitelist", L("Белый список (имена или ID через запятую)", "Whitelist (names or IDs, comma separated)"),
                default = "", spellDrop = { list = true }, width = "full" },
            { "text", "prdAuraBlacklist", L("Чёрный список (имена или ID через запятую)", "Blacklist (names or IDs, comma separated)"),
                default = "", spellDrop = { list = true }, width = "full" },
        } },
        { title = L("Видимость и мышь", "Visibility and mouse"), columns = 2, options = {
            { "toggle", "prdFade", L("Затухать вне боя в покое", "Fade out of combat at rest"), default = true,
                tooltip = L("Просыпается в бою, при атакуемой цели, при здоровье ниже 100%, трате или накоплении ресурса, "
                    .. "серии приёмов, перезарядке рун, активных тотемах и при наведении мыши (если клики не сквозные).",
                    "Wakes in combat, with an attackable target, below full health, when power is spent or built, with "
                    .. "combo points, recharging runes, active totems and on mouse over (unless click-through).") },
            { "range", "prdFadeTime", L("Длительность перехода", "Fade time"), min = 0.1, max = 3, step = 0.1, default = 0.4,
                suffix = L(" с", " s"), depends = "prdFade" },
            { "range", "prdAlphaCombat", L("Прозрачность в бою", "Opacity in combat"), min = 0, max = 100, step = 5,
                default = 100, suffix = "%" },
            { "range", "prdAlphaTarget", L("С атакуемой целью", "With an attackable target"), min = 0, max = 100, step = 5,
                default = 100, suffix = "%", depends = "prdFade" },
            { "range", "prdAlphaActive", L("Вне боя, ресурс меняется", "Out of combat, resources change"), min = 0, max = 100,
                step = 5, default = 80, suffix = "%", depends = "prdFade" },
            { "range", "prdAlphaIdle", L("Вне боя в покое", "Out of combat at rest"), min = 0, max = 100, step = 5,
                default = 0, suffix = "%", depends = "prdFade" },
            { "toggle", "prdClickThrough", L("Сквозной клик", "Click-through"), default = true,
                tooltip = L("Панель не мешает камере и выбору целей под персонажем. В бою мышь пропускается всегда, "
                    .. "кроме зажатого модификатора.", "The panel does not block the camera or clicks on targets under the "
                    .. "character. In combat the mouse always passes through unless the modifier is held.") },
            { "toggle", "prdTooltips", L("Подсказки вне боя", "Tooltips out of combat"), default = true },
            { "select", "prdModifier", L("Модификатор для подсказок в бою", "Modifier for tooltips in combat"),
                default = "shift", depends = "prdClickThrough", values = {
                { "none", L("Нет", "None") }, { "shift", "Shift" }, { "ctrl", "Ctrl" }, { "alt", "Alt" } } },
        } },
    },
})
