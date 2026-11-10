-- Run with Lua 5.1 from the addon directory.
local methods, created = {}, 0
local function object(kind, parent)
    created = created + 1
    return setmetatable({ kind = kind, parent = parent, shown = true, alpha = 1,
        children = {}, regions = {}, scripts = {}, events = {} }, { __index = methods })
end

function CreateFrame(kind, name, parent, template)
    if template == "UIPanelScrollFrameTemplate" then assert(name, "WotLK scroll templates need a name") end
    local frame = object(kind, parent)
    if parent then table.insert(parent.children, frame) end
    if name then _G[name] = frame end
    return frame
end

local function region(frame, kind)
    local value = object(kind, frame)
    table.insert(frame.regions, value)
    return value
end

for _, key in ipairs({ "SetShadowColor", "SetShadowOffset", "SetJustifyH", "SetJustifyV", "SetWordWrap",
    "RegisterForDrag", "SetBackdrop", "SetAutoFocus", "SetMaxLetters", "ClearFocus", "EnableMouseWheel" }) do
    methods[key] = function() end
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width or (self.parent.width - 4) end
function methods:GetHeight() return self.height or (self.parent.height - 4) end
function methods:SetFont(...) self.font = {...} end
function methods:ClearAllPoints() self.points = nil end
function methods:SetAllPoints(relative) self.allPoints = relative end
function methods:SetTexCoord(...) self.uv = {...} end
function methods:GetTexCoord() return unpack(self.uv or {0, 1, 0, 1}) end
function methods:SetScrollChild(value) self.scrollChild = value end
function methods:SetCooldown(start, length) self.start, self.length = start, length end
function methods:SetPoint(point, ...)
    self.points = self.points or {}
    for i, anchor in ipairs(self.points) do
        if anchor[1] == point then self.points[i] = {point, ...}; return end
    end
    table.insert(self.points, {point, ...})
end
function methods:CreateFontString() return region(self, "FontString") end
function methods:CreateTexture(_, layer, _, sublevel)
    local texture = region(self, "Texture")
    texture.layer, texture.sublevel = layer, sublevel
    return texture
end
function methods:GetObjectType() return self.kind end
function methods:GetChildren() return unpack(self.children) end
function methods:GetNumChildren() return #self.children end
function methods:GetRegions() return unpack(self.regions) end
function methods:GetFrameStrata() return self.strata or "BACKGROUND" end
function methods:SetFrameStrata(value)
    assert(value ~= "UNKNOWN", "SetFrameStrata(): Unknown frame strata: UNKNOWN")
    self.strata = value
end
function methods:GetFrameLevel() return self.frameLevel or 1 end
function methods:SetFrameLevel(value) self.frameLevel = value end
function methods:SetScale(value) self.scale = value end
function methods:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:GetEffectiveDepth() return self.depth or (self.parent and self.parent:GetEffectiveDepth()) or 0 end
function methods:GetCenter() return self.centerX, self.centerY end
function methods:GetTop() return self.centerY and self.centerY + self:GetHeight() / 2 end
function methods:EnableDrawLayer(layer) self.enabledLayer = layer end
function methods:SetAlpha(value) self.alpha = value end
function methods:GetAlpha() return self.alpha end
function methods:GetEffectiveAlpha() return self.alpha * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
function methods:EnableMouse(value) self.mouse = value end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:Disable() self.disabled = true end
function methods:Enable() self.disabled = false end
methods.HookScript = methods.SetScript
function methods:RegisterEvent(name) self.events[name] = true end
function methods:UnregisterEvent(name) self.events[name] = nil end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:Show()
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetTexture(value, ...)
    self.texture = value
    if type(value) == "number" then self.solid = {value, ...} end
end
function methods:GetTexture() return self.texture end
function methods:SetBlendMode(value) self.blend = value end
function methods:SetVertexColor(...) self.vertex = {...} end
function methods:GetVertexColor() return unpack(self.vertex or {1, 1, 1}) end
methods.SetStatusBarTexture = methods.SetTexture
function methods:SetText(value)
    self.text = tostring(value)
    if self.kind == "EditBox" and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #self.text:gsub("[\128-\191]", "") * 7 end
