-- Retail look of the player, target and target-of-target frames: live switch and geometry.
-- Run from the addon root (see INDEX.md).
local settings = { barLayout = "classic" }
local Proto = {}
Proto.__index = function(t, k)
    if Proto[k] then return Proto[k] end
    -- Unknown methods (capitalised) are no-ops; unknown fields (lowercase) are nil like on a real frame.
    if type(k) == "string" and k:match("^%u") then return function(self) return self end end
end
function Proto:SetPoint(point, rel, relPoint, x, y)
    self.points[#self.points + 1] = { point, rel, relPoint, x, y }
end
function Proto:ClearAllPoints() self.points = {} end
function Proto:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p, 1, 5) end end
function Proto:GetNumPoints() return #self.points end
function Proto:SetSize(w, h) self.w, self.h = w, h end
function Proto:GetWidth() return self.w or 10 end
function Proto:GetHeight() return self.h or 10 end
function Proto:Show() self.shown = true end
function Proto:Hide() self.shown = false end
function Proto:IsShown() return self.shown end
function Proto:SetTexture(t) self.texture = t end
function Proto:GetTexture() return self.texture end
function Proto:SetAlpha(a) self.alpha = a end
function Proto:GetFont() return "font.ttf", 12, "" end
function Proto:SetFont(f, s) self.font = { f, s } end
function Proto:SetJustifyH(j) self.justify = j end
function Proto:SetBackdrop(b) self.backdrop = b end
function Proto:GetParent() return self.parent end
function Proto:SetParent(p) self.parent = p end
function Proto:GetFrameLevel() return 5 end
function Proto:GetFrameStrata() return "MEDIUM" end
function Proto:GetStatusBarColor() return 1, 1, 1, 1 end
function Proto:SetAllPoints(r) self.points = { { "ALL", r } } end
function Proto:CreateTexture() return Proto.new() end
function Proto:CreateFontString() return Proto.new() end
function Proto:GetRegions() return end
function Proto.new(name)
    local o = setmetatable({ points = {}, shown = true, frameName = name }, Proto)
    return o
end
function Proto:SetScript(n, fn) self.scripts = rawget(self, "scripts") or {}; self.scripts[n] = fn end
function Proto:GetName() return self.frameName end
function CreateFrame(_, name, parent) local f = Proto.new(name); f.parent = parent; return f end

local function unitFrame(name, textureFrame)
    local f = Proto.new(name)
    _G[name] = f
    f.parent = UIParent
    f.points = { { "TOPLEFT", UIParent, "TOPLEFT", 0, 0 } }
    f.w, f.h = 232, 100
    _G[name .. "TextureFrameTexture"] = Proto.new()
    _G[name .. "TextureFrameTexture"].parent = Proto.new()
    _G[name .. "Portrait"] = Proto.new()
    _G[name .. "Portrait"].points = { { "TOPLEFT", f, "TOPLEFT", 6, -5 } }
    _G[name .. "Portrait"].w, _G[name .. "Portrait"].h = 37, 37
    _G[name .. "HealthBar"] = Proto.new()
    _G[name .. "ManaBar"] = Proto.new()
    _G[name .. "HealthBar"].TextString = Proto.new()
    _G[name .. "ManaBar"].TextString = Proto.new()
    _G[name .. "TextureFrameName"] = Proto.new()
    f.threatIndicator = Proto.new()
    return f
end
UIParent = Proto.new("UIParent")
local player = unitFrame("PlayerFrame")
local target = unitFrame("TargetFrame")
local tot = unitFrame("TargetFrameToT")
PlayerLevelText = Proto.new()
-- Faction badges: the client puts them away from the moved portrait.
TargetFramePVPIcon = Proto.new(); TargetFramePVPIcon.points = { { "TOPRIGHT", target, "TOPRIGHT", 0, 0 } }
PlayerPVPIcon = Proto.new(); PlayerPVPIcon.points = { { "TOPLEFT", player, "TOPLEFT", 0, 0 } }
function Proto:GetSize() return self.w or 0, self.h or 0 end
function Proto:SetDrawLayer(layer, sub) self.layer, self.sublevel = layer, sub end
SPELL_POWER_MANA = 0
function hooksecurefunc() end
function InCombatLockdown() return false end
function UnitExists() return false end
function UnitClassification() return "normal" end

local ui = { russian = false, Settings = function() return settings end,
    UnitBarFill = function() return "fill" end,
    MediaPath = function() return "" end }
local loader
local realCreate = CreateFrame
function CreateFrame(kind, name, parent)
    local f = realCreate(kind, name, parent)
    if not loader and not name and not parent then loader = f end
    return f
