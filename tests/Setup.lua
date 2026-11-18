-- Setup wizard and per-character settings on a WoW API mock (real Core/Config.lua, Core/Widgets.lua, EditLayouts.lua,
-- Setup/*.lua; Edit Mode and the modules are recorders). Run from the addon root (see INDEX.md).
local forbidden = { "C_Timer", "BackdropTemplate", "FramePool", "CreateFramePool", "SetColorTexture", "SetAtlas",
    "C_AddOns", "SetShown(", "CreateMaskTexture", "C_NamePlate" }

local methods, objects = {}, {}
local function new(kind, parent, name)
    local object = setmetatable({ kind = kind, parent = parent, shown = true, scripts = {}, width = 100, height = 20,
        points = {}, children = {}, alpha = 1, scale = 1, level = 1 }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^%u") and not key:match("^On") then return function() end end
    end })
    objects[#objects + 1] = object
    if parent and parent.children then table.insert(parent.children, object) end
    if name then _G[name] = object end
    return object
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetSize() return self.width, self.height end
function methods:SetPoint(...) table.insert(self.points, { ... }) end
function methods:ClearAllPoints() self.points = {} end
function methods:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p) end end
function methods:GetNumPoints() return #self.points end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide()
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:IsVisible()
    local node = self
    while node do
        if not node.shown then return false end
        node = node.parent
    end
    return true
end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:GetScript(name) return self.scripts[name] end
function methods:HookScript(name, fn)
    local old = self.scripts[name]
    self.scripts[name] = function(...) if old then old(...) end fn(...) end
end
function methods:CreateTexture() return new("Texture", self) end
function methods:CreateFontString() return new("FontString", self) end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:SetTexture(path) self.texture = path end
function methods:GetStringWidth() return #(self.text or "") * 6 end
function methods:GetStringHeight() return 14 end
function methods:SetMinMaxValues(a, b) self.min, self.max = a, b end
function methods:GetMinMaxValues() return self.min, self.max end
function methods:SetValue(v)
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function methods:GetValue() return self.value end
function methods:SetThumbTexture() self.thumb = new("Texture", self) end
function methods:GetThumbTexture() return self.thumb end
function methods:Enable() self.disabled = nil end
function methods:Disable() self.disabled = true end
function methods:IsEnabled() return not self.disabled and 1 or nil end
function methods:GetEffectiveScale() return self.scale end
function methods:SetScale(s) self.scale = s end
function methods:GetScale() return self.scale end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(l) self.level = l end
function methods:GetParent() return self.parent end
function methods:SetAlpha(a) self.alpha = a end
function methods:GetAlpha() return self.alpha end
function methods:GetVerticalScroll() return 0 end
function methods:GetName() return self.name end
function methods:Click(button) if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end end

local events = {}
methods.RegisterEvent = function(self, event) events[event] = events[event] or {}; events[event][self] = true end
methods.UnregisterEvent = function(self, event) if events[event] then events[event][self] = nil end end
local function fire(event, ...)
    local list = {}
    for frame in pairs(events[event] or {}) do list[#list + 1] = frame end
    for _, frame in ipairs(list) do frame.scripts.OnEvent(frame, event, ...) end
end
local function tick(seconds)
    local left = seconds
    while left > 0 do
        for _, object in ipairs(objects) do
            local update = object.scripts.OnUpdate
            if update then update(object, 0.1) end
        end
        left = left - 0.1
    end
end

function CreateFrame(kind, name, parent)
    local frame = new(kind, parent, name)
    frame.name = name
    return frame
end
function CreateFont(name) return new("Font", nil, name) end

UIParent = CreateFrame("Frame", "UIParent")
UIParent.width, UIParent.height = 1365, 768
GameTooltip = CreateFrame("GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) _G.lastPrint = text end }
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UISpecialFrames, StaticPopupDialogs, SlashCmdList = {}, {}, {}
NUM_CHAT_WINDOWS = 10
for i = 1, NUM_CHAT_WINDOWS do CreateFrame("Frame", "ChatFrame" .. i, UIParent) end
local combat, reloaded = false, false
local player = { name = "Артас", realm = "Nozdor", class = "PALADIN", level = 80, group = 1, groups = 2, tree = 1 }
local cvars = { uiScale = "1", useUiScale = "0" }
function InCombatLockdown() return combat end
function GetLocale() return "ruRU" end
function IsAddOnLoaded() return false end
function IsShiftKeyDown() return false end
function PlaySound() end
function GameTooltip_Hide() end
function geterrorhandler() return function(err) error(err, 0) end end
function ReloadUI() reloaded = true end
function GetCVar(name) return cvars[name] end
function SetCVar(name, value) cvars[name] = tostring(value) end
function UnitName() return player.name end
function GetRealmName() return player.realm end
function UnitClass() return "Класс", player.class end
function UnitLevel() return player.level end
function UnitXP() return 0 end
function GetActiveTalentGroup() return player.group end
function GetNumTalentGroups() return player.groups end
function GetSpellInfo() return nil end
function GetShapeshiftForm() return 0 end
function GetScreenResolutions() return "1280x720", "1920x1080" end
function GetCurrentResolution() return 2 end
local portrait
function SetPortraitToTexture(_, path) portrait = path end
function EnumerateServerChannels() return "Общий", "Торговля", "ПоискСпутников" end
local chat = { removed = {}, added = {}, sizes = {} }
function ChatFrame_RemoveChannel(_, name) chat.removed[#chat.removed + 1] = name end
function ChatFrame_AddChannel(frame, name) chat.added[#chat.added + 1] = name; chat.tab = frame end
function ChatFrame_RemoveAllMessageGroups() end
function GetChatWindowInfo(id) return chat.titles and chat.titles[id] or nil end
function FCF_OpenNewWindow(title) chat.opened = title; return ChatFrame5 end
function FCF_SavePositionAndDimensions(frame) chat.saved = frame end
function FCF_SetChatWindowFontSize(_, frame, size) chat.sizes[#chat.sizes + 1] = size end

local ui = {}
local function load(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    if path:find("^Setup/") then
        for _, keyword in ipairs(forbidden) do assert(not source:find(keyword, 1, true), path .. ": " .. keyword) end
    end
    assert(loadfile(path))("ForeverUI", ui)
end
for _, path in ipairs({ "Core/Config.lua", "Core/Widgets.lua", "EditLayouts.lua" }) do load(path) end

-- Module recorders -------------------------------------------------------------------------------------------------
local calls = {}
local function record(name) return function(...) calls[name] = (calls[name] or 0) + 1; calls[name .. "Args"] = { ... } end end
local suiteParts = { raid = { rfEnabled = true }, clicks = { enabled = true } }
ui.Suite = { ready = false, PrimaryTree = function() return player.tree end, TreeNames = function() return { "Свет", "Защита", "Воздаяние" } end,
    TalentRank = function() return 0 end, Part = function(key) return suiteParts[key] end }
ui.CooldownManager = { Groups = function()
    return { { id = 1, kind = "icons", enabled = true }, { id = 2, kind = "icons", enabled = true }, { id = 3, kind = "bars", enabled = true } }
end, Refresh = record("cdmRefresh") }
ui.PersonalResource = { ApplyPosition = record("prdPosition") }
ui.RaidFrames = { RestoreAnchor = record("raidRestore"), AttachContainer = record("raidAttach") }
ui.ClickCast = { Apply = record("clicks") }
ui.Chat = { Apply = record("chat") }
ui.ActionBars = { Apply = record("bars") }
ui.ApplyEditLayout = function(name) calls.layoutStyle = name; ui.Settings().barLayout = name; return true end

-- Edit Mode recorder: positions live in settings.editLayout exactly like the real one.
local sizes = { PlayerFrame = { 232, 100 }, TargetFrame = { 232, 100 }, ForeverStockUIRaidAnchor = { 300, 180 },
    ForeverStockUICDM1 = { 200, 40 }, ForeverStockUICDM2 = { 180, 30 }, CastingBarFrame = { 195, 13 } }
local function liveLayout()
    local s = ui.Settings()
    if type(s.editLayout) ~= "table" then s.editLayout = {} end
    return s.editLayout
end
local function entry(name)
    local layout = liveLayout()
    if type(layout[name]) ~= "table" then layout[name] = {} end
    return { name = name, config = layout[name] }
end
ui.EditMode = {
    Entry = entry,
    Entries = function() return { entry("ForeverStockUICDM1"), entry("ForeverStockUICDM2"), entry("ForeverStockUIDamageMeter") } end,
    Size = function(name) local s = sizes[name] or { 100, 40 }; return s[1], s[2] end,
    Place = function(name, point, relativePoint, x, y, size)
        local s = size or sizes[name] or { 100, 40 }
        local px, py = ui.ComputeEditPosition(point, relativePoint, x, y, s[1], s[2], UIParent:GetWidth(), UIParent:GetHeight())
        entry(name).config.position = { px, py }
        return true
    end,
    LoadLayout = function(source, skip)
        local live = liveLayout()
        calls.loadLayout = (calls.loadLayout or 0) + 1
        calls.loadSkip = skip
        for name, config in pairs(live) do
            if not (skip and skip(name)) and type(source[name]) ~= "table" then
                for k in pairs(config) do config[k] = nil end
            end
        end
        for name, config in pairs(source or {}) do
            if not (skip and skip(name)) then
                if type(live[name]) ~= "table" then live[name] = {} end
                for k in pairs(live[name]) do live[name][k] = nil end
                for k, v in pairs(config) do live[name][k] = ui.CopyTable(v) end
            end
        end
        return true
    end,
    Reapply = record("reapply"),
    SetBarStyle = function(style) ui.Settings().barLayout = style; calls.barStyle = style; return true end,
    IsOpen = function() return false end,
    Close = function() end,
}

-- The schemas the wizard switches go through (same ids and keys as Options/*.lua).
local applied = {}
local function schema(id, key, db, extra)
    ui.RegisterOptions(id, { title = id, enable = key, db = db, sections = { { options = {
        { "toggle", key, id, default = true, apply = function() applied[id] = (applied[id] or 0) + 1 end, reload = extra },
    } } } })
end
schema("unitframes", "unitFramesEnabled", nil, true)
schema("raidframes", "rfEnabled", function() return ui.Suite.ready and suiteParts.raid or nil end)
schema("cooldowns", "cdmEnabled")
schema("prd", "prdEnabled")
schema("meter", "meterEnabled")
schema("bags", "bagsEnabled", nil, true)
schema("skins", "foreverWindows")
schema("combattext", "enabled", function() return ui.Settings().combatText end)
schema("healermana", "hmEnabled")

for _, path in ipairs({ "Setup/Layouts.lua", "Setup/Profile.lua", "Setup/Wizard.lua" }) do load(path) end
local Setup, Layouts, wizard = ui.Setup, ui.SetupLayouts, ui.Setup.wizard

-- Pure parts ---------------------------------------------------------------------------------------------------------
assert(Layouts.GuessRole("PALADIN", 1) == "HEALER" and Layouts.GuessRole("PALADIN", 2) == "TANK", "paladin trees")
assert(Layouts.GuessRole("DRUID", 2, true) == "TANK" and Layouts.GuessRole("DRUID", 2, false) == "MELEE", "feral")
assert(Layouts.GuessRole("WARRIOR", 0) == "MELEE" and Layouts.GuessRole("PRIEST", 0) == "RANGED", "no talents yet")
assert(Layouts.GuessRole("HUNTER", 3) == "RANGED" and Layouts.GuessRole("SHAMAN", 3) == "HEALER", "trees")
assert(Layouts.AutoScale(1080) == 0.711 and Layouts.AutoScale(1440) == 0.533 and Layouts.AutoScale(720) == 1.067, "auto")
assert(Layouts.AutoScale(600) == 1.15 and Layouts.AutoScale(nil) == 1, "auto limits")
local rw, rh = Layouts.ParseResolution("1920x1080")
assert(rw == 1920 and rh == 1080, "resolution")
for _, role in ipairs(Layouts.roles) do
    local preset = Layouts.presets[role]
    assert(preset and preset.frames.PlayerFrame and preset.raid and preset.cdm and preset.prd and preset.chat, role)
    assert(Layouts.roleInfo[role].label and Layouts.roleInfo[role].icon, role .. " info")
end
assert(Layouts.Recommended("HEALER").clickcast and not Layouts.Recommended("TANK").clickcast, "click-cast for healers")
assert(Layouts.Recommended("MELEE").raidframes, "the rest stays on")

-- Fresh account: the wizard opens on the first world entry --------------------------------------------------------------
ForeverStockUIDB = {}
fire("ADDON_LOADED", "ForeverUI")
assert(Setup.DB().legacy == false, "fresh account")
ui.Suite.ready = true
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
assert(not Setup.IsOpen(), "the wizard waits for the UI to settle")
tick(3)
assert(Setup.IsOpen() and wizard.Session().mode == "full", "new character: full wizard")
assert(portrait == "Interface\\Icons\\INV_Misc_Book_09", "welcome icon in the ring")
local frame = wizard.Frame()
assert(frame.subtitle.text:find("Шаг 1 из 8"), frame.subtitle.text)
assert(not frame.nextButton:IsShown() and frame.back.text.text == "Пропустить", "welcome: cards and Skip")

local function find(node, text)
    for _, child in ipairs(node.children or {}) do
        if (child.title and child.title.text == text) or (child.label and child.label.text == text)
            or (child.text and type(child.text) == "table" and child.text.text == text) then
            return child
        end
        local found = find(child, text)
        if found then return found end
    end
end
local function page(id) return wizard.Pages[id] end

-- Detailed path.
find(page("welcome"), "Подробная установка"):Click()
assert(wizard.Session().steps[2] == "role" and #wizard.Session().steps == 8, "detailed steps")
assert(wizard.Session().draft.role == "HEALER" and wizard.Session().draft.guessed == "HEALER", "role from talents")
assert(find(page("role"), "Лекарь").badge.text == "по талантам", "recommended badge")
find(page("role"), "Танк"):Click()
assert(wizard.Session().draft.role == "TANK" and portrait == Layouts.roleInfo.TANK.icon, "role picked, ring follows")
find(page("role"), "Лекарь"):Click()
wizard.Next()
assert(frame.subtitle.text:find("Стиль"), "style step")
find(page("style"), "Retail"):Click()
assert(calls.layoutStyle == "retail" and ui.Settings().barLayout == "retail", "style applied at once")
wizard.Next()
assert(wizard.Session().draft.scaleMode == "auto", "auto scale by default")
find(page("scale"), "Авто"):Click()
tick(0.3)
assert(cvars.uiScale == "0.711" and cvars.useUiScale == "1" and UIParent.scale == 0.711, "pixel-perfect scale")
wizard.Next()
-- Layout: the healer preset is on screen as soon as the page opens.
local layout = ui.Settings().editLayout
local px, py = ui.ComputeEditPosition("RIGHT", "CENTER", -200, -20, 232, 100, 1365, 768)
assert(layout.PlayerFrame.position[1] == px and layout.PlayerFrame.position[2] == py, "player on the healer spot")
assert(ui.Settings().prdX == 0 and ui.Settings().prdY == -42, "resource panel")
assert(layout.ForeverStockUIRaidAnchor.width == 300, "raid width kept for the left pin")
local cdm1, cdm2 = layout.ForeverStockUICDM1.position, layout.ForeverStockUICDM2.position
assert(cdm1 and cdm2 and math.abs((cdm1[2] - cdm2[2]) - (40 + Layouts.CDM_GAP)) < 1e-6, "tracker groups stacked")
assert(layout.ForeverStockUICDM3 == nil or layout.ForeverStockUICDM3.position == nil, "bar groups keep the default column")
assert(calls.prdPosition and calls.raidRestore and calls.cdmRefresh, "modules follow the new spots")
find(page("layout"), "Оставить мои позиции"):Click()
assert(layout.PlayerFrame.position == nil and ui.Settings().prdY == nil, "my positions back")
find(page("layout"), "Раскладка: Лекарь"):Click()
assert(layout.PlayerFrame.position, "role layout again")
wizard.Next()
assert(suiteParts.clicks.enabled == true, "click-cast on for a healer")
local bags = find(page("modules"), "Единая сумка *")
assert(bags, "modules page lists the bags")
-- The toggle row hides its click target inside: press it.
for _, child in ipairs(bags.children) do if child.scripts.OnClick then child.scripts.OnClick(child) end end
assert(ui.Settings().bagsEnabled == false, "bags switched off (reload)")
-- Cursor outline and trail: one switch for both; on also turns the cursor effects on.
local cursorCalls = 0
ui.cursor = { Apply = function() cursorCalls = cursorCalls + 1 end }
ui.Settings().cursor, ui.Settings().cursorEnabled = { outlineEnabled = false, trailEnabled = false }, true
local outline = find(page("modules"), "Обводка и след курсора")
assert(outline, "modules page lists the cursor outline and trail")
assert(Setup.GetModule("cursor") == false, "neither outline nor trail")
ui.Settings().cursor.trailEnabled = true
assert(Setup.GetModule("cursor") == true, "the trail alone counts as on")
ui.Settings().cursor.trailEnabled, ui.Settings().cursorEnabled = false, false
wizard.Session().draft.modules.cursor = false
outline:Refresh()
local function press(row) for _, child in ipairs(row.children) do if child.scripts.OnClick then child.scripts.OnClick(child) end end end
press(outline)
assert(ui.Settings().cursor.outlineEnabled == true and ui.Settings().cursor.trailEnabled == true
    and ui.Settings().cursorEnabled == true and cursorCalls == 1, "on: outline, trail and the effects")
press(outline)
assert(ui.Settings().cursor.outlineEnabled == false and ui.Settings().cursor.trailEnabled == false,
    "off: outline and trail together")
assert(not Layouts.Recommended("HEALER").cursor == false, "recommended for every role")
wizard.Next()
assert(frame.subtitle.text:find("Чат"), "chat step")
wizard.Next()
assert(frame.nextButton.text.text == "Готово и /reload", "reload needed")
assert(page("done").children[1].text:find("Лекарь"), "summary")
chat.titles = {}
wizard.Next()
assert(reloaded and not Setup.IsOpen(), "done: closed and reloaded")
local rec = Setup.Char(false)
assert(rec.installed and rec.specs[1].role == "HEALER" and rec.specs[1].scaleMode == "auto", "saved for the character")
assert(rec.specs[1].style == "retail" and rec.specs[1].layout.PlayerFrame.position, "style and layout saved")
assert(rec.specs[1].modules.cursor == false, "cursor outline saved for the set")
assert(chat.saved == ChatFrame1 and ChatFrame1.points[1][5] == Layouts.presets.HEALER.chat.retailY, "chat placed for Retail")
assert(chat.opened == "Каналы" and #chat.added == 3 and #chat.removed == 3, "server channels moved to their tab")
assert(calls.chat, "chat tabs")
reloaded = false

-- Logout keeps what is on screen.
layout.PlayerFrame.position = { -1, -1 }
fire("PLAYER_LOGOUT")
assert(rec.specs[1].layout.PlayerFrame.position[1] == -1, "logout capture")

-- Next login of the same character: the layout is loaded before the modules read it.
ForeverStockUIDB.editLayout = { PlayerFrame = { position = { -9, -9 } } }
ForeverStockUIDB.bagsEnabled = true
ui.Fire("ConfigLoaded")
assert(ui.Settings().editLayout.PlayerFrame.position[1] == -1 and ui.Settings().bagsEnabled == false, "early load")
layout = ui.Settings().editLayout

-- First switch to the second talent set: the short wizard.
Setup.currentGroup = 1
player.group, player.tree = 2, 3
fire("ACTIVE_TALENT_GROUP_CHANGED")
assert(Setup.IsOpen() and wizard.Session().mode == "spec", "spec wizard")
assert(rec.specs[2] and rec.specs[2].configured == nil and rec.specs[2].role == "MELEE", "new set: a copy, role from talents")
assert(page("spec").children[1].text:find("Воздаяние"), "tree name shown")
find(page("spec"), "Взять настройки первого набора"):Click()
assert(not Setup.IsOpen() and rec.specs[2].configured, "first set's settings taken")

-- Switching back: the second set keeps what is on screen, the first comes back (trackers left to the CDM).
layout.PlayerFrame.position = { -2, -2 }
player.group = 1
fire("ACTIVE_TALENT_GROUP_CHANGED")
assert(rec.specs[2].layout.PlayerFrame.position[1] == -2, "set 2 captured")
assert(ui.Settings().editLayout.PlayerFrame.position[1] == -1, "set 1 loaded")
assert(calls.loadSkip and calls.loadSkip("ForeverStockUICDM1") and not calls.loadSkip("PlayerFrame"), "trackers skipped")

-- Cancel puts everything back.
Setup.Open("full")
local before = ui.Settings().editLayout.PlayerFrame.position[1]
find(page("welcome"), "Подробная установка"):Click()
find(page("role"), "Танк"):Click()
wizard.Next(); wizard.Next(); wizard.Next()
assert(ui.Settings().editLayout.PlayerFrame.position[1] ~= before, "tank layout on screen")
Setup.Cancel()
assert(not Setup.IsOpen() and ui.Settings().editLayout.PlayerFrame.position[1] == before, "cancel: layout back")
assert(ui.Settings().barLayout == "retail", "cancel: style back")

-- Quick path on a second character: role -> done with everything recommended.
player.name, player.class, player.tree, player.group = "Джайна", "MAGE", 3, 1
ForeverStockUIDB.setup.legacy = false
Setup.CheckFirstRun()
assert(Setup.IsOpen(), "second character: wizard")
find(page("welcome"), "Быстрая установка"):Click()
assert(wizard.Session().draft.role == "RANGED", "mage: ranged")
wizard.Next()
assert(frame.subtitle.text:find("Готово"), "quick: straight to done")
local ranged = Layouts.presets.RANGED.frames.CastingBarFrame
px, py = ui.ComputeEditPosition(ranged[1], ranged[2], ranged[3], ranged[4], 195, 13, 1365, 768)
assert(ui.Settings().editLayout.CastingBarFrame.position[1] == px, "ranged layout applied")
wizard.Next()
assert(Setup.Char(false).specs[1].role == "RANGED", "quick setup saved")

-- Third character copies the first one.
player.name = "Тралл"
Setup.CheckFirstRun()
local copyCard = find(page("welcome"), "Скопировать с другого персонажа")
copyCard:Click()
page("copy"):Refresh()
local row = find(page("copy"), "Артас - Nozdor")
assert(row, "the first character is offered")
row:Click()
assert(frame.subtitle.text:find("Готово"), "copied: done")
wizard.Next()
local third = Setup.Char(false)
assert(third.installed and third.specs[1].role == "HEALER" and third.specs[2].role == "MELEE", "both sets copied")
assert(ui.Settings().editLayout.PlayerFrame.position[1] == -1, "copied layout on screen")

-- Skipping marks the character as set up and leaves things as they are.
player.name = "Сильвана"
Setup.CheckFirstRun()
frame.back:Click()
assert(not Setup.IsOpen() and Setup.Char(false).installed, "skip")
assert(lastPrint:find("/fui install"), "skip hint")

-- Accounts that used ForeverUI before: settled characters keep their settings; brand-new ones get the wizard.
ForeverStockUIDB.setup.legacy = true
player.name, player.level = "Утер", 80
Setup.CheckFirstRun()
assert(not Setup.IsOpen() and Setup.Char(false).installed, "legacy character adopted")
player.name, player.level = "Новичок", 1
Setup.CheckFirstRun()
assert(Setup.IsOpen(), "a level 1 character on a legacy account gets the wizard")
Setup.Cancel()

-- Combat: the wizard waits.
combat = true
Setup.Open("full")
assert(not Setup.IsOpen(), "no wizard in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(Setup.IsOpen(), "opens after combat")
Setup.Cancel()

-- Slash command wiring lives in Core/OptionsFrame.lua; the General page buttons call Setup.Open.
assert(type(Setup.Open) == "function" and type(Setup.CopyFrom) == "function")

print("Setup OK: roles, presets, auto scale, fresh account, detailed path (role, style, scale, layout, modules, chat, "
    .. "reload), early load, talent sets (short wizard, swap), cancel, quick path, copy, skip, legacy accounts, combat")
