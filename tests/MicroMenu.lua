-- Micro menu (MicroMenu.lua) on mocks: in Retail the Store and Adventure Guide buttons get the flat icons of
-- Retail-MicroExtra (also when the client re-sets the store textures later), Classic gives the colour icons back.
-- Run from the addon root (see INDEX.md).
local noop = function() end
local P = {}
P.__index = function(_, k)
    if P[k] then return P[k] end
    if type(k) == "string" and k:match("^%u") then return noop end
end
local function new(name, parent)
    local o = setmetatable({ name = name, parent = parent, points = {}, w = 28, h = 58, alpha = 1, shown = true,
        insets = { 0, 0, 18, 0 } }, P)
    if name then _G[name] = o end
    return o
end
function P:SetPoint(...) self.points[#self.points + 1] = { ... } end
function P:ClearAllPoints() self.points = {} end
function P:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p, 1, 5) end end
function P:GetNumPoints() return #self.points end
function P:SetAllPoints(r) self.points = { { "ALL", r } } end
function P:SetSize(w, h) self.w, self.h = w, h end
function P:GetSize() return self.w, self.h end
function P:GetName() return self.name end
function P:GetParent() return self.parent end
function P:SetAlpha(a) self.alpha = a end
function P:SetTexture(t) self.texture = t end
function P:GetTexture() return self.texture end
function P:SetTexCoord(...) self.coords = { ... } end
function P:SetDesaturated(d) self.desaturated = d and true or false end
function P:SetVertexColor(...) self.color = { ... } end
function P:GetHitRectInsets() return unpack(self.insets) end
function P:SetHitRectInsets(...) self.insets = { ... } end
function P:CreateTexture() return new(nil, self) end
function P:SetScript(n, fn) self.scripts = rawget(self, "scripts") or {}; self.scripts[n] = fn end
function P:RegisterEvent() end
function P:UnregisterEvent() end
function P:SetHighlightTexture(t) self.highlight = t end
for _, state in ipairs({ "Normal", "Pushed", "Disabled" }) do
    P["Set" .. state .. "Texture"] = function(self, path)
        local key = state:lower()
        self[key] = rawget(self, key) or new(nil, self)
        self[key].texture = path
    end
    P["Get" .. state .. "Texture"] = function(self) return rawget(self, state:lower()) end
end
function CreateFrame(_, name, parent) return new(name, parent) end
function hooksecurefunc(object, method, fn)
    local old = object[method]
    object[method] = function(...) old(...); fn(...) end
end
function InCombatLockdown() return false end
function UnitFactionGroup() return "Alliance" end
SlashCmdList = {}

local settings = { barLayout = "classic" }
local ui = { Settings = function() return settings end, ApplySlotEdge = noop }
UIParent = new("UIParent")
local names = { "Character", "Spellbook", "Talent", "Achievement", "QuestLog", "Socials", "PVP", "LFD",
    "EncounterJournal", "MainMenu", "Help" }
for index, name in ipairs(names) do
    local button = new(name .. "MicroButton", UIParent)
    if index > 1 then button:SetPoint("BOTTOMLEFT", _G[names[index - 1] .. "MicroButton"], "BOTTOMRIGHT", -3, 0) end
end

local login
local frames = {}
local create = CreateFrame
function CreateFrame(...) local f = create(...); frames[#frames + 1] = f; return f end
assert(loadfile("MicroMenu.lua"))("ForeverUI", ui)
frames[1].scripts.OnEvent(frames[1], "PLAYER_LOGIN")
local watch = frames[2]

-- The Store button appears later (client patch) and is picked up by the watcher.
local store = new("StoreMicroButton", UIParent)
store:SetPoint("BOTTOMLEFT", HelpMicroButton, "BOTTOMRIGHT", -3, 0)
watch.scripts.OnUpdate(watch, 1.1)

local extra = "Retail%-MicroExtra"
settings.barLayout = "retail"
ui.MicroMenu.ApplyLayout()
for _, button in ipairs({ StoreMicroButton, EncounterJournalMicroButton }) do
    local normal = button:GetNormalTexture()
    assert(normal.texture:find(extra), button.name .. ": flat Retail icon")
    assert(not normal.desaturated, button.name .. ": not a desaturated colour icon")
    assert(button.w == 24 and button.h == 32, button.name .. ": Retail size")
    assert(button.highlight.texture:find(extra), button.name .. ": Retail mouse-over")
end
local store1 = StoreMicroButton:GetNormalTexture().coords
assert(store1[3] == 1 / 128 and store1[4] == 53 / 128, "store: first row of the extra sheet")
local guide = EncounterJournalMicroButton:GetPushedTexture().coords
assert(guide[1] == 81 / 256 and guide[3] == 55 / 128, "adventure guide: pressed cell, second row")
-- The client re-sets the store texture later: it stays the Retail icon.
StoreMicroButton:SetNormalTexture("Interface\\Store\\Stock")
assert(StoreMicroButton:GetNormalTexture().texture:find(extra), "late client texture replaced in Retail")
-- Spacing: 4 px chained after the Help button.
local _, relative, _, x = StoreMicroButton:GetPoint(1)
assert(relative == HelpMicroButton and x == 4, "store chained with the Retail spacing")

settings.barLayout = "classic"
ui.MicroMenu.ApplyLayout()
assert(StoreMicroButton:GetNormalTexture().texture:find("Micro%-Color"), "Classic colour icon back")
StoreMicroButton:SetNormalTexture("Interface\\Store\\Stock")
assert(StoreMicroButton:GetNormalTexture().texture:find("Micro%-Color"), "late client texture in Classic")
assert(EncounterJournalMicroButton.w == 28, "Classic size back")

print("MicroMenu OK: Retail Store and Adventure Guide icons, late store texture, spacing, Classic restore")
