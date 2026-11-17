-- Main action bar art (StockPanels.lua) on mocks: the stock strip MainMenuBarTexture0..3 keeps the Blizzard
-- texture, coordinates and colour; the winged slot backdrops sit only under ActionButton1..12, follow the
-- Edit Mode cell count and stay off the XP bar and inside MainMenuBar. Run from the addon root (see INDEX.md).
local noop = function() end
local P = {}
P.__index = function(_, k)
    if P[k] then return P[k] end
    if type(k) == "string" and k:match("^%u") then return noop end
end
local function new(name, parent, kind)
    local o = setmetatable({ name = name, parent = parent, kind = kind or "Frame", points = {}, shown = true,
        alpha = 1, color = { 1, 1, 1, 1 }, coords = { 0, 0, 0, 1, 1, 0, 1, 1 }, regions = {}, w = 10, h = 10 }, P)
    if name then _G[name] = o end
    return o
end
function P:SetPoint(...) self.points[#self.points + 1] = { ... } end
function P:ClearAllPoints() self.points = {} end
function P:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p, 1, 5) end end
function P:GetNumPoints() return #self.points end
function P:SetAllPoints(r) self.points = { { "TOPLEFT", r, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0 } } end
function P:SetSize(w, h) self.w, self.h = w, h end
function P:SetHeight(h) self.h = h end
function P:GetWidth() return self.w end
function P:GetHeight() return self.h end
function P:Show() self.shown = true end
function P:Hide() self.shown = false end
function P:IsShown() return self.shown end
function P:SetAlpha(a) self.alpha = a end
function P:GetAlpha() return self.alpha end
function P:SetTexture(t) self.texture = t end
function P:GetTexture() return self.texture end
function P:SetTexCoord(...)
    local n = select("#", ...)
    if n == 4 then
        local l, r, t, b = ...
        self.coords = { l, t, l, b, r, t, r, b }
    else
        self.coords = { ... }
    end
