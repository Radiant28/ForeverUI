-- SpellID.lua: spell ID line in tooltips and spell drop into input boxes. Run from the addon root (see INDEX.md).
local settings = {}
local hooks = {}

local function fontString()
    local f = { r = 1, g = 1, b = 1, shown = false }
    function f:SetText(t) self.text = t end function f:GetText() return self.text end
    function f:SetTextColor(r, g, b) self.r, self.g, self.b = r, g, b end
    function f:GetTextColor() return self.r, self.g, self.b end
    function f:Show() self.shown = true end function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    return f
end

local function tooltip(name)
    local t = { name = name, lines = 0, scripts = {}, wraps = {} }
    _G[name] = t
    for i = 1, 30 do
        _G[name .. "TextLeft" .. i] = fontString()
        _G[name .. "TextRight" .. i] = fontString()
    end
    function t:GetName() return self.name end
    function t:NumLines() return self.lines end
    function t:HookScript(n, fn)
        local old = self.scripts[n]
        self.scripts[n] = function(...) if old then old(...) end fn(...) end
    end
    function t:ClearLines()
        for i = 1, 30 do
            _G[name .. "TextLeft" .. i]:SetText(nil); _G[name .. "TextLeft" .. i]:Hide()
            _G[name .. "TextRight" .. i]:SetText(nil); _G[name .. "TextRight" .. i]:Hide()
        end
        self.lines, self.wraps = 0, {}
        if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
    end
    function t:AddLine(text, r, g, b, wrap)
        self.lines = self.lines + 1
        local left = _G[name .. "TextLeft" .. self.lines]
        left:SetText(text); left:SetTextColor(r or 1, g or 0.82, b or 0); left:Show()
        self.wraps[self.lines] = wrap
    end
    function t:AddDoubleLine(a, b2, r, g, b, rr, rg, rb)
        self:AddLine(a, r, g, b)
        local right = _G[name .. "TextRight" .. self.lines]
        right:SetText(b2); right:SetTextColor(rr or 1, rg or 1, rb or 1); right:Show()
    end
    function t:Show() self.shownCount = (self.shownCount or 0) + 1 end
    function t:GetSpell() return self.spell[1], self.spell[2], self.spell[3] end
    function t:SetUnitAura() end function t:SetUnitBuff() end function t:SetUnitDebuff() end
    return t
end

GameTooltip = tooltip("GameTooltip")
ItemRefTooltip = tooltip("ItemRefTooltip")
function hooksecurefunc(a, b, c)
    if type(a) == "table" then hooks[a.name .. b] = c else hooks[a] = b end
end
function ChatEdit_InsertLink() end

local cursor, cleared = nil, 0
function GetCursorInfo() if cursor then return unpack(cursor) end end
function ClearCursor() cursor = nil; cleared = cleared + 1 end
local links = { [5] = "|cff71d5ff|Hspell:42833|h[Fireball]|h|r", Frostbolt = "|cff71d5ff|Hspell:116|h[Frostbolt]|h|r" }
function GetSpellLink(a) return links[a] end
function GetSpellInfo(id) if id == 42833 then return "Fireball" end if id == 1459 then return "Arcane Intellect" end end
function GetSpellName() return "Fireball" end
function GetMacroSpell() return "Frostbolt" end
function GetCompanionInfo(kind, index) if kind == "MOUNT" and index == 2 then return 1, "Horse", 458 end end
function GetItemInfo() return "Potion" end
function UnitAura() return "Arcane Intellect", nil, nil, 0, nil, 0, 0, "player", nil, nil, 1459 end
UnitBuff, UnitDebuff = UnitAura, UnitAura
local focus
function GetCurrentKeyBoardFocus() return focus end

local ui = { Settings = function() return settings end }
assert(loadfile("SpellID.lua"))("ForeverUI", ui)
local SID = ui.SpellID
assert(hooks.ChatEdit_InsertLink, "shift-click hook")

-- tooltip: spell, rebuilt with the ID under the name
local function fill(t, rows)
    t:ClearLines()
    for _, row in ipairs(rows) do
        if row[2] then t:AddDoubleLine(row[1], row[2]) else t:AddLine(row[1], 1, 1, 1, true) end
    end
