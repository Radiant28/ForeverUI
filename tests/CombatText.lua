-- Combat text zones, mana colour and "only on units". Run from the addon root (see INDEX.md).
local function object(name)
    local o = { name = name, points = {}, scale = 1, alpha = 1, shown = true, scripts = {}, texts = {} }
    function o:GetName() return self.name end
    function o:SetSize() end function o:SetWidth() end function o:SetHeight() end
    function o:SetFrameStrata() end function o:RegisterEvent() end function o:UnregisterEvent() end
    function o:SetScript(n, fn) self.scripts[n] = fn end
    function o:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function o:ClearAllPoints() self.points = {} end
    function o:SetScale(v) self.scale = v end function o:GetScale() return self.scale end
    function o:SetAlpha(v) self.alpha = v end
    function o:Show() self.shown = true end function o:Hide() self.shown = false end
    function o:IsVisible() return self.shown end
    function o:CreateTexture() return object() end
    function o:CreateFontString() return object() end
    function o:SetTexture() end function o:SetTexCoord() end
    function o:SetFont() return true end function o:SetShadowColor() end function o:SetShadowOffset() end
    function o:SetTextColor(r, g, b) self.color = { r, g, b } end
    function o:SetText(t) self.text = t end
    return o
end
local frames = {}
UIParent = object("UIParent")
function CreateFrame(_, name)
    local f = object(name)
    if name then frames[name] = f end
    return f
end
function IsAddOnLoaded() return false end
function SetCVar() end
function UnitGUID(unit) return unit == "player" and "P" or nil end
function UnitExists() return false end
function GetSpellInfo() return "spell", nil, "Interface\\Icons\\X" end
function GetInventoryItemTexture() end
COMBATLOG_OBJECT_AFFILIATION_MINE = 1
local settings = { editLayout = {} }
local plate
local registered = {}
local ui = { russian = false, Settings = function() return settings end,
    MediaPath = function() return "font.ttf" end, OpenOptions = function() end,
    wfn = { FindCombatTextAnchor = function() return plate end },
    RegisterEditFrame = function(frame, label, category) registered[frame:GetName()] = { label, category } end }
SlashCmdList = {}
assert(loadfile("CombatText.lua"))("ForeverUI", ui)
local driver = frames.ForeverUICombatText
assert(driver, "driver frame")
driver.scripts.OnEvent(driver, "PLAYER_LOGIN")

assert(registered.ForeverUICombatTextOutgoing and registered.ForeverUICombatTextIncoming, "zones in Edit Mode")
local db = settings.combatText
assert(db.colorMana[3] == 1 and db.colorMana[1] < db.colorMana[3], "mana colour is blue")

local function fire(event, ...)
    driver.scripts.OnEvent(driver, "COMBAT_LOG_EVENT_UNFILTERED", 0, event, ...)
end

-- mana restored to the player: incoming zone, blue
fire("SPELL_ENERGIZE", "X", "Caster", 0, "P", "Me", 0, 1234, "Replenish", 8, 500, 0)
assert(driver.scripts.OnUpdate, "text spawned")
db.showMana = false
fire("SPELL_ENERGIZE", "X", "Caster", 0, "P", "Me", 0, 1234, "Replenish", 8, 500, 0)

-- outgoing without a plate: shown on the screen zone unless "only on units"
db.showMana, db.onlyOnUnits = true, false
driver.scripts.OnUpdate = nil
fire("SPELL_DAMAGE", "P", "Me", 0, "T", "Target", 0, 1, "Bolt", 4, 100, 0, 4, 0, 0, 0)
assert(driver.scripts.OnUpdate, "screen text shown")
driver.scripts.OnUpdate = nil
db.onlyOnUnits = true
fire("SPELL_DAMAGE", "P", "Me", 0, "T", "Target", 0, 1, "Bolt", 4, 100, 0, 4, 0, 0, 0)
assert(not driver.scripts.OnUpdate, "dropped when only on units and no plate")
plate = object(); plate.identityName = "Target"
fire("SPELL_DAMAGE", "P", "Me", 0, "T", "Target", 0, 1, "Bolt", 4, 100, 0, 4, 0, 0, 0)
assert(driver.scripts.OnUpdate, "still shown on a plate")

-- a moved zone keeps its saved position when offsets are applied
settings.editLayout.ForeverUICombatTextOutgoing = { position = { -10, -10 } }
local outgoing = frames.ForeverUICombatTextOutgoing
outgoing.points = { { "TOPRIGHT", UIParent, "TOPRIGHT", -10, -10 } }
ui.CombatText.Apply()
assert(outgoing.points[1][1] == "TOPRIGHT", "Apply must not override a moved zone")
settings.editLayout.ForeverUICombatTextOutgoing = nil
ui.CombatText.Apply()
assert(outgoing.points[1][1] == "CENTER", "default position without a saved one")
print("CombatText OK")
