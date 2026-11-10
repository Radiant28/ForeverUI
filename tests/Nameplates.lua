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
    frame.name = name
    if template == "GameTooltipTemplate" then
        for i = 1, 2 do _G[name .. "TextLeft" .. i] = object("FontString", frame) end
    end
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
function methods:GetLeft() return self.rect and self.rect[1] end
function methods:GetRight() return self.rect and self.rect[2] end
function methods:GetBottom() return self.rect and self.rect[4] end
function methods:SetHitRectInsets(...) self.hitInsets = { ... } end
-- Hidden scanning tooltip: links resolve through `tooltipLines`, units through `tooltipUnits`.
local tooltipLines, tooltipUnits = {}, {}
local function fillTooltip(self, lines)
    self.lines = lines or {}
    for i = 1, 2 do
        local line = _G[self.name .. "TextLeft" .. i]
        if line then line:SetText(self.lines[i]) end
    end
end
function methods:SetOwner() end
function methods:ClearLines() fillTooltip(self, {}) end
function methods:NumLines() return #(self.lines or {}) end
function methods:SetHyperlink(link) fillTooltip(self, tooltipLines[link]) end
function methods:SetUnit(unit) fillTooltip(self, tooltipUnits[unit]) end
function methods:SetClampRectInsets(...) self.clampInsets = { ... } end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:IsClampedToScreen() return self.clamped end
function methods:GetPoint(index)
    local anchor = self.points and self.points[index or 1]
    if anchor then return unpack(anchor) end
end
function methods:GetTop()
    if self.rect then return self.rect[3] end
    return self.centerY and self.centerY + self:GetHeight() / 2 end
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
    debuffs = { { "poison", 3, 102, "player" }, { "curse", 1, 130 } }, buffs = { { "ward", 1, 0 } } } }
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
function UnitExists(unit) return units[unit] ~= nil end
function UnitClass(unit) local class = units[unit] and units[unit].class return class, class end
function GetNumRaidMembers() return 0 end
function UnitIsUnit(a, b) return a == b end
function UnitInParty() end
function UnitInRaid() end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetNumPartyMembers() return 0 end
RAID_CLASS_COLORS = { MAGE = { r = 0.41, g = 0.8, b = 0.94 } }
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
    if entry then return entry[1], nil, entry[1], entry[2], nil, 30, entry[3], entry[4] end
end
function UnitDebuff(unit, index) return aura(unit, "debuffs", index) end
function UnitBuff(unit, index) return aura(unit, "buffs", index) end

