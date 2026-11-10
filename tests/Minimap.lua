-- Mock harness for ForeverUI Minimap.lua (run from the addon root).
local noop = function() end
local Region = {}
Region.__index = function(t, k)
    local v = rawget(Region, k)
    if v ~= nil then return v end
    if type(k) == "string" and k:match("^%l") then return nil end
    return noop
end
local all = {}
local function new(kind, name, parent)
    local o = setmetatable({ kind = kind, name = name, parent = parent, children = {}, regions = {}, scripts = {},
        w = 0, h = 0, scale = 1, shown = true, points = {} }, Region)
    if parent and kind ~= "Texture" and kind ~= "FontString" then table.insert(parent.children, o) end
    if parent and (kind == "Texture" or kind == "FontString") then table.insert(parent.regions, o) end
    if name then _G[name] = o end
    all[#all + 1] = o
    return o
end
function Region:SetSize(w, h) self.w, self.h = w, h end
function Region:SetWidth(w) self.w = w end
function Region:SetHeight(h) self.h = h end
function Region:GetWidth() return self.w end
function Region:GetHeight() return self.h end
function Region:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Region:ClearAllPoints() self.points = {} end
function Region:SetScale(s) self.scale = s end
function Region:GetScale() return self.scale end
function Region:GetEffectiveScale()
    local p = self.parent
    if self.kind == "Texture" or self.kind == "FontString" then return p:GetEffectiveScale() end
    return self.scale * (p and p:GetEffectiveScale() or 1)
end
function Region:GetParent() return self.parent end
function Region:GetChildren() return unpack(self.children) end
function Region:GetNumChildren() return #self.children end
function Region:GetRegions() return unpack(self.regions) end
function Region:GetName() return self.name end
function Region:IsObjectType(t) return self.kind == t or (t == "Frame" and self.kind == "Button") end
function Region:GetObjectType() return self.kind end
function Region:Show()
    if not self.shown then self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
end
function Region:Hide()
    if self.shown then self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
end
function Region:IsShown() return self.shown end
function Region:SetScript(s, f) self.scripts[s] = f end
function Region:GetScript(s) return self.scripts[s] end
function Region:HookScript(s, f)
    local old = self.scripts[s]
    self.scripts[s] = old and function(...) old(...); f(...) end or f
end
function Region:CreateTexture(name) return new("Texture", name, self) end
function Region:CreateFontString(name) return new("FontString", name, self) end
function Region:SetTexture(t) self.tex = t end
function Region:GetTexture() return self.tex end
function Region:SetDrawLayer(l) self.layer = l end
function Region:GetDrawLayer() return self.layer or "ARTWORK" end
function Region:GetFrameLevel() return 1 end
function Region:GetTexCoord() return 0 end
function Region:GetCenter() return 500, 400 end
function Region:GetNormalTexture() return new("Texture", nil, self) end
function Region:GetPushedTexture() return new("Texture", nil, self) end
function Region:GetFontString() return new("FontString", nil, self) end
function CreateFrame(kind, name, parent) return new(kind, name, parent) end

UIParent = new("Frame", "UIParent")
UIParent.scale = 0.9
STANDARD_TEXT_FONT = "font"
local combat = false
function InCombatLockdown() return combat end
local cursorX, cursorY = 0, 0
function GetCursorPosition() return cursorX, cursorY end
function GetGameTime() return 12, 0 end
function hooksecurefunc(t, k, f)
    if type(t) == "string" then t, k, f = _G, t, k end
    local old = t[k]
    t[k] = function(...) local r = { old(...) }; f(...); return unpack(r) end
end

MinimapCluster = new("Frame", "MinimapCluster", UIParent)
Minimap = new("Frame", "Minimap", MinimapCluster)
MinimapBackdrop = new("Frame", "MinimapBackdrop", MinimapCluster)
MinimapBorder = MinimapBackdrop:CreateTexture("MinimapBorder")
MinimapBorderTop = MinimapBackdrop:CreateTexture("MinimapBorderTop")
MinimapZoneTextButton = new("Button", "MinimapZoneTextButton", MinimapCluster)
MinimapZoneText = MinimapZoneTextButton:CreateFontString("MinimapZoneText")
MinimapZoomIn = new("Button", "MinimapZoomIn", Minimap)
MinimapZoomOut = new("Button", "MinimapZoomOut", Minimap)
MiniMapLFGFrame = new("Button", "MiniMapLFGFrame", MinimapCluster)
MiniMapLFGFrame.eye = new("Frame", nil, MiniMapLFGFrame)
MiniMapLFGFrame.eye.texture = MiniMapLFGFrame.eye:CreateTexture()
MiniMapBattlefieldFrame = new("Button", "MiniMapBattlefieldFrame", MinimapCluster)
MiniMapMailFrame = new("Button", "MiniMapMailFrame", MinimapCluster)
MiniMapMailFrame:SetSize(33, 33)

-- LibDBIcon stand-in, close to rev 29.
local lib = { objects = {} }
local function libPos(b) b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", 80, 0) end
local function libDragStart(b) b:SetScript("OnUpdate", libPos) end
local function libDragStop(b) b:SetScript("OnUpdate", nil) end
function lib:Register(name)
    local b = new("Button", "LibDBIcon10_" .. name, Minimap)
    b:SetSize(31, 31)
    local border = b:CreateTexture(nil, "OVERLAY"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b:SetScript("OnDragStart", libDragStart)
    b:SetScript("OnDragStop", libDragStop)
    lib.objects[name] = b
    libPos(b)
end
function lib:Refresh(name)
    local b = lib.objects[name]
    libPos(b)
    b:SetScript("OnDragStart", libDragStart)
    b:SetScript("OnDragStop", libDragStop)
end
function lib:Show(name) lib.objects[name]:Show(); libPos(lib.objects[name]) end
function LibStub(name) if name == "LibDBIcon-1.0" then return lib end end

local settings = { mapButtonsCircle = true, mapRingOffset = 2, mapScale = 100 }
local ui = { Settings = function() return settings end }
assert(loadfile("Minimap.lua"))("ForeverUI", ui)
local events
for _, o in ipairs(all) do
    if o.scripts.OnEvent then events = o end
end
local watcher = all[#all]
local function frame()
    if events.scripts.OnUpdate then events.scripts.OnUpdate(events, 0.016) end
end

local function ringPos(b)
    local p = b.points[#b.points]
    assert(p and p[2] == Minimap, "not anchored to minimap: " .. b.name)
    -- offsets are in button units; convert to minimap units
    local k = b:GetEffectiveScale() / Minimap:GetEffectiveScale()
    return p[4] * k, p[5] * k
end

-- Stock eye sits on the rim.
local eye = MiniMapLFGFrame.points[1]
local ex, ey = eye[4], eye[5]
assert(math.abs(math.sqrt(ex * ex + ey * ey) - 85.5) < 0.01, "eye off the rim")
assert(ex < 0 and ey < 0, "eye not at lower left")

for i = 1, 6 do lib:Register("Addon" .. i) end
local plain = new("Button", "DBMMinimapButton", Minimap)
plain:SetSize(33, 33)
local pb = plain:CreateTexture(nil, "OVERLAY"); pb:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
local pi = plain:CreateTexture(nil, "ARTWORK"); pi:SetTexture("Interface\\Icons\\foo")
local pin = new("Button", "GatherMatePin1", Minimap); pin:SetSize(12, 12)
local nodeButton = new("Button", "HandyNotesButton3", Minimap); nodeButton:SetSize(20, 20)

events.scripts.OnEvent(events, "PLAYER_LOGIN")
frame()

local function check(label)
    local placed = {}
    for _, b in ipairs({ Minimap:GetChildren() }) do
        if b.name and b.scripts.OnDragStart and b.shown then
            local x, y = ringPos(b)
            local r = math.sqrt(x * x + y * y)
            assert(math.abs(r - (82.5 + settings.mapRingOffset)) < 0.01, label .. ": off ring " .. b.name .. " r=" .. r)
            for _, o in ipairs(placed) do
                local d = math.sqrt((x - o[1]) ^ 2 + (y - o[2]) ^ 2)
                assert(d >= 27, label .. ": overlap " .. b.name .. " / " .. o[3] .. " d=" .. d)
            end
            -- eye, moon, coordinates, battlefield
            for _, s in ipairs({ { ex, ey, 17.5 + 13.5 }, { 47, 73.4, 12 + 13.5 }, { -35, -43, 18 + 13.5 } }) do
                local d = math.sqrt((x - s[1]) ^ 2 + (y - s[2]) ^ 2)
                assert(d >= s[3] - 0.01, label .. ": covers stock element " .. b.name .. " d=" .. d)
            end
            local cdx, cdy = math.max(math.abs(x) - 24, 0), math.max(math.abs(y + 97) - 5, 0)
            assert(cdx * cdx + cdy * cdy >= 13.5 ^ 2 - 0.01, label .. ": covers coordinates " .. b.name)
            placed[#placed + 1] = { x, y, b.name }
        end
    end
    return #placed
end

assert(check("initial") == 7, "plain button not gathered")

assert(pin.scripts.OnDragStart == nil and nodeButton.scripts.OnDragStart == nil, "map pins were gathered")

-- Map scale: buttons keep their size relative to the map, and the bar scale does not leak into the ring.
settings.mapScale = 130; settings.mapButtonsScale = 60
frame(); ui.Minimap.Layout(); frame()
local b1 = lib.objects.Addon1
assert(math.abs(b1:GetEffectiveScale() - Minimap:GetEffectiveScale()) < 1e-9, "ring button does not follow map scale")
check("scaled")

-- Late LibDBIcon button and late plain button are picked up.
lib:Register("Late")
frame()
local late = new("Button", "LateMinimapButton", Minimap); late:SetSize(31, 31)
watcher.scripts.OnUpdate(watcher, 1.1); frame()
assert(late.scripts.OnDragStart, "late plain button not hooked")
local n = check("late"); assert(n == 9, n)

-- Refresh moves a button back to LibDBIcon's spot and resets its drag scripts.
lib:Refresh("Addon2")
frame()
check("refresh")
local b2 = lib.objects.Addon2
-- Drag: drop it right on the LFG eye; it must slide off and save the angle.
local mx, my = Minimap:GetCenter()
local s = Minimap:GetEffectiveScale()
local function cursorAt(angle)
    cursorX = (mx + math.cos(math.rad(angle)) * 85) * s
    cursorY = (my + math.sin(math.rad(angle)) * 85) * s
end
cursorAt(215)
b2.scripts.OnDragStart(b2)
assert(b2.scripts.OnUpdate, "ring drag did not start after Refresh")
b2.scripts.OnUpdate(b2, 0.016)
b2.scripts.OnDragStop(b2)
assert(b2.scripts.OnUpdate == nil, "drag OnUpdate left behind")
local saved = settings.mapButtonAngles.LibDBIcon10_Addon2
assert(saved and math.abs(saved - 215) > 10, "dropped button stays on the eye: " .. tostring(saved))
frame()
check("dropped")
-- Drop it on another button.
local x3, y3 = ringPos(lib.objects.Addon3)
cursorAt(math.deg(math.atan2(y3, x3)))
b2.scripts.OnDragStart(b2); b2.scripts.OnUpdate(b2, 0); b2.scripts.OnDragStop(b2)
frame()
check("dropped on button")

-- Ring offset follows the setting.
settings.mapRingOffset = 10
ui.Minimap.Layout(); frame()
check("offset")

-- Bar mode.
settings.mapButtonsCircle = false
ui.Minimap.Layout(); frame()
assert(b1.points[1][2] ~= Minimap, "bar mode left button on the ring")
-- LibDBIcon moving a button in bar mode puts it back on the bar.
lib:Show("Addon1"); frame()
assert(b1.points[#b1.points][2] ~= Minimap, "bar button not restored after LibDBIcon move")

-- Overcrowded ring still places everything.
settings.mapButtonsCircle = true
settings.mapButtonAngles = {}
for i = 1, 30 do lib:Register("Crowd" .. i) end
frame()
print("Minimap OK: ring geometry, stock elements, map scale, late buttons, LibDBIcon Refresh, drag and drop, bar mode, crowded ring")
