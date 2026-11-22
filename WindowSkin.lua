local _, ui = ...
-- WoW Forever window chrome, the ElvUI way: the window's own chrome is hidden and a new one is drawn around it.
-- ElvUI draws a flat 1 px backdrop; here the frame is the bronze metal of WoW Forever, assembled from atlas
-- pieces (four corners and four edges, the top-left corner with a portrait ring). Only textures change: the
-- window keeps its size, position and behaviour. Turning the option off puts the client's chrome back.
--
-- A window is described by one entry in RECIPES; the engine (layout, hiding, restoring) is shared.

local ART = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Window-"
local METAL, METAL_H, METAL_V = ART .. "Metal", ART .. "MetalH", ART .. "MetalV"

-- Window-Metal.tga (uiframemetal2xc60, 1024 x 512, drawn for double density).
-- Corner: box left, top, right, bottom, then the outer corner of the metal inside the box (texture px).
local SHEET_W, SHEET_H = 1024, 512
local CORNERS = {
    TopLeft     = { 213, 22, 384, 192, 213, 22 },
    TopLeftRing = { 396, 204, 576, 384, 405, 214 },
    TopRight    = { 192, 214, 384, 384, 384, 214 },
    BottomLeft  = { 21, 0, 192, 197, 21, 197 },
    BottomRight = { 0, 202, 192, 399, 192, 399 },
}
-- Edge strips: file, the band the strip occupies across the file (rows for top/bottom, columns for the
-- sides), file width and height. Strips run the whole length of their file and repeat seamlessly.
local EDGES = {
    Top    = { METAL_H, 224, 289, 256, 512 },
    Bottom = { METAL_H, 169, 197, 256, 512 },
    Left   = { METAL_V, 21, 42, 512, 256 },
    Right  = { METAL_V, 362, 384, 512, 256 },
}
-- Portrait under the ring of TopLeftRing: centre and diameter (texture px).
-- The centre is that of the bright metal rim (402..520 x 209..324): the drop shadow under the ring made the
-- alpha bounds 2-3 px lower, and portraits sat low in the ring (checked in game).
local RING_X, RING_Y, RING_SIZE = 461, 266, 100
-- A square icon in the ring: its side as a share of the hole. At 0.85 its corners reach r = 59 (texture px), just
-- under the opaque metal of the rim (r 49..59), so no corner shows; the icon's own border is cropped away first.
local SQUARE_IN_RING = 0.85
local ICON_CROP = 0.08
-- Rock ground inside the frame: insets from the outer edge (texture px of the metal sheet).
local GROUND_SIDE, GROUND_TOP, GROUND_BOTTOM = 12, 40, 12
-- Centre of the dark band of the top strip below the outer edge (texture px): the title is centred on it.
-- Glyphs without descenders sit high in their box, so the title goes TITLE_NUDGE px lower still.
local HEADER_CENTER, TITLE_NUDGE = 31, 1

-- Close button: Window-Close.tga (128-redbutton-exit-c60 and its states), 256 x 256 in 128 px cells:
-- 0 normal, 1 pressed, 2 highlight, 3 disabled. The button art spans 4..125 x 2..122 of a cell.
local CLOSE = ART .. "Close"
-- Its side (texture px of the metal sheet: the header band is 65) and its offset from the top-right corner
-- (display px; 0 = flush with the outer edge): it sits on the corner, covering the frame, never outside it.
-- 2 px in from the right edge fits best (checked in game); the header buttons follow it.
local CLOSE_SIZE, CLOSE_X, CLOSE_Y = 56, -2, 0
-- Small window buttons: Window-Buttons.tga (redbuttonsc60, 256 x 128), 34 px cells. Columns: 0 minimize,
-- 1 close, 2 maximize; rows: 0 normal, 1 disabled, 2 pressed.
local WINDOW_BUTTONS = ART .. "Buttons"
local function buttonCell(col, row)
    return col * 34 / 256, (col + 1) * 34 / 256, row * 34 / 128, (row + 1) * 34 / 128
end
-- Header buttons (the "Labels" button) sit this much lower than the close button's centre (display px).
local HEADER_BUTTON_Y = -2
-- Every window: the top edge (header band) this much higher (display px).
local GENERIC_RAISE = 12
-- Old 3.3.5 windows: the frame goes this much past ElvUI's rect at the sides and the bottom (display px). The
-- bottom stays on ElvUI's edge: lower, the frame swallowed the tabs under friends and merchant (checked in game).
local RECT_SIDE, RECT_BOTTOM = 4, 0
-- Tabs hang from the bottom edge: their top tucks this far under it (display px; 8 checked in game on the merchant).
local TAB_OVERLAP = 8
local function closeCoords(cell)
    local cx, cy = (cell % 2) * 128, math.floor(cell / 2) * 128
    return (cx + 4) / 256, (cx + 125) / 256, (cy + 2) / 256, (cy + 122) / 256
end

-- Item slot rim: the WoW Forever slot frame of the action bars (Slot-Frame.tga, rim 4..108 x 4..110 of 128),
-- a little outside the icon so the quality border inside stays visible.
local SLOT_ART = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Slot-Frame"
local SLOT_OUTSET = 3
local SLOT_LARGER = 4      -- a slot texture this much larger than the button is a frame around the icon

-- Stats panel: Window-Stats.tga (512 x 512) holds three WoW Forever pieces (texture px):
--   ground 0..400 x 0..465 (paperdollinfopart2c60, the plain stat pane background),
--   inset frame 400..507 x 0..109 (commoninsideframec60, bronze scroll corners), cut as nine slices,
--   header plate 0..199 x 470..500 (paperdollinfopart1c60, the stat category title), cut as three slices.
local STATS = ART .. "Stats"
local STATS_SIZE = 512
local GROUND_BOX = { 0, 0, 400, 465 }
local INSET_X0, INSET_Y0, INSET_X1, INSET_Y1, INSET_CORNER = 400, 0, 507, 109, 24
local INSET_SCALE = 0.75
local PLATE_X0, PLATE_Y0, PLATE_X1, PLATE_Y1, PLATE_CAP = 0, 470, 199, 500, 16

-- Pure geometry: every piece for a frame of w x h display px at scale s (1 = texture px).
-- x, y run from the frame's top-left corner, y downwards. Coordinates l, r, t, b are texture coordinates.
local function corner(pieces, name, key, cx, cy, s)
    local c = CORNERS[key]
    pieces[#pieces + 1] = { name = name, file = METAL,
        x = cx - (c[5] - c[1]) * s, y = cy - (c[6] - c[2]) * s,
        w = (c[3] - c[1]) * s, h = (c[4] - c[2]) * s,
        l = c[1] / SHEET_W, r = c[3] / SHEET_W, t = c[2] / SHEET_H, b = c[4] / SHEET_H }
end

-- How far a corner reaches along the frame from its outer corner (left/top corners reach right/down).
local function reachX(key, s)
    local c = CORNERS[key]
    if key:find("Left", 1, true) then return (c[3] - c[5]) * s end
    return (c[5] - c[1]) * s
end
local function reachY(key, s)
    local c = CORNERS[key]
    if key:find("Top", 1, true) then return (c[4] - c[6]) * s end
    return (c[6] - c[2]) * s
end