end
function P:GetTexCoord() return unpack(self.coords, 1, 8) end
function P:SetVertexColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
function P:SetDrawLayer(layer, sub) self.layer, self.sublevel = layer, sub end
function P:GetDrawLayer() return self.layer or "ARTWORK", self.sublevel or 0 end
function P:GetObjectType() return self.kind end
function P:GetParent() return self.parent end
function P:GetName() return self.name end
function P:GetRegions() return unpack(self.regions) end
function P:GetEffectiveScale() return 1 end
function P:GetLeft() return self.rect and self.rect[1] end
function P:GetRight() return self.rect and self.rect[2] end
function P:GetBottom() return self.rect and self.rect[3] end
function P:GetTop() return self.rect and self.rect[4] end
function P:CreateTexture(name, layer, _, sub)
    local t = new(name, self, "Texture")
    t.layer, t.sublevel = layer, sub
    self.regions[#self.regions + 1] = t
    return t
end
function P:CreateFontString(name) return new(name, self, "FontString") end
function P:SetScript(n, fn) self.scripts = rawget(self, "scripts") or {}; self.scripts[n] = fn end
function P:RegisterEvent(e) self.events = rawget(self, "events") or {}; self.events[e] = true end
function P:UnregisterEvent(e) if rawget(self, "events") then self.events[e] = nil end end
function P:GetNormalTexture() return self.normal end

function CreateFrame(_, name, parent) return new(name, parent) end
function hooksecurefunc(a, b, c)
    if type(a) == "table" then return end
    local old = _G[a] or noop
    _G[a] = function(...) old(...); b(...) end
end
function UnitFactionGroup() return "Alliance" end
function InCombatLockdown() return false end
SlashCmdList = {}

local settings = { barLayout = "classic", barWingsBack = true }
local ui = { Settings = function() return settings end }

UIParent = new("UIParent")
MainMenuBar = new("MainMenuBar", UIParent)
MainMenuBar.rect = { 0, 1024, 0, 53 }
MainMenuBarArtFrame = new("MainMenuBarArtFrame", MainMenuBar)
for _, name in ipairs({ "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap" }) do
    new(name, MainMenuBarArtFrame, "Texture").points = { { "BOTTOM", MainMenuBar, "BOTTOM", 0, 0 } }
end
local DWARF = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf"
local stockTops = { [0] = 0.83203125, 0.58203125, 0.33203125, 0.08203125 }
for i = 0, 3 do
    local t = new("MainMenuBarTexture" .. i, MainMenuBarArtFrame, "Texture")
    t.layer, t.sublevel = "BACKGROUND", 0
    t.texture = DWARF
    t:SetTexCoord(0, 1, stockTops[i], stockTops[i] + 43 / 256)
    new("MainMenuXPBarTexture" .. i, MainMenuBar, "Texture")
    new("MainMenuMaxLevelBar" .. i, MainMenuBar, "Texture")
end
MainMenuExpBar = new("MainMenuExpBar", MainMenuBar)
MainMenuExpBar.rect = { 0, 1024, 40, 53 }
MainMenuBarMaxLevelBar = new("MainMenuBarMaxLevelBar", MainMenuBar)
MainMenuBarMaxLevelBar.shown = false
ReputationWatchBar = new("ReputationWatchBar", MainMenuBar)
ReputationWatchBar.shown = false
ReputationWatchStatusBar = new("ReputationWatchStatusBar", ReputationWatchBar)
ExhaustionLevelFillBar = new("ExhaustionLevelFillBar", MainMenuExpBar)
ActionButton_Update = noop
for i = 1, 12 do
    local b = new("ActionButton" .. i, MainMenuBarArtFrame, "CheckButton")
    b.rect = { 8 + (i - 1) * 42, 44 + (i - 1) * 42, 4, 40 }
    b.w, b.h = 36, 36
    new("ActionButton" .. i .. "Icon", b, "Texture")
    local m = new("MultiBarBottomLeftButton" .. i, UIParent, "CheckButton")
    new("MultiBarBottomLeftButton" .. i .. "Icon", m, "Texture")
end
MultiBarBottomLeftButton1.parent = new("MultiBarBottomLeft", UIParent)

assert(loadfile("StockPanels.lua"))("ForeverUI", ui)
local AB = ui.ActionBars
assert(AB and AB.WingOutsets and AB.wings, "action bar API published")

-- Before login the strip is untouched and untinted (the old code tinted it at load).
for i = 0, 3 do
    local c = _G["MainMenuBarTexture" .. i].color
    assert(c[1] == 1 and c[2] == 1 and c[3] == 1, "strip not tinted at load " .. i)
end

local function login() AB.Apply() end

-- Something hid and repainted the strip: Classic puts the stock look back.
for i = 0, 3 do
    local t = _G["MainMenuBarTexture" .. i]
    t:SetTexture("Interface\\AddOns\\Other\\Bar"); t:SetTexCoord(0, 0.5, 0, 0.5); t:SetAlpha(0)
    t:SetVertexColor(0.2, 0.3, 0.4, 0.5); t:Hide()
end
settings.barStockArt, settings.barStripBack = false, true
login()
assert(settings.barStockArt == nil and settings.barStripBack == nil, "keys of the removed switch cleared")
for i = 0, 3 do
    local t = _G["MainMenuBarTexture" .. i]
    assert(t.texture == DWARF, "stock texture " .. i)
    local ulx, uly, _, _, _, _, lrx, lry = t:GetTexCoord()
    assert(ulx == 0 and lrx == 1 and math.abs(uly - stockTops[i]) < 1e-9
        and math.abs(lry - (stockTops[i] + 43 / 256)) < 1e-9, "stock coords " .. i)
    assert(t.alpha == 1 and t.shown, "Classic always shows the strip " .. i)
    assert(t.color[1] == 1 and t.color[2] == 1 and t.color[3] == 1 and t.color[4] == 1, "white " .. i)
end
-- The XP strip keeps its tint and textures (not touched by this change).
assert(MainMenuXPBarTexture1.color[2] < 1, "XP textures keep the bar tint")

-- The former tint is an option.
settings.barStockTint, settings.barArtColor = true, { 0.5, 0.6, 0.7 }
login()
assert(MainMenuBarTexture2.color[1] == 0.5 and MainMenuBarTexture2.color[3] == 0.7, "opt-in tint")
settings.barStockTint = nil

-- Retail always hides the strip, whatever an old saved switch says.
settings.barLayout, settings.barStockArt = "retail", true
login()
assert(MainMenuBarTexture0.alpha == 0, "Retail without the stock background")
settings.barLayout = "classic"

-- Winged backdrops: one per ActionButton, on the bar art frame, BACKGROUND above the strip.
login()
for i = 1, 12 do
    local w = AB.wings[i]
    assert(w and w.parent == MainMenuBarArtFrame, "backdrop on the art frame " .. i)
    assert(w.layer == "BACKGROUND" and w.sublevel == 1, "BACKGROUND sublevel 1 " .. i)
    assert(w.texture:find("ActionBar%-SlotWing"), "winged cell " .. i)
    assert(w.shown, "shown " .. i)
end
-- No backdrop or old OVERLAY cell on the other bars, and none on the art frame's OVERLAY.
assert(#MultiBarBottomLeft.regions == 0, "other bars untouched")
for _, region in ipairs(MainMenuBarArtFrame.regions) do
    assert(region.layer ~= "OVERLAY", "no OVERLAY backdrop over the buttons")
end

-- Geometry: 2 px past the button, but not onto the XP bar (it starts at the button top).
local function offsets(w)
    local _, b1, _, x1, y1 = w:GetPoint(1)
    local _, b2, _, x2, y2 = w:GetPoint(2)
    return b1, x1, y1, b2, x2, y2
end
local b1, x1, y1, b2, x2, y2 = offsets(AB.wings[1])
assert(b1 == ActionButton1 and b2 == ActionButton1, "anchored to its button")
assert(x1 == -2 and y1 == 0 and x2 == 2 and y2 == -2, "outsets with the XP bar shown")
MainMenuExpBar.shown = false
AB.LayoutWings()
b1, x1, y1 = offsets(AB.wings[1])
assert(y1 == 2, "full outset without the XP bar")
-- Bar edges: a button 1 px from the bar bottom gets 1 px below.
ActionButton3.rect = { 92, 128, 1, 37 }
AB.LayoutWings()
local _, _, _, _, _, bottom = offsets(AB.wings[3])
assert(bottom == -1, "clamped at the bar bottom")
MainMenuExpBar.shown = true

-- Edit Mode grid: 6 cells, the rest of the backdrops hide; ApplyGryphons (called by applyBar) relays out.
settings.editLayout = { MainMenuBar = { count = 6, rows = 2 } }
ui.ApplyGryphons()
for i = 1, 12 do assert(AB.wings[i].shown == (i <= 6), "count " .. i) end
-- A second row above the bar is outside MainMenuBar: the bar clamp does not apply, the XP fence does not
-- overlap it vertically either, so it gets the full outset.
ActionButton4.rect = { 8, 44, 46, 82 }
MainMenuExpBar.rect = { 0, 1024, 40, 45 }
AB.LayoutWings()
local _, _, top4, _, _, bottom4 = offsets(AB.wings[4])
assert(top4 == 2 and bottom4 == -1, "second row: full top, 1 px down to the XP bar")

-- Retail keeps the backdrops.
settings.barLayout = "retail"
AB.Apply()
for i = 1, 6 do assert(AB.wings[i].shown, "Retail keeps the backdrops " .. i) end
settings.barLayout = "classic"

-- One-time migration: an old Retail switch-off comes back on once, a later choice is kept.
settings.barSlotBackgrounds, settings.barWingsBack = false, nil
AB.Apply()
assert(settings.barSlotBackgrounds == true and AB.wings[1].shown, "backdrops switched back on once")

settings.barSlotBackgrounds = false
AB.Apply()
for i = 1, 12 do assert(not AB.wings[i].shown, "switched off " .. i) end

-- Gryphons: each cap stretched over its own holder frame in the bar art (moved by Edit Mode).
settings.barSlotBackgrounds = true
settings.editLayout = {}
local leftHolder, rightHolder = _G[ui.GryphonHolders[1]], _G[ui.GryphonHolders[2]]
assert(leftHolder and rightHolder and leftHolder.parent == MainMenuBarArtFrame, "holders in the bar art")
local function capOn(cap, holder)
    local p1, r1, _, _, _ = cap:GetPoint(1)
    local p2, r2 = cap:GetPoint(2)
    return p1 == "TOPLEFT" and r1 == holder and p2 == "BOTTOMRIGHT" and r2 == holder
end
-- Classic: holders take the stock cap points, sized like the art.
AB.Apply()
assert(capOn(MainMenuBarLeftEndCap, leftHolder) and capOn(MainMenuBarRightEndCap, rightHolder), "caps on holders")
local hp, hr = leftHolder:GetPoint(1)
assert(hp == "BOTTOM" and hr == MainMenuBar, "Classic: stock point on the holder")
assert(math.abs(leftHolder.w - 234 * 0.44) < 1e-6, "Classic holder sized like the art")
-- Retail: left cap 2 px over the first slot, right 3 px over the last, both 24 px below.
settings.barLayout = "retail"
AB.Apply()
local p, rel, rp, x, y = leftHolder:GetPoint(1)
assert(p == "BOTTOMRIGHT" and rel == ActionButton1 and rp == "BOTTOMLEFT" and x == 2 and y == -24, "Retail left")
p, rel, rp, x, y = rightHolder:GetPoint(1)
assert(p == "BOTTOMLEFT" and rel == ActionButton12 and x == -3 and y == -24, "Retail right")
assert(leftHolder.w == 104.5 and leftHolder.h == 98, "Retail holder size")
-- A spot saved in Edit Mode wins: the holder already sits there and is not put back.
local refreshed = 0
ui.RefreshEditLayout = function() refreshed = refreshed + 1 end
settings.editLayout[ui.GryphonHolders[1]] = { position = { -900, -700 } }
leftHolder:ClearAllPoints()
leftHolder:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -900, -700)
AB.Apply()
p, rel = leftHolder:GetPoint(1)
assert(p == "TOPRIGHT" and rel == UIParent and leftHolder:GetNumPoints() == 1, "saved spot kept")
assert(capOn(MainMenuBarLeftEndCap, leftHolder), "cap follows the moved holder")
-- Saved but not placed yet: default points now, Edit Mode asked to move it.
leftHolder:ClearAllPoints()
AB.Apply()
assert(refreshed > 0 and leftHolder:GetNumPoints() == 1, "Edit Mode refresh requested")
-- Hidden by the Edit Mode "Show" switch: only that cap disappears.
settings.editLayout[ui.GryphonHolders[1]].hidden = true
AB.Apply()
assert(MainMenuBarLeftEndCap.alpha == 0 and MainMenuBarRightEndCap.alpha == 1, "one cap hidden")
settings.editLayout = {}
settings.barLayout = "classic"
AB.Apply()
assert(MainMenuBarLeftEndCap.alpha == 1, "cap shown again")

-- Pure function.
local l, r, b, t = AB.WingOutsets({ l = 10, r = 46, b = 4, t = 40 }, {}, nil, 2, 1)
assert(l == 2 and r == 2 and b == 2 and t == 2, "no fences")
l, r, b, t = AB.WingOutsets({ l = 10, r = 46, b = 4, t = 40 }, { { l = 0, r = 100, b = 41, t = 50 } }, nil, 2, 2)
assert(t == 0.5, "fence room in button units")

print("ActionBars tests passed")
