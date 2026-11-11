-- Tooltip module: anchor, cursor mode, combat rules. Run from the addon root (see INDEX.md).
local combat, shift, unit = false, false, nil
local settings = {}
local registered
local function frame()
    local f = { alpha = 1, scale = 1, points = {}, shown = false, scripts = {}, hooks = {} }
    function f:SetSize() end function f:SetFrameStrata() end function f:EnableMouse() end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:SetScale(s) self.scale = s end function f:GetScale() return self.scale end
    function f:RegisterEvent() end
    function f:SetScript(n, fn) self.scripts[n] = fn end
    function f:HookScript(n, fn) self.hooks[n] = fn end
    function f:SetOwner(o, a) self.owner, self.anchorType = o, a; if self.ownerHook then self.ownerHook() end end
    function f:GetEffectiveScale() return self.scale end
    function f:GetUnit() return "name", unit end
    function f:GetOwner() return self.owner end
    function f:SetAlpha(a) self.alpha = a end function f:GetAlpha() return self.alpha end
    function f:Show() self.shown = true end function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    return f
end
UIParent = frame()
GameTooltip = frame()
function CreateFrame() return frame() end
function InCombatLockdown() return combat end
function IsShiftKeyDown() return shift end function IsControlKeyDown() return false end function IsAltKeyDown() return false end
local hooked
local mouseover = true
function UnitExists() return mouseover end
local now = 0
function GetTime() return now end
function GetCursorPosition() return 500, 300 end
function hooksecurefunc(a, b, c)
    if type(a) == "table" then
        if b == "SetOwner" then a.ownerHook = c else a.fadeHook = c end
    else hooked = b end
end
local ui = { russian = false, Settings = function() return settings end,
    OptionBinding = function() return "binding" end,
    RegisterEditFrame = function(f, label, category, slider) registered = { f, label, category, slider } end }
assert(loadfile("Tooltip.lua"))("ForeverUI", ui)

assert(registered and registered[1] == ui.Tooltip.anchor and registered[3] == "tooltip" and registered[4] == "binding")
assert(ui.Tooltip.anchor.points[1][1] == "BOTTOMRIGHT", "default position")

-- anchor mode
hooked(GameTooltip, UIParent)
assert(GameTooltip.points[1][1] == "BOTTOMRIGHT" and GameTooltip.points[1][2] == ui.Tooltip.anchor)
-- cursor mode
settings.tooltipPosition = "cursor"
hooked(GameTooltip, UIParent)
assert(GameTooltip.anchorType == "ANCHOR_NONE")
local p = GameTooltip.points[1]
assert(p[1] == "TOPLEFT" and p[2] == UIParent and p[3] == "BOTTOMLEFT" and p[4] == 516 and p[5] == 284, "default cursor offset")
settings.tooltipCursorX, settings.tooltipCursorY = -30, 10
GameTooltip.hooks.OnUpdate(GameTooltip)
p = GameTooltip.points[1]
assert(p[4] == 470 and p[5] == 310, "custom offset follows cursor")
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
GameTooltip.points = {}
GameTooltip.hooks.OnUpdate(GameTooltip)
assert(#GameTooltip.points == 0, "other SetOwner stops following")
settings.tooltipCursorX, settings.tooltipCursorY = nil, nil
hooked(GameTooltip, UIParent)
-- scale
settings.tooltipScale = 150
hooked(GameTooltip, UIParent)
assert(GameTooltip.scale == 1.5 and ui.Tooltip.anchor.scale == 1.5)

-- combat rules
local function show() GameTooltip:Show(); GameTooltip.hooks.OnShow(GameTooltip); return GameTooltip.shown end
combat, unit = true, "mouseover"
settings.tooltipCombat = "show"; assert(show())
settings.tooltipCombat = "units"; assert(not show(), "unit tooltip hidden in combat")
unit = nil; assert(show(), "non-unit tooltip kept in units mode")
settings.tooltipCombat = "all"; assert(not show())
settings.tooltipCombatModifier = "shift"; shift = true; assert(show(), "modifier reveals")
shift = false; assert(not show())
combat = false; assert(show(), "always shown out of combat")

-- fade-out
settings.tooltipCombat = "show"
GameTooltip:Show()
settings.tooltipFade = "default"; GameTooltip.fadeHook(GameTooltip); assert(GameTooltip.shown and GameTooltip.alpha == 1)
settings.tooltipFade = "instant"; GameTooltip.fadeHook(GameTooltip); assert(not GameTooltip.shown, "instant hides")
GameTooltip:Show()
settings.tooltipFade, settings.tooltipFadeTime = "custom", 1
GameTooltip.fadeHook(GameTooltip)
now = 0.5; GameTooltip.hooks.OnUpdate(GameTooltip)
assert(GameTooltip.shown and math.abs(GameTooltip.alpha - 0.5) < 1e-9, "half faded")
now = 1.2; GameTooltip.hooks.OnUpdate(GameTooltip)
assert(not GameTooltip.shown and GameTooltip.alpha == 1, "hidden and alpha restored")
GameTooltip:Show(); GameTooltip.fadeHook(GameTooltip)
now = 1.7; GameTooltip.hooks.OnUpdate(GameTooltip)
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
assert(GameTooltip.alpha == 1, "new owner cancels fade")

-- world unit tooltips fade without FadeOut: detected through the lost mouseover
settings.tooltipFade = "instant"
GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
unit, mouseover = "mouseover", true
GameTooltip:Show(); GameTooltip.hooks.OnTooltipSetUnit(GameTooltip)
GameTooltip.hooks.OnUpdate(GameTooltip)
assert(GameTooltip.shown, "unit still hovered")
mouseover = false
GameTooltip.hooks.OnUpdate(GameTooltip)
assert(not GameTooltip.shown, "instant hide when the unit is lost")
settings.tooltipFade, settings.tooltipFadeTime = "custom", 1
GameTooltip:SetOwner(UIParent, "ANCHOR_NONE"); mouseover = true
GameTooltip:Show(); GameTooltip.hooks.OnTooltipSetUnit(GameTooltip)
mouseover = false; now = 10
GameTooltip.hooks.OnUpdate(GameTooltip)
now = 10.5; GameTooltip.hooks.OnUpdate(GameTooltip)
assert(GameTooltip.shown and math.abs(GameTooltip.alpha - 0.5) < 1e-9, "custom fade after unit lost")
print("Tooltip OK")
