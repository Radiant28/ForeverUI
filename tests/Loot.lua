-- Run from the addon directory (see INDEX.md): loot window skin. The fade-out lends the retail art
-- to a background frame; reopening the window must give the art back its strata and levels, so the
-- opaque art background never covers the loot rows. Also: the card tint does not darken on every update.

local objects = {}
local methods = {}
local function new(kind, parent, name)
    local object = setmetatable({ kind = kind, shown = true, alpha = 1, scale = 1, scripts = {}, children = {},
        regions = {}, strata = "MEDIUM", level = 1, color = { 1, 1, 1, 1 } }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
    objects[#objects + 1] = object
    if parent then object:SetParent(parent) end
    if name then _G[name] = object end
    return object
end
-- Like the client: a reparented frame takes the parent's strata and a level above it; its children
-- keep their offsets. A toplevel window moving to another level carries its children along.
local function shift(frame, strata, delta)
    frame.strata, frame.level = strata, frame.level + delta
    for _, child in ipairs(frame.children) do shift(child, strata, delta) end
end
local function cascade(frame, strata, level) shift(frame, strata, level - frame.level) end
function methods:SetParent(parent)
    if self.parent then
        local list = self.kind == "Texture" and self.parent.regions or self.parent.children
        for i, v in ipairs(list) do if v == self then table.remove(list, i) break end end
    end
    self.parent = parent
    if self.kind == "Texture" or self.kind == "FontString" then
        table.insert(parent.regions, self)
        return
    end
    table.insert(parent.children, self)
    cascade(self, parent.strata, parent.level + 1)
end
function methods:GetParent() return self.parent end
function methods:GetChildren() return unpack(self.children) end
function methods:GetRegions() return unpack(self.regions) end
function methods:SetFrameStrata(strata) cascade(self, strata, self.level) end
function methods:GetFrameStrata() return self.strata end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level end
function methods:Show() local was = self.shown self.shown = true if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local was = self.shown self.shown = false if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:IsVisible() local n = self while n do if not n.shown then return false end n = n.parent end return true end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:HookScript(name, fn)
    local old = self.scripts[name]
    self.scripts[name] = function(...) if old then old(...) end fn(...) end
end
function methods:CreateTexture() return new("Texture", self) end
function methods:IsObjectType(kind) return self.kind == kind end
function methods:SetVertexColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
function methods:GetVertexColor() return unpack(self.color) end
function methods:SetAlpha(a) self.alpha = a end
function methods:GetAlpha() return self.alpha end
function methods:GetEffectiveScale() return 1 end
function methods:SetText(t) self.text = t end
function methods:GetText() return self.text end
function methods:GetTexture() return self.texture end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetTexCoord(...) self.coords = { ... } end
function methods:GetTexCoord() return unpack(self.coords or { 0, 0, 0, 1, 1, 0, 1, 1 }) end
function methods:GetLeft() return 100 end
function methods:GetTop() return 400 end

function CreateFrame(kind, name, parent) return new(kind, parent, name) end
function hooksecurefunc(name, fn)
    local old = _G[name]
    _G[name] = function(...) local r = { old(...) } fn(...) return unpack(r) end
end
local now = 100
function GetTime() return now end
ITEM_QUALITY_COLORS, SlashCmdList = { [1] = { r = 1, g = 1, b = 1 }, [3] = { r = 0, g = 0.44, b = 0.87 } }, {}
local slotInfo = {}
function GetLootSlotInfo(slot) local info = slotInfo[slot] or {} return "icon", "Item", 1, info.quality or 1, info.locked end
LOOTFRAME_NUMBUTTONS = 4

UIParent = new("Frame")
UIParent.strata, UIParent.level = "MEDIUM", 0
LootFrame = new("Frame", UIParent, "LootFrame")
LootFrame:SetFrameStrata("HIGH")
LootFrame.level = 5
local art = new("Frame", LootFrame)
art.level = 6
art.Bg = art:CreateTexture()
art.MetalBorder = new("Frame", art)
art.MetalBorder.level = 7
art.MetalBorder:CreateTexture()
art.MetalBorder.TitleText = new("FontString")
LootFrame.RetailArt = art
for i = 1, LOOTFRAME_NUMBUTTONS do
    local button = new("Button", LootFrame, "LootButton" .. i)
    button.level = 8
    button.slot = i
    button.RetailCard = { Border = new("Texture"), Highlight = new("Texture"), Bg = new("Texture") }
    for _, part in pairs(button.RetailCard) do part.texture, part.coords = "client-card", { 1, 2, 3, 4, 5, 6, 7, 8 } end
    button.RetailIconHover = new("Texture")
    _G["LootButton" .. i .. "IconTexture"] = new("Texture")
    _G["LootButton" .. i .. "Text"] = new("FontString")
    _G["LootButton" .. i .. "Count"] = new("FontString")
end
LootFrameUpButton, LootFrameDownButton = new("Button"), new("Button")
local openLevel = 5
-- The client raises the toplevel loot window when it opens; the level differs between openings.
function LootFrame_Show() cascade(LootFrame, LootFrame.strata, openLevel) LootFrame:Show() end
function LootFrame_UpdateButton(index)
    local card = _G["LootButton" .. index].RetailCard
    if not card.Bg.clientSet then card.Bg:SetVertexColor(0.5, 0.5, 0.5, 1) card.Bg.clientSet = true end
end

local settings = { lootFadeDuration = 0.3 }
local ui = { Settings = function() return settings end }
assert(loadfile("Loot.lua"))("ForeverUI", ui)

local function tick(seconds)
    local step = 0.05
    for _ = 1, math.floor(seconds / step + 0.5) do
        now = now + step
        for _, object in ipairs(objects) do
            local update = object.scripts.OnUpdate
            if update and object:IsVisible() then update(object, step) end
        end
    end
end

local function assertRowsOnTop(where)
    assert(art:GetParent() == LootFrame, where .. ": the art is back in the loot window")
    assert(art:GetFrameStrata() == "HIGH" and art.MetalBorder:GetFrameStrata() == "HIGH", where .. ": art strata restored")
    local base = LootFrame:GetFrameLevel()
    assert(art:GetFrameLevel() == base + 1 and art.MetalBorder:GetFrameLevel() == base + 2, where .. ": art levels restored")
    for i = 1, LOOTFRAME_NUMBUTTONS do
        local button = _G["LootButton" .. i]
        assert(button:GetFrameStrata() == art:GetFrameStrata() and button:GetFrameLevel() > art:GetFrameLevel(),
            where .. ": loot row " .. i .. " is drawn over the art")
    end
end

LootFrame.shown = false                -- closed at login, no fade yet
openLevel = 20                         -- opened and closed while raised high...
LootFrame_Show(LootFrame)
LootFrame:Hide()                       -- fade starts: the art is lent to the background
assert(art:GetParent() ~= LootFrame, "the art fades with the background")
openLevel = 5                          -- ...and reopened lower: the art must not stay at the old level
LootFrame_Show(LootFrame)              -- reopened before the fade ended
assertRowsOnTop("reopened during the fade")
LootFrame:Hide()
tick(1)                                -- fade finished
LootFrame_Show(LootFrame)
assertRowsOnTop("reopened after the fade")
LootFrame:Hide()
LootFrame:Hide()                       -- a second hide while the art is still lent changes nothing
tick(1)
LootFrame_Show(LootFrame)
assertRowsOnTop("double hide")

-- WoW Forever cards: atlas cells, quality outline, dim outline for locked slots, shade over the window.
local card = LootButton1.RetailCard
local cells = ui.Loot.cells
local function cellOf(region)
    for name, c in pairs(cells) do
        if region.texture == ui.Loot.atlas and math.abs(region.coords[3] - c[3] / 512) < 1e-6 then return name end
    end
end
for _ = 1, 5 do LootFrame_UpdateButton(1) end
assert(cellOf(card.Bg) == "bg" and cellOf(card.Highlight) == "glow" and cellOf(card.Border) == "stroke", "Forever card cells")
local r, g, b = card.Bg:GetVertexColor()
assert(r == 1 and math.abs(g - 0.86) < 1e-6, "common items: warm card, not darkened by repeated updates")
slotInfo[1] = { quality = 3 }
LootFrame_UpdateButton(1)
r, g, b = card.Border:GetVertexColor()
assert(r == 0 and math.abs(b - 0.87) < 1e-6, "rare items get a blue outline")
slotInfo[1] = { quality = 3, locked = 1 }
LootFrame_UpdateButton(1)
assert(cellOf(card.Border) == "strokeDim", "locked slots get the dim outline")
settings.lootQualityBorder = false
LootFrame_UpdateButton(1)
r = card.Border:GetVertexColor()
assert(math.abs(r - 0.86) < 1e-6, "quality outline can be turned off")
local shade
for _, region in ipairs(art.regions) do if region.texture == ui.Loot.atlas then shade = region end end
assert(shade and shade.shown and math.abs(shade.coords[3] - cells.shade[3] / 512) < 1e-6, "window shade")

-- Off: the client's card textures come back; the old warm tint is applied once.
settings.lootForeverCards = false
ui.Loot.Apply()
assert(card.Bg.texture == "client-card" and card.Border.texture == "client-card" and card.Bg.coords[8] == 8,
    "client textures and coordinates restored")
assert(not shade.shown, "no shade with client cards")
card.Bg:SetVertexColor(0.5, 0.5, 0.5, 1)
for _ = 1, 5 do LootFrame_UpdateButton(1) end
r, g, b = card.Bg:GetVertexColor()
assert(math.abs(g - 0.5 * 0.83) < 0.001 and math.abs(b - 0.5 * 0.65) < 0.001, "the client card tint does not darken on each update")

print("Loot OK: art strata and levels restored after the fade, rows over the art, Forever cards (quality, locked, shade), client cards restored")
