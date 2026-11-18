-- Setup wizard data: the four roles, their frame layouts and the modules each role starts with.
-- Pure tables and functions only: Setup/Profile.lua applies them, tests/Setup.lua checks them.
local _, ui = ...
local L = ui.L

local Layouts = {}
ui.SetupLayouts = Layouts

Layouts.roles = { "TANK", "HEALER", "MELEE", "RANGED" }
Layouts.roleInfo = {
    TANK = { label = L("Танк", "Tank"), icon = "Interface\\Icons\\Ability_Defend",
        text = L("Угроза и рамка цели крупно, CDM над рамкой игрока.", "Threat and the target frame up front.") },
    HEALER = { label = L("Лекарь", "Healer"), icon = "Interface\\Icons\\Spell_Holy_FlashHeal",
        text = L("Рейд по центру, рамки игрока и цели по бокам.", "Raid in the centre, player and target aside.") },
    MELEE = { label = L("ДД ближнего боя", "Melee DPS"), icon = "Interface\\Icons\\Ability_DualWield",
        text = L("Ресурсы и CDM прямо под персонажем.", "Resources and CDM right under the character.") },
    RANGED = { label = L("ДД дальнего боя", "Ranged DPS"), icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
        text = L("Полоса заклинаний по центру, CDM над ней.", "The cast bar in the centre, CDM above it.") },
}

-- Role of a talent tree (the same table as the Cooldown Manager: class -> role per tree).
local TREE_ROLES = {
    WARRIOR = { "MELEE", "MELEE", "TANK" }, PALADIN = { "HEALER", "TANK", "MELEE" },
    PRIEST = { "HEALER", "HEALER", "RANGED" }, DRUID = { "RANGED", "MELEE", "HEALER" },
    SHAMAN = { "RANGED", "MELEE", "HEALER" }, MAGE = { "RANGED", "RANGED", "RANGED" },
    WARLOCK = { "RANGED", "RANGED", "RANGED" }, HUNTER = { "RANGED", "RANGED", "RANGED" },
    ROGUE = { "MELEE", "MELEE", "MELEE" }, DEATHKNIGHT = { "MELEE", "MELEE", "MELEE" },
}
Layouts.treeRoles = TREE_ROLES

-- class, primary tree (0 = no points), feralTank: the druid has Protector of the Pack / is in bear form.
function Layouts.GuessRole(class, tree, feralTank)
    local roles = TREE_ROLES[class or ""]
    if not roles then return "MELEE" end
    if not tree or tree == 0 then
        -- No talents yet: what the class does first.
        if class == "PRIEST" or class == "MAGE" or class == "WARLOCK" or class == "HUNTER" then return "RANGED" end
        if class == "SHAMAN" or class == "DRUID" then return "RANGED" end
        return "MELEE"
    end
    if class == "DRUID" and tree == 2 and feralTank then return "TANK" end
    return roles[tree] or roles[1]
end

---------------------------------------------------------------------------------------------------
-- Modules shown on the wizard's "Modules" page. kind: how Profile.lua reads and writes it.
--   main     - a key of ForeverStockUIDB (schema id/key for the live apply), reload = needs /reload
--   option   - a schema option stored outside the main table (raid frames live in the suite profile)
--   clicks   - the click-casting part of the suite profile
--   cursor   - the outline and the trail of the cursor effects together (ForeverStockUIDB.cursor); on also turns the
--              effects on
--   account  - account-wide (not saved per character)
---------------------------------------------------------------------------------------------------
Layouts.modules = {
    { id = "unitframes", key = "unitFramesEnabled", kind = "main", reload = true,
        label = L("Рамки юнитов WoW Forever", "WoW Forever unit frames") },
    { id = "raidframes", key = "rfEnabled", kind = "option", label = L("Фреймы группы и рейда", "Party and raid frames") },
    { id = "cooldowns", key = "cdmEnabled", kind = "main", label = "Cooldown Manager" },
    { id = "prd", key = "prdEnabled", kind = "main", label = L("Панель ресурсов", "Personal resources") },
    { id = "meter", key = "meterEnabled", kind = "main", label = L("Измерители урона", "Damage meters") },
    { id = "nameplates", key = "nameplatesEnabled", kind = "account", reload = true,
        label = L("Неймплейты (на аккаунт)", "Nameplates (account)") },
    { id = "bags", key = "bagsEnabled", kind = "main", reload = true, label = L("Единая сумка", "Combined bags") },
    { id = "skins", key = "foreverWindows", kind = "main", label = L("Скины окон", "Window skins") },
    { id = "combattext", key = "enabled", kind = "combattext", label = L("Текст боя", "Combat text") },
    { id = "cursor", key = "outlineEnabled", kind = "cursor", label = L("Обводка и след курсора", "Cursor outline and trail") },
    { id = "clickcast", key = "enabled", kind = "clicks", label = "Click-cast" },
    { id = "healermana", key = "hmEnabled", kind = "main", label = L("Мана хила", "Healer mana") },
}

