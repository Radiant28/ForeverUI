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


-- Classic stays as it was: no Retail pieces are shown.
assert(settings.barLayout == "classic")
ui.UnitFrames.ApplyLayout()
local classicHealth = { unpack(PlayerFrameHealthBar.points[1], 1, 5) }
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
local tn = TargetFrameTextureFrameName
assert(tn.points[1][1] == "LEFT" and tn.points[1][3] == "TOPLEFT" and tn.points[1][4] == 4 and tn.justify == "LEFT", "target name")
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
print("UnitFramesRetail OK: live switch, player, target and ToT geometry, classic restore")
