-- Per-character settings of the setup wizard: role, bar look, UI scale, frame positions and the big module switches
-- are kept for each character and each talent set, inside ForeverStockUIDB.setup (not SavedVariablesPerCharacter: the
-- other characters have to be readable to copy from them). Everything else stays account-wide.
--
-- ForeverStockUIDB.setup = {
--     legacy = true,        -- the account used ForeverUI before the wizard existed
--     chars = { ["Name - Realm"] = { class, group = last talent set, installed = true, specs = { [1] = state, [2] = state } } },
-- }
-- state = { role, style ("classic"|"retail"), scaleMode ("auto"|"manual"), scale, modules = { [id] = bool },
--           raw = { prdX, prdY, prdScale, barXpWidth }, layout = copy of editLayout, configured = true }
--
-- Loading happens twice: right after the SavedVariables (ADDON_LOADED), before any module reads its settings, the
-- character's frame layout and main-table switches are put in place; at PLAYER_LOGIN, once the suite profile exists,
-- the raid frame and click-casting switches and the UI scale follow.
local addonName, ui = ...
local L = ui.L
local Layouts = ui.SetupLayouts
local copy = ui.CopyTable

local Setup = { VERSION = 1 }
ui.Setup = Setup

local RAW = { "prdX", "prdY", "prdScale", "barXpWidth" }

local function settings() return ui.Settings() end

function Setup.DB()
    local s = settings()
    if type(s.setup) ~= "table" then s.setup = {} end
    if type(s.setup.chars) ~= "table" then s.setup.chars = {} end
    return s.setup
end

function Setup.CharKey()
    return (UnitName("player") or "?") .. " - " .. (GetRealmName and GetRealmName() or "?")
end

local function nameKnown()
    local name = UnitName("player")
    return name and name ~= "" and name ~= UNKNOWNOBJECT and name ~= "Unknown"
end

function Setup.Char(create)
    local chars = Setup.DB().chars
    local key = Setup.CharKey()
    local rec = chars[key]
    if not rec and create then
        rec = { specs = {} }
        chars[key] = rec
    end
    if rec then
        if type(rec.specs) ~= "table" then rec.specs = {} end
        if not rec.class and UnitClass then rec.class = select(2, UnitClass("player")) end
    end
    return rec
end

function Setup.TalentGroup()
    return GetActiveTalentGroup and GetActiveTalentGroup() or 1
end

-- The role the talents point to (what the wizard pre-selects).
function Setup.GuessRole()
    local class = UnitClass and select(2, UnitClass("player"))
    local tree = ui.Suite and ui.Suite.PrimaryTree and ui.Suite.PrimaryTree() or 0
    local feral = false
    if class == "DRUID" and tree == 2 then
        local talent = GetSpellInfo and GetSpellInfo(57877)
        feral = (GetShapeshiftForm and GetShapeshiftForm() == 1)
            or (talent and ui.Suite and ui.Suite.TalentRank and ui.Suite.TalentRank(talent) > 0) or false
    end
    return Layouts.GuessRole(class, tree, feral)
end

local function isTrackerFrame(name) return type(name) == "string" and name:find("^ForeverStockUICDM") ~= nil end
Setup.IsTrackerFrame = isTrackerFrame

---------------------------------------------------------------------------------------------------
-- Module switches
---------------------------------------------------------------------------------------------------
local function suiteReady() return ui.Suite and ui.Suite.ready end
local function clicksPart()
    if not suiteReady() or not ui.Suite.Part then return end
    local ok, part = pcall(ui.Suite.Part, "clicks")
    return ok and type(part) == "table" and part or nil
end

local moduleById = {}
for _, module in ipairs(Layouts.modules) do moduleById[module.id] = module end
Setup.moduleById = moduleById