end
fill(GameTooltip, { { "Fireball", "Rank 16" }, { "400 Mana", "35 yd range" }, { "Hurls a fiery ball." } })
GameTooltip.spell = { "Fireball", "Rank 16", 42833 }
GameTooltip.scripts.OnTooltipSetSpell(GameTooltip)
assert(GameTooltip:NumLines() == 4, "one line added")
assert(GameTooltipTextLeft1:GetText() == "Fireball" and GameTooltipTextRight1:GetText() == "Rank 16", "name line kept")
assert(GameTooltipTextLeft2:GetText():find("ID: ", 1, true) and GameTooltipTextLeft2:GetText():find("42833", 1, true), "ID under name")
assert(GameTooltipTextLeft3:GetText() == "400 Mana" and GameTooltipTextRight3:GetText() == "35 yd range", "double line moved")
assert(GameTooltipTextLeft4:GetText() == "Hurls a fiery ball." and GameTooltip.wraps[4], "description kept wrapped")
-- second event on the same tooltip does not add a second line
GameTooltip.scripts.OnTooltipSetSpell(GameTooltip)
assert(GameTooltip:NumLines() == 4, "no duplicate")

-- no ID from GetSpell: falls back to the spell link by name
fill(GameTooltip, { { "Frostbolt" } })
GameTooltip.spell = { "Frostbolt", "", nil }
GameTooltip.scripts.OnTooltipSetSpell(GameTooltip)
assert(GameTooltipTextLeft2:GetText():find("116", 1, true), "ID by name")

-- bottom placement
settings.tooltipSpellIdPlace = "bottom"
fill(GameTooltip, { { "Fireball", "Rank 16" }, { "Hurls a fiery ball." } })
GameTooltip.spell = { "Fireball", "Rank 16", 42833 }
GameTooltip.scripts.OnTooltipSetSpell(GameTooltip)
assert(GameTooltipTextLeft3:GetText():find("42833", 1, true) and GameTooltipTextLeft2:GetText() == "Hurls a fiery ball.", "bottom")
settings.tooltipSpellIdPlace = nil

-- aura tooltip
fill(GameTooltip, { { "Arcane Intellect" }, { "Increases Intellect by 60." }, { "59 min" } })
hooks.GameTooltipSetUnitAura(GameTooltip, "player", 1, "HELPFUL")
assert(GameTooltipTextLeft2:GetText():find("1459", 1, true) and GameTooltipTextLeft4:GetText() == "59 min", "aura ID")
-- turned off
settings.tooltipSpellId = false
fill(GameTooltip, { { "Arcane Intellect" } })
hooks.GameTooltipSetUnitBuff(GameTooltip, "player", 1)
assert(GameTooltip:NumLines() == 1, "setting off")
settings.tooltipSpellId = nil

-- cursor values
cursor = { "spell", 5, "spell" }
assert(SID.CursorValue() == 42833, "spellbook slot via link")
cursor = { "spell", 5, "spell", 9999 }
assert(SID.CursorValue() == 9999, "4th value wins")
cursor = { "macro", 3 }
assert(SID.CursorValue() == 116, "macro spell")
cursor = { "companion", 2, "MOUNT" }
assert(SID.CursorValue() == 458, "mount")
cursor = { "item", 33447, "|Hitem:33447:0|h" }
assert(SID.CursorValue() == nil and SID.CursorValue(true) == "item:33447", "items only when allowed")

-- edit boxes
local function box()
    local b = { scripts = {}, text = "" }
    function b:EnableMouse(v) self.mouse = v end
    function b:HookScript(n, fn) self.scripts[n] = fn end
    function b:SetText(t) self.text = t end function b:GetText() return self.text end
    function b:SetCursorPosition(p) self.pos = p end
    return b
end
local committed
local single = SID.Attach(box(), { commit = function(_, text) committed = text end })
assert(single.mouse and single.scripts.OnReceiveDrag and single.scripts.OnMouseDown)
single:SetText("old")
cursor = { "spell", 5, "spell" }
single.scripts.OnReceiveDrag(single)
assert(single.text == "42833" and committed == "42833" and cursor == nil and cleared == 1, "drop replaces and clears the cursor")
single.scripts.OnMouseDown(single) -- nothing on the cursor: nothing happens
assert(single.text == "42833" and cleared == 1)

local list = SID.Attach(box(), { list = true })
list:SetText("1459, ")
cursor = { "spell", 5, "spell" }
list.scripts.OnMouseDown(list)
assert(list.text == "1459, 42833", "list appends")
cursor = { "item", 6265 }
list.scripts.OnReceiveDrag(list)
assert(list.text == "1459, 42833" and cursor, "item ignored, cursor kept")
cursor = nil

local named = SID.Attach(box(), { as = "name" })
cursor = { "spell", 5, "spell" }
named.scripts.OnReceiveDrag(named)
assert(named.text == "Fireball", "name mode")

-- shift-click while the box has focus
focus = list
list:SetText("")
hooks.ChatEdit_InsertLink(links.Frostbolt)
assert(list.text == "116", "shift-click inserts the ID")
focus = box()
hooks.ChatEdit_InsertLink(links.Frostbolt)
assert(focus.text == "", "other boxes untouched")

print("SpellID tests passed")