WorldFrame = CreateFrame("Frame")
WorldFrame:SetSize(1600, 900)
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
-- The layout checks below use the native anchoring; the clickbox mode is tested on its own further down.
ForeverUI_NameplatesDB.clickFollowsPlate = false
ForeverUI_NameplatesDB.combatOnlyEngaged = false
assert(not WoWForeverNameplatesOptionsScroll)
SlashCmdList.WOWFOREVERNAMEPLATES("")
assert(openedCategory == mainOptions and WoWForeverNameplatesOptionsScroll.parent == mainOptions)
assert(not WoWForeverNameplatesOptions)
-- Forever stacking is on by default, so the native spreading stays off and plates move only once.
assert(cvars.nameplateAllowOverlap == "1" and cvars.nameplateDistance == "41" and options.verticalSpacing.disabled)
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
    assert(math.abs(anchor[5] - cfg.plateOffsetY * ratio - (overlay.stackOffset or 0)) <= pixel / 2 + 0.000001)
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
-- The WoW: Forever radial fill is the default: elapsed 28 of 30 s shows both halves and the edge ray.
local radial = view[1].radial
assert(cfg.auraTimerAnimation == "forever" and not view[1].cooldown and radial:IsShown())
assert(radial.left:IsShown() and radial.right:IsShown() and radial.edge.uv and #radial.edge.uv == 8)
assert(radial.right.points[1][3] == "TOP" and radial.left.points[2][3] == "BOTTOM" and radial.edge.allPoints == radial)
for _, uv in ipairs({ radial.right.uv, radial.left.uv, radial.edge.uv }) do
    for i = 1, 8 do assert(uv[i] >= -0.000001 and uv[i] <= 1.000001, "sampling stays inside the texture") end
end
assert(view[1].time.frameLevel == nil or view[1].time.parent.frameLevel > radial.frameLevel)
assert(not view[3].radial, "auras without a duration get no fill")
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
assert(not radial:IsShown())
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
assert(not sweep:IsShown() and view[1].time:GetAlpha() == 1 and not radial:IsShown())
now = 100

-- Timer font settings.
cfg.auraTimerSize, cfg.auraTimerOutline, cfg.auraTimerFont, cfg.auraTimerColour = 13, "thick", "Test Font", { 1, 0.5, 0 }
ui.wfn.Changed()
tick()
assert(view[1].time.font[1] == "test-font.ttf" and view[1].time.font[2] == 13 and view[1].time.font[3] == "THICKOUTLINE")
assert(view[1].time.color[2] == 0.5 and view[1].count.font[3] == "THICKOUTLINE")
cfg.auraTimerSize, cfg.auraTimerOutline, cfg.auraTimerFont, cfg.auraTimerColour = 0, "thin", "", { 1, 1, 1 }
ui.wfn.Changed()

-- The timer text can be switched off; the next tick restores it.
cfg.auraTimerText = false
ui.wfn.Changed()
tick()
assert(view[1].time.text == "" and view[2].time.text == "")
cfg.auraTimerText = true
ui.wfn.Changed()
tick()
assert(view[1].time.text == "2")

-- Aura filters: poison is mine, curse has no visible caster, ward is a buff.
local function shownAuras()
    driver.scripts.OnEvent(driver, "UNIT_AURA", "target")
    tick()
    local list = {}
    for i = 1, 4 do if view[i]:IsShown() then list[#list + 1] = view[i].icon.texture end end
    return table.concat(list, ",")
end
assert(shownAuras() == "poison,curse,ward")
cfg.auraOthers = false
assert(shownAuras() == "poison,ward", "only my debuffs")
cfg.auraOthers, cfg.auraMine = true, false
assert(shownAuras() == "curse,ward", "only other debuffs")
cfg.auraOthersClass = true
local knows = GetSpellInfo
GetSpellInfo = function() return nil end
assert(shownAuras() == "ward", "other casters outside my class are hidden")
GetSpellInfo = knows
assert(shownAuras() == "curse,ward", "a debuff I can cast counts as my class")
cfg.auraMine, cfg.auraOthersClass, cfg.auraBuffs = true, false, false
assert(shownAuras() == "poison,curse", "buffs hidden")
cfg.auraDebuffs, cfg.auraBuffs = false, true
assert(shownAuras() == "ward", "debuffs hidden")
cfg.auraBuffs = false
assert(shownAuras() == "", "everything hidden")
cfg.auraDebuffs, cfg.auraBuffs = true, true
assert(shownAuras() == "poison,curse,ward")

-- Friendly players: class colours and the name-only mode.
local target = units.target
target.player, target.friendly, target.class = true, true, "MAGE"
tick()
assert(view.health:IsShown() and view.health.color[1] == 0.41, "friendly class colour")
cfg.friendlyNameOnly = true
tick()
assert(not view.health:IsShown() and view.name:IsShown() and view.name.color[1] == 0.41, "name only in class colour")
cfg.classColourFriend = false
tick()
assert(view.name.color[1] == 1, "plain name without class colours")
cfg.friendlyNameOnly, cfg.classColourFriend = false, true
target.player, target.friendly, target.class = nil, nil, nil
tick()
assert(view.health:IsShown() and view.health.color[1] == 0.82, "enemy NPC keeps the native colour")

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

-- Two plates at the same spot form a column: the first stays, the second rises by one plate footprint.
for _ = 1, 40 do tick() end
assert(cfg.stackForever and (view.stackOffset or 0) == 0, "lowest plate stays " .. tostring(view.stackOffset))
local lift = second.stackOffset
assert(lift and lift > 0 and math.abs(second.stackY - view.stackY - view.stackHeight) < 0.001, "second plate stacked")
assert(math.abs(second.points[1][5] - (cfg.plateOffsetY * second.nativeHealth:GetEffectiveScale()
    / second:GetEffectiveScale() + lift)) <= 1, "stack offset reaches the anchor")
cfg.stackForever = false
cfg.stacking = true
options.stacking.apply()
tick()
assert(second.stackOffset == nil and cvars.nameplateAllowOverlap == "0", "native stacking takes over without our offsets")
cfg.stackForever = true
options.stacking.apply()
assert(cvars.nameplateAllowOverlap == "1")

-- Clickbox mode (after RefinedBlizzPlates): the native frame is resized to the drawn plate, the drawn
-- plate sits on its bottom, and offsets lift the real frame through clamp insets.
local plateWidth0, plateHeight0 = a:GetWidth(), a:GetHeight()
WorldFrame.rect = { 0, 1600, 900, 0 }
a.points = { { "BOTTOM", WorldFrame, "BOTTOMLEFT", 505, 300 } }
cfg.clickFollowsPlate = true
ui.wfn.Changed()
tick()
local clickWidth = math.max(cfg.widthEnemy, cfg.widthFriend)
local clickHeight = math.max(cfg.heightEnemy, cfg.heightFriend) + cfg.nameLift + math.max(cfg.nameSizeEnemy, cfg.nameSizeFriend) + 4
assert(a.width == clickWidth and a.height == clickHeight, "plate frame sized to the drawn plate")
assert(view.points[1][1] == "BOTTOM" and view.points[1][2] == a and view.points[1][3] == "BOTTOM", "drawn plate on the frame")
assert(a.clamped == true and a.clampInsets, "frame clamped")
local insets = a.clampInsets
local left = 505 - clickWidth / 2
local lift = cfg.plateOffsetY + (view.stackRaise or 0)
assert(insets[2] == 1600 - (left + clickWidth + cfg.plateOffsetX), "negative X offset pushes from the right")
assert(insets[4] == -(300 + lift), "Y offset lifts the frame from the bottom")
assert(insets[1] == 10000 and insets[3] == -10000)
-- The column lifts the real frame of the second plate, not just its picture.
b.points = { { "BOTTOM", WorldFrame, "BOTTOMLEFT", 505, 300 } }
for _ = 1, 40 do tick() end
assert(second.stackRaise and second.stackRaise > 0 and second.stackOffset == nil)
assert(math.abs(b.clampInsets[4] + 300 + cfg.plateOffsetY + second.stackRaise / b:GetEffectiveScale()) < 0.001)
-- In combat the frames are protected: nothing is resized until combat ends.
locked = true
cfg.nameLift = cfg.nameLift + 2
ui.wfn.Changed()
tick()
assert(a.height == clickHeight, "no resize in combat")
locked = false
driver.scripts.OnEvent(driver, "PLAYER_REGEN_ENABLED")
assert(a.height == clickHeight + 2, "resized after combat")
cfg.nameLift = cfg.nameLift - 2
cfg.clickFollowsPlate = false
ui.wfn.Changed()
tick()
assert(a.width == plateWidth0 and a.height == plateHeight0 and a.clampInsets[4] == 0, "native frame restored")
assert(view.points[1][2] == view.nativeHealth and view.points[1][3] == "TOP")
a.points, b.points, WorldFrame.rect = nil, nil, nil

-- Screen-edge fade: the second plate sits 73% of half the screen height from the centre.
WorldFrame.centerX, WorldFrame.centerY = 800, 450
cfg.edgeFadeInner, cfg.edgeFadeOuter = 60, 70
for _ = 1, 30 do tick() end
assert(second:GetEffectiveAlpha() < 0.001, "plate beyond the vanishing radius is hidden")
assert(view:GetEffectiveAlpha() == 1, "the target never fades")
cfg.edgeFadeOuter = 200
for _ = 1, 30 do tick() end
assert(second:GetEffectiveAlpha() > 0.3, "inside the gradient the plate shows again")
cfg.edgeFadeInner, cfg.edgeFadeOuter = 60, 120
WorldFrame.centerX, WorldFrame.centerY = nil, nil

-- A friendly player is class coloured without being targeted: the Nozdor client reports its class.
local ally = plate("Ally")
ally.children[1]:SetStatusBarColor(0, 0, 1)
ally.children[1]:SetValue(100)
local nativeQuery = NozdorActionNative
function NozdorActionNative(command, frame)
    if command == "plateguid" then return frame == ally and "0x0000000000000042" or "" end
    if command == "unitinfo" then return frame == "0x0000000000000042" and 8 or nil end
end
instance = "none"
tick()
local allyView = ally.children[3]
assert(allyView:IsShown() and allyView.health.color[1] == 0.41 and allyView.health.color[3] == 0.94, "ally in mage colour")
NozdorActionNative = nativeQuery

-- A blue bar is a friendly player even when the plate GUID does not look like a player's.
local stranger = plate("Stranger")
stranger.children[1]:SetStatusBarColor(0, 0, 1)
stranger.children[1]:SetValue(100)
function NozdorActionNative(command, frame)
    if command == "plateguid" then return frame == stranger and "F13000ABCDEF" or "" end
    if command == "unitinfo" then return frame == "F13000ABCDEF" and 8 or nil end
end
tick()
local strangerView = stranger.children[3]
assert(strangerView.kind == "player" and strangerView.health.color[1] == 0.41, "class colour without a player-shaped GUID")

-- Without any native client help, classes are learnt from the combat log and chat, and saved.
NozdorActionNative = nil
local passer = plate("Passer")
passer.children[1]:SetStatusBarColor(0, 0, 1)
passer.children[1]:SetValue(100)
tick()
local passerView = passer.children[3]
assert(passerView.health.color[3] == 1, "unknown ally stays blue")
function GetPlayerInfoByGUID(guid)
    if guid == "0x0000000000000099" then return "Маг", "MAGE" end
    if guid == "0x0000000000000100" then return "Воин", "WARRIOR" end
end
RAID_CLASS_COLORS.WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }
driver.scripts.OnEvent(driver, "COMBAT_LOG_EVENT_UNFILTERED", 0, "SPELL_HEAL", "0x0000000000000099", "Passer", 0x511,
    "0x0000000000000099", "Passer", 0x511)
tick()
assert(passerView.health.color[1] == 0.41, "class learnt from the combat log")
driver.scripts.OnEvent(driver, "CHAT_MSG_SAY", "hi", "Talker-Realm", "", "", "", "", 0, 0, "", 0, 1, "0x0000000000000100")
assert(cfg.classCache.Passer == "MAGE" and cfg.classCache.Talker == "WARRIOR", "classes saved by name")
NozdorActionNative = nativeQuery

-- The stock cast bar has no spell text: the name comes from the combat log, matched by the icon.
local castWas = cfg.cast
cfg.cast = true
local caster = plate("Caster")
caster.children[2].regions[1]:SetText("")
caster.children[2]:Show()
local spellInfo = GetSpellInfo
function GetSpellInfo(id) if id == 133 then return "Огненный шар", nil, "Cast-Icon" end return spellInfo(id) end
driver.scripts.OnEvent(driver, "COMBAT_LOG_EVENT_UNFILTERED", 0, "SPELL_CAST_START", "0xF130000000000123", "Caster", 0xa48,
    "", nil, 0, 133, "Огненный шар", 4)
tick()
local casterView = caster.children[3]
assert(casterView.cast:IsShown() and casterView.cast.text.text == "Огненный шар", tostring(casterView.cast.text.text))
GetSpellInfo = spellInfo
cfg.cast = castWas

-- In combat only the units fighting me or my group stay.
cfg.combatOnlyEngaged = true
inCombat = true
tick()
assert(not casterView:IsShown(), "a unit nobody fights is hidden in combat")
driver.scripts.OnEvent(driver, "COMBAT_LOG_EVENT_UNFILTERED", 0, "SWING_DAMAGE", "0x0000000000000001", "Me", 0x511,
    "0xF130000000000123", "Caster", 0xa48)
tick()
assert(casterView:IsShown(), "a unit I hit stays")
cfg.combatKeepFriends = true
inCombat = false
driver.scripts.OnEvent(driver, "PLAYER_REGEN_ENABLED")
inCombat = true
tick()
assert(not casterView:IsShown(), "combat memory cleared when combat ends")
inCombat = false
tick()
assert(casterView:IsShown())
cfg.combatOnlyEngaged, cfg.combatKeepFriends = false, false
caster:Hide()
tick()

-- Friendly NPCs show the name only; their title is learnt from a world mouseover and saved by name.
NozdorActionNative = nil
local hideFull = cfg.hideFullHealthOutOfCombat
cfg.hideFullHealthOutOfCombat = false
local banker = plate("Казначей")
banker.children[1]:SetStatusBarColor(0, 1, 0)
banker.children[1]:SetValue(100)
tick()
local bankerView = banker.children[3]
assert(bankerView:IsShown() and not bankerView.health:IsShown(), "friendly NPC shows the name only")
assert(not bankerView.subtitle:IsShown(), "no title before the NPC was ever seen")
units.mouseover = { name = "Казначей", level = 80, friendly = true }
tooltipUnits.mouseover = { "Казначей", "Хранилище аккаунта" }
tick()
units.mouseover = nil
tick()
assert(bankerView.subtitle:IsShown() and bankerView.subtitle.text == "<Хранилище аккаунта>", tostring(bankerView.subtitle.text))
assert(cfg.npcTitleCache["Казначей"] == "<Хранилище аккаунта>", "title saved by name")
cfg.friendlyNPCNameOnly = false
tick()
assert(bankerView.health:IsShown())
cfg.friendlyNPCNameOnly, cfg.hideFullHealthOutOfCombat = true, hideFull
banker:Hide()
tick()
NozdorActionNative = nativeQuery

-- A player's guild is learnt from a world mouseover (no plate hover, no target) and saved by name.
NozdorActionNative = nil
local guildie = plate("Ямамба")
guildie.children[1]:SetStatusBarColor(0, 0, 1)
guildie.children[1]:SetValue(100)
tick()
local guildieView = guildie.children[3]
assert(guildieView:IsShown() and not guildieView.subtitle:IsShown(), "no guild before the player was ever seen")
local guildInfo = GetGuildInfo
function GetGuildInfo(unit) if unit == "mouseover" then return "Банки на опыт всем" end return guildInfo(unit) end
units.mouseover = { name = "Ямамба", level = 80, player = true, friendly = true, class = "MAGE" }
tick()
units.mouseover = nil
GetGuildInfo = guildInfo
tick()
assert(guildieView.subtitle:IsShown() and guildieView.subtitle.text == "<Банки на опыт всем>", tostring(guildieView.subtitle.text))
assert(cfg.guildCache["Ямамба"] == "<Банки на опыт всем>", "guild saved by name")
guildie:Hide()
tick()
NozdorActionNative = nativeQuery

-- A crowd of namesakes: one column without overlaps, and quiet plates refresh at the slower rate.
local snakes = {}
for i = 1, 20 do
    snakes[i] = plate("Змея")
    snakes[i].children[1]:SetValue(50)
end
for _ = 1, 3 do tick() end
local column = {}
for i = 1, 20 do
    local v = snakes[i].children[3]
    assert(v:IsShown() and v.stackY, "snake " .. i .. " stacked")
    column[#column + 1] = v
end
table.sort(column, function(x, y) return x.stackY < y.stackY end)
for i = 2, #column do
    assert(column[i].stackY >= column[i - 1].stackY + column[i - 1].stackHeight - 0.001, "column has no overlaps")
end
local quietView = snakes[1].children[3]
snakes[1].children[1]:SetValue(20)
tick()
assert(quietView.health.value == 50, "a quiet plate in a crowd waits for its slower refresh")
now = now + 0.3
tick()
assert(quietView.health.value == 20, "and refreshes after it")
cfg.crowdSaver = false
snakes[1].children[1]:SetValue(30)
tick()
assert(quietView.health.value == 30, "without the saver every scan refreshes")
cfg.crowdSaver = true
for i = 1, 20 do snakes[i]:Hide() end
tick()

-- Name text colour (players fall back to it when class colours are not used for names).
cfg.nameTextColour = { 1, 0.8, 0.2 }
ui.wfn.Changed()
tick()
assert(strangerView.name.color[2] == 0.8 and strangerView.name.color[3] == 0.2, "custom name colour")
cfg.nameTextColour = { 1, 1, 1 }
ui.wfn.Changed()
tick()

-- Name letter limit (0 keeps the whole name).
cfg.nameMaxLetters = 3
ui.wfn.Changed()
tick()
assert(strangerView.name.text:sub(1, 3) == "Str" and strangerView.name.text:sub(-3) == "...", strangerView.name.text)
cfg.nameMaxLetters = 0
ui.wfn.Changed()
tick()
assert(not strangerView.name.text:find("...", 1, true))

-- NPC titles read from the creature cache by GUID; a guild for a targeted player.
local merchant = plate("Brom")
merchant.children[1]:SetStatusBarColor(0, 1, 0)
merchant.children[1]:SetValue(90)
tooltipLines["unit:0xF130000000000077"] = { "Brom", "Торговец оружием" }
function NozdorActionNative(command, frame)
    if command == "plateguid" then return frame == merchant and "0xF130000000000077" or "" end
end
tick()
local merchantView = merchant.children[3]
assert(merchantView.subtitle:IsShown() and merchantView.subtitle.text == "<Торговец оружием>", tostring(merchantView.subtitle.text))
cfg.npcTitles = false
tick()
assert(not merchantView.subtitle:IsShown())
cfg.npcTitles = true
function GetGuildInfo(unit) if unit == "target" then return "Гильдия Тестов" end end
units.target.player, units.target.friendly, units.target.class = true, true, "MAGE"
tick()
assert(view.subtitle:IsShown() and view.subtitle.text == "<Гильдия Тестов>", tostring(view.subtitle.text))
units.target.player, units.target.friendly, units.target.class = nil, nil, nil
NozdorActionNative = nativeQuery

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
assert(customs == 2 and keys.plateOffsetY.default == cfg.plateOffsetY and keys.auraTimerAnimation.values[2][1] == "forever")
for _, key in ipairs({ "auraDebuffs", "auraBuffs", "auraMine", "auraOthers", "auraOthersClass", "auraTimerText", "auraTimerFont",
    "auraTimerSize", "auraTimerOutline", "auraTimerColour", "classColourEnemy", "classColourFriend", "friendlyNameOnly", "friendlyNPCNameOnly", "crowdSaver", "crowdThreshold", "edgeFade", "edgeFadeInner", "edgeFadeOuter", "npcTitles", "playerGuilds", "subtitleSize",
    "nameMaxLetters", "nameTextColour" }) do
    assert(keys[key], "schema option " .. key)
end
assert(keys.clickFollowsPlate == nil and keys.verticalSpacing.default == 0.9 and cfg.spacingDefault090)
assert(#keys.auraTimerFont.values() >= 3 and keys.auraOthersClass.depends(function() return true end))
assert(keys.castColourOpen[1] == "color" and keys.nameOutline.values[1][1] == "soft" and keys.targetGlow.default == true)
ui.RegisterOptions = nil

conflict, driver = true, nil
assert(loadfile("ForeverUI_Nameplates.lua"))("ForeverUI", ui)
driver.scripts.OnEvent(driver, "PLAYER_LOGIN")
assert(driver.scripts.OnUpdate == nil)
print("Nameplates OK: embedded options, media previews and live selection, CVars, boxes, cast, filters, threat, auras, recycling")