function Setup.GetModule(module)
    if type(module) == "string" then module = moduleById[module] end
    if not module then return false end
    local kind = module.kind
    if kind == "main" or kind == "account" then return settings()[module.key] ~= false end
    if kind == "combattext" then
        local t = settings().combatText
        return not (type(t) == "table" and t.enabled == false)
    end
    if kind == "cursor" then
        local t = type(settings().cursor) == "table" and settings().cursor or {}
        return settings().cursorEnabled ~= false and (t.outlineEnabled ~= false or t.trailEnabled ~= false)
    end
    if kind == "option" then
        if not suiteReady() then return true end
        return ui.GetOption(module.id, module.key) ~= false
    end
    if kind == "clicks" then
        local part = clicksPart()
        return not part or part.enabled ~= false
    end
    return true
end

-- Returns true when the change needs a /reload to show.
function Setup.SetModule(module, on)
    if type(module) == "string" then module = moduleById[module] end
    if not module then return false end
    on = on and true or false
    if Setup.GetModule(module) == on then return false end
    if module.reload then
        settings()[module.key] = on
        return true
    end
    local kind = module.kind
    if kind == "cursor" then
        local s = settings()
        if type(s.cursor) ~= "table" then s.cursor = {} end
        -- Outline and trail go together; they show only with the cursor effects on.
        s.cursor.outlineEnabled, s.cursor.trailEnabled = on, on
        if on then s.cursorEnabled = true end
        if ui.cursor and ui.cursor.Apply then ui.SafeCall(ui.cursor.Apply) end
        ui.Fire("OptionsRefresh", "cursor")
        return false
    end
    if kind == "clicks" then
        local part = clicksPart()
        if part then
            part.enabled = on
            if ui.ClickCast and ui.ClickCast.Apply then ui.RunOutOfCombat("setupClicks", ui.ClickCast.Apply) end
        end
    elseif kind == "combattext" then
        if type(settings().combatText) ~= "table" then settings().combatText = {} end
        if select(2, ui.FindOption("combattext", "enabled")) then
            ui.SetOption("combattext", "enabled", on)
        else
            settings().combatText.enabled = on
        end
    elseif select(2, ui.FindOption(module.id, module.key)) then
        ui.SetOption(module.id, module.key, on)
    else
        settings()[module.key] = on
    end
    return false
end

---------------------------------------------------------------------------------------------------
-- Capture and load
---------------------------------------------------------------------------------------------------
-- Live settings -> state. keepTrackers: the tracker group spots stay as they were in the state (they are swapped
-- by the Cooldown Manager itself on a talent change, possibly before this runs).
function Setup.Capture(state, keepTrackers)
    local s = settings()
    state.raw = state.raw or {}
    for _, key in ipairs(RAW) do state.raw[key] = copy(s[key]) end
    state.style = s.barLayout == "retail" and "retail" or "classic"
    state.modules = state.modules or {}
    for _, module in ipairs(Layouts.modules) do
        if module.kind ~= "account" and (module.kind ~= "option" and module.kind ~= "clicks" or suiteReady()) then
            state.modules[module.id] = Setup.GetModule(module)
        end
    end
    local previous = state.layout
    state.layout = copy(type(s.editLayout) == "table" and s.editLayout or {})
    if keepTrackers then
        for name in pairs(state.layout) do
            if isTrackerFrame(name) then state.layout[name] = nil end
        end
        for name, config in pairs(type(previous) == "table" and previous or {}) do
            if isTrackerFrame(name) then state.layout[name] = copy(config) end
        end
    end
    state.version = Setup.VERSION
    return state
end

function Setup.NewState()
    return Setup.Capture({ role = Setup.GuessRole() })
end

-- Early load (ADDON_LOADED): only the main table, no module has read it yet.
local function writeEarly(state)
    local s = settings()
    for _, key in ipairs(RAW) do
        if state.raw and state.raw[key] ~= nil then s[key] = copy(state.raw[key]) end
    end
    if state.style then s.barLayout = state.style end
    for id, on in pairs(state.modules or {}) do
        local module = moduleById[id]
        if module and module.kind == "main" then s[module.key] = on and true or false end
        if module and module.kind == "combattext" and type(s.combatText) == "table" then s.combatText.enabled = on end
        if module and module.kind == "cursor" and type(s.cursor) == "table" then
            s.cursor.outlineEnabled, s.cursor.trailEnabled = on, on
        end
    end
    if type(state.layout) == "table" then s.editLayout = copy(state.layout) end
