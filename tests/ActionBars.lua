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

function CreateFrame(_, name, parent, template)
    local f = new(name, parent)
    f.template = template
    return f
end
-- Secure handler (bonus bar header): attributes, frame refs, wrapped scripts, state drivers.
function P:SetAttribute(k, v) self.attrs = rawget(self, "attrs") or {}; self.attrs[k] = v end
function P:GetAttribute(k) return rawget(self, "attrs") and self.attrs[k] end
function P:SetFrameRef(k, f) self:SetAttribute("frameref-" .. k, f) end
function P:GetFrameRef(k) return self:GetAttribute("frameref-" .. k) end
function P:WrapScript(frame, script, body) frame.wraps = frame.wraps or {}; frame.wraps[script] = { self, body } end
function P:HookScript(n, fn) self.hooks = rawget(self, "hooks") or {}; self.hooks[n] = fn end
local bonusOffset = 0
function GetBonusBarOffset() return bonusOffset end
local drivers = {}
function RegisterStateDriver(frame, state, cond) drivers[#drivers + 1] = { frame, state, cond } end
function hooksecurefunc(a, b, c)
    if type(a) == "table" then return end
    local old = _G[a] or noop
    _G[a] = function(...) old(...); b(...) end
end
function UnitFactionGroup() return "Alliance" end
function InCombatLockdown() return false end
SlashCmdList = {}

local settings = { barLayout = "classic", barWingsBack = true }
local combatQueue = {}
local ui = { Settings = function() return settings end }
ui.RunOutOfCombat = function(token, fn)
    if InCombatLockdown() then combatQueue[token] = fn return false end
    fn()
    return true
end

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
-- Bonus bar (shadowform, stances): its own strip and buttons over the main ones.
BonusActionBarFrame = new("BonusActionBarFrame", MainMenuBar)
for i = 0, 1 do
    local t = BonusActionBarFrame:CreateTexture("BonusActionBarTexture" .. i, "BACKGROUND", nil, 0)
    t.texture = DWARF
    t:SetTexCoord(0, 1, stockTops[i], stockTops[i] + 43 / 256)
end
for i = 1, 12 do
    local b = new("BonusActionButton" .. i, BonusActionBarFrame, "CheckButton")
    b.rect = { 8 + (i - 1) * 42, 44 + (i - 1) * 42, -30, 6 } -- still sliding in
    new("BonusActionButton" .. i .. "Icon", b, "Texture")
end

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
-- The bonus bar's strip takes the same tint, keeps its own texture.
for i = 0, 1 do
    local t = _G["BonusActionBarTexture" .. i]
    assert(t.color[1] == 0.5 and t.color[2] == 0.6 and t.color[3] == 0.7, "bonus strip tinted " .. i)
    assert(t.texture == DWARF and t.alpha == 1, "bonus strip shown, client texture " .. i)
end
settings.barStockTint = nil
login()
assert(BonusActionBarTexture0.color[1] == 1 and BonusActionBarTexture0.color[3] == 1, "bonus strip white")

-- Retail always hides the strip, whatever an old saved switch says.
settings.barLayout, settings.barStockArt = "retail", true
login()
assert(MainMenuBarTexture0.alpha == 0, "Retail without the stock background")
assert(BonusActionBarTexture0.alpha == 0 and BonusActionBarTexture1.alpha == 0, "Retail without the bonus strip")
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
-- Bonus backdrops: on the bonus frame above its strip, measured on the main button (not the sliding one).
for i = 1, 12 do
    local w = AB.bonusWings[i]
    assert(w and w.parent == BonusActionBarFrame and w.layer == "BACKGROUND" and w.sublevel == 1, "bonus backdrop " .. i)
    assert(w.texture:find("ActionBar%-SlotWing") and w.shown, "bonus winged cell " .. i)
    assert(BonusActionBarTexture0.color[1] == 1 and w.color[1] == 1, "backdrop not tinted as strip " .. i)
end
local bb1, bx1, by1, _, bx2, by2 = offsets(AB.bonusWings[1])
assert(bb1 == BonusActionButton1 and bx1 == -2 and by1 == 2 and bx2 == 2 and by2 == -2, "bonus outsets like the main")
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
for i = 1, 12 do assert(AB.bonusWings[i].shown == (i <= 6), "bonus count " .. i) end
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

-- No bar background or gryphons (editor switch): only the buttons stay, in both layouts.
local sideArt = {}
for _, name in ipairs({ "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight",
    "SlidingActionBarTexture0", "SlidingActionBarTexture1", "PossessBackground1", "PossessBackground2" }) do
    sideArt[#sideArt + 1] = new(name, UIParent, "Texture")
end
local function bareCheck(hidden, label)
    local want = hidden and 0 or 1
    for i = 0, 3 do
        assert(_G["MainMenuBarTexture" .. i].alpha == want, label .. ": strip " .. i)
        assert(_G["MainMenuMaxLevelBar" .. i].alpha == want, label .. ": max-level bar " .. i)
    end
    assert(BonusActionBarTexture0.alpha == want and BonusActionBarTexture1.alpha == want, label .. ": bonus strip")
    for _, texture in ipairs(sideArt) do assert(texture.alpha == want, label .. ": " .. texture.name) end
    assert(MainMenuBarLeftEndCap.alpha == want and MainMenuBarRightEndCap.alpha == want, label .. ": gryphons")
    for i = 1, 12 do assert(AB.wings[i].shown, label .. ": slot backdrops keep their own switch " .. i) end
end
settings.barArtHidden = true
AB.Apply()
bareCheck(true, "Classic bare")
settings.barLayout = "retail"
AB.Apply()
for i = 0, 3 do assert(_G["MainMenuBarTexture" .. i].alpha == 0, "Retail bare strip " .. i) end
assert(MainMenuBarLeftEndCap.alpha == 0 and sideArt[1].alpha == 0, "Retail bare: gryphons and side art")
settings.barLayout, settings.barArtHidden = "classic", false
AB.Apply()
bareCheck(false, "Classic with art")

-- Pure function.
local l, r, b, t = AB.WingOutsets({ l = 10, r = 46, b = 4, t = 40 }, {}, nil, 2, 1)
assert(l == 2 and r == 2 and b == 2 and t == 2, "no fences")
l, r, b, t = AB.WingOutsets({ l = 10, r = 46, b = 4, t = 40 }, { { l = 0, r = 100, b = 41, t = 50 } }, nil, 2, 2)
assert(t == 0.5, "fence room in button units")

-- Bonus bar: hidden in forms and stances (also in combat, through the secure header), shown for possess.
local header = AB.bonusHeader
assert(header and header.template == "SecureHandlerStateTemplate", "secure state header")
assert(not AB.bonusStats.error, "no setup error")
assert(header:GetFrameRef("bonus") == BonusActionBarFrame, "frame ref to the bonus bar")
local driver = drivers[#drivers]
assert(driver[1] == header and driver[2] == "bonus" and driver[3] == "[bonusbar:5] possess; none", "state driver")
local wrap = BonusActionBarFrame.wraps and BonusActionBarFrame.wraps.OnShow
assert(wrap and wrap[1] == header, "OnShow wrapped by the header")
assert(not wrap[2]:find("owner"), "the wrap needs only self")
local backup = BonusActionBarFrame.hooks and BonusActionBarFrame.hooks.OnShow
assert(backup, "backup OnShow hook")
-- Snippets run as bodies of restricted functions: (self, stateid, newstate) for the state, (self) for wraps.
-- No `owner` in the wrap environment, as it may be on the client.
local function run(body, head, ...)
    local fn = assert(loadstring(head .. "\n" .. body))
    setfenv(fn, setmetatable({ owner = false }, { __index = _G }))
    fn(...)
end
local function setState(state)
    header:SetAttribute("state-bonus", state)
    run(header:GetAttribute("_onstate-bonus"), "local self, stateid, newstate = ...", header, "bonus", state)
end
local secureWrap = true
local function clientShow() -- ShowBonusActionBar: Show fires the wrapped OnShow, then the hook
    BonusActionBarFrame:Show()
    if secureWrap then run(wrap[2], "local self = ...", BonusActionBarFrame) end
    backup(BonusActionBarFrame)
end
local function boundButton(id) -- the stock ActionButtonDown pick
    return BonusActionBarFrame:IsShown() and _G["BonusActionButton" .. id] or _G["ActionButton" .. id]
end
setState("none")
assert(not BonusActionBarFrame:IsShown(), "hidden at start")
bonusOffset = 1
clientShow() -- cat form / battle stance / stealth / shadowform
assert(not BonusActionBarFrame:IsShown(), "form does not show the bonus bar")
assert(AB.bonusStats.missed == 0, "the secure hide did it")
for i = 1, 12 do
    assert(_G["ActionButton" .. i].shown and _G["ActionButton" .. i].alpha == 1, "main button kept " .. i)
    assert(boundButton(i) == _G["ActionButton" .. i], "key goes to the main button " .. i)
end
bonusOffset = 5
setState("possess")
assert(BonusActionBarFrame:IsShown(), "possess shows the bar")
clientShow()
assert(BonusActionBarFrame:IsShown() and boundButton(1) == BonusActionButton1, "possess keeps its keys")
bonusOffset = 0
setState("none")
assert(not BonusActionBarFrame:IsShown(), "hidden after possess")

-- The secure hide does nothing on the client: the backup hides it out of combat, in combat once it ends.
secureWrap, bonusOffset = false, 3
clientShow()
assert(not BonusActionBarFrame:IsShown() and AB.bonusStats.missed == 1, "backup hides it")
InCombatLockdown = function() return true end
clientShow()
assert(BonusActionBarFrame:IsShown() and combatQueue["bonusbar-hide"], "in combat: queued")
InCombatLockdown = function() return false end
combatQueue["bonusbar-hide"]()
assert(not BonusActionBarFrame:IsShown(), "hidden after combat")
bonusOffset = 5
clientShow()
assert(BonusActionBarFrame:IsShown(), "backup keeps possess")
BonusActionBarFrame:Hide()

-- Without secure handlers: hidden after ShowBonusActionBar, out of combat.
bonusOffset = 1
function ShowBonusActionBar() BonusActionBarFrame:Show() end
RegisterStateDriver = nil
local ui2 = { Settings = ui.Settings, RunOutOfCombat = ui.RunOutOfCombat }
assert(loadfile("StockPanels.lua"))("ForeverUI", ui2)
assert(not ui2.ActionBars.bonusHeader and ui2.ActionBars.bonusStats.error, "fallback without a header")
ShowBonusActionBar()
assert(not BonusActionBarFrame:IsShown(), "fallback hides it")
assert(SlashCmdList.FOREVERUIBONUS, "/fuibonus")
ui2.ActionBars.bonusHeader = header
local probes = {}
function header:Execute(body) probes[#probes + 1] = body end
local realPrint = print
print = function() end
SlashCmdList.FOREVERUIBONUS("")
print = realPrint
assert(#probes == 1 and probes[1]:find("bar:Hide"), "/fuibonus probes the secure hide")

print("ActionBars tests passed")