end
assert(loadfile("ForeverUI.lua"))("ForeverUI", ui)
assert(ui.UnitFrames.ApplyLayout, "ApplyLayout is exported")

loader.scripts.OnEvent(loader, "ADDON_LOADED", "ForeverUI")

-- The faction badge sits on the portrait's outer top corner: right of the target's portrait, left of the player's.
local tp, pp = TargetFramePVPIcon.points[1], PlayerPVPIcon.points[1]
assert(tp[1] == "CENTER" and tp[2] == TargetFramePortrait and tp[3] == "TOPRIGHT", "target faction badge on its portrait")
assert(pp[1] == "CENTER" and pp[2] == PlayerFramePortrait and pp[3] == "TOPLEFT", "player faction badge on its portrait")
assert(TargetFramePVPIcon.parent ~= nil and TargetFramePVPIcon.parent == TargetFramePortrait.parent,
    "badge on the portrait layer, over the ring")


-- Name accent (reaction gradient behind the target name): a little see-through in Classic, more in Retail.
local gradients = {}
function Proto:SetGradientAlpha(...) self.gradient = { ... }; gradients[#gradients + 1] = self end
function Proto:SetHeight(h) self.h = h end
function UnitExists() return true end
function UnitIsDeadOrGhost() return false end
function UnitSelectionColor() return 1, 0, 0 end
TargetFrame.unit = "target"
local function accentOf()
    for i = #gradients, 1, -1 do if gradients[i].gradient then return gradients[i] end end
end

-- Classic stays as it was: no Retail pieces are shown.
assert(settings.barLayout == "classic")
ui.UnitFrames.ApplyLayout()
local classicHealth = { unpack(PlayerFrameHealthBar.points[1], 1, 5) }
ui.UnitFrames.ApplyBarFill() -- refreshes the target name accent
local accent = accentOf()
assert(accent and accent.gradient[5] == 0.9 and accent.gradient[9] == 0.1 and accent.shown,
    "Classic accent: the Retail gradient, 0.9 at the bottom to 0.1 at the top")
assert(math.abs(accent.gradient[2] - 165 / 255) < 1e-9, "Classic accent: the reaction colour at 60%")
assert(accent.points[1][1] == "TOPLEFT" and accent.points[1][2] == TargetFrame, "Classic accent in the name slot")
assert(classicHealth[1] == "TOPLEFT" and classicHealth[2] == PlayerFrame, "classic health keeps the chrome anchor")

-- Switch to Retail: bars anchor to the portrait with DragonUI's offsets.
settings.barLayout = "retail"
ui.UnitFrames.ApplyLayout()
local h = PlayerFrameHealthBar
assert(h.points[1][1] == "LEFT" and h.points[1][2] == PlayerFramePortrait and h.points[1][3] == "RIGHT"
    and h.points[1][4] == 2 and h.points[1][5] == -1, "player health on the portrait")
assert(h.w == 125 and h.h == 20)
assert(PlayerFramePortrait.points[1][1] == "TOPLEFT" and PlayerFramePortrait.points[1][4] == 42
    and PlayerFramePortrait.w == 56, "player portrait")
local t = TargetFrameHealthBar
assert(t.points[1][1] == "RIGHT" and t.points[1][3] == "LEFT" and t.points[1][4] == -1.25 and t.w == 126, "target health")
assert(TargetFramePortrait.points[1][1] == "TOPRIGHT" and TargetFramePortrait.w == 54, "target portrait")
local m = TargetFrameManaBar
assert(m.w == 133 and m.h == 9.5 and m.points[1][5] == -18.75, "target mana")
local gr = accent.gradient
assert(gr[5] == 0.9 and gr[9] == 0.1 and accent.shown, "Retail accent fades from 0.9 at the bottom to 0.1 at the top")
assert(math.abs(gr[2] - 165 / 255) < 1e-9 and math.abs(gr[3] - 13 / 255) < 1e-9 and gr[6] == gr[2],
    "Retail accent: the reaction colour at 65% (red target), same colour top and bottom")
assert(accent.points[1][1] == "BOTTOMLEFT" and accent.points[1][2] == TargetFrameHealthBar
    and accent.points[2][1] == "BOTTOMRIGHT" and accent.h == 17, "Retail accent on top of the health bar")
local tn = TargetFrameTextureFrameName
assert(tn.points[1][1] == "CENTER" and tn.points[1][2] == TargetFrameHealthBar and tn.points[1][3] == "TOP"
    and tn.points[1][4] == 0 and tn.points[1][5] == 8 and tn.justify == "CENTER" and tn.w == 120, "target name centred")
local pn = PlayerFrameTextureFrameName
assert(pn.points[1][1] == "CENTER" and pn.points[1][2] == PlayerFrameHealthBar and pn.justify == "CENTER", "player name centred")
local totName = TargetFrameToTTextureFrameName
assert(totName.points[1][2] == TargetFrameToTHealthBar and totName.justify == "CENTER", "ToT name centred")
local th = TargetFrameToTHealthBar
assert(th.w == 70.5 and th.h == 10 and th.points[1][2] == TargetFrameToTPortrait, "ToT health")
assert(TargetFrameToTPortrait.points[1][1] == "TOPLEFT" and TargetFrameToTPortrait.points[1][4] == 6
    and TargetFrameToTPortrait.w == 37, "ToT portrait back at its stock place")

-- Back to Classic: the chrome geometry returns.
settings.barLayout = "classic"
ui.UnitFrames.ApplyLayout()
local back = PlayerFrameHealthBar.points[1]
assert(back[1] == "TOPLEFT" and back[2] == PlayerFrame and back[4] == classicHealth[4] and back[5] == classicHealth[5],
    "classic health restored")
assert(PlayerFramePortrait.w ~= 56, "classic portrait restored")
assert(accent.gradient[5] == 0.9 and accent.points[1][1] == "TOPLEFT", "Classic accent back in the name slot")
-- Frame border (unitBarBorder) on chromed frames: drawn on its own layer above the chrome, in the border colour;
-- the bar panel keeps only the background. Hidden in Retail.
local created = {}
local plainCreate = CreateFrame
function CreateFrame(...) local f = plainCreate(...); created[#created + 1] = f; return f end
function Proto:SetBackdropBorderColor(...) self.edgeColor = { ... } end
local levels = {}
function Proto:SetFrameLevel(l) levels[self] = l end
local BORDER = "Media/border/Ferous1"
ui.MediaPath = function(kind) if kind == "border" then return BORDER end return "" end
settings.ufBorderColor = { 0.2, 0.4, 0.6, 1 }
ui.UnitFrames.ApplyPanelMedia()
local edges = {}
for _, f in ipairs(created) do
    if f.backdrop and f.backdrop.edgeFile == BORDER then edges[#edges + 1] = f end
end
assert(#edges == 3, "a border on each chromed frame (player, target, ToT): " .. #edges)
for _, e in ipairs(edges) do
    assert(e.shown ~= false, "border shown")
    assert(not e.backdrop.bgFile, "the border layer has no background")
    assert(e.edgeColor[1] == 0.2 and e.edgeColor[3] == 0.6, "border colour applied")
    assert(levels[e] == 6, "above the chrome layer (level 5 + 1)")
    assert(e.parent == PlayerFrame or e.parent == TargetFrame or e.parent == TargetFrameToT, "on the unit frame")
end
-- A changed colour reaches the same layers, no new ones.
settings.ufBorderColor = { 1, 0, 0, 1 }
local count = #created
ui.UnitFrames.ApplyPanelMedia()
assert(#created == count and edges[1].edgeColor[1] == 1 and edges[1].edgeColor[2] == 0, "colour change applied")
settings.barLayout = "retail"
ui.UnitFrames.ApplyLayout()
-- Retail: the same layers frame the health and power bars.
for _, e in ipairs(edges) do
    assert(e.shown ~= false, "border kept in Retail")
    local unit = e.parent:GetName()
    assert(e.points[1][1] == "TOPLEFT" and e.points[1][2] == _G[unit .. "HealthBar"]
        and e.points[2][1] == "BOTTOMRIGHT" and e.points[2][2] == _G[unit .. "ManaBar"], "Retail border around the bars")
    assert(e.points[1][4] < 0 and e.points[1][5] == -e.points[1][4] and e.points[2][4] == -e.points[1][4], "Retail border outset by the inset")
end
settings.barLayout = "classic"
ui.UnitFrames.ApplyLayout()
for _, e in ipairs(edges) do
    assert(e.shown ~= false and e.points[1][1] == "ALL", "border back on the panel in Classic")
end
-- "None": no border anywhere.
ui.MediaPath = function() return "" end
ui.UnitFrames.ApplyPanelMedia()
for _, e in ipairs(edges) do assert(e.shown == false, "no border with None") end

print("UnitFramesRetail OK: live switch, player, target and ToT geometry, classic restore, name accent in both layouts, centred Retail names, border on chromed frames and in Retail, None")