end
Setup.WriteEarly = writeEarly

-- Suite-backed switches (PLAYER_LOGIN or later).
local function writeSuite(state)
    for id, on in pairs(state.modules or {}) do
        local module = moduleById[id]
        if module and (module.kind == "option" or module.kind == "clicks") then Setup.SetModule(module, on) end
    end
end

-- Puts a state on the running interface (talent switch, wizard cancel, copy). Returns true when a module switch
-- needs a /reload. Out of combat only: Edit Mode cannot move protected frames in combat.
function Setup.ApplyState(state, options)
    if not state then return false end
    if InCombatLockdown() then
        ui.RunOutOfCombat("setupApplyState", function() Setup.ApplyState(state, options) end)
        return false
    end
    options = options or {}
    local s = settings()
    local reload = false
    for id, on in pairs(state.modules or {}) do
        if moduleById[id] and Setup.SetModule(id, on) then reload = true end
    end
    local EM = ui.EditMode
    if state.style and EM and EM.SetBarStyle and (s.barLayout == "retail" and "retail" or "classic") ~= state.style then
        EM.SetBarStyle(state.style)
    end
    for _, key in ipairs(RAW) do
        if state.raw and state.raw[key] ~= nil then s[key] = copy(state.raw[key]) end
    end
    if EM and EM.LoadLayout then
        EM.LoadLayout(state.layout, options.skipTrackers and isTrackerFrame or nil)
    end
    Setup.RefreshPlaced()
    if not options.keepScale then Setup.ApplyScale(state) end
    return reload
end

-- Modules that place frames from their own settings follow the loaded positions.
function Setup.RefreshPlaced()
    local PRD = ui.PersonalResource
    if PRD and PRD.ApplyPosition then ui.SafeCall(PRD.ApplyPosition) end
    local RF = ui.RaidFrames
    if RF then
        if RF.RestoreAnchor then ui.SafeCall(RF.RestoreAnchor) end
        if RF.AttachContainer then ui.SafeCall(RF.AttachContainer) end
    end
    local CDM = ui.CooldownManager
    if CDM and CDM.Refresh then ui.SafeCall(CDM.Refresh) end
    if ui.ActionBars and ui.ActionBars.Apply then ui.SafeCall(ui.ActionBars.Apply) end
    if ui.RefreshEditLayout then ui.RefreshEditLayout() end
end

---------------------------------------------------------------------------------------------------
-- UI scale
---------------------------------------------------------------------------------------------------
function Setup.ScreenHeight()
    local text
    if GetScreenResolutions and GetCurrentResolution then
        local index = GetCurrentResolution()
        if index and index > 0 then text = select(index, GetScreenResolutions()) end
    end
    if not text and GetCVar then text = GetCVar("gxResolution") end
    local _, height = Layouts.ParseResolution(text)
    return height
end

function Setup.ScaleOf(state)
    if not state or not state.scaleMode then return nil end
    if state.scaleMode == "auto" then return Layouts.AutoScale(Setup.ScreenHeight()) end
    if type(state.scale) == "number" then return math.max(0.4, math.min(Layouts.MAX_SCALE, state.scale)) end
end

-- The uiScale CVar accepts 0.64..1.15; a smaller pixel-perfect scale (1440p and up) goes to UIParent itself.
function Setup.SetScale(scale)
    if type(scale) ~= "number" then return end
    local function apply()
        if SetCVar then
            local cvar = math.max(Layouts.MIN_CVAR_SCALE, scale)
            if GetCVar and GetCVar("useUiScale") ~= "1" then SetCVar("useUiScale", "1") end
            if not (GetCVar and math.abs((tonumber(GetCVar("uiScale")) or 0) - cvar) < 0.0005) then
                SetCVar("uiScale", tostring(cvar))
            end
        end
        if UIParent and UIParent.SetScale and math.abs((UIParent:GetScale() or 1) - scale) > 0.0005 then
            UIParent:SetScale(scale)
        end
        Setup.appliedScale = scale
        if ui.RefreshEditLayout then ui.RefreshEditLayout() end
    end
    ui.RunOutOfCombat("setupScale", apply)
