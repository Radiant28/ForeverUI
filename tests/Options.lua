-- Run with Lua 5.1 from the addon directory: lua tests/Options.lua
-- Loads the configuration core, widget factory, options window and every schema on a permissive
-- WoW API mock, builds each page and drives the controls.
local forbidden = { "C_Timer", "BackdropTemplate", "FramePool", "CreateFramePool", "Settings.RegisterCanvas",
    "SetColorTexture", "SetAtlas", "C_AddOns", "SetShown(" }

local methods = {}
local objects = {}
local function new(kind, parent, name)
    local object = setmetatable({ kind = kind, parent = parent, shown = kind ~= "Frame" or true, scripts = {},
        width = 100, height = 20, points = {}, children = {}, alpha = 1, scale = 1, level = 1 }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        -- Unknown WoW methods are no-ops; addon fields and script-like hooks stay nil as on real frames.
        if type(key) == "string" and key:match("^%u") and not key:match("^On") and not key:match("^Forever") then
            return function() end
        end
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
function methods:SetFormattedText(fmt, ...) self.text = fmt:format(...) end
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
function methods:Enable() self.disabled = nil; if self.scripts.OnEnable then self.scripts.OnEnable(self) end end
function methods:Disable() self.disabled = true; if self.scripts.OnDisable then self.scripts.OnDisable(self) end end
function methods:IsEnabled() return not self.disabled and 1 or nil end
function methods:GetEffectiveScale() return self.scale end
function methods:SetScale(s) self.scale = s end
function methods:GetScale() return self.scale end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(l) self.level = l end
function methods:GetParent() return self.parent end
function methods:SetParent(p) self.parent = p end
function methods:SetAlpha(a) self.alpha = a end
function methods:GetAlpha() return self.alpha end
function methods:GetVerticalScroll() return rawget(self, "vscroll") or 0 end
function methods:SetVerticalScroll(v) self.vscroll = v end
function methods:SetVertexColor(...) self.color = { ... } end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:SetBackdropColor(...) self.backdropColor = { ... } end
function methods:SetBackdropBorderColor(...) self.borderColor = { ... } end
function methods:GetFrameStrata() return "MEDIUM" end
function methods:GetName() return self.name end
function methods:Click(button)
    if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end
end

function CreateFrame(kind, name, parent)
    local frame = new(kind, parent, name)
    frame.name = name
    return frame
end
function CreateFont(name)
    local font = new("Font", nil, name)
    return font
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent.width, UIParent.height = 1920, 1080
InterfaceOptionsFramePanelContainer = CreateFrame("Frame")
InterfaceOptionsFrame = CreateFrame("Frame")
InterfaceOptionsFrame.shown = false
ColorPickerFrame = CreateFrame("Frame", "ColorPickerFrame")
ColorPickerFrame.shown = false
function ColorPickerFrame:SetColorRGB(r, g, b) self.rgb = { r, g, b }; if self.func then self.func() end end
function ColorPickerFrame:GetColorRGB() return unpack(self.rgb) end
OpacitySliderFrame = CreateFrame("Slider")
OpacitySliderFrame.value = 0.25
GameTooltip = CreateFrame("GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UISpecialFrames, StaticPopupDialogs, SlashCmdList = {}, {}, {}
YES, NO = "Yes", "No"
local combat, popups, categories, reloaded = false, {}, {}, false
function InCombatLockdown() return combat end
function GetLocale() return "ruRU" end
function GetAddOnMetadata() return "1.2.0" end
function IsAddOnLoaded() return false end
function IsShiftKeyDown() return false end
function PlaySound() end
function GameTooltip_Hide() end
function geterrorhandler() return function(err) error(err, 0) end end
function InterfaceOptions_AddCategory(panel) categories[#categories + 1] = panel end
function InterfaceOptionsFrame_OpenToCategory(panel) categories.opened = panel end
function HideUIPanel(frame) frame:Hide() end
function StaticPopup_Show(name) popups[#popups + 1] = name; return {} end
function ReloadUI() reloaded = true end
function GetCVar() return nil end
function tinsert(t, v) table.insert(t, v) end
LibStub = nil

local events = {}
local registerEvent = function(self, event) events[event] = events[event] or {}; events[event][self] = true end
methods.RegisterEvent = registerEvent
methods.UnregisterEvent = function(self, event) if events[event] then events[event][self] = nil end end
local function fire(event, ...)
    local frames = {}
    for frame in pairs(events[event] or {}) do frames[#frames + 1] = frame end
    for _, frame in ipairs(frames) do frame.scripts.OnEvent(frame, event, ...) end
end

local ui = {}
local function load(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    for _, keyword in ipairs(forbidden) do assert(not source:find(keyword, 1, true), path .. ": " .. keyword) end
    assert(loadfile(path))("ForeverUI", ui)
end

for _, path in ipairs({ "Core/Config.lua", "Core/Widgets.lua", "Core/OptionsFrame.lua", "Core/Compat.lua" }) do load(path) end
ui.bundledMedia = { font = {}, statusbar = {}, background = {}, border = {} }
load("Media.lua")

-- Module APIs the schemas call into.
local applied = {}
local function recorder(name) return function() applied[name] = (applied[name] or 0) + 1 end end
ui.UnitFrames = { ApplyHealthColor = recorder("health"), ApplyBarFill = recorder("fill"), ApplyPanelMedia = recorder("panel"),
    ApplyColors = recorder("colors"), ApplyVisibility = recorder("visibility") }
ui.CastBar = { stock = { width = 195, height = 13, scale = 100 }, Apply = recorder("cast") }
ui.Bags = { Relayout = recorder("relayout"), Refresh = recorder("refresh") }
ui.Minimap = { Layout = recorder("minimap") }
ui.Performance = { Apply = recorder("perf") }
ui.Merchant = { Apply = recorder("merchant") }
ui.ActionBars = { Apply = recorder("bars") }
ui.MicroMenu = { ApplyColors = recorder("micro") }
ui.Chat = { Apply = recorder("chat") }
ui.EditMode = { Open = recorder("editOpen"), Apply = recorder("edit") }
ui.CombatMeterLimits = { minWidth = 145, maxWidth = 600, minRows = 1, maxRows = 15 }
ui.CombatMeter = { Apply = recorder("meter"), ResetWidth = recorder("meterWidth"), ResetDamageRows = recorder("rows"),
    ResetHealingRows = recorder("rows"), BuildPreview = function(parent) local f = CreateFrame("Frame", nil, parent); return 80 end }
ui.ItemLabels = {
    defaults = {
        level = { point = 2, x = 0, y = -2, size = 5, color = { 1, 0.89, 0.6 } },
        durability = { point = 8, x = 0, y = 2, size = 3, color = { 0.35, 1, 0.2 }, durability = true },
        bagsLevel = { point = 2, x = 0, y = -2, size = 1, color = { 1, 0.89, 0.6 }, bag = true },
        bagsDurability = { point = 7, x = 2, y = 2, size = 1, color = { 0.35, 1, 0.2 }, bag = true, durability = true },
    },
    sizes = { 9, 10, 11, 12, 13 }, bagSizes = { "Auto", 9, 10, 11 }, pointNames = { "TL", "T", "TR", "L", "C", "R", "BL", "B", "BR" },
    Apply = recorder("labels"),
}
ui.CombatText = { defaults = { enabled = true, fontSize = 20, fontName = "Font", fontOutline = "OUTLINE", fontShadow = true,
    shortNumbers = false, showIcons = true, showSwingIcon = true, iconPosition = "LEFT", animStyle = "FOUNTAIN",
    anchorToNameplates = true, colorBySchool = true, colorNormal = { 1, 1, 1 }, colorCrit = { 1, 0.85, 0.15 },
    colorHeal = { 0.2, 0.92, 0.3 }, colorHealCrit = { 0.25, 1, 0.35 }, colorPet = { 1, 0.65, 0.2 } },
    switches = { { "enabled", "Вкл", "On" }, { "showMisses", "Промахи", "Misses" } },
    sliders = { { "fontSize", "Размер", "Size", 12, 38, 1 } },
    schools = { [1] = { 1, 1, 0 }, [2] = { 1, 1, 0.5 }, [4] = { 1, 0.4, 0 }, [8] = { 0, 1, 0 }, [16] = { 0, 1, 1 },
        [32] = { 0.7, 0.4, 1 }, [64] = { 1, 0.5, 1 } },
    Apply = recorder("ct"), Test = recorder("ctTest"), active = true }
ui.cursor = { defaults = { outlineEnabled = true, trailEnabled = true, outlineStyle = "ring", trailStyle = "smooth",
    mode = "always", size = 36, thickness = 2, outlineAlpha = 0.85, glow = 0.45, softness = 3, offsetX = 0, offsetY = 0,
    outlineR = 0.85, outlineG = 0.72, outlineB = 0.42, width = 16, trailAlpha = 0.55, length = 400, lifetime = 0.55,
    fade = 1.5, taper = 0.8, edge = 1, density = 0.8, smoke = 0.65, trailR = 0.35, trailG = 0.75, trailB = 1 },
    ranges = { size = { 16, 100, 1 }, thickness = { 1, 8, 0.5 }, outlineAlpha = { 0, 1, 0.05 }, glow = { 0, 1, 0.05 },
        softness = { 0, 12, 0.5 }, offsetX = { -60, 60, 1 }, offsetY = { -60, 60, 1 }, width = { 4, 60, 1 },
        trailAlpha = { 0, 1, 0.05 }, length = { 40, 1200, 10 }, lifetime = { 0.1, 3, 0.05 }, fade = { 0.5, 4, 0.1 },
        taper = { 0, 1, 0.05 }, edge = { 0, 1, 0.5 }, density = { 0.1, 1, 0.05 }, smoke = { 0, 1, 0.05 } },
    settings = {}, Apply = recorder("cursor") }

local schemas = {}
for line in io.lines("ForeverUI.toc") do
    local path = line:match("^Options\\(.+%.lua)%s*$")
    if path then
        schemas[#schemas + 1] = path
        load("Options/" .. path)
    end
end
assert(#schemas >= 15, "every schema file is listed in the toc")

-- SavedVariables arrive after the files run: normalization fills defaults into the saved table.
ForeverStockUIDB = { bagsCellSize = 999, castFontOutline = "BOGUS", ufChromeColor = { 2, 0, 0 }, mapScale = 103 }
ui.Settings().combatText = {}
fire("ADDON_LOADED", "ForeverUI")
local db = ForeverStockUIDB
assert(db.bagsCellSize == 48, "ranges are clamped")
assert(db.castFontOutline == "OUTLINE", "selects fall back to the default")
assert(db.ufChromeColor[1] == 0.93, "invalid colours are replaced")
assert(db.mapScale == 105, "ranges snap to the step")
assert(db.unitFramesEnabled == true and db.castWidth == 195 and db.unitBarFill == 3, "defaults are written")
assert(db.levelSize == 5 and db.bagsDurabilityAutoColor == true, "generated label schema works")

-- Live apply and callbacks.
local changed
ui.RegisterCallback("SettingChanged", function(id, key, value) changed = { id, key, value } end, "test")
ui.SetOption("bags", "bagsCellSize", 30)
assert(applied.relayout == 1 and changed[2] == "bagsCellSize" and db.bagsCellSize == 30)
ui.SetOption("unitframes", "ufManaColor", { 0.1, 0.2, 0.3 })
assert(applied.colors == 1 and db.ufManaColor[3] == 0.3)
assert(not ui.IsDefault("bags", "bagsCellSize"))
ui.ResetOption("bags", "bagsCellSize")
assert(db.bagsCellSize == 36 and ui.IsDefault("bags", "bagsCellSize"))

-- Dependencies: the master switch disables the rest of a module.
local spec = ui.GetModule("castbar")
assert(ui.IsOptionAvailable(spec, spec.byKey.castWidth))
ui.SetOption("castbar", "castMidStyle", false)
assert(not ui.IsOptionAvailable(spec, spec.byKey.castWidth) and ui.IsOptionAvailable(spec, spec.byKey.castMidStyle))
assert(not ui.IsOptionAvailable(spec, spec.byKey.castIconSize), "castIconSize depends on the icon")
local addon = ui.GetModule("addonbar")
assert(not ui.IsOptionAvailable(addon, addon.byKey.mapButtonsScale), "bar settings need the ring off")
ui.SetOption("addonbar", "mapButtonsCircle", false)
assert(ui.IsOptionAvailable(addon, addon.byKey.mapButtonsScale))

-- Protected modules queue their apply until combat ends.
combat = true
local before = applied.minimap or 0
ui.SetOption("addonbar", "mapButtonsSpacing", 6)
assert((applied.minimap or 0) == before and ui.HasCombatQueue())
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(applied.minimap == before + 1 and not ui.HasCombatQueue())

-- Reload-required options raise the footer flag.
ui.SetOption("bags", "bagsEnabled", false)
assert(ui.IsReloadPending())

-- Split colours (CursorUZ keys) and per-option databases.
ui.SetOption("cursor", "outline", { 0.1, 0.2, 0.3 })
assert(ui.cursor.settings.outlineR == 0.1 and ui.cursor.settings.outlineB == 0.3 and applied.cursor == 1)
ui.SetOption("cursor", "cursorEnabled", false)
assert(db.cursorEnabled == false and ui.cursor.settings.cursorEnabled == nil)

-- Binding for Edit Mode.
local binding = ui.OptionBinding("minimap", "mapScale")
assert(select(1, binding:GetMinMaxValues()) == 60 and binding:GetValueStep() == 5 and binding.foreverDefault == 100)
binding:SetValue(120)
assert(db.mapScale == 120 and binding:GetValue() == 120)

-- The window: open, build every page and touch every control.
SlashCmdList.FOREVERUI("")
local window = ForeverUIOptions
assert(window and window:IsShown(), "/fui opens the window")
local function walk(frame, visit)
    visit(frame)
    for _, child in ipairs(frame.children or {}) do walk(child, visit) end
end
local built = 0
for _, module in ipairs(ui.optionOrder) do
    ui.OpenOptions(module.id)
    built = built + 1
    walk(window, function(object)
        if object.opt and object.access and object.Refresh then
            object:Refresh()
            local kind, current = object.kind, object.access.get and object.access.get()
            if object.enabled and kind == "toggle" then object.access.set(not current) end
            if object.enabled and kind == "range" and object.slider then object.slider:SetValue((object.slider.max or 1)) end
            if object.enabled and kind == "color" then object.access.set({ 0.5, 0.5, 0.5, 0.5 }) end
            if object.enabled and (kind == "select") and object.box then
                object.box:Click()
                local list = ForeverUIDropdownList
                assert(list and list:IsShown(), "dropdown opens")
                local first = list.rows[1]
                if first.item then first:Click() end
                assert(not list:IsShown(), "choosing closes the list")
            end
        end
    end)
end
assert(built == #ui.optionOrder and built >= 17)

-- Colour picker with alpha.
local row
walk(window, function(object) if object.kind == "color" and object.opt and object.opt.alpha and object.enabled then row = row or object end end)
ui.OpenOptions("unitframes")
walk(window, function(object)
    if object.kind == "color" and object.opt and object.opt.key == "ufPanelColor" then row = object end
end)
assert(row, "alpha colour control exists")
ui.Widgets.OpenColorPicker(row.access.get(), true, function(color) row.access.set(color) end)
ColorPickerFrame.rgb = { 0.2, 0.4, 0.6 }
ColorPickerFrame.func()
assert(db.ufPanelColor[2] == 0.4 and math.abs(db.ufPanelColor[4] - 0.75) < 1e-6, "opacity becomes alpha")

-- Module reset restores defaults and reapplies once per function.
ui.SetOption("performance", "perfFontSize", 20)
ui.ResetModule("performance")
assert(db.perfFontSize == 12)

-- Legacy controls still work (Edit Mode toolbar, label editor).
local panel = CreateFrame("Frame")
local hits = 0
local legacy = ui.Slider(panel, "editGridSpacing", "Grid", -80, { 8, 64, 4, 24 }, function() hits = hits + 1 end)
legacy:SetValue(40)
assert(db.editGridSpacing == 40 and hits == 1 and legacy:GetValue() == 40)
local check = ui.Checkbox(panel, "editSnap", "Snap", -30, false, function() hits = hits + 1 end)
assert(_G.ForeverStockUI_editSnap == check)
ui.SetOption("editmode", "editSnap", true)
assert(check:GetChecked() == true)

-- Search filters the sidebar and the reset-all popup is wired.
window.search:SetText("шрифт")
window.search.scripts.OnTextChanged(window.search)
SlashCmdList.FOREVERUI("reset")
assert(popups[#popups] == "FOREVERUI_RESET_ALL")
StaticPopupDialogs.FOREVERUI_RESET_ALL.OnAccept()
assert(reloaded and db.bagsCellSize == 36 and db.castMidStyle == true)

window:Hide()
print(("Options OK: %d schemas, %d modules, %d frames; normalization, live apply, dependencies, combat queue, reload flag, "
    .. "split colours, bindings, every page and control, alpha picker, resets, legacy API"):format(#schemas,
    #ui.optionOrder, #objects))