function methods:SetTextColor(...) self.color = {...} end
methods.SetStatusBarColor = methods.SetTextColor
function methods:GetStatusBarColor() return unpack(self.color) end
function methods:SetMinMaxValues(low, high) self.low, self.high = low, high end
function methods:GetMinMaxValues() return self.low, self.high end
function methods:SetValue(value) self.value = value end
function methods:GetValue() return self.value end

local now, conflict, inCombat = 100, false, false
local resolution = "1600x900"
local locked, instance = false, "none"
local cvars = { nameplateAllowOverlap = "1", nameplateDistance = "30" }
local options = {}
local media = {}
local mediaPaths = {
    font = { ["Test Font"] = "test-font.ttf", ["Тестовая гарнитура"] = "cyrillic-font.ttf" },
    statusbar = { ["Test Stripes"] = "test-stripes.tga", ["Test Gloss"] = "test-gloss.tga" },
}
local fontNames = { "Test Font", "Тестовая гарнитура" }
for i = 1, 6 do
    local name = "Example font " .. i
    fontNames[#fontNames + 1] = name
    mediaPaths.font[name] = "example-font-" .. i .. ".ttf"
end
function media:HashTable(kind) return mediaPaths[kind] end
function media:List(kind)
    if kind == "font" then return fontNames end
    return { "Test Gloss", "Test Stripes" }
end
function LibStub(name) if name == "LibSharedMedia-3.0" then return media end end
local mainOptions, openedCategory
local ui = {
    Options = function()
        mainOptions = CreateFrame("Frame")
        mainOptions:Hide()
        return mainOptions
    end,
    Checkbox = function(_, key, _, _, _, apply) options[key] = { apply = apply } end,
    Slider = function(_, key, _, _, _, apply, _, settings)
        local slider = { apply = apply, Disable = function(self) self.disabled = true end }
        slider.select = function(value) settings[key] = value; apply() end
        options[key] = slider
        return slider
    end,
}
function InterfaceOptionsFrame_OpenToCategory(panel) openedCategory = panel; panel:Show() end
local longName = string.rep("Я", 30)
local units = { player = { level = 25 }, target = { guid = "A", name = longName, level = 23, kind = "elite",
    debuffs = { { "poison", 3, 102 }, { "curse", 1, 130 } }, buffs = { { "ward", 1, 0 } } } }
function IsAddOnLoaded(name) return name == "!!RefinedBlizzPlates" and conflict end
function GetCVar(name) return name == "gxResolution" and resolution or cvars[name] end
function SetCVar(name, value) assert(cvars[name] and not locked); cvars[name] = value end
function InCombatLockdown() return locked end
function IsInInstance() return instance ~= "none", instance end
function GetTime() return now end
function GetQuestDifficultyColor(level) return { r = level / units.player.level, g = 1, b = 0 } end
function UnitGUID(unit) return units[unit] and units[unit].guid end
function UnitName(unit) return units[unit].name end
function UnitLevel(unit) return units[unit].level end
function UnitClassification(unit) return units[unit].kind end
function UnitAffectingCombat(unit) return unit == "player" and inCombat or units[unit].combat end
function UnitThreatSituation(_, unit) return units[unit].threat end
function UnitCreatureType(unit) return units[unit].creature end
function UnitIsPlayer(unit) return units[unit].player end
function UnitPlayerControlled(unit) return units[unit].controlled end
function UnitIsFriend(_, unit) return units[unit].friendly end
function UnitReaction(unit) return units[unit].reaction end
function UnitCastingInfo(unit)
    local cast = units[unit].cast
    if cast then return cast.name, nil, cast.name, cast.icon, cast.start, cast.finish, nil, 1, cast.shield end
end
function UnitChannelInfo() end
function IsSpellKnown(id) return id == 1766 end
function GetSpellInfo() return "Kick" end
local spellCooldown = 0
function GetSpellCooldown() return spellCooldown > 0 and now or 0, spellCooldown, 1 end
local cursorX, cursorY = 0, 0
function GetCursorPosition() return cursorX, cursorY end
local function aura(unit, key, index)
    local entry = units[unit][key] and units[unit][key][index]
    if entry then return entry[1], nil, entry[1], entry[2], nil, 30, entry[3] end
end
function UnitDebuff(unit, index) return aura(unit, "debuffs", index) end
function UnitBuff(unit, index) return aura(unit, "buffs", index) end

WorldFrame = CreateFrame("Frame")
UIParent = CreateFrame("Frame")
SlashCmdList, UISpecialFrames = {}, {}
local stockBorder = [[Interface\Tooltips\Nameplate-Border]]
local stockThreat = [[Interface\TargetingFrame\UI-TargetingFrame-Flash]]
local function plate(name)
    local frame = CreateFrame("Frame", nil, WorldFrame)
    frame.strata = "UNKNOWN"
    frame.depth = 20
    local health = CreateFrame("StatusBar", nil, frame)
    health.centerX, health.centerY = 503.25, 310.5
    health:SetHeight(8)
    health:SetMinMaxValues(0, 100)
    health:SetValue(35)
    health:SetStatusBarColor(1, 0, 0)
    local cast = CreateFrame("StatusBar", nil, frame)
    cast:SetMinMaxValues(0, 10)
    cast:SetValue(4)
    region(cast, "FontString"):SetText("Native cast")
    cast:Hide()
    for i = 1, 11 do region(frame, (i == 7 or i == 8) and "FontString" or "Texture") end
    frame.regions[1]:SetTexture(stockThreat)
    frame.regions[2]:SetTexture(stockBorder)
    frame.regions[5]:SetTexture("cast-icon")
    frame.regions[7]:SetText(name)
    frame.regions[8]:SetText(23)
    frame.regions[10]:SetTexture("raid-marker")
    region(frame, "FontString"):SetText("Extra native label")
    for _, i in ipairs({1, 4, 6, 9, 11}) do frame.regions[i]:Hide() end
    return frame
end

local a, b = plate(longName), plate(longName)
b:SetAlpha(0.6)
local unrelated = plate("Not a nameplate")
unrelated.regions[2]:SetTexture("other border")
local create = CreateFrame
local driver
function CreateFrame(...)
    local frame = create(...)
    driver = driver or frame
    return frame
end

local forbidden = {"CreateMaskTexture", "AddMaskTexture", "SetColorTexture", "SetShown", "C_NamePlate",
    "C_Timer", "C_AddOns", "BackdropTemplate", "SetAtlas", "SetIgnoreParentScale", "SetSnapToPixelGrid"}
for _, suffix in ipairs({"NameplateBoxes", "NameplateStyle", "NameplateOptions", "Nameplates"}) do
    local filename = "ForeverUI_" .. suffix .. ".lua"
    local file = assert(io.open(filename, "r"))
    local source = file:read("*a")
    file:close()
    for _, keyword in ipairs(forbidden) do assert(not source:find(keyword, 1, true), filename .. ": " .. keyword) end
    assert(loadfile(filename))("ForeverUI", ui)
end
assert(WoWForeverNameplates:RegisterBox("early", { update = function() end }))
assert(WoWForeverNameplates:SetBoxEnabled("early", false))
driver.scripts.OnEvent(driver, "PLAYER_LOGIN")
assert(not WoWForeverNameplatesOptionsScroll)
SlashCmdList.WOWFOREVERNAMEPLATES("")
assert(openedCategory == mainOptions and WoWForeverNameplatesOptionsScroll.parent == mainOptions)
assert(not WoWForeverNameplatesOptions)
assert(cvars.nameplateAllowOverlap == "0" and cvars.nameplateDistance == "41" and options.verticalSpacing.disabled)
local cfg = ForeverUI_NameplatesDB
assert(cfg.plateOffsetX == 0 and cfg.plateOffsetY == 8)
local API = WoWForeverNameplates
assert(WoWForeverNameplatesDB == cfg and API:IsBoxEnabled("wfn-level"))
assert(not API:IsBoxEnabled("early") and cfg.boxOff.early)
assert(API:UnregisterBox("early"))
locked, cfg.maxDistance = true, 30
options.maxDistance.apply()
assert(cvars.nameplateDistance == "41")
locked = false
driver.scripts.OnEvent(driver, "PLAYER_REGEN_ENABLED")
assert(cvars.nameplateDistance == "30")
local function tick() driver.scripts.OnUpdate(driver, 0.05) end
tick()
local view, second = a.children[3], b.children[3]
assert(view:IsShown() and view.mouse == false and unrelated.children[3] == nil)
assert(a.scale == nil and a.points == nil and a.width == nil)
assert(view:GetFrameStrata() == "MEDIUM" and a:GetFrameStrata() == "UNKNOWN")
assert(view.scale == 1.15 and view:GetEffectiveAlpha() == 1 and second:GetEffectiveAlpha() == 0.5)
assert(a.children[1].alpha == 0 and a.children[2].alpha == 1 and a.regions[10].alpha == 0)
assert(view.raid:IsShown() and view.raid:GetTexture() == "raid-marker")
assert(a.regions[2]:GetTexture() == nil and not a.regions[2]:IsShown())
assert(a.regions[5]:GetTexture() == "cast-icon" and a.regions[10]:GetTexture() == "raid-marker")
for _, i in ipairs({7, 8, 12}) do
    assert(a.regions[i]:GetAlpha() == 0 and not a.regions[i]:IsShown())
    a.regions[i]:SetAlpha(1)
    a.regions[i]:Show()
end
a.regions[2]:SetTexture(stockBorder)
a.regions[2]:Show()
tick()
assert(a.regions[2]:GetTexture() == nil and not a.regions[2]:IsShown())
for _, i in ipairs({7, 8, 12}) do
    assert(a.regions[i]:GetAlpha() == 0 and not a.regions[i]:IsShown())
end

local function assertAnchor(region, index, point, relative, relativePoint, x, y)
    local anchor = region.points[index]
    assert(anchor[1] == point and anchor[2] == relative and anchor[3] == relativePoint
        and anchor[4] == x and anchor[5] == y)
end
assertAnchor(view.name, 1, "BOTTOMLEFT", view.health, "TOPLEFT", 2, 6)
assertAnchor(view.name, 2, "BOTTOMRIGHT", view.health, "TOPRIGHT", -2, 6)
local auraRow = view[1].parent
assertAnchor(auraRow, 1, "BOTTOMLEFT", view.name, "TOPLEFT", 0, 4)
assertAnchor(view[2], 1, "BOTTOMLEFT", auraRow, "BOTTOMLEFT", 18, 0)
local levelBox = view.boxes["wfn-level"]
assertAnchor(levelBox.text, 1, "CENTER", levelBox, "CENTER", 0, 0)
local function assertPixel(value, pixel)
    local pixels = value / pixel
    assert(math.abs(pixels - math.floor(pixels + 0.5)) < 0.000001)
end
local function assertChromePixels(pixel, overlay)
    overlay = overlay or view
    pixel = pixel / overlay:GetEffectiveScale()
    local native = overlay.nativeHealth
    local anchor = overlay.points[1]
    local ratio = native:GetEffectiveScale() / overlay:GetEffectiveScale()
    assert(anchor[1] == "BOTTOM" and anchor[2] == native and anchor[3] == "TOP")
    assert(math.abs(anchor[4] - cfg.plateOffsetX * ratio) <= pixel / 2 + 0.000001)
    assert(math.abs(anchor[5] - cfg.plateOffsetY * ratio) <= pixel / 2 + 0.000001)
    assertPixel(native.centerX * ratio + anchor[4] - overlay.width / 2, pixel)
    assertPixel(native:GetTop() * ratio + anchor[5], pixel)
    assertPixel(overlay.width, pixel)
    assertPixel(overlay.height, pixel)
end
assertChromePixels(768 / 900)
assertAnchor(levelBox, 1, "LEFT", view, "RIGHT", 768 / 900 / view:GetEffectiveScale(), 0)
options.plateOffsetX.select(-12)
options.plateOffsetY.select(21)
tick()
assert(view.points[1][4] < 0 and view.points[1][5] > 0)
assertChromePixels(768 / 900)
resolution = "1920x1080"
driver.scripts.OnEvent(driver, "DISPLAY_SIZE_CHANGED")
tick()
assertChromePixels(768 / 1080)
assert(view.health.value == 35 and view.health.color[1] == 0.82)
assert(levelBox.text.text == "23" and levelBox.text.color[1] == 23 / 25 and view.dragon:IsShown())
assert(view.name.text:match("%.%.%.$") and #view.name.text < #longName)
assert(view[1].time.text == "2" and view[1].count.text == "3" and view[3].time.text == "")
assert(view[3].icon.texture == "ward" and not view[4]:IsShown() and not second[1]:IsShown())
assert(cfg.auraTimerAnimation == "static" and not view[1].cooldown)
options.auraSize.select(24)
options.auraGap.select(5)
options.auraOffsetX.select(-9)
options.auraOffsetY.select(12)
tick()
assert(auraRow.width == 111 and auraRow.height == 24 and view[1].width == 24)
assertAnchor(auraRow, 1, "BOTTOMLEFT", view.name, "TOPLEFT", -9, 12)
assertAnchor(view[2], 1, "BOTTOMLEFT", auraRow, "BOTTOMLEFT", 29, 0)
assert(view[1].regions[2].allPoints == view[1] and view[1].time.font[2] == 17 and view[1].count.font[2] == 12)

local function ChooseAuraAnimation(label)
    for _, child in ipairs(WoWForeverNameplatesOptionsScroll.scrollChild.children) do
        if child.text == label or child.text == "[x] " .. label then
            child.scripts.OnClick(child)
            return
        end
    end
    error("missing aura animation " .. label)
end
ChooseAuraAnimation("Cooldown sweep")
tick()
local sweep = view[1].cooldown
assert(cfg.auraTimerAnimation == "sweep" and sweep:IsShown() and sweep.start == 72 and sweep.length == 30)
assert(sweep.frameLevel < view[1].time.parent.frameLevel and not view[3].cooldown)
ChooseAuraAnimation("Expiry pulse")
now = 100.5
tick()
assert(not sweep:IsShown() and view[1].time:GetAlpha() == 0.5 and view[2].time:GetAlpha() == 1)
ChooseAuraAnimation("Sweep and pulse")
tick()
assert(view[1].cooldown == sweep and sweep:IsShown() and view[1].time:GetAlpha() == 0.5)
ChooseAuraAnimation("No animation")
tick()
assert(not sweep:IsShown() and view[1].time:GetAlpha() == 1)
now = 100

local base, glow = view.chrome.rim, view.threatGlow
local steelTint = base.vertex
assert(base.layer == "BORDER" and base:GetTexture():match("PlateFrame$") and steelTint[2] == 0.84)
assert(view.chrome.outline:GetTexture():match("PlateMask$") and view.chrome.outline.vertex[1] == 0)
assert(view.chrome.halo:IsShown() and view.chrome.halo:GetTexture():match("PlateGlow$"))
assert(levelBox.art.rim:GetTexture():match("PlateBoxes30300$") and levelBox.art.rim.uv[1] == 2 / 256)
assert(view.health.regions[1].solid[1] == 0.08)
assert(glow.layer == "BACKGROUND" and glow.blend == "ADD" and not glow:IsShown() and a.regions[1].alpha == 0)
assert(a.regions[1]:GetTexture() == nil)
assert(glow.sublevel < view.chrome.fill.sublevel and glow.parent.frameLevel < base.parent.frameLevel)
local function assertThreatAnchor(overlay)
    local threat, rim = overlay.threatGlow, overlay.chrome.rim
    local point = threat.points[1]
    assert(point[1] == "CENTER" and point[2] == rim and point[3] == "CENTER")
    assert(threat.width == overlay.chrome.halo.width and threat.height == overlay.chrome.halo.height)
end
assertThreatAnchor(view)

inCombat = true
a.regions[1]:SetVertexColor(1, 1, 0.47)
a.regions[1]:Show()
units.target.threat = 0
tick()
assert(not glow:IsShown())
for status = 1, 3 do
    units.target.threat = status
    tick()
    assert(glow:IsShown() and glow.vertex[2] == (status == 1 and 0.8 or 0.1))
    assert(base.vertex == steelTint)
end
units.target.threat = 0
tick()
assert(not glow:IsShown())
units.target.threat = 3
tick()

local native = b.regions[1]
b.depth = 75
b:SetAlpha(0.95)
native:Show()
native:SetAlpha(1)
native:SetVertexColor(1, 1, 0.47)
assert(native:GetTexture() == nil)
tick()
assert(native:IsShown() and native:GetAlpha() == 0)
assert(second.threatGlow:IsShown() and second.threatGlow.vertex[2] == 0.8)
assert(second.scale > 0.8 and second.scale < 1)
for _ = 1, 25 do tick() end
assert(math.abs(second.scale - 0.8) < 0.0001 and math.abs(second:GetEffectiveAlpha() - 0.65) < 0.0001)
assertChromePixels(768 / 1080, second)
assertThreatAnchor(second)
native:SetVertexColor(1, 0.6, 0)
tick()
assert(second.threatGlow:IsShown() and second.threatGlow.vertex[2] == 0.1)
local beforeBlink = now
native:Hide()
now = beforeBlink + 0.05
tick()
assert(second.threatGlow:IsShown())
native:Show()
tick()
native:SetVertexColor(1, 1, 1)
tick()
assert(second.threatGlow:IsShown())
now = beforeBlink + 0.25
tick()
assert(not second.threatGlow:IsShown())
now = beforeBlink
inCombat = false
tick()
assert(not glow:IsShown() and base.vertex == steelTint)
a.regions[1]:Hide()

now = 102
a.children[1]:SetMinMaxValues(0, 80)
a.children[1]:SetValue(14)
a.children[1]:SetStatusBarColor(0.25, 0.75, 0.9)
units.player.level = 26
tick()
assert(view[1].icon.texture == "curse" and view[1].time.text == "28" and view[2].icon.texture == "ward")
assert(view.health.high == 80 and view.health.value == 14 and view.health.color[3] == 0.9)
assert(levelBox.text.color[1] == 23 / 26)
units.target.debuffs[2][2] = 2
driver.scripts.OnEvent(driver, "UNIT_AURA", "target")
tick()
assert(view[1].count.text == "2")

ChooseAuraAnimation("Sweep and pulse")
tick()
assert(view[1].cooldown:IsShown())
b:SetAlpha(1)
tick()
assert(not view[1]:IsShown() and not second[1]:IsShown())
assert(not view[1].cooldown:IsShown() and view[1].cooldown.length == 0 and view[1].time:GetAlpha() == 1)
ChooseAuraAnimation("No animation")
units.mouseover = { guid = "B", name = longName, level = 23, kind = "rare", buffs = { { "other", 1, 0 } } }
b.regions[6]:Show()
tick()
assert(second[1].icon.texture == "other" and second[1]:IsShown() and second.dragon:IsShown())
units.mouseover.buffs[1][2] = 4
now = now + 0.25
tick()
assert(second[1].count.text == "4")

local allocated = created
inCombat = true
native:SetVertexColor(1, 0, 0)
tick()
assert(second.threatGlow:IsShown())
b:Hide()
assert(not second:IsShown() and not second[1]:IsShown() and not second.threatGlow:IsShown())
native:Hide()
b.regions[6]:Hide()
b.regions[7]:SetText("Recycled")
b.regions[7]:SetAlpha(1)
b.regions[7]:Show()
b.regions[9]:Show()
units.target, units.mouseover = nil, nil
b:Show()
assert(not b.regions[7]:IsShown() and b.regions[7]:GetAlpha() == 0)
tick()
assert(second.name.text == "Recycled" and second.boxes["wfn-level"].text.text == "??" and second.dragon:IsShown())
assert(b.children[3] == second and created == allocated and not second[1]:IsShown() and not second.threatGlow:IsShown())

local neutral, friend, pet, totem = plate("Neutral beast"), plate("Friendly NPC"), plate("Wolf"), plate("Searing Totem")
neutral.children[1]:SetStatusBarColor(1, 1, 0)
friend.children[1]:SetStatusBarColor(0, 1, 0)
for _, frame in ipairs({neutral, friend, pet, totem}) do frame.children[1]:SetValue(100) end
function NozdorActionNative(command, frame)
    assert(command == "plateguid")
    if frame == pet then return "0xF140000001000001" end
    return ""
end
instance = "party"
tick()
local neutralView, petView, totemView = neutral.children[3], pet.children[3], totem.children[3]
assert(neutralView:IsShown() and neutralView.name:IsShown() and not neutralView.health:IsShown())
assert(neutral.regions[10]:GetAlpha() == 0)
assert(not friend.children[3]:IsShown() and not petView:IsShown())
assert(pet.regions[5]:GetAlpha() == 0)
assert(totemView:IsShown() and not totemView.health:IsShown())
neutral.children[1]:SetValue(99)
cfg.hideTotems = true
units.target = { guid = "0xF140000001000001", name = "Wolf", level = 20, controlled = true }
tick()
assert(neutralView.health:IsShown() and not totemView:IsShown())
assert(neutral.regions[10]:GetAlpha() == 0 and neutralView.raid:IsShown())
assert(petView:IsShown() and petView.health:IsShown() and petView:GetFrameStrata() == "MEDIUM")
assert(pet.regions[5]:GetAlpha() == 1)
units.target = nil
neutral.children[1]:SetValue(100)
cfg.hideFullHealthOutOfCombat = true
tick()
assert(not neutralView:IsShown() and not petView:IsShown())
neutral.children[2]:Show()
tick()
assert(neutralView:IsShown() and neutralView.health:IsShown() and neutralView.cast:IsShown())

local requestedBox = { icon = "test-icon", start = now, length = 30 }
assert(not API:RegisterBox("invalid", {}))
assert(API:RegisterBox("test-box", {
    owner = "Test", side = "above", places = { dungeon = true, arena = false },
    update = function(box, _, plateFrame)
        assert(box.cooldown and API:GetPlateInfo(plateFrame))
        return requestedBox
    end,
}))
local offered, active = API:BoxPlaces("test-box")
assert(#offered == 2 and active.dungeon and active.arena == false and active.world == nil)
assert(not API:SetBoxPlace("test-box", "world", true))
assert(API:SetBoxOffset("test-box", 4, -2))
local dx, dy = API:BoxOffset("test-box")
assert(dx == 4 and dy == -2)
tick()
local box = neutralView.boxes["test-box"]
assert(box:IsShown() and not box.mouse and box.icon:GetTexture() == "test-icon" and box.cooldown.length == 30)
assert(API:SetBoxPlace("test-box", "dungeon", false))
tick()
assert(not box:IsShown())

SlashCmdList.WOWFOREVERNAMEPLATES("")
assert(openedCategory == mainOptions and mainOptions:IsShown())
SlashCmdList.WOWFOREVERNAMEPLATES("preview enemy")
tick()
assert(API:IsPreviewing() and API:GetPlateInfo(neutral).previewing and box:IsShown() and box.mouse)
box.scripts.OnDragStart(box)
cursorX, cursorY = 3 * box:GetEffectiveScale(), -box:GetEffectiveScale()
box.scripts.OnUpdate(box)
dx, dy = API:BoxOffset("test-box")
assert(dx == 7 and dy == -3)
box.scripts.OnDragStop(box)
API:ResetBoxOffsets()
assert(API:BoxOffset("test-box") == 0)
SlashCmdList.WOWFOREVERNAMEPLATES("preview enemy")
assert(not box.mouse)
tick()
assert(not API:IsPreviewing() and not box:IsShown())
assert(API:SetBoxEnabled("test-box", false) and not API:IsBoxEnabled("test-box"))
assert(API:UnregisterBox("test-box") and not API:UnregisterBox("test-box"))

units.target = { guid = "A", name = longName, level = 23, cast = {
    name = "Test spell", icon = "spell-icon", start = 101000, finish = 104000, shield = true,
} }
cfg.namePlace = "undercast"
local search = WoWForeverNameplatesMediaSearch
local browser = search.parent
local function FindRow(label)
    for _, child in ipairs(browser.children) do
        if child.entry and child.entry.label == label and child:IsShown() then return child end
    end
end
local function ClickMediaButton(label)
    for _, child in ipairs(browser.children) do
        if child.text == label or child.text == "[x] " .. label then
            child.scripts.OnClick(child)
            return
        end
    end
    error("missing media control " .. label)
end
local function ChooseRow(label)
    local row = assert(FindRow(label), label)
    row.scripts.OnClick(row)
    return row
end
search:SetText("ТЕСТОВАЯ")
assert(not FindRow("Test Font") and FindRow("Тестовая гарнитура").sample.font[1] == "cyrillic-font.ttf")
search:SetText("")
ClickMediaButton(">")
assert(FindRow("Example font 6").sample.font[1] == "example-font-6.ttf" and not FindRow("Test Font"))
ClickMediaButton("<")
local chosenFont = ChooseRow("Test Font")
assert(chosenFont.sample.font[1] == "test-font.ttf" and chosenFont.background.solid[1] == 0.17)
ClickMediaButton("Cast font")
ChooseRow("Test Font")
ClickMediaButton("Health texture")
assert(ChooseRow("Test Stripes").swatch:GetTexture() == "test-stripes.tga")
ui.wfn.Changed()
tick()
assert(view.cast:IsShown() and view.cast.BorderShield:IsShown() and view.cast.text.text == "Test spell")
assert(view.cast.status:GetTexture():match("CastBar%-Fill$") and view.cast.status.high == 3)
assert(view.cast.iconArt.rim.uv[1] == 134 / 256 and view.cast.status.color[1] == cfg.castColourShut[1])
assert(view.name.points[1][1] == "TOPLEFT")
assert(view.name.font[1] == "test-font.ttf" and view.cast.text.font[1] == "test-font.ttf")
assert(view.health:GetTexture() == "test-stripes.tga" and view.health.color[3] == 0.9)
ClickMediaButton("Cast texture")
assert(ChooseRow("Test Gloss").swatch:GetTexture() == "test-gloss.tga")
tick()
assert(view.cast.status:GetTexture() == "test-gloss.tga" and view.cast.status.color[1] == cfg.castColourShut[1])
units.target.cast.shield = false
tick()
assert(not view.cast.BorderShield:IsShown() and view.cast.status.color[1] == cfg.castColourOpen[1])
spellCooldown = 5
tick()
assert(view.cast.status.color[1] == cfg.castColourBusy[1])
cfg.cast = false
a.children[2]:Show()
tick()
assert(not view.cast:IsShown() and a.children[2]:GetAlpha() == 1)

SlashCmdList.WOWFOREVERNAMEPLATES("perf")
assert(ui.wfn.profile)
now = now + 1.1
tick()
SlashCmdList.WOWFOREVERNAMEPLATES("perf dump")
SlashCmdList.WOWFOREVERNAMEPLATES("perf")
assert(not ui.wfn.profile)

-- With the ForeverUI options core present the module registers a declarative schema instead of a page.
local schema
ui.RegisterOptions = function(id, spec) schema = { id = id, spec = spec } end
ui.wfn.CreateOptions(function() end, cfg)
assert(schema and schema.id == "nameplates" and schema.spec.db() == cfg)
local keys, customs = {}, 0
for _, section in ipairs(schema.spec.sections) do
    for _, opt in ipairs(section.options) do
        if opt[2] and opt[1] ~= "custom" then keys[opt[2]] = opt end
        if opt[1] == "custom" then
            customs = customs + 1
            assert(opt.build(CreateFrame("Frame")) > 0)
        end
    end
end
assert(customs == 2 and keys.plateOffsetY.default == cfg.plateOffsetY and keys.auraTimerAnimation.values[2][1] == "sweep")
assert(keys.castColourOpen[1] == "color" and keys.nameOutline.values[1][1] == "soft" and keys.targetGlow.default == true)
ui.RegisterOptions = nil

conflict, driver = true, nil
assert(loadfile("ForeverUI_Nameplates.lua"))("ForeverUI", ui)
driver.scripts.OnEvent(driver, "PLAYER_LOGIN")
assert(driver.scripts.OnUpdate == nil)
print("Nameplates OK: embedded options, media previews and live selection, CVars, boxes, cast, filters, threat, auras, recycling")