end

function Setup.ApplyScale(state)
    local scale = Setup.ScaleOf(state)
    if scale then Setup.SetScale(scale) end
end

---------------------------------------------------------------------------------------------------
-- Role layouts
---------------------------------------------------------------------------------------------------
local function placeTrackers(spot)
    local CDM, EM = ui.CooldownManager, ui.EditMode
    if not (CDM and CDM.Groups and EM and EM.Place) then return end
    local y = spot.y
    for _, group in ipairs(CDM.Groups()) do
        local name = "ForeverStockUICDM" .. tostring(group.id)
        local entry = EM.Entry(name)
        if entry and entry.config then
            if group.kind == "bars" or group.enabled == false then
                -- Bar groups keep their default column on the left of the centre.
                if group.kind == "bars" then entry.config.position = nil end
            else
                local _, h = EM.Size(name)
                h = (h and h > 4) and h or 40
                EM.Place(name, spot.point, spot.relativePoint, spot.x, y)
                y = y - h - Layouts.CDM_GAP
            end
        end
    end
    if CDM.Refresh then CDM.Refresh() end
end

local function placeRaid(spot)
    local EM = ui.EditMode
    local name = "ForeverStockUIRaidAnchor"
    local entry = EM and EM.Entry(name)
    if not entry or not entry.config then return end
    local w, h = EM.Size(name)
    w, h = (w and w > 20) and w or 220, (h and h > 20) and h or 160
    EM.Place(name, spot.point, spot.relativePoint, spot.x, spot.y, { w, h })
    -- Raid frames keep their left edge from the saved width (RF.ResizeAnchor).
    entry.config.width, entry.config.height = w, h
end

local function placeMeter(spot)
    local meters = settings().combatMeters
    local EM = ui.EditMode
    if type(meters) ~= "table" or type(meters.order) ~= "table" then return end
    local docks = type(meters.docks) == "table" and meters.docks or {}
    for _, key in ipairs(meters.order) do
        if not docks[key] then
            EM.Place("ForeverStockUI" .. key .. "Meter", spot.point, spot.relativePoint, spot.x, spot.y)
            return
        end
    end
end

-- Puts every frame of the role layout on its spot (Edit Mode positions, PRD offsets). Out of combat only.
function Setup.ApplyPreset(role)
    local preset = Layouts.presets[role]
    local EM = ui.EditMode
    if not preset or not (EM and EM.Place) or InCombatLockdown() then return false end
    for name, spot in pairs(preset.frames) do EM.Place(name, spot[1], spot[2], spot[3], spot[4]) end
    local s = settings()
    s.prdX, s.prdY = preset.prd.x, preset.prd.y
    placeRaid(preset.raid)
    placeTrackers(preset.cdm)
    placeMeter(preset.meter)
    if EM.Reapply then EM.Reapply() end
    Setup.RefreshPlaced()
    return true
end

---------------------------------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------------------------------
Setup.channelsTab = L("Каналы", "Channels")

local function chatWindow(title)
    if not GetChatWindowInfo then return end
    local free
    for id = 2, NUM_CHAT_WINDOWS or 10 do
        local name, _, _, _, _, _, shown = GetChatWindowInfo(id)
        local frame = _G["ChatFrame" .. id]
        if frame and (shown or frame.isDocked) then
            if name == title then return frame end
        else
            free = true
        end
    end
    if free and FCF_OpenNewWindow then return FCF_OpenNewWindow(title) end
end