-- Recommended switches per role (modules not listed stay on).
local OFF = {
    TANK = { clickcast = true, healermana = true },
    HEALER = {},
    MELEE = { clickcast = true, healermana = true },
    RANGED = { clickcast = true, healermana = true },
}
function Layouts.Recommended(role)
    local result, off = {}, OFF[role] or OFF.MELEE
    for _, module in ipairs(Layouts.modules) do result[module.id] = not off[module.id] end
    return result
end

---------------------------------------------------------------------------------------------------
-- Frame layouts. Each spot: point of the frame at relativePoint of the screen (UIParent) + x, y, in UIParent units.
-- The centre column (resources, CDM, cast bar) stays clear of the bars: their top is about 240 under the centre in
-- Retail and 290 in Classic at the pixel-perfect scale (UIParent 768 high).
--   frames   - Edit Mode frames by name
--   raid     - the party/raid anchor (TOPLEFT of the group)
--   cdm      - top of the icon tracker groups, stacked downwards
--   prd      - centre of the personal resource panel
--   meter    - the first damage meter window
--   chat     - the main chat frame (bottom left corner, size); y per bar style
---------------------------------------------------------------------------------------------------
-- x leaves room for the chat's side buttons (scroll, menu), which hang to the left of the frame.
local CHAT = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 42, classicY = 116, retailY = 34, w = 380, h = 150 }
local METER = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -8, y = 108 }
local MANA = { point = "TOP", relativePoint = "CENTER", x = 0, y = 190 }
local SIDE_RAID = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 20, y = -200 }

Layouts.presets = {
    TANK = {
        frames = {
            PlayerFrame = { "RIGHT", "CENTER", -170, -120 },
            TargetFrame = { "LEFT", "CENTER", 170, -120 },
            FocusFrame = { "LEFT", "CENTER", 250, 60 },
            CastingBarFrame = { "TOP", "CENTER", 0, -212 },
            ForeverStockUIHealerManaBanner = { MANA.point, MANA.relativePoint, MANA.x, MANA.y },
        },
        raid = SIDE_RAID,
        prd = { x = 0, y = -100 },
        cdm = { point = "TOP", relativePoint = "CENTER", x = 0, y = -126 },
        meter = METER, chat = CHAT,
    },
    HEALER = {
        frames = {
            PlayerFrame = { "RIGHT", "CENTER", -200, -20 },
            TargetFrame = { "LEFT", "CENTER", 200, -20 },
            FocusFrame = { "LEFT", "CENTER", 200, 110 },
            CastingBarFrame = { "TOP", "CENTER", -316, -84 },
            ForeverStockUIHealerManaBanner = { "TOP", "CENTER", 0, 160 },
        },
        -- The group is centred on the screen: x is taken from its measured width.
        raid = { point = "TOP", relativePoint = "CENTER", x = 0, y = -66, centred = true },
        prd = { x = 0, y = -42 },
        cdm = { point = "TOP", relativePoint = "CENTER", x = 316, y = -84 },
        meter = METER, chat = CHAT,
    },
    MELEE = {
        frames = {
            PlayerFrame = { "RIGHT", "CENTER", -140, -96 },
            TargetFrame = { "LEFT", "CENTER", 140, -96 },
            FocusFrame = { "LEFT", "CENTER", 250, 60 },
            CastingBarFrame = { "TOP", "CENTER", 0, -212 },
            ForeverStockUIHealerManaBanner = { MANA.point, MANA.relativePoint, MANA.x, MANA.y },
        },
        raid = SIDE_RAID,
        prd = { x = 0, y = -96 },
        cdm = { point = "TOP", relativePoint = "CENTER", x = 0, y = -122 },
        meter = METER, chat = CHAT,
    },
    RANGED = {
        frames = {
            PlayerFrame = { "RIGHT", "CENTER", -220, -140 },
            TargetFrame = { "LEFT", "CENTER", 220, -140 },
            FocusFrame = { "LEFT", "CENTER", 250, 60 },
            CastingBarFrame = { "TOP", "CENTER", 0, -192 },
            ForeverStockUIHealerManaBanner = { MANA.point, MANA.relativePoint, MANA.x, MANA.y },
        },
        raid = SIDE_RAID,
        prd = { x = 0, y = -82 },
        cdm = { point = "TOP", relativePoint = "CENTER", x = 0, y = -106 },
        meter = METER, chat = CHAT,
    },
}

-- Gap between stacked tracker groups (UIParent units).
Layouts.CDM_GAP = 4

-- Pixel-perfect UI scale for a screen height: one UI pixel = one screen pixel (768 / height), within the range
-- the client accepts for the uiScale CVar; below 0.64 the rest goes to UIParent itself.
Layouts.MIN_CVAR_SCALE, Layouts.MAX_SCALE = 0.64, 1.15
function Layouts.AutoScale(screenHeight)
    if type(screenHeight) ~= "number" or screenHeight <= 0 then return 1 end
    local scale = 768 / screenHeight
    scale = math.floor(scale * 1000 + 0.5) / 1000
    return math.max(0.4, math.min(Layouts.MAX_SCALE, scale))
end

-- Width x height from a resolution string ("1920x1080").
function Layouts.ParseResolution(text)
    local w, h = tostring(text or ""):match("(%d+)%s*[xX]%s*(%d+)")
    return tonumber(w), tonumber(h)
end

return Layouts