-- An edge is laid as whole strips (texture coordinates never leave 0..1, so no tiling mode is needed).
local function edge(pieces, side, from, to, s, w, h)
    local e = EDGES[side]
    local band = (e[3] - e[2]) * s
    local horizontal = side == "Top" or side == "Bottom"
    local step = (horizontal and e[4] or e[5]) * s
    local pos = from
    while to - pos > 0.01 do
        local len = math.min(step, to - pos)
        local p = { name = side, file = e[1] }
        if horizontal then
            p.x, p.w, p.h = pos, len, band
            p.y = side == "Top" and 0 or h - band
            p.l, p.r, p.t, p.b = 0, len / step, e[2] / e[5], e[3] / e[5]
        else
            p.y, p.h, p.w = pos, len, band
            p.x = side == "Left" and 0 or w - band
            p.l, p.r, p.t, p.b = e[2] / e[4], e[3] / e[4], 0, len / step
        end
        pieces[#pieces + 1] = p
        pos = pos + len
    end
end

local function layout(w, h, s, ring)
    local pieces = {}
    local tl = ring and "TopLeftRing" or "TopLeft"
    corner(pieces, "TopLeft", tl, 0, 0, s)
    corner(pieces, "TopRight", "TopRight", w, 0, s)
    corner(pieces, "BottomLeft", "BottomLeft", 0, h, s)
    corner(pieces, "BottomRight", "BottomRight", w, h, s)
    edge(pieces, "Top", reachX(tl, s), w - reachX("TopRight", s), s, w, h)
    edge(pieces, "Bottom", reachX("BottomLeft", s), w - reachX("BottomRight", s), s, w, h)
    edge(pieces, "Left", reachY(tl, s), h - reachY("BottomLeft", s), s, w, h)
    edge(pieces, "Right", reachY("TopRight", s), h - reachY("BottomRight", s), s, w, h)
    local extra = {}
    if ring then
        local c = CORNERS.TopLeftRing
        local size = RING_SIZE * s
        extra.portrait = { x = (RING_X - c[5]) * s - size / 2, y = (RING_Y - c[6]) * s - size / 2, w = size, h = size }
    end
    local gx, gy = GROUND_SIDE * s, GROUND_TOP * s
    local gw, gh = math.max(w - 2 * gx, 1), math.max(h - gy - GROUND_BOTTOM * s, 1)
    extra.ground = { x = gx, y = gy, w = gw, h = gh,
        l = 0, r = 1, t = 0, b = 1 }
    return pieces, extra
end

-- Windows that get the chrome. ground: client textures replaced by the rock ground; portraits and models:
-- the client's portrait pieces, replaced by the portrait in the ring; slots: item buttons that get the rim.
local RECIPES = {
    CharacterFrame = {
        -- Its checkbox on the Skins page (key in ForeverStockUIDB, label).
        key = "skinCharacter", label = { "Окно персонажа", "Character window" },
        unit = "player", stats = true, topLevel = true,
        ground = { "CharacterFrameBg", "CharacterFrameTopTileStreaks" },
        portraits = { "CharacterFramePortrait" },
        models = { "CharacterFramePortraitModel" },
        slots = { "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
            "CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot",
            "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
            "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot",
            "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot", "CharacterAmmoSlot" },
        -- Nozdor's stats panel on the right (from the in-game tree: PaperDollFrameNewPanel is an empty 64 x 64
        -- holder; the visible panel is PaperDollFrameStrengthenFrame, 258 x 360) and the title picker drawn over
        -- it in the same style. Category headers are found by their titles (they have no names).
        panels = { "PaperDollFrameStrengthenFrame", "PlayerTitlePickerFrame" },
        headers = {},
        -- The client re-dresses the panel after these; the panel is skinned again right after.
        refresh = { "PaperDollFrame_UpdateStats" },
        refreshFrames = { "PaperDollFrame" },
        -- Buttons that sit in the header bar, right to left from the close button (ForeverUI's own "Labels").
        headerButtons = { "ForeverStockUI_CharacterLabels" },
    },
}
local ORDER = { "CharacterFrame" }

-- Every other window, the ElvUI way: one shared recipe, one line per window. The window's frame name, its label
-- on the Skins page and, for the old 3.3.5 windows whose chrome is painted into the window art, the visible rect
-- (left, top, right, bottom offsets from the window's corners, as measured for this client by ElvUI's skins).
-- A window that carries the Nozdor metal chrome (MetalBorder) is skinned like the character window whatever the
-- list says; one without both is left alone. slots: the window shows equipment slots with this name prefix.
local WINDOWS = {
    -- Nozdor metal windows
    { "SpellBookFrame", "Книга заклинаний", "Spellbook" },
    { "PlayerTalentFrame", "Таланты", "Talents", unit = "player",
        portraits = { "PlayerTalentFramePortrait" },
        refresh = { "PlayerTalentFrame_Refresh" },
        refreshFrames = { "GlyphFrame" },
        -- Glyph tab: at the full raise a strip of window background showed between the header and the glyph art.
        raise = GENERIC_RAISE - 2,
        -- The left edge 5 px further out (checked in game on the glyph tab).
        leftOut = 5,
        -- Shown again on a tab switch, the glyph frame came up above the chrome and its ornate border covered the header.
        under = { "GlyphFrame" } },
    { "TradeSkillFrame", "Профессии", "Professions" },
    { "TradeSkillCompactFrame", "Профессии (компактное окно)", "Professions (compact)" },
    { "LFDParentFrame", "Поиск подземелий", "Dungeon Finder", portrait = "HK_LFDPortraitFrame", portraitWhole = true,
        portraitScale = 1.15,
        tabs = { "HK_LFDTopTabDungeons", "HK_LFDTopTabPvp", "HK_LFDTopTabGear", "HK_LFDTopTabStats", "HK_LFDTopTabKeys" } },
    { "InspectFrame", "Осмотр", "Inspect", slots = "Inspect" },
    -- Nozdor windows of their own (names from /fuiskin); skinned when they carry the metal chrome, otherwise
    -- they only save their tree for fitting.
    { "WorldMapFrame", "Карта и журнал заданий", "Map and quest log",
        ground = { "WorldMapFrameBackground" },
        -- Maximize / minimize swap places next to the close button: they join the header.
        headerButtons = { "WorldMapFrameSizeUpButton", "WorldMapFrameSizeDownButton" }, headerShare = true,
        -- Their WoW Forever faces (columns of Window-Buttons.tga): maximize, minimize.
        headerArt = { WorldMapFrameSizeUpButton = 2, WorldMapFrameSizeDownButton = 0 } },
    { "NozdorCollectionsFrame", "Коллекции", "Collections" },
    { "EncounterJournal", "Путеводитель приключений", "Adventure Guide",
        tabs = { "EncounterJournalInstanceSelectDungeonTab", "EncounterJournalInstanceSelectRaidTab",
            "EncounterJournalInstanceSelectLootJournalTab", "EncounterJournalInstanceSelectKeystoneTab6",
            "EncounterJournalInstanceSelectKeystoneTab7", "EncounterJournalInstanceSelectTrialsTab" } },
    { "NozdorStoreFrame", "Магазин", "Shop", portraitScale = 1.5 },
    { "StoreFrame", "Магазин (окно товаров)", "Shop (items)", portraitScale = 1.5 },
    { "BattlePassFrame", "Боевой пропуск", "Battle pass" },
    { "LuckyWheelMainFrame", "Колесо удачи", "Wheel of fortune" },
    -- Old 3.3.5 windows (rect from ElvUI)
    { "FriendsFrame", "Друзья", "Friends", rect = { 11, -12, -32, 76 },
        -- The bottom buttons reach into the frame's bottom edge: they are drawn above it.
        above = { "FriendsFrameAddFriendButton", "FriendsFrameSendMessageButton" } },
    { "QuestLogFrame", "Журнал заданий", "Quest log", rect = { 11, -12, -1, 11 } },
    -- ElvUI puts the bottom of these two on the window's bottom; their art ends higher, just under the buttons at the
    -- bottom (goodbye / accept): the frame's bottom edge sits there (checked in game).
    { "QuestFrame", "Задание у NPC", "Quest (NPC)", rect = { 11, -12, -32, 46 } },
    { "GossipFrame", "Разговор с NPC", "Gossip", rect = { 11, -12, -32, 46 } },
    { "MerchantFrame", "Торговец", "Merchant", rect = { 11, -12, -32, 76 },
        merchantCells = true, -- WoW Forever cells instead of the client's slot art
        -- after every page update: empty rows lose their name plate (skinMerchantCells)
        refresh = { "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo" },
        -- Repair buttons: the WoW Forever hammer, anvil and guild anvil (cells of merchant.tga).
        icons = {
            MerchantRepairItemButton = { match = "ui%-merchant%-repairicons", cell = { 74, 64, 148, 138 } },
            MerchantRepairAllButton = { match = "ui%-merchant%-repairicons", cell = { 0, 138, 74, 212 } },
            MerchantGuildBankRepairButton = { match = "ui%-merchant%-repairicons", cell = { 74, 138, 148, 212 } },
        } },
    { "MailFrame", "Почта", "Mail", rect = { 11, -12, -32, 76 },
        -- Postal's Refresh button sat under the close button: it joins the header, left of it.
        headerButtons = { "PostalRefreshButton" } },
    { "OpenMailFrame", "Письмо", "Open mail", rect = { 11, -12, -32, 76 } },
    { "TradeFrame", "Обмен", "Trade", rect = { 11, -12, -21, 49 } },
    { "ClassTrainerFrame", "Тренер", "Trainer", rect = { 11, -12, -32, 76 } },
    { "TaxiFrame", "Полёты", "Flight map", rect = { 11, -12, -32, 76 } },
    { "PetStableFrame", "Стойла", "Stable", rect = { 11, -12, -32, 76 } },
    { "TabardFrame", "Гербы", "Tabard", rect = { 11, -12, -32, 76 } },
    { "DressUpFrame", "Примерочная", "Dressing room", rect = { 11, 0, -32, 76 } },
    { "ItemTextFrame", "Книги и записки", "Books and notes", rect = { 11, -12, -32, 76 } },
    { "MacroFrame", "Макросы", "Macros", rect = { 11, -12, -32, 76 } },
    { "ItemSocketingFrame", "Инкрустация", "Socketing", rect = { 11, -12, -2, 31 } },
    -- The money row sits right above the bottom tabs: the bottom edge goes 10 px into the tabs (tabOverlap; 20 was
    -- 10 px too low, checked in game), the tabs stay behind it; the side tabs of the bank (GuildBankTabN, right of the
    -- window) stay above the right edge.
    { "GuildBankFrame", "Гильдейский банк", "Guild bank", rect = { 11, -12, 0, 8 }, tabOverlap = 10,
        guildCells = true, -- WoW Forever cells instead of the client's column art
        raise = GENERIC_RAISE - 5, -- header band 5 px lower than in other windows (checked in game)
        above = { "GuildBankTab1", "GuildBankTab2", "GuildBankTab3", "GuildBankTab4", "GuildBankTab5", "GuildBankTab6",
            "GuildBankTab7", "GuildBankTab8",
            -- The guild emblem on top of the window: the header band covered it.
            "GuildBankEmblemFrame" } },
    { "LFRParentFrame", "Поиск рейда", "Raid browser", rect = { 11, -12, -3, 4 } },
    { "PVPParentFrame", "PvP", "PvP", rect = { 11, -12, -32, 76 } },
    { "BattlefieldFrame", "Поля боя", "Battlegrounds", rect = { 11, -12, -32, 76 } },
    { "ArenaFrame", "Арена", "Arena", rect = { 11, -12, -32, 76 } },
    { "ArenaRegistrarFrame", "Регистрация команды арены", "Arena registrar", rect = { 11, -12, -32, 76 } },
    { "PVPBannerFrame", "Знамя команды арены", "Arena banner", rect = { 11, -12, -32, 76 } },
    { "GuildRegistrarFrame", "Регистрация гильдии", "Guild registrar", rect = { 11, -12, -32, 76 } },
    { "PetitionFrame", "Хартия", "Petition", rect = { 11, -12, -32, 76 } },
    { "WorldStateScoreFrame", "Итоги поля боя", "Battleground score", rect = { 10, -15, -113, 67 } },
    { "CalendarFrame", "Календарь", "Calendar", rect = { 3, -7, -2, -4 } },
    -- ForeverUI's own bag windows (Bags.lua): their header, ring and red close button give way to the WoW Forever
    -- frame; the backpack icon goes into the ring.
    { "ForeverStockInventory", "Сумка ForeverUI", "ForeverUI backpack", rect = { 0, 0, 0, 0 },
        icon = "Interface\\Buttons\\Button-Backpack-Up", hide = { "ForeverStockInventoryPortraitFrame" } },
    { "ForeverStockBank", "Банк ForeverUI", "ForeverUI bank", rect = { 0, 0, 0, 0 },
        icon = "Interface\\Buttons\\Button-Backpack-Up", hide = { "ForeverStockBankPortraitFrame" } },
    { "HelpFrame", "Помощь", "Help", rect = { 6, 0, -45, 14 } },
}
local SLOT_SUFFIXES = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot",
    "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "AmmoSlot" }
for _, w in ipairs(WINDOWS) do
    local name = w[1]
    local recipe = { key = "skin" .. name, label = { w[2], w[3] }, generic = true, rect = w.rect, above = w.above,
        headerButtons = w.headerButtons, headerShare = w.headerShare, headerArt = w.headerArt, ground = w.ground,
        unit = w.unit, portraits = w.portraits, refresh = w.refresh, refreshFrames = w.refreshFrames,
        portrait = w.portrait, portraitScale = w.portraitScale, portraitWhole = w.portraitWhole, tabs = w.tabs,
        icons = w.icons, tabsOver = w.tabsOver, tabOverlap = w.tabOverlap, raise = w.raise, under = w.under, leftOut = w.leftOut, guildCells = w.guildCells, merchantCells = w.merchantCells,
        icon = w.icon, hide = w.hide }
    if w.slots then
        recipe.slots = {}
        for _, suffix in ipairs(SLOT_SUFFIXES) do recipe.slots[#recipe.slots + 1] = w.slots .. suffix end
    end
    RECIPES[name] = recipe
    ORDER[#ORDER + 1] = name
end

-- Metal chrome of the Nozdor client (MetalFrame2X_Decorate): pieces live on the child frame MetalBorder.
local SERVER_PIECES = { "CornerTopLeft", "CornerTopRight", "CornerBottomLeft", "CornerBottomRight",
    "BorderTop", "BorderBottom", "BorderLeft", "BorderRight" }

local function settings() return ui.Settings and ui.Settings() or {} end
local function enabled() return settings().foreverWindows ~= false end
local function option(key, default)
    local value = settings()[key]
    if value == nil then return default end
    return value
end

local skins = {}
-- True while the skin itself sets a swapped texture (its own file, or the client's back): the SetTexture hooks
-- that keep the swaps in place ignore those calls.
local marbleSetting = false

-- Hiding is remembered per region, so turning the chrome off restores exactly what was there.
local function fade(st, region)
    if not region or not region.SetAlpha then return end
    if st.alpha[region] == nil then st.alpha[region] = region:GetAlpha() or 1 end
    region:SetAlpha(0)
end

local function hide(st, region)
    if not region or not region.Hide then return end
    if st.shown[region] == nil then st.shown[region] = region:IsShown() and true or false end
    region:Hide()
end

-- Client portraits/spec rings re-shown on tab switches stay hidden while our ring portrait is on.
local hiddenHooked = {}
local function keepHidden(st, region)
    if not region or not region.Hide then return end
    hide(st, region)
    st.keepHidden = st.keepHidden or {}
    st.keepHidden[region] = true
    if hiddenHooked[region] or not hooksecurefunc or not region.Show then return end
    hiddenHooked[region] = st
    hooksecurefunc(region, "Show", function(self)
        local owner = hiddenHooked[self]
        if owner and owner.active and owner.ring and owner.keepHidden and owner.keepHidden[self] then
            self:Hide()
        end
    end)
end

local function restore(st)
    st.active = false                        -- first, so the model's and portrait's Show hooks let them show again
    st.keepHidden = {}
    if st.ownClose then st.ownClose:Hide() end  -- a close button of our own goes with the chrome
    for region, alpha in pairs(st.alpha) do region:SetAlpha(alpha) end
    for region, wasShown in pairs(st.shown) do
        if wasShown then region:Show() end
    end
    for frame, strata in pairs(st.stratas) do frame:SetFrameStrata(strata) end
    local windowLevel = st.window:GetFrameLevel()
    for frame, offset in pairs(st.levels) do frame:SetFrameLevel(math.max(0, windowLevel + offset)) end
    st.alpha, st.shown, st.levels, st.stratas = {}, {}, {}, {}
    for region in pairs(st.own) do region:Hide() end
    for region, parent in pairs(st.parents) do region:SetParent(parent) end
    st.parents = {}
    for region, size in pairs(st.sizes or {}) do
        region:SetWidth(size[1])
        region:SetHeight(size[2])
    end
    st.pins = {}
    for frame, scale in pairs(st.scales or {}) do frame:SetScale(scale) end
    st.scales = {}
    for region in pairs(st.iconButtons or {}) do
        if region.SetDesaturated then region:SetDesaturated(false) end
        region:SetVertexColor(1, 1, 1)
    end
    st.iconButtons = {}
    marbleSetting = true                     -- putting the client's file back is not the client re-setting it
    for region, path in pairs(st.swaps or {}) do region:SetTexture(path) end
    marbleSetting = false
    st.swaps = {}
    for region, justify in pairs(st.justify or {}) do region:SetJustifyH(justify) end
    st.justify = {}
    for region, coords in pairs(st.coords or {}) do
        if #coords >= 4 then region:SetTexCoord(unpack(coords)) end
    end
    st.coords = {}
    for frame, points in pairs(st.moved) do
        frame:ClearAllPoints()
        for _, p in ipairs(points) do frame:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    end
    if st.closeMoved then
        local button = st.closeMoved
        button:ClearAllPoints()
        for _, p in ipairs(st.closePoints) do button:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
        button:SetWidth(st.closeSize[1])
        button:SetHeight(st.closeSize[2])
        st.closeMoved = nil
    end
    if st.titleMoved then
        local title = st.titleMoved
        title:ClearAllPoints()
        for _, p in ipairs(st.titlePoints) do title:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
        st.titleMoved = nil
    end
    st.chrome:Hide()
    st.ground:Hide()
end

-- The highest frame level inside the window (its panels, slots, model...), so the chrome can lie above them.
local function topLevel(frame, skip, depth, best, maxDepth)
    if depth > (maxDepth or 6) then return best end
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        if not skip[child] and child.GetFrameLevel then
            local level = child:GetFrameLevel()
            if level > best then best = level end
            best = topLevel(child, skip, depth + 1, best, maxDepth)
        end
    end
    return best
end

-- recipe.under: frames of the window (and everything inside them) that must stay under the chrome. The client
-- may put such a frame up when it is shown again (the glyph tab). The chrome offset this needs, or 0.
local function underOffset(recipe, windowLevel)
    local need = 0
    for _, frameName in ipairs(recipe.under or {}) do
        local frame = _G[frameName]
        if frame and frame.GetFrameLevel and frame:IsShown() then
            local top = topLevel(frame, {}, 0, frame:GetFrameLevel(), 2)
            if top + 1 - windowLevel > need then need = top + 1 - windowLevel end
        end
    end
    return need
end

local function isTexture(region)
    return region.GetObjectType and region:GetObjectType() == "Texture"
end

-- Close button: every texture of the client (its states and the red CloseButton2X_Apply art) is made
-- transparent and the WoW Forever button is drawn instead; pressing shows the pressed state, hovering the glow.
-- The window's close button: by name first; else a child button named "...Close..." or showing the stock cross
-- (the guild bank on Nozdor has none by the usual names, and its cross stayed hidden under the chrome). A window
-- without any gets a close button of its own (it hides the window, the way the stock cross does).
-- Strict on purpose: a wrong match is moved to the corner with its art faded (an icon button would lose its icon).
local CLOSE_ART = { "ui%-panel%-minimizebutton%-up" }
local function findCloseIn(frame, depth)
    if depth > 2 or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button" then
            local childName = child.GetName and child:GetName()
            if childName and childName:find("CloseButton$") then return child end
            local normal = child.GetNormalTexture and child:GetNormalTexture()
            local path = normal and normal.GetTexture and normal:GetTexture()
            if type(path) == "string" then
                path = path:lower()
                for _, art in ipairs(CLOSE_ART) do
                    if path:find(art) then return child end
                end
            end
        end
        local found = findCloseIn(child, depth + 1)
        if found then return found end
    end
end

local function findClose(st, window, name)
    local close = window.CloseButton or (name and _G[name .. "CloseButton"])
    if close then return close end
    -- Only the old 3.3.5 windows (rect recipes) are searched or get a close button of their own; the metal windows
    -- of Nozdor carry theirs in the client's chrome.
    if not (st.recipe and st.recipe.rect) then return nil end
    close = findCloseIn(window, 0)
    if close then return close end
    if not st.ownClose then
        st.ownClose = CreateFrame("Button", name and (name .. "ForeverClose") or nil, window)
        st.ownClose:SetScript("OnClick", function()
            if HideUIPanel then HideUIPanel(window) else window:Hide() end
        end)
    end
    st.ownClose:Show()
    return st.ownClose
end

local function skinClose(st, button)
    if not button or not button.CreateTexture then return end
    st.closeButton = button
    if not st.closeFace then
        local face = button:CreateTexture(nil, "ARTWORK")
        face:SetTexture(CLOSE)
        local glow = button:CreateTexture(nil, "HIGHLIGHT")
        glow:SetTexture(CLOSE)
        glow:SetTexCoord(closeCoords(2))
        glow:SetBlendMode("ADD")
        st.closeFace, st.closeGlow = face, glow
        st.own[face], st.own[glow] = true, true
        if button.HookScript then
            button:HookScript("OnMouseDown", function() if st.active then face:SetTexCoord(closeCoords(1)) end end)
            button:HookScript("OnMouseUp", function() if st.active then face:SetTexCoord(closeCoords(0)) end end)
        end
    end
    for _, region in ipairs({ button:GetRegions() }) do
        if isTexture(region) and not st.own[region] then fade(st, region) end
    end
    -- The button itself moves onto the top-right corner, over the frame: a square nearly as tall as the header
    -- band. The client's anchors and size are kept for turning the chrome off.
    if not st.closePoints then
        st.closePoints = {}
        for i = 1, button:GetNumPoints() do st.closePoints[i] = { button:GetPoint(i) } end
        st.closeSize = { button:GetWidth(), button:GetHeight() }
    end
    local s = (tonumber(option("foreverWindowScale", 50)) or 50) / 100
    local size = CLOSE_SIZE * s
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", st.chrome, "TOPRIGHT", CLOSE_X, CLOSE_Y)
    button:SetWidth(size)
    button:SetHeight(size)
    st.closeMoved = button
    for _, tex in ipairs({ st.closeFace, st.closeGlow }) do
        tex:ClearAllPoints()
        tex:SetAllPoints(button)
    end
    local on = not button.IsEnabled or button:IsEnabled()
    st.closeFace:SetTexCoord(closeCoords((on and on ~= 0) and 0 or 3))
    st.closeFace:Show()
    st.closeGlow:Show()
end

-- A header button with a WoW Forever face (the map's maximize / minimize): the client's textures go, the button
-- takes the close button's size, the face shows the pressed and disabled states, a faint copy lights on hover.
local function skinHeaderArt(st, button, col, size)
    st.arts = st.arts or {}
    local art = st.arts[button]
    if not art then
        local face = button:CreateTexture(nil, "ARTWORK")
        face:SetTexture(WINDOW_BUTTONS)
        face:SetAllPoints(button)
        local glow = button:CreateTexture(nil, "HIGHLIGHT")
        glow:SetTexture(WINDOW_BUTTONS)
        glow:SetTexCoord(buttonCell(col, 0))
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0.35)
        glow:SetAllPoints(button)
        st.own[face], st.own[glow] = true, true
        if button.HookScript then
            button:HookScript("OnMouseDown", function() if st.active then face:SetTexCoord(buttonCell(col, 2)) end end)
            button:HookScript("OnMouseUp", function() if st.active then face:SetTexCoord(buttonCell(col, 0)) end end)
        end
        art = { face = face, glow = glow }
        st.arts[button] = art
    end
    for _, region in ipairs({ button:GetRegions() }) do
        if isTexture(region) and not st.own[region] then fade(st, region) end
    end
    st.sizes = st.sizes or {}
    if not st.sizes[button] then st.sizes[button] = { button:GetWidth(), button:GetHeight() } end
    button:SetWidth(size)
    button:SetHeight(size)
    local on = not button.IsEnabled or button:IsEnabled()
    art.face:SetTexCoord(buttonCell(col, (on and on ~= 0) and 0 or 1))
    art.face:Show()
    art.glow:Show()
end

-- Item slots: the client's slot frame (char-paperdoll-parts, on the button or as <slot>Frame) is made
-- transparent and the WoW Forever rim goes around the icon. Icon, quality border and labels are not touched.
local function skinSlot(st, button)
    if not button or not button.CreateTexture then return end
    local rim = st.rims[button]
    if not rim then
        rim = button:CreateTexture(nil, "OVERLAY")
        rim:SetTexture(SLOT_ART)
        rim:SetTexCoord(4 / 128, 108 / 128, 4 / 128, 110 / 128)
        rim:SetPoint("TOPLEFT", button, "TOPLEFT", -SLOT_OUTSET, SLOT_OUTSET)
        rim:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", SLOT_OUTSET, -SLOT_OUTSET)
        st.rims[button] = rim
        st.own[rim] = true
    end
    -- A frame around the icon is either char-paperdoll-parts or any texture clearly larger than the button
    -- (the ammo slot's frame has its own file). Icon, quality border and highlight are button-sized and stay.
    -- The icon can be larger than the button on this client: the icon region, the quality border and every item
    -- or empty-slot picture are never touched, whatever their size.
    local bw, bh = button:GetWidth() or 0, button:GetHeight() or 0
    local name = button.GetName and button:GetName()
    local keep = {}
    for _, region in ipairs({ name and _G[name .. "IconTexture"], button.icon, button.Icon, button.IconTexture,
        button.IconBorder, button.iconBorder }) do
        if region then keep[region] = true end
    end
    for _, region in ipairs({ button:GetRegions() }) do
        if isTexture(region) and not st.own[region] and not keep[region] then
            local path = type(region:GetTexture()) == "string" and region:GetTexture():lower() or ""
            local picture = path:find("interface[\\/]icons[\\/]") or path:find("ui%-paperdoll%-slot")
            local larger = bw > 0 and ((region:GetWidth() or 0) >= bw + SLOT_LARGER or (region:GetHeight() or 0) >= bh + SLOT_LARGER)
            if not picture and (larger or path:find("paperdoll%-parts")) then fade(st, region) end
        end
    end
    if name then fade(st, _G[name .. "Frame"]) end
    rim:Show()
end

-- Item cells of the guild bank (recipe.guildCells) and the merchant (recipe.merchantCells): the client's cell art
-- (guild bank columns UI-GuildBankFrame-Slots, the merchant's UI-EmptySlot) and each button's UI-Quickslot2 frame
-- are made transparent; every cell gets the WoW Forever bag cell and its bronze edge, as in the unified bag
-- (Bags.lua). Icon, count and highlight are not touched. The edge is button.foreverCellEdge: the merchant paints it
-- red for an item the character cannot use (Merchant.lua), as the client did with the faded frame.
local CELL_FILL = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Bag-Slot"
local CELL_EDGE = "Interface\\AddOns\\ForeverUI\\Art\\Backpack-Chrome"
local GUILD_COLUMNS, GUILD_ROWS = 7, 14
local MERCHANT_CELLS = 12 -- 10 items on a page, 12 on the buyback page

local function skinCell(st, button)
    if not (button and button.CreateTexture) then return end
    st.cells = st.cells or {}
    local cell = st.cells[button]
    if not cell then
        local fill = button:CreateTexture(nil, "BACKGROUND", nil, -2)
        fill:SetTexture(CELL_FILL)
        fill:SetTexCoord(1 / 64, 63 / 64, 1 / 64, 63 / 64)
        fill:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        local edge = button:CreateTexture(nil, "ARTWORK", nil, 2)
        edge:SetTexture(CELL_EDGE)
        edge:SetTexCoord(0, 0.25, 0, 0.5)
        edge:SetAllPoints(button)
        cell = { fill, edge }
        st.cells[button] = cell
        st.own[fill], st.own[edge] = true, true
        button.foreverCellEdge = edge
    end
    local name = button.GetName and button:GetName()
    fade(st, name and _G[name .. "NormalTexture"])
    cell[1]:Show()
    cell[2]:Show()
end

local function skinGuildCells(st)
    for c = 1, GUILD_COLUMNS do
        fade(st, _G["GuildBankColumn" .. c .. "Background"])
        for b = 1, GUILD_ROWS do skinCell(st, _G["GuildBankColumn" .. c .. "Button" .. b]) end
    end
end

-- A row without an item (the client hides its item button) keeps no empty name plate: the plate is faded while
-- the row is empty and given back when an item comes (page change, buyback tab, MERCHANT_UPDATE).
local function emptyPlate(st, plate, empty)
    if not plate or not plate.SetAlpha then return end
    if empty then
        fade(st, plate)
    elseif st.alpha[plate] ~= nil then
        plate:SetAlpha(st.alpha[plate])
        st.alpha[plate] = nil
    end
end

local function skinMerchantCells(st)
    for i = 1, MERCHANT_CELLS do
        fade(st, _G["MerchantItem" .. i .. "SlotTexture"])
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        skinCell(st, button)
        emptyPlate(st, _G["MerchantItem" .. i .. "NameFrame"], button and not button:IsShown())
    end
    fade(st, _G["MerchantBuyBackItemSlotTexture"])
    skinCell(st, _G["MerchantBuyBackItemItemButton"])
end

-- Slots the recipe does not name (the ammo slot, client additions): any slot-sized (30..80 px) char-paperdoll-parts
-- frame inside the window is made transparent and the rim is drawn over its place. Smaller pieces of the same file
-- (the title picker's 8 x 9 divider caps) are not slots.
local function skinSlotFrames(st, frame, depth)
    if depth > 6 or frame == st.chrome then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if isTexture(region) and not st.own[region] and st.alpha[region] == nil then
            local path = region:GetTexture()
            local w, h = region:GetWidth() or 0, region:GetHeight() or 0
            if type(path) == "string" and path:lower():find("paperdoll%-parts") and w >= 30 and w <= 80 and h >= 30 and h <= 80 then
                fade(st, region)
                local rim = st.rims[region]
                if not rim then
                    rim = region:GetParent():CreateTexture(nil, "OVERLAY")
                    rim:SetTexture(SLOT_ART)
                    rim:SetTexCoord(4 / 128, 108 / 128, 4 / 128, 110 / 128)
                    rim:SetAllPoints(region)
                    st.rims[region] = rim
                    st.own[rim] = true
                end
                rim:Show()
            end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do skinSlotFrames(st, child, depth + 1) end
end

local function statsTexture(st, parent, layer)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(STATS)
    st.own[tex] = true
    return tex
end

local function statsCoords(tex, x0, y0, x1, y1)
    tex:SetTexCoord(x0 / STATS_SIZE, x1 / STATS_SIZE, y0 / STATS_SIZE, y1 / STATS_SIZE)
end

-- Stats panel (and any inner panel the recipe names): the client's own textures of the panel (its dark fill and
-- grey scroll corners) are made transparent; the WoW Forever ground and the bronze inset frame are drawn instead.
-- Child frames (rows, headers, the model) are not touched here.
local function skinPanel(st, panel)
    if not panel or not panel.CreateTexture then return end
    local art = st.panels[panel]
    if not art then
        art = { ground = statsTexture(st, panel, "BACKGROUND"), pieces = {} }
        art.ground:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
        art.ground:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
        statsCoords(art.ground, GROUND_BOX[1], GROUND_BOX[2], GROUND_BOX[3], GROUND_BOX[4])
        local c = INSET_CORNER
        local cs = c * INSET_SCALE
        local x0, y0, x1, y1 = INSET_X0, INSET_Y0, INSET_X1, INSET_Y1
        -- Texture box, then one or two anchors { point, panel point, x, y }; corners have a fixed size.
        local slices = {
            { x0, y0, x0 + c, y0 + c, { "TOPLEFT", "TOPLEFT", 0, 0 } },
            { x1 - c, y0, x1, y0 + c, { "TOPRIGHT", "TOPRIGHT", 0, 0 } },
            { x0, y1 - c, x0 + c, y1, { "BOTTOMLEFT", "BOTTOMLEFT", 0, 0 } },
            { x1 - c, y1 - c, x1, y1, { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 } },
            { x0 + c, y0, x1 - c, y0 + c, { "TOPLEFT", "TOPLEFT", cs, 0 }, { "BOTTOMRIGHT", "TOPRIGHT", -cs, -cs } },
            { x0 + c, y1 - c, x1 - c, y1, { "BOTTOMLEFT", "BOTTOMLEFT", cs, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", -cs, cs } },
            { x0, y0 + c, x0 + c, y1 - c, { "TOPLEFT", "TOPLEFT", 0, -cs }, { "BOTTOMRIGHT", "BOTTOMLEFT", cs, cs } },
            { x1 - c, y0 + c, x1, y1 - c, { "TOPRIGHT", "TOPRIGHT", 0, -cs }, { "BOTTOMLEFT", "BOTTOMRIGHT", -cs, cs } },
        }
        for i, sl in ipairs(slices) do
            local tex = statsTexture(st, panel, "BORDER")
            statsCoords(tex, sl[1], sl[2], sl[3], sl[4])
            for k = 5, 6 do
                local a = sl[k]
                if a then tex:SetPoint(a[1], panel, a[2], a[3], a[4]) end
            end
            if not sl[6] then
                tex:SetWidth(cs)
                tex:SetHeight(cs)
            end
            art.pieces[i] = tex
        end
        st.panels[panel] = art
    end
    for _, region in ipairs({ panel:GetRegions() }) do
        if isTexture(region) and not st.own[region] then fade(st, region) end
    end
    art.ground:Show()
    for _, tex in ipairs(art.pieces) do tex:Show() end
end

-- Stat category headers: the client's title plate (header.Background, or the header's largest texture) is made
-- transparent and the WoW Forever plate takes its place, cut in three so the scroll caps keep their shape.
-- One plate in three slices, on the given layer: from the left edge of `refL` to the right edge of `refR`, as
-- tall as they are (one rect: refL == refR).
local function makePlate(st, header, refL, refR, layer)
    local plate = {}
    plate.left = statsTexture(st, header, layer)
    plate.mid = statsTexture(st, header, layer)
    plate.right = statsTexture(st, header, layer)
    statsCoords(plate.left, PLATE_X0, PLATE_Y0, PLATE_X0 + PLATE_CAP, PLATE_Y1)
    statsCoords(plate.mid, PLATE_X0 + PLATE_CAP, PLATE_Y0, PLATE_X1 - PLATE_CAP, PLATE_Y1)
    statsCoords(plate.right, PLATE_X1 - PLATE_CAP, PLATE_Y0, PLATE_X1, PLATE_Y1)
    plate.left:SetPoint("TOPLEFT", refL, "TOPLEFT")
    plate.left:SetPoint("BOTTOMLEFT", refL, "BOTTOMLEFT")
    plate.right:SetPoint("TOPRIGHT", refR, "TOPRIGHT")
    plate.right:SetPoint("BOTTOMRIGHT", refR, "BOTTOMRIGHT")
    plate.mid:SetPoint("TOPLEFT", plate.left, "TOPRIGHT")
    plate.mid:SetPoint("BOTTOMRIGHT", plate.right, "BOTTOMLEFT")
    return plate
end

local function eachSlice(plate, fn)
    fn(plate.left)
    fn(plate.mid)
    fn(plate.right)
end

-- The two end caps of the client's plate (PaperDollInfoPart textures no wider than 40 px on a non-highlight
-- layer), left one first: by position when the client has laid them out, else in region order.
local function plateCaps(st, header)
    local caps = {}
    for _, region in ipairs({ header:GetRegions() }) do
        if isTexture(region) and not st.own[region] then
            local path = region:GetTexture()
            if type(path) == "string" and path:lower():find("paperdollinfopart") and (region:GetWidth() or 0) <= 40
                and region:GetDrawLayer() ~= "HIGHLIGHT" then
                caps[#caps + 1] = region
            end
        end
    end
    if #caps ~= 2 then return end
    local l1, l2 = caps[1]:GetLeft(), caps[2]:GetLeft()
    if l1 and l2 and l2 < l1 then return caps[2], caps[1] end
    return caps[1], caps[2]
end

-- Nozdor's header is a button (234 x 22) with its plate in three PaperDollInfoPart1 pieces (two 21 x 30 caps and
-- a middle, taller than the button) plus the same three on the HIGHLIGHT layer. All of them are made transparent;
-- the WoW Forever plate takes the client plate's full size (left cap's left edge to right cap's right edge, cap
-- height), and a faint copy of it on the HIGHLIGHT layer lights up on hover. Without caps the plate covers
-- .Background or the header itself.
local function skinHeader(st, header)
    if not header or not header.CreateTexture then return end
    local plate = st.headers[header]
    if not plate then
        local capL, capR = plateCaps(st, header)
        local refL = capL or header.Background or header
        local refR = capR or refL
        plate = makePlate(st, header, refL, refR, "BACKGROUND")
        plate.ref = refL
        plate.glow = makePlate(st, header, refL, refR, "HIGHLIGHT")
        eachSlice(plate.glow, function(tex)
            tex:SetBlendMode("ADD")
            tex:SetAlpha(0.25)
        end)
        st.headers[header] = plate
    end
    -- Caps keep the plate's proportions at the header's height.
    local h = plate.ref:GetHeight() or 0
    local cap = h > 0 and h * PLATE_CAP / (PLATE_Y1 - PLATE_Y0) or 8
    for _, p in ipairs({ plate, plate.glow }) do
        p.left:SetWidth(cap)
        p.right:SetWidth(cap)
        eachSlice(p, function(tex) tex:Show() end)
    end
    if plate.ref ~= header then fade(st, plate.ref) end
    for _, region in ipairs({ header:GetRegions() }) do
        if isTexture(region) and not st.own[region] then
            local path = region:GetTexture()
            if type(path) == "string" and path:lower():find("paperdollinfopart") then fade(st, region) end
        end
    end
end

-- Decorations of a panel can sit on child frames without any text (corner scrolls, an inset frame): their
-- textures go too. Frames with text or children of their own (rows, headers, buttons) are left alone.
local function hasText(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then return true end
    end
    return false
end

local function fadeDecor(st, panel)
    for _, child in ipairs({ panel:GetChildren() }) do
        if child ~= st.chrome and select("#", child:GetChildren()) == 0 and not hasText(child)
            and child:GetObjectType() == "Frame" then
            for _, region in ipairs({ child:GetRegions() }) do
                if isTexture(region) and not st.own[region] then fade(st, region) end
            end
        end
    end
end

-- Header titles of the stats panel in any locale: the client's category names plus the item level title.
local HEADER_TEXTS = {}
for _, key in ipairs({ "PLAYERSTAT_BASE_STATS", "PLAYERSTAT_MELEE_COMBAT", "PLAYERSTAT_RANGED_COMBAT",
    "PLAYERSTAT_SPELL_COMBAT", "PLAYERSTAT_DEFENSES", "STAT_AVERAGE_ITEM_LEVEL", "STAT_CATEGORY_ATTRIBUTES",
    "STAT_CATEGORY_ENHANCEMENTS", "ITEM_LEVEL_ABBR" }) do
    if type(_G[key]) == "string" then HEADER_TEXTS[_G[key]] = true end
end
for _, text in ipairs({ "Уровень предметов", "Характеристики", "Заклинания", "Ближний бой", "Дальний бой", "Защита",
    "Item Level", "Base Stats", "Attributes", "Spell", "Melee", "Ranged", "Defenses" }) do
    HEADER_TEXTS[text] = true
end

-- Category headers have no names: a header is the frame holding one of these titles (they sit 7+ levels deep).
local function findHeaders(st, frame, depth, found)
    if depth > 12 or frame == st.chrome then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            local text = region:GetText()
            if text and HEADER_TEXTS[text] then found[#found + 1] = frame break end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do findHeaders(st, child, depth + 1, found) end
end

local function skinStats(st)
    if not st.recipe.stats or option("foreverWindowStats", true) == false then return end
    -- Panels come from the recipe. Headers are looked up by title until some are found, then remembered
    -- (their titles change with the category dropdown; the frames stay).
    if #st.statPanels == 0 then
        for _, n in ipairs(st.recipe.panels or {}) do
            if _G[n] then st.statPanels[#st.statPanels + 1] = _G[n] end
        end
    end
    if #st.statHeaders == 0 then
        local found = {}
        findHeaders(st, st.window, 0, found)
        for _, header in ipairs(found) do
            -- A frame taller than a plate holding a title is a section, not a header of its own.
            if (header:GetHeight() or 0) <= 40 then st.statHeaders[#st.statHeaders + 1] = header end
        end
        for _, n in ipairs(st.recipe.headers or {}) do
            if _G[n] then st.statHeaders[#st.statHeaders + 1] = _G[n] end
        end
    end
    for _, panel in ipairs(st.statPanels) do
        skinPanel(st, panel)
        fadeDecor(st, panel)
    end
    local seen = {}
    for _, header in ipairs(st.statHeaders) do
        if not seen[header] then
            seen[header] = true
            skinHeader(st, header)
        end
    end
end

-- Title: kept from the client, moved up or down so it sits in the middle of the new header.
local function placeTitle(st, top, s)
    local title = st.metalTitle or (st.window.MetalBorder and st.window.MetalBorder.TitleText)
    if not title or not title.GetNumPoints or title:GetNumPoints() == 0 then return end
    if not st.titlePoints then
        st.titlePoints = {}
        for i = 1, title:GetNumPoints() do st.titlePoints[i] = { title:GetPoint(i) } end
    end
    if not st.titleOffset then
        local windowTop = st.window:GetTop()
        local _, centre = title:GetCenter()
        if not (windowTop and centre) then return end
        st.titleOffset = windowTop - centre       -- the client's title centre below the window top
    end
    local shift = top - HEADER_CENTER * s - TITLE_NUDGE + (tonumber(option("foreverWindowTitleY", 0)) or 0)
        + st.titleOffset
    title:ClearAllPoints()
    for _, p in ipairs(st.titlePoints) do title:SetPoint(p[1], p[2], p[3], p[4], (p[5] or 0) + shift) end
    st.titleMoved = title
end

-- The chrome's top-left offsets from `base`, pulled in so the ring corner stays on the screen: the maximized
-- map fills the screen and its ring (raised header, ring overhang) went past the top edge.
local function keepOnScreen(base, top, left, recipe)
    local scale = base.GetEffectiveScale and base:GetEffectiveScale() or 1
    local screen = UIParent and UIParent.GetTop and UIParent:GetTop()
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local baseTop, baseLeft = base:GetTop(), base:GetLeft()
    if not (screen and baseTop and baseLeft and scale > 0) then return top, left end
    local s = (tonumber(ui.Settings and ui.Settings().foreverWindowScale) or 50) / 100
    local corner = CORNERS.TopLeftRing
    local overTop = (corner[6] - corner[2]) * s          -- the ring reaches this far above the frame's edge
    local overLeft = (corner[5] - corner[1]) * s
    local screenTop = screen * uiScale / scale
    local room = screenTop - (baseTop + top + overTop)
    if room < 0 then top = top + room end
    local roomLeft = (baseLeft + left - overLeft)
    if roomLeft < 0 then left = left - roomLeft end
    return top, left
end

-- The tabs hanging under a window: <Name>Tab1..10, <Name>TabButton1..10 (the spellbook) and the recipe's own list
-- (the finder's HK_LFDTopTab..., the adventure guide's ...Tab).
-- Inset grounds: the client's marble (UI-Background-Marble, 256 x 256) inside a window's insets takes a WoW Forever
-- ground of the same size, so the client's tiling stays as it is: the warm brown stone of the bank
-- (bankframebackgroundc60; the Forever marble is near black and looked like the client's grey). The file is
-- swapped on the region itself and put back when the skin goes.
local MARBLE = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Window-InsetGround"

-- Icons swapped for WoW Forever ones: the texture of the client's icon (recognised by its file) on a named button
-- takes Window-Merchant.tga (merchant.tga, 512 x 256) with the given cell (texture px).
local MERCHANT_ART = "Interface\\AddOns\\ForeverUI\\Art\\Forever\\Window-Merchant"
local function swapIcons(st, icons)
    for buttonName, icon in pairs(icons) do
        local button = _G[buttonName]
        if button and button.GetRegions then
            for _, region in ipairs({ button:GetRegions() }) do
                if region.GetObjectType and region:GetObjectType() == "Texture" then
                    local path = region:GetTexture()
                    if type(path) == "string" and path:lower():find(icon.match) then
                        st.swaps = st.swaps or {}
                        st.coords = st.coords or {}
                        if not st.swaps[region] then st.swaps[region] = path end
                        if not st.coords[region] and region.GetTexCoord then st.coords[region] = { region:GetTexCoord() } end
                        local c = icon.cell
                        region:SetTexture(MERCHANT_ART)
                        region:SetTexCoord(c[1] / 512, c[3] / 512, c[2] / 256, c[4] / 256)
                        st.iconButtons = st.iconButtons or {}
                        st.iconButtons[region] = button
                    end
                end
            end
        end
    end
end
-- The client sets its marble again on some updates (another merchant, a tab switch): each swapped region is
-- watched, and a marble the client puts back is replaced at once while the skin is on.
local marbleHooked = {}
local function keepMarble(st, region)
    if marbleHooked[region] or not hooksecurefunc then return end
    marbleHooked[region] = true
    hooksecurefunc(region, "SetTexture", function(self, path)
        if marbleSetting or not st.active or type(path) ~= "string" then return end
        if path:lower():find("ui%-background%-marble") then
            st.swaps = st.swaps or {}
            st.swaps[self] = path
            marbleSetting = true
            self:SetTexture(MARBLE)
            marbleSetting = false
        end
    end)
end

local function swapMarble(st, frame, depth)
    if depth > 4 or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            local path = region:GetTexture()
            if type(path) == "string" and path:lower():find("ui%-background%-marble") then
                st.swaps = st.swaps or {}
                if not st.swaps[region] then st.swaps[region] = path end
                marbleSetting = true
                region:SetTexture(MARBLE)
                marbleSetting = false
                keepMarble(st, region)
            end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child ~= st.chrome then swapMarble(st, child, depth + 1) end
    end
end

-- A swapped icon follows its button's state: a disabled button shows it grey and dimmed (the Nozdor client did not
-- desaturate the WoW Forever anvil when repairing all was unavailable).
local function syncIcons(st)
    for region, button in pairs(st.iconButtons or {}) do
        local on = not button.IsEnabled or button:IsEnabled()
        on = on and on ~= 0
        if region.SetDesaturated then region:SetDesaturated(not on) end
        if on then region:SetVertexColor(1, 1, 1) else region:SetVertexColor(0.55, 0.55, 0.55) end
    end
end

-- Pins: a region the skin places (portrait, title) is put back at once when the client moves it, so it does not
-- jump on tab switches (the finder re-anchors its portrait and title on every tab). One hook per region; it acts
-- only while the window's skin is on and the region is pinned.
local pinned, pinning = {}, false
local function pin(st, region, place)
    st.pins = st.pins or {}
    st.pins[region] = place
    if pinned[region] or not hooksecurefunc then return end
    pinned[region] = st
    for _, method in ipairs({ "SetPoint", "SetAllPoints" }) do
        if region[method] then
            hooksecurefunc(region, method, function(self)
                local owner = pinned[self]
                local again = owner and owner.active and owner.pins and owner.pins[self]
                if pinning or not again then return end
                pinning = true
                again()
                pinning = false
            end)
        end
    end
end

local function windowTabs(name, recipe)
    local tabs = {}
    for _, n in ipairs(recipe.tabs or {}) do
        if _G[n] then tabs[#tabs + 1] = _G[n] end
    end
    for i = 1, 10 do
        for _, pattern in ipairs({ "Tab", "TabButton" }) do
            local tab = _G[name .. pattern .. i]
            if tab and tab.GetTop then tabs[#tabs + 1] = tab end
        end
    end
    return tabs
end

local function texPath(region)
    local path = region and region.GetTexture and region:GetTexture()
    return type(path) == "string" and path:lower() or ""
end

-- The Nozdor metal chrome: MetalBorder, or (map, adventure guide) a shown child or grandchild of another name that
-- holds the UIFrameMetal2x pieces.
local function metalHolder(window)
    if window.MetalBorder then return window.MetalBorder end
    local function search(frame, depth)
        for _, child in ipairs({ frame:GetChildren() }) do
            if child.IsShown and child:IsShown() then
                for _, region in ipairs({ child:GetRegions() }) do
                    if isTexture(region) and texPath(region):find("uiframemetal") then return child end
                end
                if depth < 2 then
                    local found = search(child, depth + 1)
                    if found then return found end
                end
            end
        end
    end
    return search(window, 1)
end

-- Title of the metal chrome: its TitleText, or the holder's first text.
local function metalTitle(border)
    if border.TitleText then return border.TitleText end
    for _, region in ipairs({ border:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then return region end
    end
end

-- The texture that shows a portrait: the region itself, or the first texture of a portrait frame.
local function portraitTexture(p, depth)
    if not p then return end
    if isTexture(p) then return p end
    if p.GetRegions then
        for _, region in ipairs({ p:GetRegions() }) do
            if isTexture(region) and texPath(region) ~= "" then return region end
        end
    end
    -- A portrait frame can hold its picture one frame deeper (the dungeon finder's eye).
    if (depth or 0) < 1 and p.GetChildren then
        for _, child in ipairs({ p:GetChildren() }) do
            local tex = portraitTexture(child, (depth or 0) + 1)
            if tex then return tex end
        end
    end
end

local function showsPicture(p)
    if not (p and p.IsShown and p:IsShown()) then return false end
    if p.GetAlpha and p:GetAlpha() < 0.01 then return false end
    local tex = portraitTexture(p)
    return tex ~= nil and texPath(tex) ~= "" and (not tex.GetAlpha or tex:GetAlpha() >= 0.01)
end

-- The window's portrait: the first one that shows a picture among the known places (the metal chrome's ring
-- portrait, <Name>Portrait, <Name>PortraitFrame, the holder's own portrait texture). Second value: whether the
-- window has a portrait slot at all (then an empty one gets the player's portrait).
local function findPortrait(window, name, border, own)
    local candidates, count = {}, 0
    local function add(p)
        if p then
            count = count + 1
            candidates[count] = p
        end
    end
    add(own and _G[own])
    add(window.ringPortrait)
    add(window.portrait)
    add(name and _G[name .. "Portrait"])
    add(name and _G[name .. "PortraitFrame"])
    add(window.PortraitFrame)
    if border then
        for _, region in ipairs({ border:GetRegions() }) do
            if isTexture(region) and region ~= window.specRingIcon and region ~= border.specRingIcon
                and texPath(region):find("^portrait%d") then
                add(region)
            end
        end
    end
    local any = count > 0
    for i = 1, count do
        local p = candidates[i]
        if showsPicture(p) then return p, true end
    end
    return nil, any
end

-- Title of an old 3.3.5 window: a FontString of the window itself, so it would sit under the new chrome. It moves
-- to a holder frame above the chrome and is centred in the header band. Names the client uses for those titles:
local OLD_TITLES = {
    MerchantFrame = "MerchantNameText", GossipFrame = "GossipFrameNpcNameText", QuestFrame = "QuestFrameNpcNameText",
    ClassTrainerFrame = "ClassTrainerNameText", TabardFrame = "TabardFrameNameText", MailFrame = "InboxTitleText",
    OpenMailFrame = "OpenMailTitleText", ItemTextFrame = "ItemTextTitleText", TaxiFrame = "TaxiMerchant",
    QuestLogFrame = "QuestLogTitleText", FriendsFrame = "FriendsFrameTitleText", PetStableFrame = "PetStableTitleLabel",
}

local function placeOldTitle(st, recipe, name, level, s)
    local title = name and (_G[OLD_TITLES[name] or ""] or _G[name .. "TitleText"] or _G[name .. "Title"])
    if not title or not title.GetNumPoints or (title.GetObjectType and title:GetObjectType() ~= "FontString") then
        return
    end
    if not st.moved[title] then
        local points = {}
        for i = 1, title:GetNumPoints() do points[i] = { title:GetPoint(i) } end
        st.moved[title] = points
    end
    if title.SetParent and title.GetParent then
        if st.parents[title] == nil then st.parents[title] = title:GetParent() end
        st.titleHolder:SetFrameLevel(level)
        title:SetParent(st.titleHolder)
    end
    title:ClearAllPoints()
    title:SetPoint("CENTER", st.chrome, "TOP", 0,
        -(HEADER_CENTER * s + TITLE_NUDGE) + (tonumber(option("foreverWindowTitleY", 0)) or 0))
end

-- Strata order: a frame in a lower stratum than the chrome is drawn under it whatever its level (the map's close
-- and size buttons stay in their stratum when the maximized map moves up).
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7,
    TOOLTIP = 8 }
local function belowStratum(frame, chrome)
    if not (frame.GetFrameStrata and chrome.GetFrameStrata) then return false end
    return (STRATA[frame:GetFrameStrata()] or 3) < (STRATA[chrome:GetFrameStrata()] or 3)
end

-- recipe.under frames in a higher stratum than the chrome (levels alone cannot put the chrome over them): the
-- chrome goes up to their stratum; the frames lifted above the chrome follow it there (raise()).
local function underStrata(st)
    local best = st.window:GetFrameStrata()
    for _, frameName in ipairs(st.recipe.under or {}) do
        local frame = _G[frameName]
        if frame and frame.GetFrameStrata and frame:IsShown() then
            local strata = frame:GetFrameStrata()
            if (STRATA[strata] or 3) > (STRATA[best] or 3) then best = strata end
        end
    end
    return best
end

local function raise(st, frame, above)
    if not frame or not frame.GetFrameLevel then return end
    if belowStratum(frame, st.chrome) then
        if st.stratas[frame] == nil then st.stratas[frame] = frame:GetFrameStrata() end
        frame:SetFrameStrata(st.chrome:GetFrameStrata())
    end
    -- The client's level is kept relative to the window: toplevel windows move up when clicked, and a level put
    -- back as an absolute number could end under its own window.
    local level = frame:GetFrameLevel()
    if level <= above then
        if st.levels[frame] == nil then st.levels[frame] = level - st.window:GetFrameLevel() end
        frame:SetFrameLevel(above + 1)
    end
end

local function place(st)
    local chrome = st.chrome
    local w, h = chrome:GetWidth() or 0, chrome:GetHeight() or 0
    if w <= 0 or h <= 0 then return end
    local s = (tonumber(option("foreverWindowScale", 50)) or 50) / 100
    local pieces, extra = layout(w, h, s, st.ring)
    for i, p in ipairs(pieces) do
        local tex = st.tex[i]
        if not tex then
            tex = chrome:CreateTexture(nil, "BORDER")
            st.tex[i] = tex
        end
        tex:SetTexture(p.file)
        tex:SetTexCoord(p.l, p.r, p.t, p.b)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", chrome, "TOPLEFT", p.x, -p.y)
        tex:SetWidth(p.w)
        tex:SetHeight(p.h)
        tex:Show()
    end
    for i = #pieces + 1, #st.tex do st.tex[i]:Hide() end

    local portrait = st.portrait
    if extra.portrait then
        local p = extra.portrait
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", chrome, "TOPLEFT", p.x, -p.y)
        portrait:SetWidth(p.w)
        portrait:SetHeight(p.h)
        if st.clientPortrait then portrait:Hide() else portrait:Show() end
    else
        portrait:Hide()
    end

    local g = extra.ground
    st.ground:ClearAllPoints()
    st.ground:SetPoint("TOPLEFT", chrome, "TOPLEFT", g.x, -g.y)
    st.ground:SetWidth(g.w)
    st.ground:SetHeight(g.h)
    st.ground:SetTexCoord(g.l, g.r, g.t, g.b)
end

local function updatePortrait(st)
    if st.ring and st.recipe.icon and SetPortraitToTexture then
        SetPortraitToTexture(st.portrait, st.recipe.icon)
        st.portrait:Show()
        return
    end
    local unit = st.recipe.unit or st.ownUnit
    if st.ring and unit and SetPortraitTexture then
        SetPortraitTexture(st.portrait, unit)
        st.portrait:Show()
    end
end

local portraitRetry = CreateFrame("Frame")

local function create(window, recipe)
    local st = { window = window, recipe = recipe, tex = {}, alpha = {}, shown = {}, levels = {}, own = {}, rims = {},
        panels = {}, headers = {}, moved = {}, statPanels = {}, statHeaders = {}, parents = {}, stratas = {} }
    local chrome = CreateFrame("Frame", nil, window)
    chrome:SetScript("OnSizeChanged", function() if st.active then place(st) end end)
    st.chrome = chrome
    st.titleHolder = CreateFrame("Frame", nil, window)
    st.titleHolder:SetAllPoints(window)
    st.portrait = chrome:CreateTexture(nil, "BACKGROUND")
    -- The rock ground lies under everything of the window (a moved client portrait included).
    st.ground = window:CreateTexture(nil, "BACKGROUND")
    if st.ground.SetDrawLayer then st.ground:SetDrawLayer("BACKGROUND", -8) end
    -- Every window on the warm brown stone of WoW Forever (the grey rock looked like the client's own ground).
    st.ground:SetTexture(MARBLE)
    st.own[st.ground] = true
    chrome:Hide()
    st.ground:Hide()
    -- The client re-shows its 3D portrait on portrait updates; while the ring is on it stays hidden.
    for _, name in ipairs(recipe.models or {}) do
        local model = _G[name]
        if model and model.HookScript then
            model:HookScript("OnShow", function(self) if st.active and st.ring then self:Hide() end end)
        end
    end
    skins[window] = st
    -- Each time the window opens its ring portrait is drawn again (a portrait drawn before a loading screen is blank).
    if window.HookScript then
        window:HookScript("OnShow", function() if st.active then updatePortrait(st) end end)
    end
    return st
end

local function hidePortraits(st)
    if not st.ring then return end
    local window, border, recipe = st.window, st.border, st.recipe
    if window.specRingIcon and window.specRingIcon ~= st.clientPortrait then keepHidden(st, window.specRingIcon) end
    if border and border.specRingIcon and border.specRingIcon ~= st.clientPortrait then
        keepHidden(st, border.specRingIcon)
    end
    if recipe.unit then
        keepHidden(st, window.ringPortrait)
        for _, n in ipairs(recipe.portraits or {}) do keepHidden(st, _G[n]) end
        for _, n in ipairs(recipe.models or {}) do hide(st, _G[n]) end
    end
end

local function applyWindow(window, recipe)
    if not window then return end
    local st = skins[window]
    -- The master switch and the window's own checkbox on the Skins page.
    if not enabled() or (recipe.key and option(recipe.key, true) == false) then
        if st and st.active then restore(st) end
        return
    end
    -- A listed window is skinned when it carries the Nozdor metal chrome (built on its first OnShow; MetalBorder,
    -- or a child of another name holding the UIFrameMetal2x pieces) or when its visible rect is known (old 3.3.5
    -- art); otherwise it keeps the client's look.
    local border = metalHolder(window)
    local metal = border ~= nil
    if st then st.border = border end
    if recipe.generic and not metal and not recipe.rect then
        if st and st.active then restore(st) end
        return
    end
    st = st or create(window, recipe)
    if st.active then restore(st) end         -- options may have changed: start from the client's state
    st.active = true
    st.border = border
    local name = window.GetName and window:GetName()

    -- Portrait: the character window draws its own (unit portrait in the ring); every other window moves the
    -- client's visible portrait (texture or frame) into the ring. A portrait slot with nothing visible in it
    -- (the talent window) gets the player's portrait; a window without any gets the plain corner.
    st.clientPortrait, st.wantPlayer = nil, nil
    if recipe.unit then
        st.ring = option("foreverWindowPortrait", true) ~= false
    elseif recipe.icon then
        -- A window of ForeverUI itself (the bags): its own icon, round, in the ring.
        st.ring = true
    else
        local found, any = findPortrait(window, name, border, recipe.portrait)
        st.clientPortrait = found
        st.wantPlayer = any and not found
        st.ring = any and true or false
    end

    local top = 0
    local chrome = st.chrome
    chrome:ClearAllPoints()
    -- The header band sat too low over the window content (checked in game): the top edge of every window, the
    -- character window included, goes GENERIC_RAISE px higher.
    local raiseTop = recipe.raise or GENERIC_RAISE
    -- A window with tabs below (not the character window, tuned as it is): the bottom edge sits right on top of the
    -- tabs, wherever the client (or an addon) put them; the merchant's tabs on Nozdor are higher than ElvUI's
    -- measure. Offset from `base`'s bottom, or nil.
    local function tabEdge(base)
        if recipe.topLevel or not name then return nil end
        local baseBottom = base:GetBottom()
        if not baseBottom then return nil end
        local edge
        for _, tab in ipairs(windowTabs(name, recipe)) do
            local tabTop = tab:IsShown() and tab:GetTop()
            if tabTop and (not edge or tabTop - baseBottom > edge) then edge = tabTop - baseBottom end
        end
        return edge and edge - (recipe.tabOverlap or TAB_OVERLAP)
    end
    if metal or not recipe.rect then
        -- The new chrome follows the client's metal chrome: most windows have it all over the window, the merchant's
        -- is a smaller rect inside its 384 x 512 window (345 x 456 at 15, 17).
        local base = window
        if border and (border:GetWidth() or 0) > 0 and (border:GetHeight() or 0) > 0 then base = border end
        local x = tonumber(option("foreverWindowOutsetX", 1)) or 1
        local bottom = -(tonumber(option("foreverWindowOutsetBottom", 6)) or 6)
        local edge = tabEdge(base)
        if edge then bottom = math.max(edge, bottom) end
        top = (tonumber(option("foreverWindowOutsetTop", 0)) or 0) + raiseTop
        local left = -x - (recipe.leftOut or 0)
        top, left = keepOnScreen(base, top, left, recipe)
        chrome:SetPoint("TOPLEFT", base, "TOPLEFT", left, top)
        -- The title is placed from the window's top: a chrome that starts lower moves it down as much.
        local windowTop, baseTop = window:GetTop(), base:GetTop()
        if base ~= window and windowTop and baseTop then top = top - (windowTop - baseTop) end
        chrome:SetPoint("BOTTOMRIGHT", base, "BOTTOMRIGHT", x, bottom)
    else
        -- ElvUI's rect is the edge of its 1 px border; the bronze frame is thicker, so it goes a little wider and
        -- lower to keep the buttons along the edges inside (the tabs below are lifted above it further down).
        local r = recipe.rect
        local bottom = r[4] - RECT_BOTTOM
        local edge = tabEdge(window)
        -- A window with its own tabOverlap may take the edge below the window's own bottom.
        if edge and (edge > 0 or recipe.tabOverlap) then bottom = edge end
        chrome:SetPoint("TOPLEFT", window, "TOPLEFT", r[1] - RECT_SIDE, r[2] + raiseTop)
        chrome:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", r[3] + RECT_SIDE, bottom)
        -- The old window art (border, background, its painted inner frames) goes, like ElvUI's StripTextures:
        -- only the window's own textures, never its children; the portrait stays for the ring.
        for _, region in ipairs({ window:GetRegions() }) do
            if isTexture(region) and not st.own[region] and region ~= st.clientPortrait then fade(st, region) end
        end
    end

    -- The new chrome lies above everything inside the window (inner panels reach the window's edges), and the
    -- client's chrome (its title) and the close button are lifted just above it.
    local close = findClose(st, window, name)
    -- The chrome's level, as an offset above the window, worked out once: the character window takes it above
    -- every inner frame (its stats panel reaches the bottom edge); a metal window takes the level of the
    -- client's own chrome, as the client does; an old window goes just above its first two layers of frames.
    -- A high absolute level drew the map's frame over other windows opened on top of it, so the others stay low.
    local windowLevel = window:GetFrameLevel()
    if not st.chromeOffset then
        local skip = { [chrome] = true, [st.titleHolder] = true }
        if border then skip[border] = true end
        if close then skip[close] = true end
        local top
        if recipe.topLevel then
            top = topLevel(window, skip, 0, windowLevel) + 1
        elseif border then
            top = border:GetFrameLevel()
        else
            top = topLevel(window, skip, 0, windowLevel, 1) + 1
        end
        st.chromeOffset = math.max(top - windowLevel, 1)
    end
    -- The tabs hang behind the bottom edge (checked in game on the merchant): a selected tab the client
    -- raises stays behind it on re-layout as well as in relevel().
    st.tabs = (name and not recipe.topLevel and not recipe.tabsOver) and windowTabs(name, recipe) or {}
    for _, tab in ipairs(st.tabs) do
        if tab.GetFrameLevel then st.chromeOffset = math.max(st.chromeOffset, tab:GetFrameLevel() + 1 - windowLevel) end
    end
    st.chromeOffset = math.max(st.chromeOffset, underOffset(recipe, windowLevel))
    if recipe.under then chrome:SetFrameStrata(underStrata(st)) end
    local level = windowLevel + st.chromeOffset
    chrome:SetFrameLevel(level)
    -- Frames that stay above the chrome, with their place relative to it (relevel() puts them back there).
    st.lifts = {}
    local function lift(frame, above)
        if not frame then return end
        st.lifts[#st.lifts + 1] = { frame, above }
        raise(st, frame, level + above)
    end
    if border then
        for _, key in ipairs(SERVER_PIECES) do fade(st, border[key]) end
        for _, region in ipairs({ border:GetRegions() }) do
            if isTexture(region) and texPath(region):find("uiframemetal") then fade(st, region) end
        end
        lift(border, 0)
    end
    lift(close, 1)
    skinClose(st, close)
    for _, n in ipairs(recipe.above or {}) do lift(_G[n], 0) end
    if recipe.tabsOver and name then
        for _, tab in ipairs(windowTabs(name, recipe)) do lift(tab, 0) end
    end
    local left = close
    for _, n in ipairs(recipe.headerButtons or {}) do
        local button = _G[n]
        if button and left then
            if not st.moved[button] then
                local points = {}
                for i = 1, button:GetNumPoints() do points[i] = { button:GetPoint(i) } end
                st.moved[button] = points
            end
            button:ClearAllPoints()
            -- The first one sits HEADER_BUTTON_Y lower than the close button (checked in game), the rest in its row;
            -- a button with a WoW Forever face is the close button's twin and sits level with it.
            local col = recipe.headerArt and recipe.headerArt[n]
            button:SetPoint("RIGHT", left, "LEFT", col and -2 or -4, (left == close and not col) and HEADER_BUTTON_Y or 0)
            lift(button, 1)
            if col then
                local s = (tonumber(option("foreverWindowScale", 50)) or 50) / 100
                skinHeaderArt(st, button, col, CLOSE_SIZE * s)
            end
            -- Buttons that swap with each other (the map's maximize / minimize) share one place.
            if not recipe.headerShare then left = button end
        end
    end
    if recipe.slots and option("foreverWindowSlots", true) ~= false then
        for _, n in ipairs(recipe.slots) do skinSlot(st, _G[n]) end
        skinSlotFrames(st, window, 0)
    end
    if recipe.guildCells then skinGuildCells(st) end
    if recipe.merchantCells then skinMerchantCells(st) end
    skinStats(st)
    local s = (tonumber(option("foreverWindowScale", 50)) or 50) / 100
    if metal then
        st.metalTitle = metalTitle(border)
        if recipe.generic and st.metalTitle and st.metalTitle.GetNumPoints then
            -- Other metal windows: the title goes to the very centre of the header band (the map's sat at the
            -- band's bottom, off to one side); the character window keeps its tuned shift.
            local title = st.metalTitle
            if not st.moved[title] then
                local points = {}
                for i = 1, title:GetNumPoints() do points[i] = { title:GetPoint(i) } end
                st.moved[title] = points
            end
            local function centre()
                title:ClearAllPoints()
                title:SetPoint("CENTER", chrome, "TOP", 0, -(HEADER_CENTER * s + TITLE_NUDGE))
            end
            centre()
            pin(st, title, centre)
            if title.GetJustifyH and title.SetJustifyH then
                st.justify = st.justify or {}
                if not st.justify[title] then st.justify[title] = title:GetJustifyH() end
                title:SetJustifyH("CENTER")
            end
        else
            placeTitle(st, top, s)
        end
    else
        placeOldTitle(st, recipe, name, level + 1, s)
        st.lifts[#st.lifts + 1] = { st.titleHolder, 0 }
    end

    for _, n in ipairs(recipe.hide or {}) do hide(st, _G[n]) end
    hidePortraits(st)
    if option("foreverWindowGround", true) ~= false then
        for _, n in ipairs(recipe.ground or {}) do fade(st, _G[n]) end
        if metal and name then
            fade(st, _G[name .. "Bg"])
            fade(st, _G[name .. "TopTileStreaks"])
            -- The client's title bar of the metal chrome (UIFrameHorizontal) lies on the window itself: its dark
            -- line crossed the portrait in the ring.
            for _, region in ipairs({ window:GetRegions() }) do
                if isTexture(region) and texPath(region):find("uiframehorizontal") then fade(st, region) end
            end
            -- A metal holder inside a frame of its own (the adventure guide): that frame's rock and header bar.
            local holderParent = border:GetParent()
            if holderParent and holderParent ~= window then
                for _, region in ipairs({ holderParent:GetRegions() }) do
                    if isTexture(region) and not st.own[region] then fade(st, region) end
                end
            end
        end
        st.ground:Show()
    end

    swapMarble(st, window, 0)
    if recipe.icons then
        swapIcons(st, recipe.icons)
        syncIcons(st)
    end

    chrome:Show()
    place(st)
    st.lastSize = { window:GetWidth() or 0, window:GetHeight() or 0 }
    st.ownUnit = st.wantPlayer and "player" or nil
    if st.clientPortrait then
        -- The client's portrait picture goes under the ring hole; the ring of the new chrome is drawn above it. A
        -- portrait frame (shop, collections, map, the finder's eye) keeps its place: its picture texture itself is
        -- moved, since the picture covers only part of the frame (the shop's coin sat small and low). Other
        -- textures of such a frame (its own rim) are hidden. A square item or spell icon (Interface\Icons, not a
        -- portrait icon) would stick out of the round hole: it is set smaller, inside the circle.
        local holder = st.clientPortrait
        local portrait = portraitTexture(holder) or holder
        -- portraitWhole: the whole portrait frame goes into the ring, scaled, with whatever picture the client
        -- shows in it (the finder shows a different one on each tab).
        if recipe.portraitWhole and not isTexture(holder) then portrait = holder end
        if portrait ~= holder and holder.GetRegions then
            for _, region in ipairs({ holder:GetRegions() }) do
                if isTexture(region) and region ~= portrait then fade(st, region) end
            end
        end
        local path = texPath(portrait)
        -- The frame drawing the picture keeps up with the chrome's stratum: the maximized map moves to a higher
        -- one and its portrait frame stayed behind, under the rock ground (the ring showed empty).
        local pictureFrame = portrait.GetParent and portrait:GetParent()
        if pictureFrame and pictureFrame ~= window and pictureFrame.GetFrameLevel then
            lift(pictureFrame, -st.chromeOffset)
        end
        if not st.moved[portrait] then
            local points = {}
            for i = 1, portrait:GetNumPoints() do points[i] = { portrait:GetPoint(i) } end
            st.moved[portrait] = points
            st.sizes = st.sizes or {}
            st.sizes[portrait] = { portrait:GetWidth(), portrait:GetHeight() }
        end
        local hole = st.portrait:GetWidth() or 0
        if portrait == holder and recipe.portraitWhole and portrait.SetScale then
            st.scales = st.scales or {}
            if st.scales[portrait] == nil then st.scales[portrait] = portrait:GetScale() end
            local w = portrait:GetWidth() or 0
            if w > 0 and hole > 0 then portrait:SetScale(hole * (recipe.portraitScale or 1) / w) end
        end
        -- The picture inside a whole portrait frame is off its centre (the finder's eye sits 6-7 px right and down
        -- in its 75 px frame): the frame is shifted back by as much, measured once the client has laid it out.
        local shiftX, shiftY = 0, 0
        if portrait == holder and recipe.portraitWhole then
            local picture = portraitTexture(holder)
            if picture and picture.GetCenter and holder.GetCenter then
                local px, py = picture:GetCenter()
                local hx, hy = holder:GetCenter()
                if px and py and hx and hy then shiftX, shiftY = hx - px, hy - py end
            end
        end
        local function placePicture()
            portrait:ClearAllPoints()
            if portrait == holder and recipe.portraitWhole then
                portrait:SetPoint("CENTER", st.portrait, "CENTER", shiftX, shiftY)
            elseif path:find("icons[\\/]") then
                portrait:SetPoint("CENTER", st.portrait, "CENTER")
                portrait:SetWidth(hole * SQUARE_IN_RING)
                portrait:SetHeight(hole * SQUARE_IN_RING)
                if portrait.GetTexCoord and portrait.SetTexCoord then
                    st.coords = st.coords or {}
                    if not st.coords[portrait] then st.coords[portrait] = { portrait:GetTexCoord() } end
                    portrait:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                end
            elseif recipe.portraitScale then
                -- A picture with wide transparent margins (the shop's coin, the PvP emblem) is enlarged so its
                -- drawing fills the hole; the ring covers what spills over.
                portrait:SetPoint("CENTER", st.portrait, "CENTER")
                portrait:SetWidth(hole * recipe.portraitScale)
                portrait:SetHeight(hole * recipe.portraitScale)
            else
                portrait:SetAllPoints(st.portrait)
            end
        end
        placePicture()
        pin(st, portrait, placePicture)
        st.portrait:Hide()
    end
    updatePortrait(st)
end

local function apply()
    for _, name in ipairs(ORDER) do applyWindow(_G[name], RECIPES[name]) end
end

-- The client builds its chrome on the window's first OnShow (after this hook was added), so every opening
-- applies again at once and once more a moment later.
local pending = {}
local timer = CreateFrame("Frame")
timer:Hide()
timer:SetScript("OnUpdate", function(self, elapsed)
    local left = false
    for window, wait in pairs(pending) do
        wait = wait - elapsed
        if wait <= 0 then
            pending[window] = nil
            local name = window:GetName()
            applyWindow(window, RECIPES[name])
        else
            pending[window] = wait
            left = true
        end
    end
    if not left then self:Hide() end
end)

local function onShow(window)
    applyWindow(window, RECIPES[window:GetName()])
    pending[window] = 0.2
    timer:Show()
end

-- Watchdog: the client re-places and re-layers buttons after clicks (the map's maximize puts its close and size
-- buttons back, other windows re-anchor theirs) and the buttons vanished under the new chrome. Twice a second
-- every open skinned window is checked; when the close button, a header button or the window itself is no longer
-- where the skin put it, the skin is laid again.
-- "move" when the client re-anchored the close button or a header button (the skin is laid again), "level" when
-- only levels or strata drifted (a toplevel window moved up when clicked; fixed in place, without flicker).
local function needsRepair(st)
    local window, chrome = st.window, st.chrome
    -- A swapped texture (inset ground, repair icon) the client set back to its own file: laid again.
    for region, original in pairs(st.swaps or {}) do
        local now = region:GetTexture()
        if type(now) == "string" and now:lower() == original:lower() then return "move" end
    end
    -- Resized (the map maximized or back): laid again, so the chrome is fitted to the screen once more.
    local size = st.lastSize
    if size and (math.abs((window:GetWidth() or 0) - size[1]) > 0.5 or math.abs((window:GetHeight() or 0) - size[2]) > 0.5) then
        return "move"
    end
    -- A client portrait hidden, faded or blanked on a tab switch, or our own ring portrait hidden: lay again.
    if st.clientPortrait and not showsPicture(st.clientPortrait) then return "move" end
    if st.ring and not st.clientPortrait and not st.portrait:IsShown() then return "move" end
    local close = st.closeButton
    if close then
        local _, rel = close:GetPoint(1)
        if rel ~= chrome then return "move" end
    end
    local anchors = { [close or false] = true }
    for _, n in ipairs(st.recipe.headerButtons or {}) do
        if _G[n] then anchors[_G[n]] = true end
    end
    for _, n in ipairs(st.recipe.headerButtons or {}) do
        local button = _G[n]
        if button and button:GetNumPoints() > 0 then
            local _, rel = button:GetPoint(1)
            if not anchors[rel or false] then return "move" end
        end
    end
    local level = chrome:GetFrameLevel()
    if level ~= window:GetFrameLevel() + (st.chromeOffset or 1) then return "level" end
    -- The selected tab is raised by the client: every tab stays behind the bottom edge.
    for _, tab in ipairs(st.tabs or {}) do
        if tab:GetFrameLevel() >= level then return "level" end
    end
    if underOffset(st.recipe, window:GetFrameLevel()) > level - window:GetFrameLevel() then return "level" end
    if st.recipe.under and chrome:GetFrameStrata() ~= underStrata(st) then return "level" end
    for _, entry in ipairs(st.lifts or {}) do
        local frame = entry[1]
        if frame:GetFrameLevel() <= level + entry[2] or belowStratum(frame, chrome) then return "level" end
    end
    return nil
end

-- Levels only: the chrome back at its offset above the window, the lifted frames back above it.
local function relevel(st)
    local windowLevel = st.window:GetFrameLevel()
    -- A tab the client raised (the selected one) pushes the chrome's offset up, so all tabs stay behind it.
    for _, tab in ipairs(st.tabs or {}) do
        local need = tab:GetFrameLevel() + 1 - windowLevel
        if need > (st.chromeOffset or 1) then st.chromeOffset = need end
    end
    local under = underOffset(st.recipe, windowLevel)
    if under > (st.chromeOffset or 1) then st.chromeOffset = under end
    if st.recipe.under then st.chrome:SetFrameStrata(underStrata(st)) end
    local level = windowLevel + (st.chromeOffset or 1)
    st.chrome:SetFrameLevel(level)
    for _, entry in ipairs(st.lifts or {}) do raise(st, entry[1], level + entry[2]) end
end

local function repair()
    for window, st in pairs(skins) do
        if st.active and window:IsShown() then
            local need = needsRepair(st)
            if need == "move" then
                applyWindow(window, st.recipe)
            elseif need == "level" then
                relevel(st)
            end
            syncIcons(st)
        end
    end
end

local watchWait = 0
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function(self, elapsed)
    watchWait = watchWait + elapsed
    if watchWait < 0.5 then return end
    watchWait = 0
    repair()
end)

-- The client (re)builds its metal chrome: a listed window that is open gets the skin over it at once.
local function onRebuild(frame)
    local name = frame and frame.GetName and frame:GetName()
    local recipe = name and RECIPES[name]
    if recipe and frame:IsShown() then applyWindow(frame, recipe) end
end

-- /fuiframe [window]: what the client's chrome of a window is made of (for tuning the outsets).
local function describe(region)
    local parts = {}
    if region.GetObjectType then parts[#parts + 1] = region:GetObjectType() end
    if region.GetWidth then parts[#parts + 1] = string.format("%.0fx%.0f", region:GetWidth() or 0, region:GetHeight() or 0) end
    if region.GetFrameLevel then parts[#parts + 1] = "lvl " .. tostring(region:GetFrameLevel()) end
    if region.IsShown then parts[#parts + 1] = region:IsShown() and "shown" or "hidden" end
    if region.GetAlpha then parts[#parts + 1] = string.format("a%.2f", region:GetAlpha() or 0) end
    if region.GetTexture then parts[#parts + 1] = tostring(region:GetTexture()) end
    if region.GetPoint and region:GetNumPoints() > 0 then
        local point, rel, relPoint, px, py = region:GetPoint(1)
        parts[#parts + 1] = string.format("%s>%s %s %.1f,%.1f", tostring(point),
            tostring(rel and rel.GetName and rel:GetName() or "?"), tostring(relPoint), px or 0, py or 0)
    end
    return table.concat(parts, " ")
end

-- The whole frame tree of a window (frames, sizes, offsets from the window's top-left, levels, textures, texts)
-- as lines. Every frame is read under pcall: one odd frame costs one "error" line, never the dump.
local function buildTree(window, maxLines)
    maxLines = maxLines or 4000
    local lines, wl, wt = {}, window:GetLeft() or 0, window:GetTop() or 0
    local function describeFrame(frame, pad)
        local l, t = frame:GetLeft(), frame:GetTop()
        lines[#lines + 1] = string.format("%s%s [%s] %.0fx%.0f at %s,%s lvl %s %s", pad,
            tostring(frame:GetName() or "?"), tostring(frame:GetObjectType()), frame:GetWidth() or 0,
            frame:GetHeight() or 0, l and string.format("%.0f", l - wl) or "?", t and string.format("%.0f", wt - t) or "?",
            tostring(frame:GetFrameLevel()), frame:IsShown() and "shown" or "hidden")
        for _, region in ipairs({ frame:GetRegions() }) do
            local kind = region:GetObjectType()
            if kind == "Texture" then
                lines[#lines + 1] = string.format("%s  tex %s %.0fx%.0f %s a%.2f %s %s", pad,
                    tostring(region:GetName() or "-"), region:GetWidth() or 0, region:GetHeight() or 0,
                    tostring(region:GetDrawLayer()), region:GetAlpha() or 0, region:IsShown() and "shown" or "hidden",
                    tostring(region:GetTexture()))
            elseif kind == "FontString" then
                local text = region:GetText()
                if text and text ~= "" then
                    lines[#lines + 1] = string.format("%s  text %s \"%s\"", pad, tostring(region:GetName() or "-"),
                        tostring(text):gsub("[\r\n\"\\]", " "))
                end
            end
        end
    end
    local function walk(frame, depth)
        if depth > 12 or #lines > maxLines then return end
        local pad = string.rep("  ", depth)
        local ok, err = pcall(describeFrame, frame, pad)
        if not ok then lines[#lines + 1] = pad .. "error " .. tostring(err) end
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do walk(child, depth + 1) end
    end
    walk(window, 0)
    return lines
end

-- /fuiframe tree writes ForeverStockUIDB.frameDump; the automatic dump of each listed window goes to
-- ForeverStockUIDB.frameDumps[<window name>] (at most 1500 lines per window).
local function saveTree(window, perWindow)
    local ok, result = pcall(buildTree, window, perWindow and 1500 or 4000)
    local lines = ok and result or { "error " .. tostring(result) }
    local db = settings()
    if perWindow then
        local name = window.GetName and window:GetName() or "?"
        db.frameDumps = type(db.frameDumps) == "table" and db.frameDumps or {}
        db.frameDumps[name] = lines
    else
        db.frameDump = lines
    end
    return ok and #result or 0, ok
end

local function dump(name)
    name = (name and name ~= "") and name or "CharacterFrame"
    local out = function(text) DEFAULT_CHAT_FRAME:AddMessage("|cffd6a95cFUI frame|r " .. text) end
    local treeOf = name:match("^tree%s*(.*)$")
    if treeOf then
        -- /fuiframe tree [window]: goes into ForeverStockUIDB.frameDump; /reload writes it to
        -- WTF/Account/<account>/SavedVariables/ForeverUI.lua.
        local window = _G[(treeOf ~= "" and treeOf) or "CharacterFrame"]
        if not window then return out("no such frame") end
        local count, ok = saveTree(window)
        return out(ok and (count .. " lines saved; type /reload to write them to SavedVariables")
            or "dump failed, the error is saved in SavedVariables")
    end
    local layersOf = name:match("^layers%s*(.*)$")
    if layersOf then
        -- /fuiframe layers [window]: strata and levels of the window, the new chrome and the frames kept under it.
        local window = _G[(layersOf ~= "" and layersOf) or "PlayerTalentFrame"]
        if not window then return out("no such frame") end
        local function line(label, frame)
            if not frame then return out(label .. ": none") end
            local parent = frame:GetParent()
            out(label .. ": " .. tostring(frame:GetFrameStrata()) .. " lvl " .. tostring(frame:GetFrameLevel())
                .. (frame.IsShown and (frame:IsShown() and " shown" or " hidden") or "")
                .. " parent " .. tostring(parent and parent.GetName and parent:GetName() or parent)
                .. " top " .. tostring(topLevel(frame, {}, 0, frame:GetFrameLevel(), 3)))
        end
        line("window", window)
        local st = skins[window]
        line("chrome", st and st.chrome)
        line("close", st and st.closeButton)
        for _, frameName in ipairs(st and st.recipe.under or { "GlyphFrame" }) do line(frameName, _G[frameName]) end
        return
    end
    if name == "mouse" then
        -- /fuiframe mouse: the frame under the cursor and its parent, with every texture.
        local frame = GetMouseFocus and GetMouseFocus()
        for _ = 1, 2 do
            if not frame then break end
            out(tostring(frame.GetName and frame:GetName() or "?") .. ": " .. describe(frame))
            for _, region in ipairs({ frame:GetRegions() }) do
                if region.GetObjectType and region:GetObjectType() == "Texture" then out("  " .. describe(region)) end
            end
            frame = frame:GetParent()
        end
        return
    end
    local window = _G[name]
    if not window then return out(name .. ": no such frame") end
    out(name .. ": " .. describe(window) .. " scale " .. tostring(window:GetEffectiveScale()))
    local border = window.MetalBorder
    if border then
        out("MetalBorder: " .. describe(border))
        for _, key in ipairs(SERVER_PIECES) do
            if border[key] then out("  " .. key .. ": " .. describe(border[key])) end
        end
        if border.TitleText then out("  TitleText: " .. describe(border.TitleText)) end
    else
        out("no MetalBorder")
    end
    for _, key in ipairs({ "ringPortrait", "specRingIcon", "CloseButton" }) do
        if window[key] then out(key .. ": " .. describe(window[key])) end
    end
    local function regions(label, frame)
        if not frame then return end
        out(label .. ": " .. describe(frame))
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "Texture" then out("  " .. describe(region)) end
        end
    end
    regions("close", window.CloseButton or _G[name .. "CloseButton"])
    local recipe = RECIPES[name]
    local slot = recipe and recipe.slots and _G[recipe.slots[1]]
    if slot then
        regions(recipe.slots[1], slot)
        regions(recipe.slots[1] .. "Frame", _G[recipe.slots[1] .. "Frame"])
        out("slot parent: " .. describe(slot:GetParent()))
    end
    local st = skins[window]
    out("forever chrome: " .. (st and st.active and describe(st.chrome) or "off"))
end

-- The first opening of each window in a session saves its tree (1 s after showing, when the client has built
-- it), so the next /reload or logout writes it to SavedVariables without any command.
local treeWait, treeDone = {}, {}
local treeTimer = CreateFrame("Frame")
treeTimer:Hide()
treeTimer:SetScript("OnUpdate", function(self, elapsed)
    local left = false
    for window, wait in pairs(treeWait) do
        wait = wait - elapsed
        if wait <= 0 then
            treeWait[window] = nil
            saveTree(window, true)
        else
            treeWait[window] = wait
            left = true
        end
    end
    if not left then self:Hide() end
end)
local function treeOnShow(window)
    if treeDone[window] then return end
    treeDone[window] = true
    treeWait[window] = 1
    treeTimer:Show()
end

-- Windows are hooked as soon as they exist: at login for the stock ones, on ADDON_LOADED for load-on-demand UIs
-- (talents, inspect, macros, auction house, guild bank, trainer, socketing, calendar).
local hookedWindows, hookedRefresh, hookedRefreshFrames, refreshHandlers = {}, {}, {}, {}
local function refreshHandler(name)
    local fn = refreshHandlers[name]
    if not fn then
        fn = function()
            local win = _G[name]
            local st = win and skins[win]
            if not (st and st.active) then return end
            skinStats(st)
            hidePortraits(st)
            if st.recipe.merchantCells then skinMerchantCells(st) end
            if win:IsShown() then
                local need = needsRepair(st)
                if need == "move" then
                    applyWindow(win, st.recipe)
                else
                    if need == "level" then relevel(st) end
                    updatePortrait(st)
                end
            end
        end
        refreshHandlers[name] = fn
    end
    return fn
end

local function hookWindows()
    for _, name in ipairs(ORDER) do
        local recipe = RECIPES[name]
        local window = _G[name]
        if window and window.HookScript and not hookedWindows[window] then
            hookedWindows[window] = true
            window:HookScript("OnShow", onShow)
            window:HookScript("OnShow", treeOnShow)
            if window:IsShown() then
                onShow(window)
                treeOnShow(window)
            end
        end
        if recipe.refresh or recipe.refreshFrames then
            for _, fn in ipairs(recipe.refresh or {}) do
                local key = name .. ":" .. fn
                if not hookedRefresh[key] and type(_G[fn]) == "function" and hooksecurefunc then
                    hookedRefresh[key] = true
                    hooksecurefunc(fn, refreshHandler(name))
                end
            end
            for _, frameName in ipairs(recipe.refreshFrames or {}) do
                local frame = _G[frameName]
                if frame and frame.HookScript and not hookedRefreshFrames[frame] then
                    hookedRefreshFrames[frame] = true
                    frame:HookScript("OnShow", refreshHandler(name))
                end
            end
        end
    end
end

-- Windows of the Nozdor client (shop, collections, adventure guide) can be created later, without an addon of
-- their own: every 2 s the list is checked again, until every listed window is hooked.
-- Windows not in the list yet (the Nozdor map, collections, adventure guide and shop have names of their own):
-- any large named window open under UIParent is noted in ForeverStockUIDB.seenWindows and its tree saved once
-- per session in frameDumps, so it can be added to WINDOWS with its real name.
local SPY_SKIP = { "ForeverStock", "ForeverUI", "Chat", "Minimap", "Nameplate", "Cell", "DBM", "WeakAuras", "Bagnon",
    "ActionBar", "MainMenuBar", "Tooltip", "PlayerFrame", "TargetFrame", "FocusFrame", "Compact", "Party", "Raid",
    "Container", "WorldStateAlways", "UIParent", "Recount", "Skada", "Details" }
local listed = {}
for _, name in ipairs(ORDER) do listed[name] = true end
local spied = {}
local function spyFrame(frame)
    local name = frame.GetName and frame:GetName()
    if not name or listed[name] or spied[name] or not frame:IsShown() then return end
    if (frame:GetWidth() or 0) < 300 or (frame:GetHeight() or 0) < 250 then return end
    for _, fragment in ipairs(SPY_SKIP) do
        if name:find(fragment, 1, true) then return end
    end
    spied[name] = true
    local db = settings()
    db.seenWindows = type(db.seenWindows) == "table" and db.seenWindows or {}
    db.seenWindows[name] = string.format("%.0fx%.0f", frame:GetWidth() or 0, frame:GetHeight() or 0)
    treeOnShow(frame)
end
local function spyChildren(...)
    for i = 1, select("#", ...) do spyFrame(select(i, ...)) end
end

local lateTimer = CreateFrame("Frame")
local lateWait = 0
lateTimer:Hide()
lateTimer:SetScript("OnUpdate", function(self, elapsed)
    lateWait = lateWait + elapsed
    if lateWait < 2 then return end
    lateWait = 0
    hookWindows()
    spyChildren(UIParent:GetChildren())
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event, unit)
    if event == "ADDON_LOADED" then
        if self.loggedIn then hookWindows() end
    elseif event == "PLAYER_LOGIN" then
        self.loggedIn = true
        -- The window's fine-tuning is fixed in code (values checked in game: sides 1 px, bottom 6 px, top 0,
        -- thickness 50%, title offset 0, every part on); the Skins page has only checkboxes. Values saved by the
        -- sliders and toggles of earlier versions are dropped so nothing stays hidden in the settings.
        local db = settings()
        for _, key in ipairs({ "foreverWindowPortrait", "foreverWindowGround", "foreverWindowSlots", "foreverWindowStats",
            "foreverWindowTitleY", "foreverWindowScale", "foreverWindowOutsetX", "foreverWindowOutsetTop",
            "foreverWindowOutsetBottom", "foreverWindowOutsets2", "foreverWindowBottom5", "foreverWindowBottomMoved" }) do
            db[key] = nil
        end
        for _, fn in ipairs({ "MetalFrame2X_Decorate", "MetalFrame2X_Rebuild" }) do
            if type(_G[fn]) == "function" then hooksecurefunc(fn, onRebuild) end
        end
        -- The client re-dresses close buttons (new red textures): the Forever button is put back over them.
        if type(_G.CloseButton2X_Apply) == "function" then
            hooksecurefunc("CloseButton2X_Apply", function(button)
                for _, st in pairs(skins) do
                    if st.active and st.closeButton == button then skinClose(st, button) end
                end
            end)
        end
        SLASH_FUIFRAME1 = "/fuiframe"
        SlashCmdList.FUIFRAME = dump
        hookWindows()
        lateTimer:Show()
    else
        -- Unit portraits drawn by the client go blank after a loading screen (hearthstone, instance) until drawn
        -- again: the player's portrait in the ring of windows without their own (talents) included.
        for _, st in pairs(skins) do
            local u = st.recipe.unit or st.ownUnit
            if st.active and (event == "PLAYER_ENTERING_WORLD" or (u and unit == u)) then updatePortrait(st) end
        end
        if event == "PLAYER_ENTERING_WORLD" then
            -- The portrait may not be ready yet at this event: drawn once more a second later.
            local waited = 0
            portraitRetry:SetScript("OnUpdate", function(self, elapsed)
                waited = waited + elapsed
                if waited < 1 then return end
                self:SetScript("OnUpdate", nil)
                for _, st in pairs(skins) do if st.active then updatePortrait(st) end end
            end)
        end
    end
end)

ui.WindowSkin = { Apply = apply, Repair = repair, Layout = layout, Dump = dump, Recipes = RECIPES, Order = ORDER, skins = skins }