local function serverChannels()
    local list = {}
    if EnumerateServerChannels then
        for _, name in ipairs({ EnumerateServerChannels() }) do list[#list + 1] = name end
    end
    return list
end

-- chat = { tabs, place, channels, fontSize (number or nil) }
function Setup.ApplyChat(chat, role, style)
    if type(chat) ~= "table" then return end
    local s = settings()
    if chat.tabs then
        s.chatManage, s.chatGroupWindow, s.chatGuildWindow, s.chatLootWindow = true, true, true, true
        if ui.Chat and ui.Chat.Apply then ui.SafeCall(ui.Chat.Apply) end
    end
    local frame = ChatFrame1
    if chat.place and frame then
        local spot = (Layouts.presets[role] or Layouts.presets.MELEE).chat
        local y = style == "retail" and spot.retailY or spot.classicY
        frame:ClearAllPoints()
        frame:SetPoint(spot.point, UIParent, spot.relativePoint, spot.x, y)
        frame:SetWidth(spot.w)
        frame:SetHeight(spot.h)
        if frame.SetUserPlaced and frame:IsMovable() then frame:SetUserPlaced(true) end
        if FCF_SavePositionAndDimensions then ui.SafeCall(FCF_SavePositionAndDimensions, frame) end
    end
    if chat.channels then
        local tab = chatWindow(Setup.channelsTab)
        if tab and tab ~= frame then
            if ChatFrame_RemoveAllMessageGroups then ChatFrame_RemoveAllMessageGroups(tab) end
            for _, name in ipairs(serverChannels()) do
                if frame and ChatFrame_RemoveChannel then ChatFrame_RemoveChannel(frame, name) end
                if ChatFrame_AddChannel then ChatFrame_AddChannel(tab, name) end
            end
            if FCF_SelectDockFrame and frame then FCF_SelectDockFrame(frame) end
        end
    end
    if type(chat.fontSize) == "number" and FCF_SetChatWindowFontSize then
        for id = 1, NUM_CHAT_WINDOWS or 10 do
            local window = _G["ChatFrame" .. id]
            if window then ui.SafeCall(FCF_SetChatWindowFontSize, nil, window, chat.fontSize) end
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Characters
---------------------------------------------------------------------------------------------------
-- Other characters with saved settings: { { key, rec } } sorted by name.
function Setup.OtherChars()
    local list, own = {}, Setup.CharKey()
    for key, rec in pairs(Setup.DB().chars) do
        if key ~= own and type(rec) == "table" and type(rec.specs) == "table" and next(rec.specs) then
            list[#list + 1] = { key, rec }
        end
    end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    return list
end

-- Copies every talent set of another character to this one and puts the current set on screen.
function Setup.CopyFrom(key)
    local source = Setup.DB().chars[key]
    if type(source) ~= "table" or type(source.specs) ~= "table" then return false end
    local rec = Setup.Char(true)
    rec.specs = copy(source.specs)
    rec.installed = true
    local group = Setup.TalentGroup()
    local state = rec.specs[group] or rec.specs[1] or rec.specs[2]
    rec.specs[group] = state
    rec.group = group
    return Setup.ApplyState(state)
end

-- A character the account has never seen before the wizard existed: brand-new ones get the wizard, the others keep
-- what they had (their settings are taken as they are).
function Setup.IsFreshCharacter()
    local level = UnitLevel and UnitLevel("player") or 1
    local class = UnitClass and select(2, UnitClass("player"))
    if class == "DEATHKNIGHT" then
        return level <= 55 and (not UnitXP or UnitXP("player") == 0)
    end
    return level <= 1
end

-- Takes the running settings as this character's (skip, legacy characters).
function Setup.Adopt(installed)
    local rec = Setup.Char(true)
    local group = Setup.TalentGroup()
    rec.specs[group] = Setup.Capture(rec.specs[group] or { role = Setup.GuessRole() })
    rec.specs[group].configured = true
    rec.group = group
    if installed then rec.installed = true end
    return rec
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
local loaded -- { group, state } of the early load

ui.RegisterCallback("ConfigLoaded", function()
    local setup = Setup.DB()
    if setup.legacy == nil then
        -- Edit Mode creates editLayout at login: when it is already saved, ForeverUI ran here before.
        setup.legacy = type(settings().editLayout) == "table" and next(settings().editLayout) ~= nil
    end
    if not nameKnown() then return end
    local rec = Setup.Char(false)
    if not rec then return end
    local group = rec.group or 1
    local state = rec.specs[group] or rec.specs[1] or rec.specs[2]
    if state then
        writeEarly(state)
        loaded = { group = group, state = state }
    end
end, "Setup")

local driver = CreateFrame("Frame")
Setup.driver = driver
local waitFor, waited, firstWorld

local function after(seconds, fn)
    waitFor, waited = seconds, 0
    driver:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + elapsed
        if waited < waitFor then return end
        self:SetScript("OnUpdate", nil)
        fn()
    end)
end

local function hint()
    ui.Print(L("доступна установка интерфейса: |cffe8c27a/fui install|r", "the setup wizard is available: |cffe8c27a/fui install|r"))
end

-- First look after login: new character -> wizard; new talent set -> short wizard; else nothing.
function Setup.CheckFirstRun()
    if InCombatLockdown() then
        ui.RunOutOfCombat("setupFirstRun", Setup.CheckFirstRun)
        return
    end
    local rec = Setup.Char(false)
    local group = Setup.TalentGroup()
    Setup.currentGroup = group
    if not rec then
        if Setup.DB().legacy and not Setup.IsFreshCharacter() then
            Setup.Adopt(true)
            hint()
        elseif Setup.Open then
            Setup.Open("full")
        end
        return
    end
    if not rec.installed then
        if Setup.Open then Setup.Open("full") end
        return
    end
    -- The early load used the last saved set; the client may be on the other one.
    if loaded and loaded.group ~= group and rec.specs[group] then
        Setup.ApplyState(rec.specs[group])
        ui.Print((L("загружены позиции набора талантов %d.", "positions of talent set %d loaded.")):format(group))
    end
    rec.group = group
    if not rec.specs[group] then
        local other = rec.specs[group == 1 and 2 or 1]
        rec.specs[group] = other and copy(other) or Setup.Capture({ role = Setup.GuessRole() })
        rec.specs[group].configured = nil
        if Setup.Open and GetNumTalentGroups and GetNumTalentGroups() > 1 then Setup.Open("spec") end
    end
end

-- Talent set switched: the old set keeps what is on screen, the new one is loaded (or set up the first time).
function Setup.TalentGroupChanged()
    local rec = Setup.Char(false)
    local group = Setup.TalentGroup()
    local old = Setup.currentGroup
    if not rec or not rec.installed or old == nil or old == group then
        Setup.currentGroup = group
        return
    end
    if Setup.IsOpen and Setup.IsOpen() and Setup.Cancel then Setup.Cancel() end
    rec.specs[old] = Setup.Capture(rec.specs[old] or {}, true)
    Setup.currentGroup = group
    rec.group = group
    local state = rec.specs[group]
    if state then
        if Setup.ApplyState(state, { skipTrackers = true, keepScale = true }) then
            ui.Print(L("у этого набора талантов включены другие модули: нужна перезагрузка интерфейса (/reload).",
                "this talent set uses other modules: reload the interface (/reload)."))
        end
        return
    end
    state = copy(rec.specs[old])
    state.configured = nil
    state.role = Setup.GuessRole()
    rec.specs[group] = state
    if Setup.Open then Setup.Open("spec") end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
driver:RegisterEvent("UI_SCALE_CHANGED")
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if loaded then
            writeSuite(loaded.state)
            Setup.ApplyScale(loaded.state)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if firstWorld then return end
        firstWorld = true
        -- Let the modules settle (late frames, raid container) before the wizard measures anything.
        after(2.5, Setup.CheckFirstRun)
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        Setup.TalentGroupChanged()
    elseif event == "UI_SCALE_CHANGED" then
        -- The client puts UIParent back on the CVar: a pixel-perfect scale under 0.64 is set again.
        -- Only UIParent: setting the CVar again would fire this event again.
        local scale = Setup.appliedScale
        if scale and scale < Layouts.MIN_CVAR_SCALE and math.abs(UIParent:GetScale() - scale) > 0.0005 then
            ui.RunOutOfCombat("setupParentScale", function() UIParent:SetScale(scale) end)
        end
    elseif event == "PLAYER_LOGOUT" then
        if Setup.IsOpen and Setup.IsOpen() and Setup.Cancel then Setup.Cancel(true) end
        local rec = Setup.Char(false)
        if rec and rec.installed then
            local group = Setup.currentGroup or Setup.TalentGroup()
            rec.specs[group] = Setup.Capture(rec.specs[group] or {})
            rec.group = group
        end
    end
end)
